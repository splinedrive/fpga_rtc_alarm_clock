/*
 *  i2c.vh
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
`define MY_I2C_DECLS \
localparam MY_I2C_IDLE            = 8'h00; \
localparam MY_I2C_READ            = 8'h01; \
localparam MY_I2C_WRITE           = 8'h02; \
localparam MY_I2C_START           = 8'h03; \
localparam MY_I2C_STOP            = 8'h04; \
localparam MY_I2C_TRANS_START     = 8'h05; \
localparam MY_I2C_TRANS_END       = 8'h06; \
localparam MY_I2C_NOP             = 8'h07;
