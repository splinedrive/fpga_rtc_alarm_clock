/*
 *  top.v of fpga clock
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
`ifdef SIM
module top_tb;
inout  sda;
`else
module top(input clk,
           inout sda,
           input btn0,
           input btn1,
           input int_,
           output speaker,
           output led,
           output scl_pin);
reg [7:0] reg_file[3:0];
`endif

assign led = ~alarm_state;
assign speaker = (!alarm_state | !enabled_alarm)? 1'b1 : spk;

localparam TRANSFER_RATE   = 100_000;
localparam CLK_FREQ        = 12_000_000;
localparam SYSTEM_CLK_MHZ  = 12;
localparam CLK_PERIOD      = 1/$itor(CLK_FREQ);
localparam PERIOD_NS       = $rtoi(CLK_PERIOD*10.0e9);
localparam SCL_CYCLES      = CLK_FREQ / TRANSFER_RATE;
localparam BAUDRATE        = 115200;

wire spk;
alarm_tone #(.CLK_FREQ(CLK_FREQ)) alarm_tone_i(.clk(clk), .speaker(spk));

wire [7:0] data_rx;
wire i2c_ready;
wire stopped;
wire sda_oe;
`ifdef SIM
reg sda_in;
`else
wire sda_in;
`endif
wire sda_out;
wire scl;
reg enable;

wire error;
wire valid;

wire [3:0] hundreds;
wire [3:0] tens;
wire [3:0] ones;

wire [11:0] bcd;

reg [$clog2(CLK_FREQ) -1:0] cycle_cnt;
wire [$clog2(CLK_FREQ) -1:0] tick = cycle_cnt == ((CLK_FREQ/1)-1);


reg int_s_;
reg alarm_state;
reg enabled_alarm;
reg blink_alarm;

always @(posedge clk) begin
    if (!resetn) begin
        int_s_ <= !int_;
        alarm_state <= 0;
        enabled_alarm <= 0;
        blink_alarm  <= 1'b0;
    end else begin
        int_s_ <= int_;

        if (~btn1_pressed_s & btn1_pressed & !setup) begin
            enabled_alarm <= enabled_alarm ^ 1'b1;
            alarm_state <= 1'b0;
        end else begin
            if (int_s_ & !int_) begin
                alarm_state <= 1'b1;
            end
        end
    end
    blink_alarm <= enabled_alarm ? blink_alarm ^ (tick & !setup & alarm_state) : 1'b0;
end

always @(posedge clk) begin
    if (!resetn) begin
        cycle_cnt <= 0;
    end else begin
        cycle_cnt <= tick ? 0 : cycle_cnt + 1;
    end
end

wire [7:0] setup_device_register;
wire [0:(16*8) -1] positions  = {8'h00, 8'h10, 8'h30, 8'h40, 8'h60, 8'h70, /* hh:mm:ss*/
                                 8'h01, 8'h11, 8'h31, 8'h41, 8'h61, 8'h71, /* dd/mm/yy */
                                 8'hb1, 8'hc1, 8'he1, 8'hf1}; /* alarm hh:mm */


wire [0:(8*8) -1] register_ds3231  = {8'h02, 8'h01, 8'h00,  // hh:mm:ss
                                      8'h04, 8'h05, 8'h06,  // dd/mm/yy
                                      8'h09, 8'h08};        // alarm hh:mm

wire [0:(8*8) -1] register_ds3231_mask  = {8'h23, 8'h59, 8'h59,  // hh:mm:ss
        8'h31, 8'h12, 8'h99,  // dd/mm/yy
        8'h23, 8'h59};       // hh/mm

wire [7:0] setup_device_register = register_ds3231 [(cur_pos<<3) +:8];
wire [7:0] setup_device_register_mask = register_ds3231_mask [(cur_pos<<3) +:8];

reg [7:0] cur_pos;


