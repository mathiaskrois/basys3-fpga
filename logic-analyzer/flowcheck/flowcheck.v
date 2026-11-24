// Toolchain smoke test: blinks LED15 at ~1.5 Hz and shows a block-RAM word,
// loaded with $readmemh, on LED0-7 (switches sw[7:0] pick the address).
// If LED0-7 show 0xA5 with all switches down, RAM init made it into the bitstream.
`default_nettype none
module flowcheck (
    input  wire        clk,
    input  wire [15:0] sw,
    output wire [15:0] led
);
    reg [25:0] cnt = 0;
    always @(posedge clk) cnt <= cnt + 1'b1;

    (* ram_style = "block" *) reg [7:0] rom [0:4095];
    initial $readmemh("flowcheck/rom.hex", rom);
    reg [7:0] q = 0;
    always @(posedge clk) q <= rom[{4'd0, sw[7:0]}];

    assign led = {cnt[25], 7'd0, q};
endmodule
`default_nettype wire
