// UART loopback: every byte value 0..255 through uart_tx -> uart_rx at 921600 baud.
`timescale 1ns/1ps
module tb_uart;
    reg clk = 0;
    always #5 clk = ~clk;                       // 100 MHz

    reg  [7:0] txd;
    reg        start = 0;
    wire       line, busy;
    wire [7:0] rxd;
    wire       rxv;

    uart_tx #(.CLKS_PER_BIT(108)) u_tx (.clk(clk), .rst(1'b0), .data(txd), .start(start), .tx(line), .busy(busy));
    uart_rx #(.CLKS_PER_BIT(108)) u_rx (.clk(clk), .rst(1'b0), .rx(line), .data(rxd), .valid(rxv));

    integer i, errors = 0, got = 0;
    reg [7:0] expect_q [0:255];

    always @(posedge clk) if (rxv) begin
        if (rxd !== expect_q[got]) begin
            $display("FAIL: byte %0d got %02x expected %02x", got, rxd, expect_q[got]);
            errors = errors + 1;
        end
        got = got + 1;
    end

    initial begin
        repeat (20) @(posedge clk);
        for (i = 0; i < 256; i = i + 1) begin
            expect_q[i] = i[7:0] ^ 8'h5A;
            @(posedge clk); while (busy) @(posedge clk);
            txd <= i[7:0] ^ 8'h5A; start <= 1;
            @(posedge clk); start <= 0;
        end
        while (busy) @(posedge clk);
        repeat (2000) @(posedge clk);
        if (got != 256) begin $display("FAIL: received %0d of 256 bytes", got); errors = errors + 1; end
        if (errors == 0) $display("PASS tb_uart: 256 bytes looped back");
        else             $display("FAIL tb_uart: %0d errors", errors);
        $finish;
    end
endmodule