wire [7:0] blink_pos0 = positions[(cur_pos<<4) +:8];
wire [7:0] blink_pos1 = positions[(cur_pos<<4) + 8 +:8];

wire blink_comb0 = blink_font && (blink_pos0[7:4] == x) && (blink_pos0[3:0] == y);
wire blink_comb1 = blink_font && (blink_pos1[7:4] == x) && (blink_pos1[3:0] == y);

reg btn0_pressed_s;
reg blink_font;
reg setup;
always @(posedge clk) begin
    if (~resetn) begin
        cur_pos <= 0;
        blink_font <= 0;
        btn0_pressed_s <= btn0_pressed;
        setup <= 1'b0;
    end else begin
        btn0_pressed_s <= btn0_pressed;
        if (~btn0_pressed_s & btn0_pressed) begin

            if (!blink_font & !cur_pos) begin
                setup <= 1'b1;
                blink_font <= 1'b1;
            end else if (cur_pos == 7) begin
                blink_font <= 1'b0;
                setup <= 1'b0;
                cur_pos <= 0;
            end else begin
                cur_pos <= cur_pos + 1;
            end
        end else begin
            blink_font <= blink_font ^ (tick & setup);
        end
    end
end

reg btn1_pressed_s;
reg increment;
always @(posedge clk) begin
    if (~resetn) begin
        increment <= 1'b0;
        btn1_pressed_s <= btn1_pressed;
    end else begin
        btn1_pressed_s <= btn1_pressed;
        if (~btn1_pressed_s & btn1_pressed & setup) begin
            increment <= 1'b1;
        end else begin
            if (opcode == UNSETUP) increment <= 1'b0;
        end
    end
end

assign {hundreds, tens, ones } = bcd;
wire [7:0] binary = reg_file[4];
double_dabble double_dabble_i(binary, bcd);

wire btn0_pressed;
debouncer debouncer_i0(clk, btn0, btn0_pressed);

wire btn1_pressed;
debouncer debouncer_i1(clk, btn1, btn1_pressed);

i2c_api
    #(
        .TRANSFER_RATE(TRANSFER_RATE),
        .CLK_FREQ(CLK_FREQ)
    ) i2c_api_i (
        .clk(clk),
        .resetn(resetn),
        .enable(enable),
        .slave_addr(mux_slave_addr),
        .device_register(mux_device_register),
        .data_tx(mux_data_tx),
        .data_rx(data_rx),
        .scl(scl),
        .sda_oe(sda_oe),
        .i2c_function(mux_i2c_function),
`ifdef SIM
        .sda(sda),
`endif
        .sda_in(sda_in),
        .sda_out(sda_out),
        .done(done),
        .ready(i2c_ready)
    );

`ifndef SIM
SB_IO #(
          .PIN_TYPE(6'b1010_01),
          .PULLUP(1'b0)
      ) sda_i (
          .PACKAGE_PIN(sda),
          .OUTPUT_ENABLE(sda_oe),
          .D_OUT_0(sda_out),
          .D_IN_0(sda_in)
      );

SB_IO #(
          .PIN_TYPE(6'b1010_01),
          .PULLUP(1'b0)
      ) sdc_i (
          .PACKAGE_PIN(scl_pin),
          .OUTPUT_ENABLE(1'b1),
          .D_OUT_0(scl)
      );
`endif


`ifdef SIM
reg clk = 0;
always #(PERIOD_NS>>1) clk = ~clk;

initial begin
    $dumpfile("testbench.vcd");
    $dumpvars(0, top_tb);
    $dumpon;
end

initial begin
    sda_in = 1'b0;
end
`endif

reg [5:0] reset_cnt = 0;
wire resetn = &reset_cnt;

always @(posedge clk) begin
    reset_cnt <= reset_cnt + !resetn;
end

