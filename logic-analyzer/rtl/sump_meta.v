// Replies to the SUMP ID (0x02) and metadata (0x04) commands from a small ROM.
//
// ID reply: "1ALS".
// Metadata: key bytes; key>>5 gives the type: 0 = NUL-terminated string,
// 1 = 32-bit value sent BIG-endian (unlike command arguments), ending in 0x00.
// sigrok needs 0x20 (probe count) and 0x21 (sample memory in bytes) to create
// channels; 0x23 (max sample rate) stops it asking for >100 MHz demux mode.
`default_nettype none
module sump_meta #(
    parameter AW = 17                      // sample memory = 2^AW bytes
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       send_id,
    input  wire       send_meta,
    output reg  [7:0] data,
    output wire       valid,
    input  wire       ready
);
    localparam [31:0] MEM_BYTES = 32'd1 << AW;
    localparam [31:0] MAX_RATE  = 32'd100_000_000;
    localparam [5:0]  ID_FIRST = 6'd0,  ID_LAST = 6'd3;
    localparam [5:0]  MD_FIRST = 6'd4,  MD_LAST = 6'd40;

    reg       active = 1'b0;
    reg [5:0] idx    = 6'd0;
    reg [5:0] last   = 6'd0;
    assign valid = active;

    always @(*) begin
        case (idx)
        // ---- ID
        6'd0:  data = "1";
        6'd1:  data = "A";
        6'd2:  data = "L";
        6'd3:  data = "S";
        // ---- 0x01 device name "Basys3-LA"
        6'd4:  data = 8'h01;
        6'd5:  data = "B";
        6'd6:  data = "a";
        6'd7:  data = "s";
        6'd8:  data = "y";
        6'd9:  data = "s";
        6'd10: data = "3";
        6'd11: data = "-";
        6'd12: data = "L";
        6'd13: data = "A";
        6'd14: data = 8'h00;
        // ---- 0x02 FPGA firmware version "1.0"
        6'd15: data = 8'h02;
        6'd16: data = "1";
        6'd17: data = ".";
        6'd18: data = "0";
        6'd19: data = 8'h00;
        // ---- 0x20 number of probes = 8
        6'd20: data = 8'h20;
        6'd21: data = 8'h00;
        6'd22: data = 8'h00;
        6'd23: data = 8'h00;
        6'd24: data = 8'h08;
        // ---- 0x21 sample memory (bytes)
        6'd25: data = 8'h21;
        6'd26: data = MEM_BYTES[31:24];
        6'd27: data = MEM_BYTES[23:16];
        6'd28: data = MEM_BYTES[15:8];
        6'd29: data = MEM_BYTES[7:0];
        // ---- 0x23 max sample rate (Hz)
        6'd30: data = 8'h23;
        6'd31: data = MAX_RATE[31:24];
        6'd32: data = MAX_RATE[23:16];
        6'd33: data = MAX_RATE[15:8];
        6'd34: data = MAX_RATE[7:0];
        // ---- 0x24 protocol version = 2
        6'd35: data = 8'h24;
        6'd36: data = 8'h00;
        6'd37: data = 8'h00;
        6'd38: data = 8'h00;
        6'd39: data = 8'h02;
        // ---- end of metadata
        default: data = 8'h00;             // idx 40
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            active <= 1'b0;
        end else if (send_id) begin
            idx <= ID_FIRST; last <= ID_LAST; active <= 1'b1;
        end else if (send_meta) begin
            idx <= MD_FIRST; last <= MD_LAST; active <= 1'b1;
        end else if (active && ready) begin
            if (idx == last) active <= 1'b0;
            else             idx    <= idx + 1'b1;
        end
    end
endmodule
`default_nettype wire
