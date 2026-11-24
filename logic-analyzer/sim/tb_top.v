// Full-system test of `top` over real serial bits at 921600 baud, as the PC
// would see it. Checks the ID reply, captures of the built-in test signals
// (internally via sw0 and through a simulated JC->JB jumper), and btnC.
`timescale 1ns/1ps
module tb_top;
    reg clk = 0;
    always #5 clk = ~clk;

    localparam real BIT_NS = 1.0e9 / 921600.0;

    reg         host_tx = 1'b1;           // PC -> FPGA line
    wire        fpga_tx;
    reg  [15:0] sw = 0;
    reg         btnC = 0;
    reg         jumper = 0;               // 1 = JC wired to JB
    wire [7:0]  JC;
    wire [7:0]  JB = jumper ? JC : 8'h00;
    wire [15:0] led;
    wire [6:0]  seg;
    wire        dp;
    wire [3:0]  an;

    top dut (.clk(clk), .RsRx(host_tx), .RsTx(fpga_tx), .JB(JB), .JC(JC), .sw(sw),
             .btnC(btnC), .led(led), .seg(seg), .dp(dp), .an(an));

    // PC-side receiver (same UART module, 921600 baud)
    wire [7:0] pc_data;
    wire       pc_valid;
    uart_rx #(.CLKS_PER_BIT(108)) pc_rx (.clk(clk), .rst(1'b0), .rx(fpga_tx), .data(pc_data), .valid(pc_valid));

    reg [7:0] rxbuf [0:4095];
    integer   nrx = 0;
    always @(posedge clk) if (pc_valid) begin rxbuf[nrx] = pc_data; nrx = nrx + 1; end

    integer errors = 0;
    task check(input cond, input [8*64-1:0] msg);
        if (!cond) begin $display("FAIL: %0s", msg); errors = errors + 1; end
    endtask

    task send(input [7:0] b);
        integer i;
        begin
            host_tx = 0; #(BIT_NS);
            for (i = 0; i < 8; i = i + 1) begin host_tx = b[i]; #(BIT_NS); end
            host_tx = 1; #(BIT_NS);
        end
    endtask
    task send_long(input [7:0] op, input [31:0] arg);
        begin send(op); send(arg[7:0]); send(arg[15:8]); send(arg[23:16]); send(arg[31:24]); end
    endtask
    task wait_bytes(input integer n);
        integer t;
        begin
            t = 0;
            while (nrx < n && t < 20_000_000) begin @(posedge clk); t = t + 1; end
            #(BIT_NS * 30);
        end
    endtask

    // The longest and the typical length of runs of equal values in `bit` over
    // the first n bytes, ignoring the partial runs at both ends.
    task runs(input integer n, input integer bitn, input integer width, output integer min_run, output integer max_run);
        integer i, run, first;
        reg [7:0] prev;
        begin
            min_run = 1 << 30; max_run = 0; run = 1; first = 1;
            prev = (rxbuf[0] >> bitn) & ((1 << width) - 1);
            for (i = 1; i < n; i = i + 1) begin
                if (((rxbuf[i] >> bitn) & ((1 << width) - 1)) == prev) run = run + 1;
                else begin
                    if (!first) begin
                        if (run < min_run) min_run = run;
                        if (run > max_run) max_run = run;
                    end
                    first = 0; run = 1;
                    prev = (rxbuf[i] >> bitn) & ((1 << width) - 1);
                end
            end
        end
    endtask

    task capture_test_signals(input [8*32-1:0] how);
        integer mn, mx;
        begin
            send_long(8'h80, 0);                      // 100 MHz
            send_long(8'h81, {16'd99, 16'd99});       // 400 samples, no trigger
            nrx = 0; send(8'h01); wait_bytes(400);
            check(nrx == 400, "capture returned 400 bytes");
            runs(400, 0, 1, mn, mx);
            if (mn != 50 || mx != 50) $display("  %0s ch0 runs %0d..%0d", how, mn, mx);
            check(mn == 50 && mx == 50, "ch0 is a 1 MHz square (runs of 50 samples)");
            runs(400, 4, 4, mn, mx);
            if (mn != 100 || mx != 100) $display("  %0s ch4-7 runs %0d..%0d", how, mn, mx);
            check(mn == 100 && mx == 100, "ch4-7 count at 1 MHz (runs of 100 samples)");
            check((((rxbuf[0] >> 4) - (rxbuf[399] >> 4)) & 4'hF) == 3 || (((rxbuf[0] >> 4) - (rxbuf[399] >> 4)) & 4'hF) == 4,
                  "counter counts up in time order (newest first)");
        end
    endtask

    initial begin
        #(2000);
        // 1. probe the way sigrok does: 5x reset, ID
        repeat (5) send(8'h00);
        nrx = 0; send(8'h02); wait_bytes(4);
        check(nrx == 4 && rxbuf[0] == "1" && rxbuf[1] == "A" && rxbuf[2] == "L" && rxbuf[3] == "S", "ID over UART is 1ALS");

        // 2. trigger setup as sigrok does with no trigger: stage 0 mask 0, START
        send_long(8'hC0, 0); send_long(8'hC1, 0); send_long(8'hC2, 32'h0800_0000);

        // 3. internal test signals (sw0)
        sw[0] = 1; #(1000);
        check(led[12] == 1'b1, "LED12 shows test mode");
        capture_test_signals("internal:");

        // 4. external path: JC jumpered to JB
        sw[0] = 0; jumper = 1; #(1000);
        capture_test_signals("jumper:");

        // 5. manual trigger: wait for 0x55 on 8 channels (never happens with JB=0)
        jumper = 0;
        send_long(8'hC0, 32'hFF); send_long(8'hC1, 32'h55); send_long(8'hC2, 32'h0800_0000);
        send_long(8'h81, {16'd0, 16'd3});
        nrx = 0; send(8'h01);
        #(20000);
        check(led[13] == 1'b1, "LED13 shows armed");
        btnC = 1; #(200); btnC = 0;
        wait_bytes(16);
        check(nrx == 16, "btnC triggers a capture of 16 bytes");
        check(led[15:13] == 3'b000, "idle again after sending");

        if (errors == 0) $display("PASS tb_top: all checks");
        else             $display("FAIL tb_top: %0d errors", errors);
        $finish;
    end
endmodule