/* oled part */
localparam SETCONTRAST         = 8'h81;
localparam DISPLAYALLON_RESUME = 8'hA4;
localparam DISPLAYALLON        = 8'hA5;
localparam NORMALDISPLAY       = 8'hA6;
localparam INVERTDISPLAY       = 8'hA7;
localparam DISPLAYOFF          = 8'hAE;
localparam DISPLAYON           = 8'hAF;
localparam SETDISPLAYOFFSET    = 8'hD3;
localparam SETCOMPINS          = 8'hDA;
localparam SETVCOMDETECT       = 8'hDB;
localparam SETDISPLAYCLOCKDIV  = 8'hD5;
localparam SETPRECHARGE        = 8'hD9;
localparam SETMULTIPLEX        = 8'hA8;
localparam SETLOWCOLUMN        = 8'h00;
localparam SETHIGHCOLUMN       = 8'h10;
localparam SETSTARTLINE        = 8'h40;
localparam MEMORYMODE          = 8'h20;
localparam COLUMNADDR          = 8'h21;
localparam PAGEADDR            = 8'h22;
localparam COMSCANINC          = 8'hC0;
localparam COMSCANDEC          = 8'hC8;
localparam SEGREMAP            = 8'hA0;
localparam CHARGEPUMP          = 8'h8D;


reg [7:0] font;
reg [3:0] x; // 0 - 15
reg [0:0] y; // 0 - 1
reg  [8:0] ssd1306_addr;
wire [7:0] ssd1306_out;
wire ready_gfx;
wire done_gfx;
reg render;
reg rd;
reg and_fb;

gfx_unit gfx_unit_i(
             .clk(clk),
             .and_fb(and_fb),
             .font(font),
             .x(x), // 0 - 15
             .y(y), // 0 - 3
             .ssd1306_addr(ssd1306_addr),
             .ssd1306_out(ssd1306_out),
             .rd(rd),
             .ready(ready_gfx),
             .resetn(resetn),
             .render(render),
             .done(done_gfx)
         );


reg [4:0] state;
reg [3:0] return_state;
reg [31:0] wait_states;
wire done;
wire [7:0] data_tx;

