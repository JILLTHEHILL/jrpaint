module regfile (
	clock,
	ctrl_writeEnable, ctrl_reset, ctrl_writeReg,
	ctrl_readRegA, ctrl_readRegB, data_writeReg,
	data_readRegA, data_readRegB
);

    input clock,ctrl_writeEnable,ctrl_reset;
    input [4:0] ctrl_writeReg,ctrl_readRegA,ctrl_readRegB;
    input [31:0] data_writeReg;

    output [31:0] data_readRegA,data_readRegB;

    wire [31:0] readSelectA;
    wire [31:0] readSelectB;
    assign readSelectA=32'b1<<ctrl_readRegA;
    assign readSelectB=32'b1<<ctrl_readRegB;

    wire [31:0] r0;
    assign r0=32'b0;

    wire flagWEnonZero;
    wire t0,t1,t2;
    or o0(t0,ctrl_writeReg[0],ctrl_writeReg[1]);
    or o1(t1,ctrl_writeReg[2],ctrl_writeReg[3]);
    or o2(t2,t0,t1);
    or o3(flagWEnonZero,t2,ctrl_writeReg[4]);

    wire actualWE;
    and a0(actualWE,ctrl_writeEnable,flagWEnonZero);

    wire [31:0] writeSelectBits;
    assign writeSelectBits=actualWE<<ctrl_writeReg;

    tristateBuffer tri0A(.out(data_readRegA),.in(r0),.en(readSelectA[0]));
    tristateBuffer tri0B(.out(data_readRegB),.in(r0),.en(readSelectB[0]));

    genvar i;
    generate
    for(i=1;i<32;i=i+1) begin:REG_AND_READS
        wire [31:0] qi;
        register #(.W(32)) regN(.clock(clock),.out(qi),.in(data_writeReg),.enable(writeSelectBits[i]),.reset(ctrl_reset));
        tristateBuffer triA(.out(data_readRegA),.in(qi),.en(readSelectA[i]));
        tristateBuffer triB(.out(data_readRegB),.in(qi),.en(readSelectB[i]));
    end
    endgenerate
endmodule

module tristateBuffer(out,in,en);
    input [31:0] in;
    input en;
    output [31:0] out;
    assign out=en?in:32'bz;
endmodule