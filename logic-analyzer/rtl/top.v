// Basys 3 logic analyzer: top level and board wiring.
//   JB[7:0]  8 probe inputs (3.3 V only)  JB pin 1 = channel 0 ... pin 10 = channel 7
//   JC[7:0]  built-in test signals out    (jumper JC -> JB to test the full path)
//   sw[0]    sample the test signals internally instead of JB
//   btnC     manual trigger
//   LED0-7   live channel levels   LED12 test mode   LED13 armed
//   LED14    triggered (recording the post-trigger part)   LED15 sending to PC
//   7-seg    rdy / Arn / trig / SEnd
//   USB-UART 921600 baud 8N1, SUMP / Openbench Logic Sniffer protocol
`default_nettype none
module top (
    input  wire        clk,               // 100 MHz
    input  wire        RsRx,              // from PC (FTDI TXD)
    output wire        RsTx,              // to PC
    input  wire [7:0]  JB,
    output wire [7:0]  JC,
    input  wire [15:0] sw,
    input  wire        btnC,
    output wire [15:0] led,
    output wire [6:0]  seg,
    output wire        dp,
    output wire [3:0]  an
);
    localparam CLKS_PER_BIT = 108;        // 100 MHz / 921600 baud (+0.47 %)

    // ---- power-on reset (FPGA flip-flops start at their initial values)
    reg [7:0] por = 8'd0;
    always @(posedge clk) if (!por[7]) por <= por + 1'b1;
    wire rst = !por[7];

    // ---- input synchronisers (asynchronous outside world -> clk)
    reg [7:0] jb_s1 = 0, jb_s2 = 0;
    reg [1:0] rx_s  = 2'b11;              // UART idles high
    reg [1:0] btn_s = 2'b00;
    reg [1:0] sw_s  = 2'b00;
    always @(posedge clk) begin
        jb_s1 <= JB;      jb_s2 <= jb_s1;
        rx_s  <= {rx_s[0], RsRx};
        btn_s <= {btn_s[0], btnC};
        sw_s  <= {sw_s[0], sw[0]};
    end

    // ---- test signals
    wire [7:0] test_sig;
    testgen u_gen (.clk(clk), .rst(rst), .sig(test_sig));
    assign JC = test_sig;

    // ---- UART
    wire [7:0] rx_data, tx_data;
    wire       rx_valid, tx_valid, tx_busy;
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .clk(clk), .rst(rst), .rx(rx_s[1]), .data(rx_data), .valid(rx_valid));
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .clk(clk), .rst(rst), .data(tx_data), .start(tx_valid), .tx(RsTx), .busy(tx_busy));

    // ---- analyzer
    wire [7:0] live;
    wire [1:0] state;
    wire       test_mode;
    la_core #(.AW(17)) u_core (
        .clk(clk), .rst(rst),
        .probe_ext(jb_s2), .probe_test(test_sig), .test_sw(sw_s[1]),
        .force_trig(btn_s[1]),
        .rx_data(rx_data), .rx_valid(rx_valid),
        .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(!tx_busy),
        .live(live), .state(state), .test_mode(test_mode));

    // ---- status
    assign led = {state == 2'd3, state == 2'd2, state == 2'd1, test_mode, 4'b0000, live};
    sevenseg u_7seg (.clk(clk), .state(state), .seg(seg), .dp(dp), .an(an));
endmodule
`default_nettype wire
