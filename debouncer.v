/*
 *  debouncer.v
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
module debouncer(
           input  clk,
           input  button,
           output button_pressed
       );

reg [1:0] button_sync = 0;

always @(posedge clk) begin
    button_sync <= {button_sync[0], button};
end

wire button_s = button_sync[1];

reg [1:0] state = 0;
reg [15:0] debounce_cnt;

assign button_pressed = state == 2;
always @(posedge clk) begin
    case (state)
        0: begin
            if (~button_s) begin
                debounce_cnt <= 0;
                state <= 1;
            end
        end

        1: begin
            debounce_cnt <= debounce_cnt + 1;
            if (button_s) begin
                state <= 0;
            end
            if (&debounce_cnt) begin
                state <= 2;
            end
        end

        2: begin
            if (button_s) state <= 0;
        end

        default:
            state <= 0;
    endcase
end

endmodule
