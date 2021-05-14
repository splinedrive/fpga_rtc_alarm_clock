/*
 *  framebuffer.v
 *
 *  copyright (c) 2021  hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`timescale 1 ns/10 ps
`default_nettype none
module framebuffer
       #(
           parameter XSIZE = 128,
           parameter YSIZE = 64,
           parameter ADDR_DEPTH = XSIZE*YSIZE/8,
           parameter DATA_WIDTH = 8
       ) (
           input clk,
           input  [$clog2(ADDR_DEPTH)-1:0] wr_addr,
           input  [$clog2(ADDR_DEPTH)-1:0] rd_addr,
           input  [DATA_WIDTH-1:0] in,
           output [DATA_WIDTH-1:0] out,
           input cs,
           input we
       );


reg [DATA_WIDTH -1:0] fb_buffer[0:ADDR_DEPTH-1];

integer idx;
initial begin
    $display("ADDR_DEPTH:", ADDR_DEPTH);
    $display("DATA_WIDTH:", DATA_WIDTH);
    for (idx = 0; idx < ADDR_DEPTH; idx = idx + 1) begin
        fb_buffer[idx] = 0;
    end
    //$readmemh("fb.mem", fb_buffer); // 8x16*256

end

reg [DATA_WIDTH -1:0] out_buf;
always @(posedge clk) begin

    if (cs) begin
        out_buf <= fb_buffer[rd_addr];

        if (we) begin
            fb_buffer[wr_addr] <= in;
        end
    end

end

assign out = cs ? out_buf : 'hz;

endmodule
