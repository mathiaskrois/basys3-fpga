// SUMP command parser.
// Bytes with bit 7 clear are 1-byte ("short") commands. Bytes with bit 7 set
// start a 5-byte ("long") command: opcode + 32-bit argument, least-significant
// byte first. The host sends reset (0x00) five times in a row, which always
// resynchronises us because a long command consumes at most 4 more bytes.
`default_nettype none
module sump_cmd (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,
    output reg         short_valid,
    output reg  [7:0]  short_cmd,
    output reg         long_valid,
    output reg  [7:0]  long_cmd,
    output reg  [31:0] long_arg
);
    reg [2:0]  n   = 3'd0;     // argument bytes received so far (0 = waiting for opcode)
    reg [7:0]  op  = 8'd0;
    reg [31:0] arg = 32'd0;

    always @(posedge clk) begin
        short_valid <= 1'b0;
        long_valid  <= 1'b0;
        if (rst) begin
            n <= 3'd0;
        end else if (rx_valid) begin
            if (n == 3'd0) begin
                if (rx_data[7]) begin
                    op <= rx_data;
                    n  <= 3'd1;
                end else begin
                    short_cmd   <= rx_data;
                    short_valid <= 1'b1;
                end
            end else begin
                arg <= {rx_data, arg[31:8]};
                if (n == 3'd4) begin
                    long_cmd   <= op;
                    long_arg   <= {rx_data, arg[31:8]};
                    long_valid <= 1'b1;
                    n          <= 3'd0;
                end else
                    n <= n + 1'b1;
            end
        end
    end
endmodule
`default_nettype wire
