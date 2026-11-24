// What the sigrok bridge simulates: the analyzer core sampling the built-in
// test signals, with byte-level serial streams driven from C++.
`default_nettype none
module bridge_top (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] rx_data,
    input  wire       rx_valid,
    output wire [7:0] tx_data,
    output wire       tx_valid,
    output wire [1:0] state
);
    wire [7:0] test_sig, live;
    wire       test_mode;
    testgen u_gen (.clk(clk), .rst(rst), .sig(test_sig));
    la_core #(.AW(17)) u_core (
        .clk(clk), .rst(rst), .probe_ext(8'h00), .probe_test(test_sig), .test_sw(1'b1),
        .force_trig(1'b0), .rx_data(rx_data), .rx_valid(rx_valid),
        .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(1'b1),
        .live(live), .state(state), .test_mode(test_mode));
endmodule
`default_nettype wire
