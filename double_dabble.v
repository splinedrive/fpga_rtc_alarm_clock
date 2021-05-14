/*
 *  double_dabble.v
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
module double_dabble
       #(
           parameter WIDTH_I = 8,
           parameter WIDTH_O = WIDTH_I + ((WIDTH_I - 4)/3)
       )
       (
           input [WIDTH_I -1:0] binary,
           output reg [WIDTH_O:0] bcd
       );

initial begin
    $display("WIDTH_O:", WIDTH_O);
end

integer i, j;
always @(binary) begin
    bcd = 0;
    for (i = WIDTH_I-1; i >= 0; i = i - 1) begin
        bcd = {bcd[WIDTH_O-1:0], binary[i]};
        for (j = 1; j < WIDTH_O; j = j + 4) begin
            if (bcd[j +:4] > 4) begin
                bcd[j +:4] = bcd[j +:4] + 4'd3;
            end
        end
    end
end

endmodule
