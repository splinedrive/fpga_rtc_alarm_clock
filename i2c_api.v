/*
 *  i2c_api.v
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
`include "i2c_api.vh"
`include "i2c.vh"
module i2c_api
       #(
           parameter TRANSFER_RATE   = 100_000,
           parameter CLK_FREQ        = 25_000_000
       ) (
           input clk,
           input resetn,
           input enable,
           input [6:0] slave_addr,
           input [7:0] device_register,
           input [7:0] data_tx,
           output [7:0] data_rx,
           output scl,
           output sda_oe,
           input [7:0] i2c_function,
           `ifdef SIM
           inout sda,
           `endif
           input sda_in,
           output sda_out,
           output reg done,
           output reg ready
       );
`MY_I2C_DECLS
    `I2C_API_DECLS

    wire i2c_ready;

reg rd_wr;
reg start_stop;
reg [7:0] data_out;
reg [5:0] state;
reg [7:0] i2c_atomic;

`ifdef SIM

reg [255:0] i2c_primitiv_str;

always @(*) begin
    case (i2c_atomic)
        MY_I2C_IDLE     : i2c_primitiv_str = "MY_I2C_IDLE";
        MY_I2C_READ     : i2c_primitiv_str = "MY_I2C_READ";
        MY_I2C_WRITE    : i2c_primitiv_str = "MY_I2C_WRITE";
        MY_I2C_START    : i2c_primitiv_str = "MY_I2C_START";
        MY_I2C_STOP     : i2c_primitiv_str = "MY_I2C_STOP";
        MY_I2C_TRANS_START     : i2c_primitiv_str = "MY_I2C_TRANS_START";
        MY_I2C_TRANS_END   : i2c_primitiv_str = "MY_I2C_TRANS_END";
    endcase
end

`endif


my_i2c
    #(
        .TRANSFER_RATE(TRANSFER_RATE),
        .CLK_FREQ(CLK_FREQ)
    ) my_i2c_i(
        .clk(clk),
        .resetn(resetn),
        .enable(enable),
        .transaction(i2c_function == I2C_WRITE_RAW | transaction_i2c),
        .i2c_atomic(i2c_atomic),
        .slave_addr(slave_addr),
        .rd_wr(rd_wr),
        .data_out(data_out),
        .data_in(data_rx),
        .scl(scl),
        .sda_oe(sda_oe),
        .sda_in(sda_in),
        .sda_out(sda_out),
`ifdef SIM
        .sda(sda),
`endif
        .ready(i2c_ready)
    );

reg [6:0] i2c_atomic_pc;

reg ld_register;
reg ld_data_out;
reg ld_data_in;
reg transaction_i2c;
reg [8+6+1-1:0] ctrl;

always @(*) begin
    case (i2c_atomic_pc)
        /* device_register => register */
        /* data_out => value for write, data_rx <= value from read */
        /*           cmd                    ldi  ld_reg ld_dat  r_w   done , ready transaction*/
        00:  ctrl = {MY_I2C_IDLE,           1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0};

        /* readU8(register, value)                                              */
        /* Read an unsigned byte from the specified register                    */
        /*           cmd                    ldi  ld_reg ld_dat  r_w done , ready transaction*/
        10: ctrl = {MY_I2C_START,           1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1};
        11: ctrl = {MY_I2C_WRITE,           1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1};
        12: ctrl = {MY_I2C_STOP,            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};

        /*           cmd                    ldi  ld_reg ld_dat  r_w done , ready transaction*/
        13: ctrl = {MY_I2C_START,           1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1};
        14: ctrl = {MY_I2C_READ,            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1};
        15: ctrl = {MY_I2C_STOP,            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};

        /*           cmd                    ldi  ld_reg ld_dat  r_w done , ready transaction*/
        16: ctrl = {MY_I2C_IDLE,            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0};

        /* write8(register, value)                                            */
        /* Write an 8-bit value to the specified register                     */
        /*           cmd                    ldi  ld_reg ld_dat  r_w   done , ready transaction*/
        20: ctrl = {MY_I2C_START,           1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1};
        21: ctrl = {MY_I2C_WRITE,           1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1};
        22: ctrl = {MY_I2C_WRITE,           1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1};
        23: ctrl = {MY_I2C_STOP,            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0};
        24: ctrl = {MY_I2C_IDLE,            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0};

        /* writeRaw8(value)
        /* Write an 8-bit value to the specified register                     */
        /*           cmd                    ldi  ld_reg ld_dat  r_w   done , ready transaction*/
        40: ctrl = {MY_I2C_WRITE,           1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1};
        41: ctrl = {MY_I2C_IDLE,            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0};

        /* START Trasaction */
        /*           cmd                    ldi  ld_reg ld_dat  r_w   done , ready transaction*/
        50: ctrl = {MY_I2C_START,           1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0}; /* transaction 1? */
        51: ctrl = {MY_I2C_IDLE,            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0};

        /* STOP Trasaction */
        60: ctrl = {MY_I2C_STOP,            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
        61: ctrl = {MY_I2C_IDLE,            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0};

        127: ctrl = {MY_I2C_IDLE,           1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0};
        default: begin
            /*       cmd                      ldi  ld_reg ld_dat  r_w done  ready */
            ctrl = {MY_I2C_IDLE,              1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0};
        end
    endcase
end

always @(posedge clk) begin
    if (~resetn) begin
        i2c_atomic_pc <= 0;
        state <= 0;
        ready <= 1'b0;
        done <= 1'b0;
        i2c_atomic_pc <= 0;
    end else begin

        if (enable) begin
            {i2c_atomic, ld_data_in, ld_register, ld_data_out, rd_wr, done, ready, transaction_i2c} <= ctrl;
            if (ld_register) begin
                data_out <= device_register;
            end else if (ld_data_out) begin
                data_out <= data_tx;
            end

            case (state)

                0: begin
                    if (i2c_ready) begin
                        case (i2c_function)
                            I2C_READ_U8: begin
                                i2c_atomic_pc <= 10;
                                state <= 10;
                            end

                            I2C_WRITE_8: begin
                                i2c_atomic_pc <= 20;
                                state <= 10;
                            end

                            I2C_WRITE_RAW: begin
                                i2c_atomic_pc <= 40;
                                state <= 10;
                            end

                            I2C_START: begin
                                i2c_atomic_pc <= 50;
                                state <= 10;
                            end

                            I2C_STOP: begin
                                i2c_atomic_pc <= 60;
                                state <= 10;
                            end

                            I2C_NOP: begin
                                i2c_atomic_pc <= 127;
                                state <= 10;
                            end

                            default: begin
                                i2c_atomic_pc <= 0;
                                state <= 0;
                            end
                        endcase
                    end
                end

                10: begin
                    if (i2c_ready) begin
                        if (done) begin
                            i2c_atomic_pc <= 0;
                            state <= 0;
                        end else begin
                            i2c_atomic_pc <= i2c_atomic_pc + 1;
                        end
                    end
                end

                default: begin
                    state <= 0;
                end
            endcase
        end
    end
end

endmodule
