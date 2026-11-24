// Logic-analyzer core: SUMP command parser + configuration registers +
// capture engine + ID/metadata replies, with byte-stream interfaces.
// `top` wraps this with UARTs; the Verilator sigrok bridge drives it directly.
`default_nettype none
module la_core #(
    parameter AW = 17
) (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] probe_ext,          // external channels, already synchronised
    input  wire [7:0] probe_test,         // built-in test signals
    input  wire       test_sw,            // 1 = sample the test signals
    input  wire       force_trig,         // manual trigger (btnC), synchronised
    input  wire [7:0] rx_data,
    input  wire       rx_valid,
    output wire [7:0] tx_data,
    output wire       tx_valid,
    input  wire       tx_ready,
    output wire [7:0] live,               // what is being sampled right now
    output wire [1:0] state,              // 0 idle, 1 armed, 2 post-trigger, 3 sending
    output wire       test_mode
);
    // ---------------- command parser
    wire        s_valid, l_valid;
    wire [7:0]  s_cmd, l_cmd;
    wire [31:0] l_arg;
    sump_cmd u_cmd (
        .clk(clk), .rst(rst), .rx_data(rx_data), .rx_valid(rx_valid),
        .short_valid(s_valid), .short_cmd(s_cmd),
        .long_valid(l_valid), .long_cmd(l_cmd), .long_arg(l_arg));

    // ---------------- configuration registers
    reg [23:0] divider    = 24'd0;
    reg [15:0] read_cnt   = 16'd255;
    reg [15:0] delay_cnt  = 16'd255;
    reg [31:0] flags      = 32'd0;
    reg [31:0] trig_mask  = 32'd0;
    reg [31:0] trig_value = 32'd0;
    reg [3:0]  trig_start = 4'b0001;

    wire [1:0] l_stage = l_cmd[3:2];
    always @(posedge clk) begin
        if (rst) begin
            divider <= 24'd0; read_cnt <= 16'd255; delay_cnt <= 16'd255; flags <= 32'd0;
            trig_mask <= 32'd0; trig_value <= 32'd0; trig_start <= 4'b0001;
        end else if (l_valid) begin
            case (l_cmd)
            8'h80: divider <= l_arg[23:0];
            8'h81: begin read_cnt <= l_arg[15:0]; delay_cnt <= l_arg[31:16]; end
            8'h82: flags <= l_arg;
            default:
                if (l_cmd[7:4] == 4'hC)
                    case (l_cmd[1:0])
                    2'd0: trig_mask [l_stage*8 +: 8] <= l_arg[7:0];
                    2'd1: trig_value[l_stage*8 +: 8] <= l_arg[7:0];
                    2'd2: trig_start[l_stage]        <= l_arg[27];
                    default: ;
                    endcase
            endcase
        end
    end

    wire cmd_reset = s_valid && s_cmd == 8'h00;
    wire cmd_run   = s_valid && s_cmd == 8'h01;
    wire cmd_id    = s_valid && s_cmd == 8'h02;
    wire cmd_meta  = s_valid && s_cmd == 8'h04;

    // ---------------- sample source
    assign test_mode = test_sw | flags[11];          // flags bit 11 = internal test mode
    wire [7:0] sample = test_mode ? probe_test : probe_ext;
    assign live = sample;

    // ---------------- capture
    wire [7:0] cap_data;
    wire       cap_valid;
    wire       meta_valid;
    wire [7:0] meta_data;
    capture #(.AW(AW)) u_cap (
        .clk(clk), .rst(rst), .sample(sample),
        .divider(divider), .read_cnt(read_cnt), .delay_cnt(delay_cnt),
        .trig_mask(trig_mask), .trig_value(trig_value), .trig_start(trig_start),
        .arm(cmd_run), .abort(cmd_reset), .force_trig(force_trig),
        .tx_data(cap_data), .tx_valid(cap_valid), .tx_ready(tx_ready && !meta_valid),
        .state(state));

    // ---------------- ID / metadata replies
    sump_meta #(.AW(AW)) u_meta (
        .clk(clk), .rst(rst), .send_id(cmd_id), .send_meta(cmd_meta),
        .data(meta_data), .valid(meta_valid), .ready(tx_ready));

    assign tx_valid = meta_valid | cap_valid;
    assign tx_data  = meta_valid ? meta_data : cap_data;
endmodule
`default_nettype wire
