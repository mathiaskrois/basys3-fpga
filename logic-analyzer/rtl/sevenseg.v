// Shows the analyzer state on the 4-digit display:
//   idle " rdy"   armed " Arn"   triggered "trig"   sending "SEnd"
// The display is common-anode: segments and anodes are active LOW.
// Digits are lit one at a time, each for ~0.66 ms (full refresh ~2.6 ms).
`default_nettype none
module sevenseg (
    input  wire       clk,
    input  wire [1:0] state,
    output reg  [6:0] seg,                // seg[0] = CA (a) ... seg[6] = CG (g)
    output wire       dp,
    output reg  [3:0] an                  // an[3] = leftmost digit
);
    // segment patterns, active high, bit order {g,f,e,d,c,b,a}
    localparam [6:0] C_BLANK = 7'b0000000, C_r = 7'b1010000, C_d = 7'b1011110,
                     C_y = 7'b1101110, C_A = 7'b1110111, C_n = 7'b1010100,
                     C_t = 7'b1111000, C_i = 7'b0000100, C_g = 7'b1101111,
                     C_S = 7'b1101101, C_E = 7'b1111001;

    reg [27:0] text;                      // 4 digits, leftmost in [27:21]
    always @(*) begin
        case (state)
        2'd0:    text = {C_BLANK, C_r, C_d, C_y};
        2'd1:    text = {C_BLANK, C_A, C_r, C_n};
        2'd2:    text = {C_t, C_r, C_i, C_g};
        default: text = {C_S, C_E, C_n, C_d};
        endcase
    end

    reg [17:0] refresh = 0;
    always @(posedge clk) refresh <= refresh + 1'b1;
    wire [1:0] digit = refresh[17:16];    // 0 = rightmost

    always @(posedge clk) begin
        an  <= ~(4'b0001 << digit);
        seg <= ~text[digit*7 +: 7];
    end
    assign dp = 1'b1;                     // decimal points off
endmodule
`default_nettype wire
