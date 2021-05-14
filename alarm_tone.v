/*
 *  alarm_tone.v
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
`default_nettype none
module alarm_tone #(
           parameter CLK_FREQ=12_000_000
       )
       (
           input clk,
           output reg speaker
       );
localparam divider0 = CLK_FREQ/220/2;


reg [$clog2(divider0)-1:0] counter0;
always @(posedge clk) begin
    if (!counter0) begin
        counter0 <= divider0 -1;
    end
    else begin
        counter0 <= counter0 -1;
    end
end

reg enable = 1;
reg [$clog2(CLK_FREQ) -1:0] sys_cycles;

wire tick = (CLK_FREQ/2 - 1) == sys_cycles;
always @(posedge clk) begin
    if (tick) sys_cycles <= 0; else sys_cycles <= sys_cycles + 1;
    enable <= enable ^ tick;
end

always @(posedge clk) begin
    if (!counter0 & enable) speaker <= ~speaker;
end


endmodule
