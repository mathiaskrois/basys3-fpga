// Capture engine: circular sample buffer, sequential trigger, and readback.
//
//  IDLE --arm--> ARMED: record every sample into a ring buffer and look for
//                the trigger. Stages are checked in order (0,1,2,3); a stage
//                matches when (sample ^ value) & mask == 0, so mask 0 matches
//                at once. A matching stage with its START bit set fires the
//                trigger; otherwise the next stage is checked from the next
//                sample on. force_trig (btnC) fires it at the next sample.
//                Triggers are ignored until the pre-trigger part of the
//                window has been filled since arming.
//        ARMED --trigger--> POST: record (delay_cnt+1)*4 samples, counting
//                the trigger sample itself.
//        POST --done--> DUMP: send (read_cnt+1)*4 samples, NEWEST FIRST, as
//                the sigrok OLS driver expects.
//  `abort` (the SUMP reset command) returns to IDLE from any state.
`default_nettype none
module capture #(
    parameter AW = 17
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  sample,
    input  wire [23:0] divider,           // sample every divider+1 clocks
    input  wire [15:0] read_cnt,          // (read_cnt+1)*4 samples sent back
    input  wire [15:0] delay_cnt,         // (delay_cnt+1)*4 samples after trigger
    input  wire [31:0] trig_mask,         // 4 stages x 8 bits, stage 0 in [7:0]
    input  wire [31:0] trig_value,
    input  wire [3:0]  trig_start,        // START bit per stage
    input  wire        arm,
    input  wire        abort,
    input  wire        force_trig,
    output reg  [7:0]  tx_data,
    output reg         tx_valid,
    input  wire        tx_ready,
    output reg  [1:0]  state
);
    localparam S_IDLE = 2'd0, S_ARMED = 2'd1, S_POST = 2'd2, S_DUMP = 2'd3;
    localparam [18:0] MEM_SAMPLES = 19'd1 << AW;

    initial begin state = S_IDLE; tx_valid = 1'b0; end

    // ---- sample memory: one write port, one registered read port.
    // Built as 2^(AW-15) banks of 32K x 8 so that every RAMB36 is used in its
    // native 32K x 1 mode: no RAMB36 cascades (an openXC7 trouble spot).
    // Requires AW >= 16.
    localparam NB = 1 << (AW - 15);
    reg  [AW-1:0]   wptr = 0;
    reg  [AW-1:0]   rptr = 0;
    reg  [AW-16:0]  rbank = 0;            // bank of the word now on the read bus
    wire [8*NB-1:0] qbus;
    reg             we;
    genvar b;
    generate for (b = 0; b < NB; b = b + 1) begin : bank
        reg [7:0] m [0:32767];
        reg [7:0] q;
`ifdef SIMULATION
        integer k;
        initial for (k = 0; k < 32768; k = k + 1) m[k] = 8'h00;
`endif
        always @(posedge clk) begin
            if (we && wptr[AW-1:15] == b) m[wptr[14:0]] <= sample;
            q <= m[rptr[14:0]];
        end
        assign qbus[b*8 +: 8] = q;
    end endgenerate
    always @(posedge clk) rbank <= rptr[AW-1:15];
    wire [7:0] rdata = qbus[rbank*8 +: 8];

    // ---- sample-rate divider
    reg  [23:0] div_cnt = 0;
    wire        sample_en = (div_cnt == 0);

    // ---- trigger stage selection
    reg  [1:0] stg = 0;
    wire [7:0] cur_mask  = trig_mask [stg*8 +: 8];
    wire [7:0] cur_value = trig_value[stg*8 +: 8];
    wire       stg_match = (((sample ^ cur_value) & cur_mask) == 8'd0);
    reg        forced = 1'b0;

    // ---- counts, clamped to the memory size. Registered: the configuration
    // only changes between captures, and this keeps the arithmetic out of the
    // timing-critical trigger path. (Arming happens many clocks after the
    // last configuration command, so the one-cycle delay never matters.)
    wire [18:0] post_req = ({3'd0, delay_cnt} + 19'd1) << 2;
    wire [18:0] read_req = ({3'd0, read_cnt}  + 19'd1) << 2;
    reg  [18:0] post_total = 19'd4, read_total = 19'd4, pre_total = 19'd0;
    always @(posedge clk) begin
        post_total <= (post_req > MEM_SAMPLES) ? MEM_SAMPLES : post_req;
        read_total <= (read_req > MEM_SAMPLES) ? MEM_SAMPLES : read_req;
        // The trigger is only looked for once the pre-trigger part of the
        // window has been filled since arming, so a capture never contains
        // stale data from an earlier run.
        pre_total  <= (read_total > post_total) ? read_total - post_total : 19'd0;
    end
    reg  [18:0] fill = 0;                 // samples recorded since arming (saturates)
    wire        pre_full = (fill >= pre_total);
    reg  [18:0] left = 0;                 // samples still to record / send
    reg  [1:0]  ph   = 0;                 // dump phase

    always @(*) we = sample_en && (state == S_ARMED || state == S_POST);

    always @(posedge clk) begin
        if (rst || abort) begin
            state    <= S_IDLE;
            tx_valid <= 1'b0;
            forced   <= 1'b0;
        end else if (arm) begin
            state    <= S_ARMED;
            stg      <= 2'd0;
            div_cnt  <= 24'd0;
            fill     <= 19'd0;
            forced   <= 1'b0;
            tx_valid <= 1'b0;
        end else begin
            if (state == S_ARMED || state == S_POST)
                div_cnt <= sample_en ? divider : div_cnt - 1'b1;

            case (state)
            S_ARMED: begin
                if (force_trig) forced <= 1'b1;
                if (sample_en) begin
                    wptr <= wptr + 1'b1;
                    if (!pre_full) begin
                        fill <= fill + 1'b1;               // still filling the pre-trigger window
                    end else if (forced || force_trig || (stg_match && trig_start[stg])) begin
                        state <= S_POST;
                        left  <= post_total - 1'b1;     // trigger sample already stored
                        if (post_total == 19'd1) begin  // cannot happen (min 4), kept for safety
                            state <= S_DUMP; rptr <= wptr; left <= read_total; ph <= 2'd0;
                        end
                    end else if (stg_match && stg != 2'd3)
                        stg <= stg + 1'b1;
                end
            end
            S_POST:
                if (sample_en) begin
                    wptr <= wptr + 1'b1;
                    left <= left - 1'b1;
                    if (left == 19'd1) begin
                        state <= S_DUMP;
                        rptr  <= wptr;                  // newest sample = the one written now
                        left  <= read_total;
                        ph    <= 2'd0;
                    end
                end
            S_DUMP:
                case (ph)
                2'd0: ph <= 2'd1;                       // mem[rptr] being read
                2'd1: begin
                    tx_data  <= rdata;
                    tx_valid <= 1'b1;
                    ph       <= 2'd2;
                end
                default:
                    if (tx_ready) begin
                        tx_valid <= 1'b0;
                        rptr     <= rptr - 1'b1;
                        left     <= left - 1'b1;
                        ph       <= 2'd0;
                        if (left == 19'd1) state <= S_IDLE;
                    end
                endcase
            default: ;
            endcase
        end
    end
endmodule
`default_nettype wire
