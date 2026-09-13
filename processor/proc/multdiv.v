module multdiv(
	data_operandA, data_operandB, 
	ctrl_MULT, ctrl_DIV, 
	clock, 
	data_result, data_exception, data_resultRDY);

    input [31:0] data_operandA, data_operandB;
    input ctrl_MULT, ctrl_DIV, clock;

    output [31:0] data_result;
    output data_exception, data_resultRDY;

    wire [4:0] multCount;
    wire multActive_q, multActive_d;

    wire multDone;
    wire multReady;
    wire [64:0] boothNum_q,boothNum_d;
    wire [2:0] boothBits;
    wire [31:0] boothAluOut;
    wire boothNoOp;
    wire boothDoOp;
    wire [31:0] boothOperand;
    wire signed [64:0] boothPreShift,boothPostShift;
    wire multException;
    wire [31:0] multResult;

    tFlipFlop m0(.t(multActive_q),.clock(clock),.reset(ctrl_MULT|ctrl_DIV),.q(multCount[0]));
    tFlipFlop m1(.t(multActive_q&multCount[0]),.clock(clock),.reset(ctrl_MULT|ctrl_DIV),.q(multCount[1]));
    tFlipFlop m2(.t(multActive_q&multCount[0]&multCount[1]),.clock(clock),.reset(ctrl_MULT|ctrl_DIV),.q(multCount[2]));
    tFlipFlop m3(.t(multActive_q&multCount[0]&multCount[1]&multCount[2]),.clock(clock),.reset(ctrl_MULT|ctrl_DIV),.q(multCount[3]));
    tFlipFlop m4(.t(multActive_q&multCount[0]&multCount[1]&multCount[2]&multCount[3]),.clock(clock),.reset(ctrl_MULT|ctrl_DIV),.q(multCount[4]));

    assign multDone=multCount[4]&multCount[0]&~multCount[3]&~multCount[2]&~multCount[1];
    assign multReady=multActive_q&multDone;

    register #(.W(65)) multStateReg(.clock(clock),.in(boothNum_d),.out(boothNum_q),.enable(1'b1),.reset(ctrl_MULT));

    assign boothBits=boothNum_q[2:0];

    assign boothNoOp =(~boothBits[2] & ~boothBits[1] & ~boothBits[0]) | ( boothBits[2] &  boothBits[1] &  boothBits[0]);
    assign boothDoOp = (~boothBits[2] &  boothBits[1] &  boothBits[0]) | ( boothBits[2] & ~boothBits[1] & ~boothBits[0]);

    assign boothOperand=boothDoOp?(data_operandA<<1):data_operandA;

    alu multAlu(.data_operandA(boothNum_q[64:33]),.data_operandB(boothOperand),.ctrl_ALUopcode({4'b0000,boothBits[2]}),.ctrl_shiftamt(5'b0),.data_result(boothAluOut),.isNotEqual(),.isLessThan(),.overflow());
    assign boothPreShift=boothNoOp?boothNum_q:{boothAluOut,boothNum_q[32:0]};

    assign boothPostShift=boothPreShift>>>2;

    assign boothNum_d=(~(multCount[4] | multCount[3] | multCount[2] | multCount[1] | multCount[0]))?{32'b0,data_operandB,1'b0}:boothPostShift;

    wire m_aIsMinInt,m_bIsMinInt,m_aIsNegOne,m_bIsNegOne;
    wire m_specialOvf;

    assign m_aIsMinInt= (data_operandA[31]& ~data_operandA[30]& ~data_operandA[29]& ~data_operandA[28]&
    ~data_operandA[27]& ~data_operandA[26]& ~data_operandA[25]& ~data_operandA[24]&
    ~data_operandA[23]& ~data_operandA[22]& ~data_operandA[21]& ~data_operandA[20]&
    ~data_operandA[19]& ~data_operandA[18]& ~data_operandA[17]& ~data_operandA[16]&
    ~data_operandA[15]& ~data_operandA[14]& ~data_operandA[13]& ~data_operandA[12]&
    ~data_operandA[11]& ~data_operandA[10]& ~data_operandA[9]& ~data_operandA[8]&
    ~data_operandA[7]& ~data_operandA[6]& ~data_operandA[5]& ~data_operandA[4]&
    ~data_operandA[3]& ~data_operandA[2]& ~data_operandA[1]& ~data_operandA[0]);
    assign m_bIsMinInt= (data_operandB[31]& ~data_operandB[30]& ~data_operandB[29]&
    ~data_operandB[28]& ~data_operandB[27]& ~data_operandB[26]&
    ~data_operandB[25]& ~data_operandB[24]& ~data_operandB[23]&
    ~data_operandB[22]& ~data_operandB[21]& ~data_operandB[20]&
    ~data_operandB[19]& ~data_operandB[18]& ~data_operandB[17]&
    ~data_operandB[16]& ~data_operandB[15]& ~data_operandB[14]&
    ~data_operandB[13]& ~data_operandB[12]& ~data_operandB[11]&
    ~data_operandB[10]& ~data_operandB[9]& ~data_operandB[8]&
    ~data_operandB[7]& ~data_operandB[6]& ~data_operandB[5]&
    ~data_operandB[4]& ~data_operandB[3]& ~data_operandB[2]&
    ~data_operandB[1]& ~data_operandB[0]);
    assign m_aIsNegOne=&data_operandA;
    assign m_bIsNegOne=&data_operandB;
    assign m_specialOvf=(m_aIsMinInt&m_bIsNegOne)|(m_bIsMinInt&m_aIsNegOne);

    wire upperAllZero;
    wire upperAllOne;
    wire resultSignBit;
    wire signExtendOk;
    wire signExtendOverflow;

    assign upperAllZero=~(|boothNum_q[64:33]);
    assign upperAllOne=&boothNum_q[64:33];
    assign resultSignBit=boothNum_q[32];

    assign signExtendOk= ((~resultSignBit&upperAllZero)|
    (resultSignBit&upperAllOne));

    assign signExtendOverflow=~signExtendOk;
    assign multException=m_specialOvf|signExtendOverflow;
    assign multResult=boothNum_q[32:1];

    assign multActive_d=ctrl_MULT?1'b1:(ctrl_DIV|multDone)?1'b0:multActive_q;
    dffe_ref multActiveFf(.q(multActive_q),.d(multActive_d),.clk(clock),.en(1'b1),.clr(1'b0));

    //div
    wire [31:0] divResult;
    wire divReady;
    wire divException;

    div divUnit(.clock(clock),.clr(1'b0),.start(ctrl_DIV),.cancel(ctrl_MULT),.opA(data_operandA),.opB(data_operandB),.result(divResult),.resultRDY(divReady),.exception(divException));

    assign data_result=multReady?multResult:divReady?divResult:32'b0;
    assign data_exception=multReady?multException:divReady?divException:1'b0;
    assign data_resultRDY=multReady|divReady;
endmodule

module div(clock,clr,start,cancel,opA,opB,result,resultRDY,exception);
    input clock,clr;
    input start;
    input cancel;
    input [31:0] opA,opB;
    output [31:0] result;
    output resultRDY;
    output exception;

    wire [5:0] divCount;
    wire resetAll;
    wire divActive_q,divActive_d;
    wire divDone;

    assign resetAll=clr|start|cancel;

    tFlipFlop d0(.t(divActive_q),.clock(clock),.reset(resetAll),.q(divCount[0]));
    tFlipFlop d1(.t(divActive_q&divCount[0]),.clock(clock),.reset(resetAll),.q(divCount[1]));
    tFlipFlop d2(.t(divActive_q&divCount[0]&divCount[1]),.clock(clock),.reset(resetAll),.q(divCount[2]));
    tFlipFlop d3(.t(divActive_q&divCount[0]&divCount[1]&divCount[2]),.clock(clock),.reset(resetAll),.q(divCount[3]));
    tFlipFlop d4(.t(divActive_q&divCount[0]&divCount[1]&divCount[2]&divCount[3]),.clock(clock),.reset(resetAll),.q(divCount[4]));
    tFlipFlop d5(.t(divActive_q&divCount[0]&divCount[1]&divCount[2]&divCount[3]&divCount[4]),.clock(clock),.reset(resetAll),.q(divCount[5]));

    assign divDone=divCount[5]&~divCount[4]&~divCount[3]&~divCount[2]&~divCount[1]&divCount[0];
    assign resultRDY=divActive_q&divDone;

    wire [31:0] dividendAbs_in,divisorAbs_in;
    wire quotientSign_in;
    wire [31:0] dividendAbs_q,divisorAbs_q,dividendAbs_d,divisorAbs_d;
    wire quotientSign_q,quotientSign_d;
    wire divideByZero_q,divideByZero_d;
    wire overflow_q,overflow_d;

    assign quotientSign_in=opA[31]^opB[31];

    wire [31:0] opANeg,opBNeg;
    negate32 negA(.in(opA),.out(opANeg));
    negate32 negB(.in(opB),.out(opBNeg));

    assign dividendAbs_in=opA[31]?opANeg:opA;
    assign divisorAbs_in=opB[31]?opBNeg:opB;

    assign dividendAbs_d=
    (divCount[5]|divCount[4]|divCount[3]|divCount[2]|divCount[1]|divCount[0])?
    dividendAbs_q:dividendAbs_in;

    assign divisorAbs_d=
    (divCount[5]|divCount[4]|divCount[3]|divCount[2]|divCount[1]|divCount[0])?
    divisorAbs_q:divisorAbs_in;

    assign quotientSign_d=
    (divCount[5]|divCount[4]|divCount[3]|divCount[2]|divCount[1]|divCount[0])?
    quotientSign_q:quotientSign_in;

    assign divideByZero_d=
    (divCount[5]|divCount[4]|divCount[3]|divCount[2]|divCount[1]|divCount[0])?
    divideByZero_q:
    ~(opB[31]|opB[30]|opB[29]|opB[28]|opB[27]|opB[26]|opB[25]|opB[24]|
    opB[23]|opB[22]|opB[21]|opB[20]|opB[19]|opB[18]|opB[17]|opB[16]|
    opB[15]|opB[14]|opB[13]|opB[12]|opB[11]|opB[10]|opB[9]|opB[8]|
    opB[7]|opB[6]|opB[5]|opB[4]|opB[3]|opB[2]|opB[1]|opB[0]);

    wire opAIsMinInt,opBIsNegOne;
    assign opAIsMinInt=opA[31]&~(|opA[30:0]);
    assign opBIsNegOne=&opB;
    assign overflow_d=
    (divCount[5]|divCount[4]|divCount[3]|divCount[2]|divCount[1]|divCount[0])?
    overflow_q: (opAIsMinInt&opBIsNegOne);

    register #(.W(32)) dividendAbsReg(.clock(clock),.in(dividendAbs_d),.out(dividendAbs_q),.enable(1'b1),.reset(resetAll));
    register #(.W(32)) divisorAbsReg(.clock(clock),.in(divisorAbs_d),.out(divisorAbs_q),.enable(1'b1),.reset(resetAll));
    dffe_ref quotientSignFf(.q(quotientSign_q),.d(quotientSign_d),.clk(clock),.en(1'b1),.clr(resetAll));
    dffe_ref divideByZeroFf(.q(divideByZero_q),.d(divideByZero_d),.clk(clock),.en(1'b1),.clr(resetAll));
    dffe_ref overflowFf(.q(overflow_q),.d(overflow_d),.clk(clock),.en(1'b1),.clr(resetAll));

    assign divActive_d=start?1'b1:(cancel|divDone)?1'b0:divActive_q;
    dffe_ref divActiveFf(.q(divActive_q),.d(divActive_d),.clk(clock),.en(1'b1),.clr(1'b0));

    wire [64:0] divState_q,divState_d;
    wire [64:0] divStateInit;
    wire [64:0] divStateShifted;
    wire [32:0] remShift_u,divisor33_u;
    wire [31:0] quotShift_u;
    wire signed [32:0] remShift_s,divisor33_s,remNext_s;

    wire nextQuotBit;
    wire [31:0] quotNext_u;

    wire [64:0] divStateNext;

    register #(.W(65)) divStateReg(.clock(clock),.in(divState_d),.out(divState_q),.enable(1'b1),.reset(resetAll));

    assign divStateInit={33'b0,dividendAbs_in};
    assign divStateShifted={divState_q[63:0],1'b0};
    assign remShift_u=divStateShifted[64:32];
    assign quotShift_u=divStateShifted[31:0];
    assign divisor33_u={1'b0,divisorAbs_q};
    assign remShift_s=remShift_u;
    assign divisor33_s=divisor33_u;

    wire [32:0] remAdd_u,remSub_u;
    wire [32:0] remNext_u;

    addsub33 remAdd(.a(remShift_u),.b(divisor33_u),.is_sub(1'b0),.sum(remAdd_u));
    addsub33 remSub(.a(remShift_u),.b(divisor33_u),.is_sub(1'b1),.sum(remSub_u));

    assign remNext_u=remShift_u[32]?remAdd_u:remSub_u;
    assign remNext_s=remNext_u;

    assign nextQuotBit=~remNext_s[32];
    assign quotNext_u={quotShift_u[31:1],nextQuotBit};
    assign divStateNext={remNext_s,quotNext_u};

    assign divState_d=
    (divCount[5]|divCount[4]|divCount[3]|divCount[2]|divCount[1]|divCount[0])?
    (resultRDY?divState_q:divStateNext):
    divStateInit;

    wire [31:0] quotientMag,quotientOut;
    wire [31:0] quotientMagNeg;

    assign quotientMag=divState_q[31:0];
    negate32 negQ(.in(quotientMag),.out(quotientMagNeg));

    assign quotientOut=quotientSign_q?quotientMagNeg:quotientMag;

    assign result=(divideByZero_q|overflow_q)?32'b0:quotientOut;
    assign exception=divideByZero_q|overflow_q;
endmodule

module negate32(in,out);
    input [31:0] in;
    output [31:0] out;
    wire cout_dummy,c31_dummy;
    add_sub n0(.a(32'b0),.b(in),.is_sub(1'b1),.sum(out),.cout(cout_dummy),.c31(c31_dummy));
endmodule

module addsub33(a,b,is_sub,sum);
    input [32:0] a,b;
    input is_sub;
    output [32:0] sum;

    wire [32:0] bx;
    wire c32,c31_dummy;
    genvar i;
    generate
    for(i=0;i<33;i=i+1) begin:loop
    xor(bx[i],b[i],is_sub);
    end
    endgenerate

    cla32bit lo(.a(a[31:0]),.b(bx[31:0]),.cin(is_sub),.cout(c32),.sum(sum[31:0]),.carryIn31(c31_dummy));
    xor(sum[32],a[32],bx[32],c32);
endmodule