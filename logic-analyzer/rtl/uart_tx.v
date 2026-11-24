// UART transmitter, 8N1, LSB first.
// A byte is accepted on any clock where `start` is high and `busy` is low.
`default_nettype none
module uart_tx #(
    parameter CLKS_PER_BIT = 108
) (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data,
    input  wire       start,
    output wire       tx,
    output wire       busy
);
    reg [9:0]  sh    = 10'h3FF;   // {stop, data[7:0], start}, shifted out LSB first
    reg [3:0]  left  = 4'd0;      // bits still to send
    reg [15:0] cnt   = 16'd0;

    assign tx   = sh[0];
    assign busy = (left != 0);

    always @(posedge clk) begin
        if (rst) begin
            sh   <= 10'h3FF;
            left <= 4'd0;
        end else if (!busy) begin
            if (start) begin
                sh   <= {1'b1, data, 1'b0};
                left <= 4'd10;
                cnt  <= CLKS_PER_BIT - 1;
            end
        end else if (cnt == 0) begin
            sh   <= {1'b1, sh[9:1]};
            left <= left - 1'b1;
            cnt  <= CLKS_PER_BIT - 1;
        end else
            cnt <= cnt - 1'b1;
    end
endmodule
`default_nettype wire
