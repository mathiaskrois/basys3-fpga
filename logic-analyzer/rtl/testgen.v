// Built-in test signals (100 MHz clock), output on Pmod JC and usable
// internally (sw0) so the analyzer can be checked without any wiring.
//   ch0  1 MHz square wave
//   ch1  100 kHz square wave
//   ch2  100 kHz PWM whose duty cycle sweeps 0..100 % every 10 ms
//   ch3  UART 115200 8N1: "Hello from Basys3\r\n", then ~1 ms idle, repeated
//   ch4-7 4-bit counter, counting at 1 MHz (ch4 = 500 kHz)
`default_nettype none
module testgen (
    input  wire       clk,
    input  wire       rst,
    output wire [7:0] sig
);
    // ---- squares
    reg [5:0] c1m  = 0; reg sq1m  = 0;
    reg [8:0] c100 = 0; reg sq100 = 0;
    always @(posedge clk) begin
        if (c1m == 6'd49)   begin c1m  <= 0; sq1m  <= ~sq1m;  end else c1m  <= c1m  + 1'b1;
        if (c100 == 9'd499) begin c100 <= 0; sq100 <= ~sq100; end else c100 <= c100 + 1'b1;
    end

    // ---- PWM sweep
    reg [9:0] pwm_cnt  = 0;
    reg [9:0] pwm_duty = 0;
    always @(posedge clk) begin
        if (pwm_cnt == 10'd999) begin
            pwm_cnt  <= 0;
            pwm_duty <= (pwm_duty == 10'd999) ? 10'd0 : pwm_duty + 1'b1;
        end else
            pwm_cnt <= pwm_cnt + 1'b1;
    end
    wire pwm = (pwm_cnt < pwm_duty);

    // ---- 4-bit counter at 1 MHz (one tick per 1 MHz period)
    reg [3:0] ctr = 0;
    always @(posedge clk) if (c1m == 6'd49 && sq1m) ctr <= ctr + 1'b1;

    // ---- UART message
    localparam MSG_LEN = 19;
    reg  [7:0]  ch;
    reg  [4:0]  mi = 0;
    always @(*) begin
        case (mi)
        5'd0:  ch = "H"; 5'd1:  ch = "e"; 5'd2:  ch = "l"; 5'd3:  ch = "l";
        5'd4:  ch = "o"; 5'd5:  ch = " "; 5'd6:  ch = "f"; 5'd7:  ch = "r";
        5'd8:  ch = "o"; 5'd9:  ch = "m"; 5'd10: ch = " "; 5'd11: ch = "B";
        5'd12: ch = "a"; 5'd13: ch = "s"; 5'd14: ch = "y"; 5'd15: ch = "s";
        5'd16: ch = "3"; 5'd17: ch = 8'h0D; default: ch = 8'h0A;
        endcase
    end
    wire        u_busy, u_line;
    reg  [16:0] gap = 0;                  // idle time between messages
    wire        u_start = !u_busy && gap == 0;
    uart_tx #(.CLKS_PER_BIT(868)) u_tx (   // 100 MHz / 115200 = 868.06
        .clk(clk), .rst(rst), .data(ch), .start(u_start), .tx(u_line), .busy(u_busy));
    always @(posedge clk) begin
        if (rst) begin
            mi <= 0; gap <= 17'd100_000;
        end else if (gap != 0) begin
            gap <= gap - 1'b1;
        end else if (u_start) begin
            if (mi == MSG_LEN - 1) begin mi <= 0; gap <= 17'd100_000; end
            else mi <= mi + 1'b1;
        end
    end

    assign sig = {ctr, u_line, pwm, sq100, sq1m};
endmodule
`default_nettype wire