`I2C_API_DECLS

    /* instructions */
    localparam NOP      = 4'd00;
localparam STOP     = 4'd01;
localparam JMP      = 4'd02;
localparam LD       = 4'd03;
localparam WAIT     = 4'd04;
localparam JNZ      = 4'd05;
localparam FB_FLUSH = 4'd06;
localparam PUTC     = 4'd07;
localparam SETUP0   = 4'd08;
localparam SETUP1   = 4'd09;
localparam UNSETUP  = 4'd10;
localparam ALARM    = 4'd11;

wire [7:0] i2c_function;
wire [6:0] slave_addr;
wire [7:0] device_register;
wire [3:0] opcode;
wire [7:0] operand;

reg [3:0] led_idx;

reg [7:0] ip = 0;

reg [ 8 + 7 + 8 + 8 + 4 +  8 - 1:0] ctrl;
always @(*) begin
    case (ip)
        /* i2c_function                  slave_addr   out                  reg     opcode   operand */
        /* DISPLAYOFF */
        00: ctrl <= {I2C_NOP,             7'h3c,       8'h00,                8'h00,  NOP,      8'd00};
        01: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        02: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        03: ctrl <= {I2C_WRITE_RAW,       7'h3c,       DISPLAYOFF,           8'h00,  NOP,      8'h00};
        04: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        05: ctrl <= {I2C_NOP,             7'h3c,       8'h00,                8'h00,  NOP,      8'd00};
        /* SETDISPLAYCLOCKDIV 0xf0 */
        06: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        07: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        08: ctrl <= {I2C_WRITE_RAW,       7'h3c,       SETDISPLAYCLOCKDIV,   8'h00,  NOP,      8'h00};
        09: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'hf0,                8'h00,  NOP,      8'h00};
        10: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* SETMULTIPLEX 0x1f */
        11: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        12: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        13: ctrl <= {I2C_WRITE_RAW,       7'h3c,       SETMULTIPLEX,         8'h00,  NOP,      8'h00};
        14: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h1f,                8'h00,  NOP,      8'h00};
        15: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};


        /* SETDISPLAYOFFSET 0x0, 0x00 */
        16: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        17: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        18: ctrl <= {I2C_WRITE_RAW,       7'h3c,       SETDISPLAYOFFSET,     8'h00,  NOP,      8'h00};
        19: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        20: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        21: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* SETSTARTLINE | 0 */
        22: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        22: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        23: ctrl <= {I2C_WRITE_RAW,       7'h3c,       SETSTARTLINE | 1'b0,  8'h00,  NOP,      8'h00};
        24: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* CHARGEPUMP 0x14 */
        25: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        26: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        27: ctrl <= {I2C_WRITE_RAW,       7'h3c,       CHARGEPUMP,           8'h00,  NOP,      8'h00};
        28: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h14,                8'h00,  NOP,      8'h00};
        29: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* MEMORYMODE 0x0*/
        30: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        31: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        32: ctrl <= {I2C_WRITE_RAW,       7'h3c,       MEMORYMODE,           8'h00,  NOP,      8'h00};
        33: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        34: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* SEGREMAP | 0x1 */
        35: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        36: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        37: ctrl <= {I2C_WRITE_RAW,       7'h3c,       SEGREMAP | 1'b1,      8'h00,  NOP,      8'h00};
        38: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* COMSCANDEC */
        39: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        40: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        41: ctrl <= {I2C_WRITE_RAW,       7'h3c,       COMSCANDEC,           8'h00,  NOP,      8'h00};
        42: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* SETCOMPINS 0x02 */
        43: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        44: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        45: ctrl <= {I2C_WRITE_RAW,       7'h3c,       SETCOMPINS,           8'h00,  NOP,      8'h00};
        46: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h02,                8'h00,  NOP,      8'h00};
        47: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* SETCONTRAST 0x8f*/
        48: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        49: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        50: ctrl <= {I2C_WRITE_RAW,       7'h3c,       SETCONTRAST,          8'h00,  NOP,      8'h00};
        51: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h8f,                8'h00,  NOP,      8'h00};
        52: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* SETVCOMDETECT 0x40 */
        53: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        54: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        55: ctrl <= {I2C_WRITE_RAW,       7'h3c,       SETVCOMDETECT,        8'h00,  NOP,      8'h00};
        56: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h40,                8'h00,  NOP,      8'h00};
        57: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* DISPLAYALLON_RESUME */
        58: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        59: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        60: ctrl <= {I2C_WRITE_RAW,       7'h3c,       DISPLAYALLON_RESUME,  8'h00,  NOP,      8'h00};
        61: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* NORMALDISPLAY */
        62: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        63: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        64: ctrl <= {I2C_WRITE_RAW,       7'h3c,       NORMALDISPLAY,        8'h00,  NOP,      8'h00};
        65: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* DISPLAYON */
        66: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        67: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        68: ctrl <= {I2C_WRITE_RAW,       7'h3c,       DISPLAYON,            8'h00,  NOP,      8'h00};
        //69: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'd165};
        /* set 00 alarm seconds */
        69: ctrl <= {I2C_WRITE_8,         7'h68,       8'h00,                 8'h07,  NOP,      8'h60};

        /* nop */
        70: ctrl <= {I2C_NOP,              7'h00,       8'h00,               8'h00,  NOP,     8'd79};

        71: ctrl <= {I2C_NOP,              7'h68,       8'h00,               8'h00,  NOP,      8'h00};
        /* read seconds */
        72: ctrl <= {I2C_READ_U8,          7'h68,       8'h00,               8'h00,  LD,       8'h03};
        /* read minutes */
        73: ctrl <= {I2C_READ_U8,          7'h68,       8'h00,               8'h01,  LD,       8'h02};
        /* read hours   */
        74: ctrl <= {I2C_READ_U8,          7'h68,       8'h00,               8'h02,  LD,       8'h01};
        /* */
        75: ctrl <= {I2C_READ_U8,          7'h68,       8'h00,               8'h02,  JMP,      8'd79};
        /* write seconds */
        76: ctrl <= {I2C_WRITE_8,          7'h68,       8'h00,               8'h00,  NOP,      8'h00};
        /* write minutes */
        77: ctrl <= {I2C_WRITE_8,          7'h68,       8'h01,               8'h01,  NOP,      8'h00};
        /* write hours   */
        78: ctrl <= {I2C_WRITE_8,          7'h68,       8'h02,               8'h02,  NOP,      8'h05};
        /* wait */
        79: ctrl <= {I2C_NOP,          7'h68,       8'h00,               8'h11,   NOP,     8'h04};

        /* COLUMNADDR */
        80: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        81: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        82: ctrl <= {I2C_WRITE_RAW,       7'h3c,       COLUMNADDR,           8'h00,  NOP,      8'h00};
        83: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* 0 */
        84: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        85: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        86: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        87: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* 127 */
        88: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        89: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        90: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h7f,                8'h00,  NOP,      8'h00};
        91: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* PAGEADDR */
        92: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        93: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        94: ctrl <= {I2C_WRITE_RAW,       7'h3c,       PAGEADDR,             8'h00,  NOP,      8'h00};
        95: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* 0 */
        96: ctrl <= {I2C_START,           7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        97: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        98: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        99: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        /* 3 */
        100:  ctrl <= {I2C_START,          7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        101: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h00,                8'h00,  NOP,      8'h00};
        102: ctrl <= {I2C_WRITE_RAW,       7'h3c,       8'h03,                8'h00,  NOP,      8'h00};
        103: ctrl <= {I2C_STOP,            7'h3c,       8'h00,                8'h00,  NOP,      8'h00};

        104: ctrl <= {I2C_START,         7'h3c,       8'h00,                 8'h00,  NOP,       8'd69};
        105: ctrl <= {I2C_WRITE_RAW,     7'h3c,       8'h40,                 8'h00,  FB_FLUSH,  8'd69};
        106: ctrl <= {I2C_STOP,          7'h3c,       8'h00,                 8'h00,  NOP,       8'd69};
        107: ctrl <= {I2C_NOP,           7'h3c,       8'h00,                 8'h00,  NOP,       8'd69};

        /* m digit seconds  */
        108: ctrl <= {I2C_NOP,           7'h3c,       8'h00,                 8'h03,  PUTC,      8'h70};
        /* l digit seconds */
        109: ctrl <= {I2C_NOP,           7'h3c,       8'h01,                 8'h03,  PUTC,      8'h60};
        /* m digit minutes */
        110: ctrl <= {I2C_NOP,           7'h3c,       8'h00,                 8'h02,  PUTC,      8'h40};
        /* l digit minutes */
        111: ctrl <= {I2C_NOP,           7'h3c,       8'h01,                 8'h02,  PUTC,      8'h30};
        /* m digit hours */
        112: ctrl <= {I2C_NOP,           7'h3c,       8'h00,                 8'h01,  PUTC,      8'h10};
        /* l digit hours */
        113: ctrl <= {I2C_NOP,           7'h3c,       8'h01,                 8'h01,  PUTC,      8'h00};
        /* : */
        114: ctrl <= {I2C_NOP,           7'h3c,       8'h02,                 8'h01,  PUTC,      8'h50};
        /* : */
        115: ctrl <= {I2C_NOP,           7'h3c,       8'h02,                 8'h01,  PUTC,      8'h28};
        /* C Sign */
        116: ctrl <= {I2C_NOP,           7'h00,       8'h04,                 8'h00,  PUTC,      8'hd0};
        /* ones celsius */
        117: ctrl <= {I2C_NOP,           7'h00,       8'h05,                 8'h04,  PUTC,      8'he0};
        /* tens celsius */
        118: ctrl <= {I2C_NOP,           7'h00,       8'h03,                 8'h04,  PUTC,      8'hf0};
        /* celsius  */
        119: ctrl <= {I2C_READ_U8,       7'h68,       8'h00,                 8'h11,  LD,        8'h04};
        /* month  */
        120: ctrl <= {I2C_READ_U8,       7'h68,       8'h00,                 8'h05,  LD,        8'h05};
        /* m digit */
        121: ctrl <= {I2C_NOP,           7'h3c,       8'h01,                 8'h05,  PUTC,      8'h31};
        /* l digit */
        122: ctrl <= {I2C_NOP,           7'h3c,       8'h00,                 8'h05,  PUTC,      8'h41};
        /* day  */
        123: ctrl <= {I2C_READ_U8,       7'h68,       8'h00,                 8'h04,  LD,        8'h05};
        /* m digit */
        124: ctrl <= {I2C_NOP,           7'h3c,       8'h01,                 8'h05,  PUTC,      8'h01};
        /* l digit */
        125: ctrl <= {I2C_NOP,           7'h3c,       8'h00,                 8'h05,  PUTC,      8'h11};
        /* / */
        /* year  */
        126: ctrl <= {I2C_READ_U8,       7'h68,       8'h00,                 8'h06,  LD,        8'h05};
        /* m digit */
        127: ctrl <= {I2C_NOP,           7'h3c,       8'h01,                 8'h05,  PUTC,      8'h61};
        /* l digit */
        128: ctrl <= {I2C_NOP,           7'h3c,       8'h00,                 8'h05,  PUTC,      8'h71};
        /* / */
        129: ctrl <= {I2C_NOP,           7'h00,       8'h06,                 8'h05,  PUTC,     8'h51};

        /* alarm */
        /* read minutes */
        130: ctrl <= {I2C_READ_U8,          7'h68,       8'h00,               8'h08,  LD,       8'h02};
        /* read hours   */
        131: ctrl <= {I2C_READ_U8,          7'h68,       8'h00,               8'h09,  LD,       8'h01};
        /* print alarm */
        /* m digit minutes */
        132: ctrl <= {I2C_NOP,           7'h3c,       8'h00,                 8'h02,  PUTC,      8'hf1};
        /* l digit minutes */
        133: ctrl <= {I2C_NOP,           7'h3c,       8'h01,                 8'h02,  PUTC,      8'he1};
        /* m digit hours */
        134: ctrl <= {I2C_NOP,           7'h3c,       8'h00,                 8'h01,  PUTC,      8'hc1};
        /* l digit hours */
        135: ctrl <= {I2C_NOP,           7'h3c,       8'h01,                 8'h01,  PUTC,      8'hb1};
        /* : */
        136: ctrl <= {I2C_NOP,           7'h3c,       8'h02,                 8'h01,  PUTC,      8'hd1};

        /* / */
        137: ctrl <= {I2C_NOP,           7'h00,       8'h06,                 8'h05,  PUTC,     8'h21};
        138: ctrl <= {I2C_NOP,           7'h68,       8'h00,                 8'h00,  SETUP0,   8'h00};
        139: ctrl <= {I2C_NOP,           7'h68,       8'h00,                 8'h00,  SETUP1,   8'h60};
        140: ctrl <= {I2C_NOP,           7'h68,       8'h00,                 8'h00,  UNSETUP,  8'h60};
        /* alarm when hours, minutes, seconds match a1m4 */
        141: ctrl <= {I2C_WRITE_8,       7'h68,       8'h80,                 8'h0a,  NOP,      8'h60};
        /* alarm  1 interrupt enable */
        142: ctrl <= {I2C_WRITE_8,       7'h68,       8'b0001_1101,          8'h0e,  NOP,      8'h00};
        /* enable alarm */
        143: ctrl <= {I2C_WRITE_8,       7'h68,       8'h00,                 8'h0f,  NOP,    8'h60};
        /* */
        /* alarm symbol  */
        144: ctrl <= {I2C_NOP,           7'h00,       8'h07,                 8'h00,  PUTC,     8'ha0};
        145: ctrl <= {I2C_NOP,           7'h68,       8'h00,                 8'h00,  WAIT,     8'h1f};
        146: ctrl <= {I2C_NOP,           7'h00,       8'h00,                 8'h00,  JMP,      8'd70};

        default:
            ctrl <= 0;
    endcase
end

wire [7:0] mux_data_tx;
wire [7:0] mux_i2c_function;
wire [6:0] mux_slave_addr;
wire [7:0] mux_device_register;

always @(*) begin

    mux_slave_addr = slave_addr;
    if ((opcode == ALARM)) begin
        mux_data_tx = 8'h80;
        mux_device_register = 8'h0f;
        mux_i2c_function = I2C_WRITE_8;
    end else begin
        if ((opcode == SETUP1) && increment) begin
            mux_data_tx = tmp_value;
            mux_device_register = setup_device_register;
            mux_i2c_function = I2C_WRITE_8;
        end else if ((opcode == SETUP0) && increment) begin
            mux_data_tx = 0;
            mux_device_register = setup_device_register;
            mux_i2c_function = I2C_READ_U8;
        end else begin
            mux_device_register = device_register;
            if (opcode == FB_FLUSH) begin
                mux_data_tx = (rd ? ssd1306_out : 8'h40);
                mux_i2c_function = I2C_WRITE_RAW;
            end else begin
                mux_data_tx = data_tx;
                mux_i2c_function = i2c_function;
            end
        end
    end
end

/*       8               7           8          8              4         8 */
assign {i2c_function, slave_addr, data_tx, device_register, opcode, operand} = ctrl;

reg [7:0] i2c_function_fb_flush;
reg [7:0] tmp_value;

wire [4:0] sa;
wire [3:0] digita = sa[3:0];
wire sac = sa[4];

always @(*) begin
    sa = data_rx[3:0] + 1;
    if (sa > 9) sa = sa + 6;
end

wire [4:0] sb;
wire [3:0] digitb = sb[3:0];
//wire sbc = sb[4];

always @(*) begin
    sb = data_rx[7:4] + sac;
    //if (sb > 9) sb = sb + 6;
end

always @(posedge clk) begin
    if (~resetn) begin
        render <= 0;
        x <= ~0;
        y <= ~0;
        font <= 0;
        state <= 0;
        return_state <= 0;
        ip <= 0;
        enable <= 1'b1;
        led_idx <= 0;
        and_fb <= 1'b0;
        rd <= 1'b0;
        tmp_value <= 0;

`ifndef SIM
        reg_file[0] <= ~0;
        reg_file[1] <= ~0;
        reg_file[2] <= ~0;
        reg_file[3] <= ~0;
