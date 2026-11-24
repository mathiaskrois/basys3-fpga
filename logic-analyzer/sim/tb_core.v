// la_core testbench at the byte level (no UART), with a randomly stalling
// consumer on the transmit side. The probes carry an 8-bit counter that
// increments every clock, so every captured byte is predictable.
`timescale 1ns/1ps
module tb_core;
    reg clk = 0;
    always #5 clk = ~clk;

    reg        rst = 1;
    reg  [7:0] cnt8 = 0;
    reg        use_const = 0;
    reg  [7:0] const_val = 0;
    wire [7:0] probe = use_const ? const_val : cnt8;
    reg        test_sw = 0, force_trig = 0;
    reg  [7:0] rx_data = 0;
    reg        rx_valid = 0;
    wire [7:0] tx_data;
    wire       tx_valid;
    reg        tx_ready = 0;
    wire [1:0] state;
    wire [7:0] live;
    wire       test_mode;

    always @(posedge clk) cnt8 <= cnt8 + 1'b1;

    la_core #(.AW(17)) dut (
        .clk(clk), .rst(rst), .probe_ext(probe), .probe_test(8'hA5), .test_sw(test_sw),
        .force_trig(force_trig), .rx_data(rx_data), .rx_valid(rx_valid),
        .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(tx_ready),
        .live(live), .state(state), .test_mode(test_mode));

    // ---- receive side: collect every transferred byte
    reg  [7:0] rxbuf [0:262143];
    integer    nrx = 0;
    always @(posedge clk) begin
        tx_ready <= ($random & 3) != 0;        // stall about 1 cycle in 4
        if (tx_valid && tx_ready) begin
            rxbuf[nrx] = tx_data;
            nrx = nrx + 1;
        end
    end

    integer errors = 0;
    task check(input cond, input [8*64-1:0] msg);
        if (!cond) begin $display("FAIL: %0s", msg); errors = errors + 1; end
    endtask

    task send(input [7:0] b);
        begin
            @(posedge clk); rx_data <= b; rx_valid <= 1;
            @(posedge clk); rx_valid <= 0;
            repeat (3) @(posedge clk);
        end
    endtask
    task send_long(input [7:0] op, input [31:0] arg);
        begin send(op); send(arg[7:0]); send(arg[15:8]); send(arg[23:16]); send(arg[31:24]); end
    endtask
    task sump_reset; begin repeat (5) send(8'h00); end endtask
    task set_trigger(input integer s, input [7:0] mask, input [7:0] value, input start);
        begin
            send_long(8'hC0 + 4*s, {24'd0, mask});
            send_long(8'hC1 + 4*s, {24'd0, value});
            send_long(8'hC2 + 4*s, {4'd0, start, 3'd0, 6'd0, s[1:0], 16'd0});
        end
    endtask
    task clear_triggers;
        integer s;
        begin for (s = 0; s < 4; s = s + 1) set_trigger(s, 8'h00, 8'h00, s == 0); end
    endtask
    task wait_bytes(input integer n);
        integer t;
        begin
            t = 0;
            while (nrx < n && t < 4000000) begin @(posedge clk); t = t + 1; end
            repeat (50) @(posedge clk);
        end
    endtask
    // all bytes from index 0 to n-1 step down by `step` (mod 256), newest first
    task check_run(input integer n, input integer step, input [8*64-1:0] msg);
        integer i, bad;
        begin
            bad = 0;
            for (i = 0; i + 1 < n; i = i + 1)
                if (((rxbuf[i] - rxbuf[i+1]) & 8'hFF) != step) bad = bad + 1;
            if (bad) $display("  %0d discontinuities, first bytes %02x %02x %02x", bad, rxbuf[0], rxbuf[1], rxbuf[2]);
            check(bad == 0, msg);
        end
    endtask

    reg seen30;
    always @(posedge clk) begin
        if (dut.cmd_run) seen30 <= 0;
        else if (state == 2'd1 && probe == 8'h30) seen30 <= 1;
    end
    reg [7:0] probe_at_trig;
    reg       seen30_at_trig;
    reg [1:0] state_q = 0;
    always @(posedge clk) begin
        state_q <= state;
        if (state == 2'd2 && state_q == 2'd1) begin probe_at_trig <= probe; seen30_at_trig <= seen30; end
    end

    integer i;
    reg [7:0] meta_exp [0:36];
    initial begin
        // expected metadata reply
        meta_exp[0]=8'h01; meta_exp[1]="B"; meta_exp[2]="a"; meta_exp[3]="s"; meta_exp[4]="y";
        meta_exp[5]="s"; meta_exp[6]="3"; meta_exp[7]="-"; meta_exp[8]="L"; meta_exp[9]="A"; meta_exp[10]=0;
        meta_exp[11]=8'h02; meta_exp[12]="1"; meta_exp[13]="."; meta_exp[14]="0"; meta_exp[15]=0;
        meta_exp[16]=8'h20; meta_exp[17]=0; meta_exp[18]=0; meta_exp[19]=0; meta_exp[20]=8;
        meta_exp[21]=8'h21; meta_exp[22]=0; meta_exp[23]=8'h02; meta_exp[24]=0; meta_exp[25]=0;
        meta_exp[26]=8'h23; meta_exp[27]=8'h05; meta_exp[28]=8'hF5; meta_exp[29]=8'hE1; meta_exp[30]=8'h00;
        meta_exp[31]=8'h24; meta_exp[32]=0; meta_exp[33]=0; meta_exp[34]=0; meta_exp[35]=2;
        meta_exp[36]=8'h00;

        repeat (5) @(posedge clk); rst <= 0;

        // 1. ID
        sump_reset; nrx = 0; send(8'h02); wait_bytes(4);
        check(nrx == 4 && rxbuf[0] == "1" && rxbuf[1] == "A" && rxbuf[2] == "L" && rxbuf[3] == "S", "ID reply is 1ALS");

        // 2. metadata
        nrx = 0; send(8'h04); wait_bytes(37);
        check(nrx == 37, "metadata length 37");
        for (i = 0; i < 37; i = i + 1) if (rxbuf[i] !== meta_exp[i]) begin
            $display("  metadata byte %0d = %02x, expected %02x", i, rxbuf[i], meta_exp[i]); errors = errors + 1;
        end

        // 3. no trigger, full rate, 16 samples
        sump_reset; clear_triggers;
        send_long(8'h80, 0); send_long(8'h81, {16'd3, 16'd3}); send_long(8'h82, 32'h0000_0038);
        nrx = 0; send(8'h01); wait_bytes(16);
        check(nrx == 16, "no-trigger capture returns 16 bytes");
        check_run(16, 1, "no-trigger capture is newest-first consecutive");

        // 4. value trigger 0x80, 64 samples, 8 after trigger
        sump_reset; clear_triggers; set_trigger(0, 8'hFF, 8'h80, 1);
        send_long(8'h81, {16'd1, 16'd15});
        nrx = 0; send(8'h01); wait_bytes(64);
        check(nrx == 64, "trigger capture returns 64 bytes");
        check(rxbuf[0] == 8'h87, "newest sample = trigger + 7");
        check(rxbuf[63] == 8'h48, "oldest sample = trigger - 56");
        check_run(64, 1, "trigger capture consecutive");

        // 5. divider 3 -> every 4th clock
        sump_reset; clear_triggers;
        send_long(8'h80, 3); send_long(8'h81, {16'd3, 16'd3});
        nrx = 0; send(8'h01); wait_bytes(16);
        check(nrx == 16, "divided capture returns 16 bytes");
        check_run(16, 4, "divider 3 gives a step of 4");

        // 6. two-stage trigger: 0x30 first, then 0x20 (START)
        sump_reset; clear_triggers;
        set_trigger(0, 8'hFF, 8'h30, 0); set_trigger(1, 8'hFF, 8'h20, 1);
        send_long(8'h80, 0); send_long(8'h81, {16'd0, 16'd0});
        nrx = 0; send(8'h01); wait_bytes(4);
        check(nrx == 4 && rxbuf[0] == 8'h23 && rxbuf[3] == 8'h20, "two-stage trigger fires on 0x20");
        check(seen30_at_trig === 1'b1, "two-stage trigger waited for stage 0 (0x30) first");

        // 7. manual trigger on a never-matching condition
        sump_reset; clear_triggers; set_trigger(0, 8'hFF, 8'h55, 1);
        use_const = 1; const_val = 8'h3C;
        send_long(8'h81, {16'd0, 16'd1});
        nrx = 0; send(8'h01);
        repeat (500) @(posedge clk);
        check(state == 2'd1, "still armed before manual trigger");
        @(posedge clk) force_trig <= 1; @(posedge clk) force_trig <= 0;
        wait_bytes(8);
        check(nrx == 8 && rxbuf[0] == 8'h3C && rxbuf[7] == 8'h3C, "manual trigger completes capture");
        use_const = 0;

        // 8. reset aborts an armed capture
        set_trigger(0, 8'hFF, 8'h55, 1); use_const = 1;
        send(8'h01); repeat (100) @(posedge clk);
        check(state == 2'd1, "armed");
        sump_reset; check(state == 2'd0, "reset returns to idle");
        use_const = 0;

        // 9. internal test mode via flags bit 11
        clear_triggers; send_long(8'h82, 32'h0000_0800);
        send_long(8'h81, {16'd0, 16'd0});
        nrx = 0; send(8'h01); wait_bytes(4);
        check(nrx == 4 && rxbuf[0] == 8'hA5, "flags bit 11 samples the test signals");
        send_long(8'h82, 32'h0);

        // 10. maximum capture: read count clamps to 131072, ring buffer wraps
        sump_reset; clear_triggers;
        send_long(8'h81, {16'hFFFF, 16'hFFFF});
        nrx = 0; send(8'h01); wait_bytes(131072);
        check(nrx == 131072, "max capture returns exactly 131072 bytes");
        check_run(131072, 1, "max capture consecutive across buffer wrap");

        if (errors == 0) $display("PASS tb_core: all checks");
        else             $display("FAIL tb_core: %0d errors", errors);
        $finish;
    end
endmodule
