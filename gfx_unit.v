/*
 *  gfx_unit.v
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
module gfx_unit(
           input clk,
           input and_fb,
           input [7:0] font,
           input [3:0] x, // 0 - 7
           input [0:0] y, // 0 - 3
           input  [8:0] ssd1306_addr,
           output [7:0] ssd1306_out,
           input rd,
           output ready,
           input resetn,
           input render,
           output reg done
       );

localparam XSIZE = 128;
localparam YSIZE = 32;
localparam ADDR_DEPTH = XSIZE*YSIZE/8;
localparam DATA_WIDTH = 8;

wire  [DATA_WIDTH-1:0] in;
wire [DATA_WIDTH-1:0] out;
reg  cs;
reg  we;

reg [7:0] font_bitmap[0:1023];//4095];
initial begin
    $readmemh("font_vga.mem", font_bitmap); // 8x16*256
end

assign ssd1306_out = rd ? out : 'hz;

framebuffer
    #(
        .XSIZE(XSIZE),
        .YSIZE(YSIZE),
        .ADDR_DEPTH(ADDR_DEPTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) framebuffer_i(
        .clk(clk),
        .wr_addr(fb_wr_ptr),
        .rd_addr(rd ? ssd1306_addr : fb_rd_ptr),
        .in(in),
        .out(out),
        .cs(cs | rd),
        .we(we)
    );

reg render_r;
always @(posedge clk) begin
    if (~resetn) begin
        render_r <= 0;
    end else begin
        render_r <= render;
    end
end


reg [3:0] state;
reg [8:0] i;
reg [8:0] offset;
wire [8:0] index = (x<<3) + (y<<8);
wire [11:0] font_index = (font<<4) + i;
wire [7:0] tile = font_bitmap[font_index];
wire [2:0] shift = (7-offset);
wire [7:0] bit_tile = ((tile & (1<<(shift)))>>(shift))<<(i&7);
wire [$clog2(ADDR_DEPTH)-1:0] fb_rd_ptr = index + offset + ((i>>3)<<7);
wire [$clog2(ADDR_DEPTH)-1:0] fb_wr_ptr = fb_rd_ptr;
assign in = and_fb ? out & bit_tile : out | bit_tile;
assign ready = !state;

always @(posedge clk) begin
    if (~resetn) begin
        done <= 1'b0;
        offset <= 0;
        we <= 0;
        i <= 0;
        state <= 0;
        cs <= 0;
    end else begin
        case (state)

            0: begin
                done <= 1'b0;
                if (!render_r & render) begin
                    i <= 0;
                    offset <= 0;
                    we <= 1'b0;
                    cs <= 1'b1;
                    state <= 1;
                    i <= 0;
                end else begin
                    we <= 1'b0;
                    cs <= 1'b0;
                end
            end

            /* font rederer start */
            1: begin
                if (i == 16) begin
                    we <= 1'b0;
                    cs <= 1'b0;
                    done <= 1'b1;
                    state <= 0;
                end else begin
                    we <= 1'b1;
                    state <= 2;
                end
            end

            2: begin
                we <= 1'b0;
                offset <= offset + 1;
                if (offset == 7) begin
                    offset <= 0;
                    i <= i + 1;
                    state <= 1;
                end else begin
                    state <= 1;
                end
            end
            /* font rederer stop */

            default:
                state <= 0;
        endcase
    end
end

endmodule
