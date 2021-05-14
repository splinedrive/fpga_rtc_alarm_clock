/*
 *  i2c.v*
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
`include "i2c.vh"
module my_i2c
       #(
           parameter TRANSFER_RATE   = 400_000,
           parameter CLK_FREQ        = 25_000_000
       ) (
           input       clk,
           input       resetn,
           input       enable,
           input       transaction,
           input [7:0] i2c_atomic,
           input [6:0] slave_addr,

           input       rd_wr,
           input      [7:0] data_out,
           output reg [7:0] data_in,

           output reg scl,
           output reg sda_oe,

           input       sda_in,
           output reg  sda_out,

           output ready

  `ifdef SIM
           ,inout     sda
  `endif
       );
`MY_I2C_DECLS
    localparam CLK_PERIOD      = 1/$itor(CLK_FREQ);
localparam SCL_CYCLES      = CLK_FREQ / TRANSFER_RATE;
localparam PERIOD_NS       = $rtoi(CLK_PERIOD*10.0e9);

initial begin
    $display("===============================");
    $display("CLK_FREQ       :\t", CLK_FREQ);
    $display("CLK_PERIOD     :\t", CLK_PERIOD);
    $display("PERIOD_NS :\t", PERIOD_NS);
    $display("SCL_CYCLES :\t", SCL_CYCLES);
    $display("===============================");
end


wire [7:0] slave_addr_rw = {slave_addr, rd_wr};
`ifdef SIM
assign sda = sda_oe ? sda_out : 1'bz;
`endif

reg [3:0] bit_counter;
reg scl_r;
reg ack;

reg [4:0] state;
reg [4:0] return_state;
reg [9:0] wait_states0;
reg [9:0] wait_states1;

localparam SCL_CYCLES_SHIFT =  ((3*SCL_CYCLES/4) -1);
wire scl_cycle = wait_states0 == SCL_CYCLES_SHIFT;

reg [1:0] sda_in_sync;
always @(posedge clk) begin : SDA_SYNCHRONIZER
    if (~resetn) begin
        sda_in_sync <= 0;
    end else begin
        sda_in_sync <= {sda_in_sync[0], sda_in};
    end
end

localparam IDLE               = 4'd0,
           START              = 4'd1,
           SLAVE_7BIT_ADDR_RW = 4'd2,
           CHECK_ACK_SLAVE    = 4'd3,
           CHECK_ACK_SLAVE1   = 4'd4,
           READ_BYTE          = 4'd5,
           WRITE_BYTE         = 4'd6,
           MASTER_N_ACK       = 4'd7,
           STOP               = 4'd8,
           WAIT_STATES        = 4'd15;

`ifdef SIM
reg [255:0] state_str;

always @(*) begin
    case (state)
        IDLE                  : state_str = "IDLE";
        START                 : state_str = "START";
        SLAVE_7BIT_ADDR_RW    : state_str = "SLAVE_7BIT_ADDR_RW";
        CHECK_ACK_SLAVE       : state_str = "CHECK_ACK_SLAVE";
        READ_BYTE             : state_str = "READ_BYTE";
        WRITE_BYTE            : state_str = "WRITE_BYTE";
        STOP                  : state_str = "STOP";
        WAIT_STATES           : state_str = "WAIT_STATES";
    endcase
end
`endif

assign ready = (state == IDLE);

always @(posedge clk) begin : I2C_MASTER
    if (~resetn) begin : RESET
        scl <= 1'b1;
        ack <= 1'b0;
        sda_oe <= 1'b1;
        sda_out <= 1'b1;
        state <= IDLE;
        return_state <= IDLE;
        bit_counter <= 0;
    end else begin : STATES
        if (enable) begin

            case (state)
                IDLE: begin

                    case (i2c_atomic)

                        MY_I2C_IDLE: begin
                            if (!transaction) begin
                                sda_oe  <= 1'b1;
                                sda_out <= 1'b1;
                                scl     <= 1'b1;
                            end else begin
                                sda_oe  <= 1'b1;
                                sda_out <= 1'b1;
                                scl     <= 1'b0;
                            end
                            wait_states1 <= 1;
                            return_state <= IDLE;
                            state <= WAIT_STATES;
                        end

                        MY_I2C_START: begin
                            wait_states0 <= SCL_CYCLES -1;
                            wait_states1 <= SCL_CYCLES -1;
                            state <= WAIT_STATES;
                            return_state <= START;
                        end

                        MY_I2C_STOP: begin
                            wait_states0 <= SCL_CYCLES -1;
                            wait_states1 <= SCL_CYCLES -1;
                            state <= WAIT_STATES;
                            return_state <= STOP;
                        end

                        MY_I2C_WRITE: begin
                            sda_oe <= 1'b1;
                            bit_counter <= 8;
                            wait_states0 <= SCL_CYCLES -1;
                            wait_states1 <= SCL_CYCLES -1;
                            state <= WAIT_STATES;
                            return_state <= WRITE_BYTE;
                        end

                        MY_I2C_READ: begin
                            sda_oe <= 1'b0;
                            bit_counter <= 8;
                            wait_states0 <= SCL_CYCLES -1;
                            wait_states1 <= SCL_CYCLES -1;
                            state <= WAIT_STATES;
                            return_state <= READ_BYTE;
                        end

                        default: begin
                            state <= IDLE;
                        end
                    endcase
                end

                START: begin
                    sda_oe <= 1'b1;
                    sda_out <= 1'b0;
                    bit_counter <= 8;

                    scl <= 1'b1;
                    wait_states0 <= SCL_CYCLES -1;
                    wait_states1 <= SCL_CYCLES -1;
                    state <= WAIT_STATES;
                    return_state <= SLAVE_7BIT_ADDR_RW;
                end

                SLAVE_7BIT_ADDR_RW: begin
                    scl <= (wait_states0 > (SCL_CYCLES>>1)) ? 1'b0 : 1'b1;
                    wait_states0 <= (wait_states0 == 1) ? SCL_CYCLES : wait_states0 - 1'b1;

                    if (scl_cycle) begin
                        bit_counter <= bit_counter - 1'b1;

                        if (bit_counter > 0) begin
                            sda_out <= slave_addr_rw[bit_counter -1'b1]; /* address and rw bit */
                        end

                        if (bit_counter == 0) begin
                            wait_states0 <= (SCL_CYCLES>>1) -1;
                            bit_counter <= 1;
                            wait_states0 <= SCL_CYCLES_SHIFT;
                            sda_oe <= 1'b0;
                            state <= CHECK_ACK_SLAVE;
                        end
                    end

                end

                CHECK_ACK_SLAVE: begin
                    scl <= (wait_states0 > (SCL_CYCLES>>1)) ? 1'b0 : 1'b1;
                    wait_states0 <= (wait_states0 == 1) ? SCL_CYCLES : wait_states0 - 1'b1;

                    scl_r <= scl;
                    if (~scl_r & scl) begin
                        ack <= sda_in_sync[1];
                    end

                    if (scl_cycle) begin
                        bit_counter <= bit_counter - 1'b1;
                        if (bit_counter == 0) begin

                            if (~ack) begin /* check for ~ack */
                                scl <= !transaction;

                                bit_counter <= 8;
                                wait_states0 <= SCL_CYCLES -1;
                                wait_states1 <= SCL_CYCLES -1;

                                state <= WAIT_STATES;
                                return_state <= CHECK_ACK_SLAVE1;
                                sda_oe <= 1'b1;
                                sda_out <= transaction;
                            end else begin
                                sda_oe <= 1'b1;
                                state <= IDLE;
                            end
                        end
                    end
                end

                CHECK_ACK_SLAVE1: begin
                    sda_out <= 1'b1;
                    scl <= !transaction;
                    wait_states1 <= SCL_CYCLES -1;
                    state <= WAIT_STATES;
                    return_state <= IDLE;
                    sda_oe <= 1'b1;
                    sda_out <= transaction;
                end

                WRITE_BYTE: begin
                    scl <= (wait_states0 > (SCL_CYCLES>>1)) ? 1'b0 : 1'b1;
                    wait_states0 <= (wait_states0 == 1) ? SCL_CYCLES : wait_states0 - 1'b1;

                    if (scl_cycle) begin
                        bit_counter <= bit_counter - 1'b1;

                        if (bit_counter > 0) sda_out <= data_out[bit_counter -1'b1];

                        if (bit_counter == 0) begin
                            sda_oe <= 1'b0;
                            bit_counter <= 0;
                            wait_states0 <= (SCL_CYCLES_SHIFT) -1;
                            state <= CHECK_ACK_SLAVE;
                        end
                    end

                end

                READ_BYTE: begin
                    scl <= (wait_states0 > (SCL_CYCLES>>1)) ? 1'b0 : 1'b1;
                    wait_states0 <= (wait_states0 == 1) ? SCL_CYCLES : wait_states0 - 1'b1;

                    scl_r <= scl;
                    if (~scl_r & scl) begin
                        data_in <= {data_in[6:0], sda_in_sync[1]};
                    end

                    if (scl_cycle) begin
                        bit_counter <= bit_counter - 1'b1;
                        if (bit_counter == 0) begin
                            bit_counter <= 1;
                            wait_states0 <= SCL_CYCLES_SHIFT -1;
                            sda_out <= 1'b1;// todo
                            sda_oe <= 1'b1;
                            state <= MASTER_N_ACK;
                        end
                    end

                end

                MASTER_N_ACK: begin
                    scl <= (wait_states0 > (SCL_CYCLES>>1)) ? 1'b0 : 1'b1;
                    wait_states0 <= (wait_states0 == 1) ? SCL_CYCLES : wait_states0 - 1'b1;

                    if (scl_cycle) begin
                        //sda_out <= !start_stop ? 1'b0 : 1'b1; /* master ack or nack */
                        sda_out <= 1'b1;
                        bit_counter <= bit_counter - 1'b1;
                        if (bit_counter == 0) begin
                            sda_out <= 1'b0;
                            //            sda_out <= i2c_atomic == MY_I2C_TRANS_WAIT ? 1'b1 : 1'b0;
                            sda_out <= transaction;
                            sda_oe <= 1'b1;
                            bit_counter <= 8;
                            wait_states0 <= SCL_CYCLES_SHIFT<<2 -1;
                            state <= IDLE;
                            //state <= start_stop ? READ_BYTE : STOP;
                        end
                    end

                end

                STOP: begin
                    scl <= 1'b1;
                    sda_oe <= 1'b1;
                    sda_out <= 1'b1; /* low to high => stop */
                    wait_states1 <= (SCL_CYCLES>>0) -2; /* important for synchronizing */
                    return_state <= IDLE;
                    state <= WAIT_STATES;
                end

                /* wait states */
                WAIT_STATES: begin
                    wait_states1 <= wait_states1 - 1'b1;
                    if (wait_states1 == 1'b1) begin
                        state <= return_state;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
end

endmodule
