`timescale 1 ns / 100 ps

// Build this top with the sources in rachel_processor/proc only.
// Jill's processor tree uses the same module names and will collide in Vivado.

module FinalProjectJRPaint(
    input clk,
    output hSync,
    output vSync,
    output [3:0] VGA_R,
    output [3:0] VGA_G,
    output [3:0] VGA_B,
    output LED17_B,
    output LED17_G,
    output LED17_R,
    output DISP_SEG_A,
    output DISP_SEG_B,
    output DISP_SEG_C,
    output DISP_SEG_D,
    output DISP_SEG_E,
    output DISP_SEG_F,
    output DISP_SEG_G,
    output DISP_DP,
    output [7:0] DISP_EN,
    output audioOut,
    output audioEn,
    output chSel,
    inout ps2_clk,
    inout ps2_data,
    input [15:0] SW,
    input BTNU,
    input BTNL,
    input BTNR,
    input BTND,
    input BTNC
);

    localparam VIDEO_W = 640;
    localparam VIDEO_H = 480;

    localparam CELL_SIZE  = 8;
    localparam GRID_W     = 80;
    localparam GRID_H     = 60;
    localparam GRID_COUNT = GRID_W * GRID_H;
    localparam GRID_AW    = $clog2(GRID_COUNT);

    localparam [31:0] MMIO_MOUSE_DX      = 32'd4096;
    localparam [31:0] MMIO_MOUSE_DY      = 32'd4097;
    localparam [31:0] MMIO_MOUSE_BUTTONS = 32'd4098;
    localparam [31:0] MMIO_MOUSE_PACKET  = 32'd4099;
    localparam [31:0] MMIO_FRAME  = 32'd4100;
    localparam [31:0] MMIO_CX     = 32'd4101;
    localparam [31:0] MMIO_CY     = 32'd4102;
    localparam [31:0] MMIO_BTNC   = 32'd4103;
    localparam [31:0] MMIO_SW     = 32'd4104;
    localparam [31:0] MMIO_LED    = 32'd4105;
    localparam [31:0] MMIO_PEN    = 32'd4106;
    localparam [31:0] DRAW_BASE   = 32'd8192;
    localparam [31:0] DRAW_LAST   = DRAW_BASE + GRID_COUNT - 1;

    localparam CURSOR_SIZE   = 50;
    localparam CURSOR_PIXELS = CURSOR_SIZE * CURSOR_SIZE;
    localparam CURSOR_AW     = $clog2(CURSOR_PIXELS) + 1;
    localparam [7:0] CURSOR_COLOR = 8'd94;

    reg [11:0] palette[0:255];
    initial $readmemh("colors.mem", palette);

    wire clk25;
    wire locked;
    wire reset;
    assign reset = ~locked;

    clk_wiz_0 pll (
        .clk_out1(clk25),
        .reset(1'b0),
        .locked(locked),
        .clk_in1(clk)
    );

    wire active;
    wire screenEnd;
    wire [9:0] x;
    wire [8:0] y;

    VGATimingGenerator #(
        .HEIGHT(VIDEO_H),
        .WIDTH(VIDEO_W)
    ) Display (
        .clk25(clk25),
        .reset(reset),
        .screenEnd(screenEnd),
        .active(active),
        .hSync(hSync),
        .vSync(vSync),
        .x(x),
        .y(y)
    );

    wire [GRID_AW-1:0] displayAddr;
    assign displayAddr = y[8:3] * GRID_W + x[9:3];

    wire regWriteEn;
    wire memWriteEn;
    wire [4:0] regWriteAddr;
    wire [4:0] regReadAddrA;
    wire [4:0] regReadAddrB;
    wire [31:0] imemAddr;
    wire [31:0] imemQ;
    wire [31:0] dmemAddr;
    wire [31:0] dmemData;
    wire [31:0] dmemQ;
    wire [31:0] regWriteData;
    wire [31:0] regReadDataA;
    wire [31:0] regReadDataB;

    processor CPU (
        .clock(clk25),
        .reset(reset),
        .address_imem(imemAddr),
        .q_imem(imemQ),
        .address_dmem(dmemAddr),
        .data(dmemData),
        .wren(memWriteEn),
        .q_dmem(dmemQ),
        .ctrl_writeEnable(regWriteEn),
        .ctrl_writeReg(regWriteAddr),
        .ctrl_readRegA(regReadAddrA),
        .ctrl_readRegB(regReadAddrB),
        .data_writeReg(regWriteData),
        .data_readRegA(regReadDataA),
        .data_readRegB(regReadDataB)
    );

    ROM #(
        .MEMFILE("finalprojectJRPaint_assembly.mem")
    ) InstMem (
        .clk(clk25),
        .addr(imemAddr[11:0]),
        .dataOut(imemQ)
    );

    regfile RegisterFile (
        .clock(clk25),
        .ctrl_writeEnable(regWriteEn),
        .ctrl_reset(reset),
        .ctrl_writeReg(regWriteAddr),
        .ctrl_readRegA(regReadAddrA),
        .ctrl_readRegB(regReadAddrB),
        .data_writeReg(regWriteData),
        .data_readRegA(regReadDataA),
        .data_readRegB(regReadDataB)
    );

    wire [7:0] ps2RxData;
    wire ps2ReadData;
    wire ps2Busy;
    wire ps2Err;
    wire [7:0] ps2TxData;
    wire ps2WriteData;

    Ps2Interface MouseInterface (
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .clk(clk25),
        .rst(reset),
        .tx_data(ps2TxData),
        .write_data(ps2WriteData),
        .rx_data(ps2RxData),
        .read_data(ps2ReadData),
        .busy(ps2Busy),
        .err(ps2Err)
    );

    wire signed [11:0] mouseDx;
    wire signed [11:0] mouseDy;
    wire mouseLeft;
    wire mouseRight;
    wire mouseMiddle;
    wire mousePacketReady;

    wire drawWrite;
    wire cxWrite;
    wire cyWrite;
    wire ledWrite;
    wire penWrite;
    wire mouseAckWrite;
    wire ramWrite;
    wire [GRID_AW-1:0] drawAddr;
    wire [31:0] ramQ;

    assign drawWrite = memWriteEn && (dmemAddr >= DRAW_BASE) && (dmemAddr <= DRAW_LAST);
    assign cxWrite = memWriteEn && (dmemAddr == MMIO_CX);
    assign cyWrite = memWriteEn && (dmemAddr == MMIO_CY);
    assign ledWrite = memWriteEn && (dmemAddr == MMIO_LED);
    assign penWrite = memWriteEn && (dmemAddr == MMIO_PEN);
    assign mouseAckWrite = memWriteEn && (dmemAddr == MMIO_MOUSE_PACKET);
    assign ramWrite = memWriteEn && ~drawWrite && ~cxWrite && ~cyWrite && ~ledWrite && ~penWrite && ~mouseAckWrite;
    assign drawAddr = dmemAddr - DRAW_BASE;

    MousePacketDecoder MouseDecoder (
        .clk(clk25),
        .reset(reset),
        .rxData(ps2RxData),
        .rxValid(ps2ReadData),
        .busy(ps2Busy),
        .clearPacket(mouseAckWrite),
        .txData(ps2TxData),
        .txWrite(ps2WriteData),
        .dx(mouseDx),
        .dy(mouseDy),
        .left(mouseLeft),
        .right(mouseRight),
        .middle(mouseMiddle),
        .packetReady(mousePacketReady)
    );

    RAM #(
        .DATA_WIDTH(32),
        .ADDRESS_WIDTH(12),
        .DEPTH(4096)
    ) ProcMem (
        .clk(clk25),
        .wEn(ramWrite),
        .addr(dmemAddr[11:0]),
        .dataIn(dmemData),
        .dataOut(ramQ)
    );

    wire [GRID_AW-1:0] canvasAddr;
    wire [3:0] canvasColor;
    assign canvasAddr = drawWrite ? drawAddr : displayAddr;

    RAM #(
        .DEPTH(GRID_COUNT),
        .DATA_WIDTH(4),
        .ADDRESS_WIDTH(GRID_AW)
    ) CanvasMemory (
        .clk(clk25),
        .wEn(drawWrite),
        .addr(canvasAddr),
        .dataIn(dmemData[3:0]),
        .dataOut(canvasColor)
    );

    reg frameToggle;
    reg [6:0] cursorX;
    reg [5:0] cursorY;
    reg [3:0] ledColor;
    reg [2:0] penSize;
    reg [15:0] dispCount;
    reg active_q;
    reg inCursor_q;
    reg canvasRead_q;
    reg mmioRead_q;
    reg [31:0] mmioData;

    assign dmemQ = mmioRead_q ? mmioData : ramQ;

    wire signed [11:0] sx;
    wire signed [11:0] sy;
    wire signed [11:0] cursorLeft;
    wire signed [11:0] cursorTop;
    wire [6:0] cursorDrawSize;
    wire inCursor;
    wire [6:0] cursorLocalX;
    wire [6:0] cursorLocalY;
    wire [5:0] cursorSpriteX;
    wire [5:0] cursorSpriteY;
    wire [CURSOR_AW-1:0] cursorAddr;
    wire cursorPixel;

    assign sx = $signed({2'b00, x});
    assign sy = $signed({3'b000, y});
    // Keep the cursor scale aligned with the selected brush size.
    assign cursorDrawSize =
        (penSize == 3'd1) ? 7'd40  :
        (penSize == 3'd2) ? 7'd66  :
        (penSize == 3'd3) ? 7'd92  :
        (penSize == 3'd4) ? 7'd116 : 7'd127;
    assign cursorLeft = $signed({2'b00, cursorX, 3'b000}) + 12'sd4 - ($signed({5'b0, cursorDrawSize}) >>> 1);
    assign cursorTop = $signed({3'b000, cursorY, 3'b000}) + 12'sd4 - ($signed({5'b0, cursorDrawSize}) >>> 1);

    assign inCursor =
        active &&
        (sx >= cursorLeft) &&
        (sx < cursorLeft + $signed({5'b0, cursorDrawSize})) &&
        (sy >= cursorTop) &&
        (sy < cursorTop + $signed({5'b0, cursorDrawSize}));

    assign cursorLocalX = sx - cursorLeft;
    assign cursorLocalY = sy - cursorTop;
    assign cursorSpriteX = inCursor ? ((cursorLocalX * CURSOR_SIZE) / cursorDrawSize) : 6'd0;
    assign cursorSpriteY = inCursor ? ((cursorLocalY * CURSOR_SIZE) / cursorDrawSize) : 6'd0;
    assign cursorAddr = cursorSpriteY * CURSOR_SIZE + cursorSpriteX;

    ROM #(
        .DATA_WIDTH(1),
        .ADDRESS_WIDTH(CURSOR_AW),
        .DEPTH(CURSOR_PIXELS),
        .MEMFILE("cursor.mem")
    ) CursorSprite (
        .clk(clk25),
        .addr(cursorAddr),
        .dataOut(cursorPixel)
    );

    always @(posedge clk25 or posedge reset) begin
        if (reset) begin
            frameToggle <= 1'b0;
            cursorX <= GRID_W / 2;
            cursorY <= GRID_H / 2;
            ledColor <= 4'd0;
            penSize <= 3'd1;
            dispCount <= 16'd0;
            active_q <= 1'b0;
            inCursor_q <= 1'b0;
            canvasRead_q <= 1'b0;
            mmioRead_q <= 1'b0;
            mmioData <= 32'd0;
        end else begin
            active_q <= active;
            inCursor_q <= inCursor;
            canvasRead_q <= ~drawWrite;
            dispCount <= dispCount + 16'd1;

            if (screenEnd)
                frameToggle <= ~frameToggle;

            if (cxWrite)
                cursorX <= dmemData[6:0];

            if (cyWrite)
                cursorY <= dmemData[5:0];

            if (ledWrite)
                ledColor <= dmemData[3:0];

            if (penWrite)
                penSize <= dmemData[2:0];

            mmioRead_q <= 1'b1;
            case (dmemAddr)
                MMIO_MOUSE_DX:      mmioData <= {{20{mouseDx[11]}}, mouseDx};
                MMIO_MOUSE_DY:      mmioData <= {{20{mouseDy[11]}}, mouseDy};
                MMIO_MOUSE_BUTTONS: mmioData <= {29'd0, mouseMiddle, mouseRight, mouseLeft};
                MMIO_MOUSE_PACKET:  mmioData <= {31'd0, mousePacketReady};
                MMIO_FRAME: mmioData <= {31'd0, frameToggle};
                MMIO_CX:    mmioData <= {25'd0, cursorX};
                MMIO_CY:    mmioData <= {26'd0, cursorY};
                MMIO_BTNC:  mmioData <= {31'd0, BTNC};
                MMIO_SW:    mmioData <= {16'd0, SW};
                MMIO_LED:   mmioData <= {28'd0, ledColor};
                MMIO_PEN:   mmioData <= {29'd0, penSize};
                default: begin
                    mmioRead_q <= 1'b0;
                    mmioData <= 32'd0;
                end
            endcase
        end
    end

    wire [11:0] colorData;
    assign colorData = active_q
        ? ((inCursor_q && cursorPixel) ? palette[CURSOR_COLOR]
                                       : (canvasRead_q ? palette[canvasColor] : palette[0]))
        : palette[10];

    assign {VGA_R, VGA_G, VGA_B} = colorData;
    assign LED17_R = (ledColor != 4'd0) && |palette[ledColor][11:8];
    assign LED17_G = (ledColor != 4'd0) && |palette[ledColor][7:4];
    assign LED17_B = (ledColor != 4'd0) && |palette[ledColor][3:0];

    assign {DISP_SEG_A, DISP_SEG_B, DISP_SEG_C, DISP_SEG_D, DISP_SEG_E, DISP_SEG_F, DISP_SEG_G} =
        dispCount[15]
            ? ((penSize == 3'd5) ? 7'b1001111 : 7'b0000001)
            : ((penSize == 3'd1) ? 7'b0010010 :
               (penSize == 3'd2) ? 7'b1001100 :
               (penSize == 3'd3) ? 7'b0100000 :
               (penSize == 3'd4) ? 7'b0000000 :
                                   7'b0000001);
    assign DISP_DP = ~dispCount[15];
    assign DISP_EN = dispCount[15] ? 8'b11111101 : 8'b11111110;

    ColorAudioController AudioCue (
        .clk(clk),
        .reset(reset),
        .color(ledColor),
        .audioOut(audioOut),
        .audioEn(audioEn),
        .chSel(chSel)
    );

endmodule

module ColorAudioController(
    input clk,
    input reset,
    input [3:0] color,
    output audioOut,
    output audioEn,
    output chSel
);

    localparam integer SAMPLE_RATE = 8000;
    localparam integer SAMPLE_DIVIDER = 100_000_000 / SAMPLE_RATE;

    assign chSel = 1'b0;
    assign audioEn = 1'b1;
`include "color_audio_table.vh"

    reg [AUDIO_AW-1:0] sample_addr;
    reg [AUDIO_AW-1:0] samples_left;
    reg [13:0] sample_divider;
    reg [9:0] pwm_level;
    reg playback_active;
    reg [3:0] color_q;
    wire [7:0] sample_q;

    AudioSampleROM #(
        .DATA_WIDTH(8),
        .ADDRESS_WIDTH(AUDIO_AW),
        .DEPTH(AUDIO_DEPTH),
        .MEMFILE("color_audio.mem")
    ) AudioSamples (
        .clk(clk),
        .addr(sample_addr),
        .dataOut(sample_q)
    );

    PWMSerializer #(
        .PERIOD_WIDTH_NS(20000),
        .SYS_FREQ_MHZ(100)
    ) AudioPwm (
        .clk(clk),
        .reset(reset),
        .duty_cycle(playback_active ? pwm_level : 10'd512),
        .signal(audioOut)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sample_addr <= {AUDIO_AW{1'b0}};
            samples_left <= {AUDIO_AW{1'b0}};
            sample_divider <= 14'd0;
            pwm_level <= 10'd512;
            playback_active <= 1'b0;
            color_q <= 4'd0;
        end else begin
            color_q <= color;

            if (color != color_q) begin
                sample_divider <= 14'd0;
                pwm_level <= 10'd512;

                case (color)
                    4'd1: begin
                        sample_addr <= WHITE_START;
                        samples_left <= WHITE_LEN;
                        playback_active <= 1'b1;
                    end
                    4'd2: begin
                        sample_addr <= PINK_START;
                        samples_left <= PINK_LEN;
                        playback_active <= 1'b1;
                    end
                    4'd3: begin
                        sample_addr <= RED_START;
                        samples_left <= RED_LEN;
                        playback_active <= 1'b1;
                    end
                    4'd4: begin
                        sample_addr <= ORANGE_START;
                        samples_left <= ORANGE_LEN;
                        playback_active <= 1'b1;
                    end
                    4'd5: begin
                        sample_addr <= YELLOW_START;
                        samples_left <= YELLOW_LEN;
                        playback_active <= 1'b1;
                    end
                    4'd6: begin
                        sample_addr <= GREEN_START;
                        samples_left <= GREEN_LEN;
                        playback_active <= 1'b1;
                    end
                    4'd7: begin
                        sample_addr <= BLUE_START;
                        samples_left <= BLUE_LEN;
                        playback_active <= 1'b1;
                    end
                    4'd8: begin
                        sample_addr <= PURPLE_START;
                        samples_left <= PURPLE_LEN;
                        playback_active <= 1'b1;
                    end
                    4'd9: begin
                        sample_addr <= BROWN_START;
                        samples_left <= BROWN_LEN;
                        playback_active <= 1'b1;
                    end
                    4'd10: begin
                        sample_addr <= BLACK_START;
                        samples_left <= BLACK_LEN;
                        playback_active <= 1'b1;
                    end
                    default: begin
                        sample_addr <= {AUDIO_AW{1'b0}};
                        samples_left <= {AUDIO_AW{1'b0}};
                        playback_active <= 1'b0;
                    end
                endcase
            end else if (playback_active) begin
                if (sample_divider == SAMPLE_DIVIDER - 1) begin
                    sample_divider <= 14'd0;
                    pwm_level <= {sample_q, 2'b00};
                    if (samples_left == {{(AUDIO_AW-1){1'b0}}, 1'b1}) begin
                        playback_active <= 1'b0;
                        samples_left <= {AUDIO_AW{1'b0}};
                    end else begin
                        sample_addr <= sample_addr + {{(AUDIO_AW-1){1'b0}}, 1'b1};
                        samples_left <= samples_left - {{(AUDIO_AW-1){1'b0}}, 1'b1};
                    end
                end else begin
                    sample_divider <= sample_divider + 14'd1;
                end
            end else begin
                sample_divider <= 14'd0;
                pwm_level <= 10'd512;
            end
        end
    end
endmodule

module AudioSampleROM #(
    parameter DATA_WIDTH = 8,
    parameter ADDRESS_WIDTH = 8,
    parameter DEPTH = 256,
    parameter MEMFILE = ""
)(
    input wire clk,
    input wire [ADDRESS_WIDTH-1:0] addr,
    output reg [DATA_WIDTH-1:0] dataOut = 0
);

    (* rom_style = "block" *) reg [DATA_WIDTH-1:0] memoryArray [0:DEPTH-1];

    initial begin
        if (MEMFILE != "") begin
            $readmemh(MEMFILE, memoryArray);
        end
    end

    always @(posedge clk) begin
        dataOut <= memoryArray[addr];
    end
endmodule

module MousePacketDecoder(
    input clk,
    input reset,
    input [7:0] rxData,
    input rxValid,
    input busy,
    input clearPacket,
    output reg [7:0] txData,
    output reg txWrite,
    output reg signed [11:0] dx,
    output reg signed [11:0] dy,
    output reg left,
    output reg right,
    output reg middle,
    output reg packetReady
);

    reg sawSelfTest;
    reg enablePending;
    reg enabled;
    reg [1:0] byteCount;
    reg [7:0] byte0;
    reg [7:0] byte1;
    reg currentLeft;
    reg currentRight;
    reg currentMiddle;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            txData <= 8'h00;
            txWrite <= 1'b0;
            dx <= 12'sd0;
            dy <= 12'sd0;
            left <= 1'b0;
            right <= 1'b0;
            middle <= 1'b0;
            packetReady <= 1'b0;
            sawSelfTest <= 1'b0;
            enablePending <= 1'b0;
            enabled <= 1'b0;
            byteCount <= 2'd0;
            byte0 <= 8'h00;
            byte1 <= 8'h00;
            currentLeft <= 1'b0;
            currentRight <= 1'b0;
            currentMiddle <= 1'b0;
        end else begin
            txWrite <= 1'b0;

            if (clearPacket) begin
                dx <= 12'sd0;
                dy <= 12'sd0;
                packetReady <= 1'b0;
                left <= currentLeft;
                right <= currentRight;
                middle <= currentMiddle;
            end

            if (enablePending && ~busy) begin
                txData <= 8'hF4;
                txWrite <= 1'b1;
                enablePending <= 1'b0;
            end

            if (rxValid) begin
                if (~enabled) begin
                    if (rxData == 8'hAA) begin
                        sawSelfTest <= 1'b1;
                    end else if (sawSelfTest && (rxData == 8'h00)) begin
                        enablePending <= 1'b1;
                    end else if (rxData == 8'hFA) begin
                        enabled <= 1'b1;
                        sawSelfTest <= 1'b0;
                    end
                end else begin
                    case (byteCount)
                        2'd0: begin
                            if (rxData[3]) begin
                                byte0 <= rxData;
                                byteCount <= 2'd1;
                            end
                        end
                        2'd1: begin
                            byte1 <= rxData;
                            byteCount <= 2'd2;
                        end
                        default: begin
                            currentLeft <= byte0[0];
                            currentRight <= byte0[1];
                            currentMiddle <= byte0[2];
                            left <= byte0[0];
                            right <= byte0[1];
                            middle <= byte0[2];
                            if (~byte0[6])
                                dx <= dx + $signed({{3{byte0[4]}}, byte0[4], byte1});
                            if (~byte0[7])
                                dy <= dy + $signed({{3{byte0[5]}}, byte0[5], rxData});
                            packetReady <= 1'b1;
                            byteCount <= 2'd0;
                        end
                    endcase
                end
            end
        end
    end
endmodule
