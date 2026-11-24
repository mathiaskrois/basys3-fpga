// UART receiver, 8N1, LSB first.
// Finds the falling edge of the start bit, waits half a bit to reach its
// middle, then samples every CLKS_PER_BIT clocks. `rx` must already be
// synchronised to `clk`.
`default_nettype none
module uart_rx #(
    parameter CLKS_PER_BIT = 108          // 100 MHz / 921600 baud
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid               // one-cycle pulse per byte
);
    localparam S_IDLE = 2'd0, S_START = 2'd1, S_DATA = 2'd2, S_STOP = 2'd3;

    reg [1:0]  state = S_IDLE;
    reg [15:0] cnt   = 16'd0;
    reg [2:0]  bitn  = 3'd0;
    reg [7:0]  sh    = 8'd0;

    always @(posedge clk) begin
        valid <= 1'b0;
        if (rst) begin
            state <= S_IDLE;
        end else begin
            case (state)
            S_IDLE:
                if (!rx) begin
                    cnt   <= CLKS_PER_BIT / 2 - 1;
                    state <= S_START;
                end
            S_START:
                if (cnt == 0) begin
                    if (!rx) begin                 // still low: real start bit
                        cnt   <= CLKS_PER_BIT - 1;
                        bitn  <= 3'd0;
                        state <= S_DATA;
                    end else
                        state <= S_IDLE;           // glitch
                end else
                    cnt <= cnt - 1'b1;
            S_DATA:
                if (cnt == 0) begin
                    sh  <= {rx, sh[7:1]};
                    cnt <= CLKS_PER_BIT - 1;
                    if (bitn == 3'd7) state <= S_STOP;
                    bitn <= bitn + 1'b1;
                end else
                    cnt <= cnt - 1'b1;
            S_STOP:
                if (cnt == 0) begin
                    if (rx) begin                  // valid stop bit
                        data  <= sh;
                        valid <= 1'b1;
                    end
                    state <= S_IDLE;
                end else
                    cnt <= cnt - 1'b1;
            endcase
        end
    end
endmodule
`default_nettype wire