`endif
    end else begin
        case (state)
            0: begin
                if (i2c_ready) begin
                    state <= 1;
                end
            end
            1: begin
                if (done) begin

                    case (opcode)
                        SETUP0:begin
                            if (cur_pos == 2) tmp_value <= 0;
                            else begin
                                if (data_rx >= setup_device_register_mask)
                                        if (cur_pos == 0 || cur_pos == 1 || cur_pos == 6 || cur_pos == 7) tmp_value <= 0; else tmp_value <= 1;
                                else
                                    tmp_value <= {digitb, digita};
                            end

                            ip <= ip + 1;
                            state <= 0;
                        end
                        SETUP1: begin
                            ip <= ip + 1;
                            state <= 0;
                        end
                        ALARM: begin
                            ip <= ip + 1;
                            state <= 0;
                        end
                        FB_FLUSH: begin
                            state <= 10;
                        end
                        JMP: begin
                            ip <= operand;
                            state <= 0;
                        end
                        LD: begin
                            led_idx <= operand;
                            ip <= ip + 1;
                            state <= 0;
                        end
                        WAIT: begin
                          `ifndef SIM
                            wait_states[22 -:8] <= operand -1;
                            return_state <= 0;
                            state <= 15;
                          `else
                            state <= 0;
                          `endif
                            ip <= ip + 1;
                        end
                        PUTC: begin
                            x <= (operand & 8'hf0)>>4;
                            y <= (operand & 8'h0f);
                            rd <= 0;
                            font <= 8'hff;
                            and_fb <= 1'b1;
                            render <= 1'b1;
                            if (ready_gfx) begin
                                state <= 5;
                            end
                        end
                        STOP: begin
                          `ifdef SIM
                            $finish;
                    `endif
                            ip <= ip;
                            state <= 0;
                        end
                        default: begin
                            ip <= ip + 1;
                            state <= 0;
                        end
                    endcase
                `ifndef SIM
                    if (opcode == LD) begin
                        reg_file[operand] <= data_rx;
                        state <= 0;
                    end
                `endif
                end
            end

            5: begin
                render <= 1'b0;
                if (done_gfx) begin
                    if ((operand >= 8'hb1) & (operand & 1) & ~setup) begin
                        and_fb <= 1'b1;
                        font <= 8'hff;
                        state <= 6;
                    end else begin
                        and_fb <= 1'b0;
                        /* temperature */
                        if (data_tx == 3) begin
                            font <= 8'd09;//"0";
                        end else if (data_tx == 7) begin /* alarm sign */
                            if (!blink_alarm) begin
                                font <= (enabled_alarm) ? 8'd15 : 8'hff;
                                and_fb <= (enabled_alarm) ? 1'b0 : 1'b1;
                            end else begin
                                font <= 8'hff;
                                and_fb <= 1;
                            end
                        end else if (data_tx == 4) begin /* tens celsius */
                            font <= tens + "0";
                        end else if (data_tx == 5) begin /* ones celsius */
                            font <= ones + "0";
                        end else if (data_tx == 6) begin /* / sign */
                            font <= "/";
                        end else if (data_tx == 2) begin /* colun */
                            font <= ":";
                        end else if (data_tx == 1) begin /* colun */

                            if (blink_comb0 || blink_comb1) begin
                                font <= 8'hff;
                                and_fb <= 1;
                            end else begin
                                font <= ((reg_file[device_register] & 8'hf0) >> 4) + "0";
                            end
                        end else if (data_tx == 0) begin /* colun */

                            if (blink_comb0 || blink_comb1) begin
                                font <= 8'hff;
                                and_fb <= 1;
                            end else begin
                                font <= (reg_file[device_register] & 8'h0f) + "0";
                            end

                        end else begin
                            /* clock */
                        end
                        state <= 6;
                    end
                end
            end

            6: begin
                if (ready_gfx) begin
                    render <= 1'b1;
                    state <= 7;
                end
            end

            7: begin
                if (done_gfx) begin
                    render <= 1'b0;
                    ip <= ip + 1;
                    state <= 0;
                end
            end


            10: begin

                if (i2c_ready) begin
                    ssd1306_addr <= 0;
                    rd <= 1'b1;
                    state <= 11;
                end
            end

            11: begin
                if (done)begin
                    state <= 2;
                end
            end

            2: begin
                if (&ssd1306_addr) begin
                    ip <= ip + 1;
                    state <= 0;
                    rd <= 1'b0;
                end else begin
                    if (i2c_ready) begin
                        ssd1306_addr <= ssd1306_addr + 1;
                        state <= 3;
                    end
                end

            end

            3: begin
                if (done) begin
                    state <= 2;
                end
            end

            15: begin
                wait_states <= wait_states -1;
                if (wait_states == 1) state <= return_state;
            end

            default:
                state <= 0;
        endcase
    end
end

endmodule
