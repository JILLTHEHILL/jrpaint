module alu(data_operandA, data_operandB, ctrl_ALUopcode, ctrl_shiftamt, data_result, isNotEqual, isLessThan, overflow);
        
    input [31:0] data_operandA, data_operandB;
    input [4:0] ctrl_ALUopcode, ctrl_shiftamt;

    output [31:0] data_result;
    output isNotEqual, isLessThan, overflow;

    wire [31:0] sum, and_out, or_out, sll_out, sra_out;
    wire is_add, is_sub, is_and, is_or, is_sll, is_sra;
    wire c32, c31;

    decoder DECODER(.ctrl_ALUopcode(ctrl_ALUopcode), .is_add(is_add), .is_sub(is_sub), .is_and(is_and), .is_or(is_or), .is_sll(is_sll), .is_sra(is_sra));
    
    add_sub ADD_OR_SUB(.a(data_operandA), .b(data_operandB), .is_sub(is_sub), .sum(sum), .cout(c32), .c31(c31));
    and_or AND_OR_RESULT(.a(data_operandA), .b(data_operandB), .and_out(and_out), .or_out(or_out));
    barrelsll SLL(.in(data_operandA), .shamt(ctrl_shiftamt), .out(sll_out));
    barrelsra SRA(.in(data_operandA), .shamt(ctrl_shiftamt), .out(sra_out));

    signals SIGNALS(.sum(sum), .c31(c31), .c32(c32), .is_add(is_add), .is_sub(is_sub), .isNotEqual(isNotEqual), .isLessThan(isLessThan), .overflow(overflow));
    final_result_mux FINAL_RES_MUX(.sum(sum), .and_out(and_out), .or_out(or_out), .sll_out(sll_out), .sra_out(sra_out), .is_add(is_add), .is_sub(is_sub), .is_and(is_and), .is_or(is_or), .is_sll(is_sll), .is_sra(is_sra), .res(data_result));
endmodule


module decoder(ctrl_ALUopcode, is_add, is_sub, is_and, is_or, is_sll, is_sra);
    input [4:0] ctrl_ALUopcode;
    output is_add, is_sub, is_and, is_or, is_sll, is_sra;

    wire op4, op3, op2, op1, op0;
    wire nop4, nop3, nop2, nop1, nop0;

    assign op4 = ctrl_ALUopcode[4];
    assign op3 = ctrl_ALUopcode[3];
    assign op2 = ctrl_ALUopcode[2];
    assign op1 = ctrl_ALUopcode[1];
    assign op0 = ctrl_ALUopcode[0];

    not (nop4, op4);
    not (nop3, op3);
    not (nop2, op2);
    not (nop1, op1);
    not (nop0, op0);

    and (is_add, nop4, nop3, nop2, nop1, nop0);
    and (is_sub, nop4, nop3, nop2, nop1, op0);
    and (is_and, nop4, nop3, nop2, op1, nop0);
    and (is_or, nop4, nop3, nop2, op1, op0);
    and (is_sll, nop4, nop3, op2, nop1, nop0);
    and (is_sra, nop4, nop3, op2, nop1, op0);
endmodule

module final_result_mux(sum, and_out, or_out, sll_out, sra_out, is_add, is_sub, is_and, is_or, is_sll, is_sra, res);
    input [31:0] sum, and_out, or_out, sll_out, sra_out;
    input is_add, is_sub, is_and, is_or, is_sll, is_sra;
    output [31:0] res;

    assign res =
        is_add ? sum :
        is_sub ? sum :
        is_and ? and_out :
        is_or ? or_out :
        is_sll ? sll_out :
        is_sra ? sra_out :
        32'b0;
endmodule

module and_or(a, b, and_out, or_out);
    input [31:0] a, b;
    output [31:0] and_out, or_out;

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : AND_OR
            and (and_out[i], a[i], b[i]);
            or (or_out[i], a[i], b[i]);
        end
    endgenerate
endmodule

module add_sub(a, b, is_sub, sum, cout, c31);
    input [31:0] a, b;
    input is_sub;
    output [31:0] sum;
    output cout, c31;

    wire [31:0] b_after_xor;
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : B_XOR
            xor (b_after_xor[i], b[i], is_sub);
        end
    endgenerate
    cla32bit cla(.a(a), .b(b_after_xor), .cin(is_sub), .cout(cout), .sum(sum), .carryIn31(c31));
endmodule

module signals(sum, c31, c32, is_add, is_sub, isNotEqual, isLessThan, overflow);
    input [31:0] sum;
    input c31, c32, is_add, is_sub;
    output isNotEqual, isLessThan, overflow;

    xor (overflow, c31, c32);

    xor (isLessThan, sum[31], overflow);

    wire [32:0] checkneq;
    assign checkneq[0] = 1'b0;
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : NEQ
            or (checkneq[i+1], checkneq[i], sum[i]);
        end
    endgenerate
    assign isNotEqual = checkneq[32];
endmodule

module cla8bit(a, b, cin, cout, sum, P, G, prev);
    input [7:0] a;
    input [7:0] b;
    input cin;
    output cout;
    output [7:0] sum;
    output P;
    output G;
    output prev;

    wire [7:0] p, g;
    wire c0, c1, c2, c3, c4, c5, c6, c7, c8;
    assign c0 = cin;

    or (p[0], a[0], b[0]);
    and (g[0], a[0], b[0]);
    or (p[1], a[1], b[1]);
    and (g[1], a[1], b[1]);
    or (p[2], a[2], b[2]);
    and (g[2], a[2], b[2]);
    or (p[3], a[3], b[3]);
    and (g[3], a[3], b[3]);
    or (p[4], a[4], b[4]);
    and (g[4], a[4], b[4]);
    or (p[5], a[5], b[5]);
    and (g[5], a[5], b[5]);
    or (p[6], a[6], b[6]);
    and (g[6], a[6], b[6]);
    or (p[7], a[7], b[7]);
    and (g[7], a[7], b[7]);

    wire c1_temp0;
    and (c1_temp0, p[0], c0);
    or (c1, g[0], c1_temp0);

    wire c2_temp0, c2_temp1;
    and (c2_temp0, p[1], g[0]);
    and (c2_temp1, p[1], p[0], c0);
    or (c2, g[1], c2_temp0, c2_temp1);

    wire c3_temp0, c3_temp1, c3_temp2;
    and (c3_temp0, p[2], g[1]);
    and (c3_temp1, p[2], p[1], g[0]);
    and (c3_temp2, p[2], p[1], p[0], c0);
    or (c3, g[2], c3_temp0, c3_temp1, c3_temp2);

    wire c4_temp0, c4_temp1, c4_temp2, c4_temp3;
    and (c4_temp0, p[3], g[2]);
    and (c4_temp1, p[3], p[2], g[1]);
    and (c4_temp2, p[3], p[2], p[1], g[0]);
    and (c4_temp3, p[3], p[2], p[1], p[0], c0);
    or (c4, g[3], c4_temp0, c4_temp1, c4_temp2, c4_temp3);

    wire c5_temp0, c5_temp1, c5_temp2, c5_temp3, c5_temp4;
    and (c5_temp0, p[4], g[3]);
    and (c5_temp1, p[4], p[3], g[2]);
    and (c5_temp2, p[4], p[3], p[2], g[1]);
    and (c5_temp3, p[4], p[3], p[2], p[1], g[0]);
    and (c5_temp4, p[4], p[3], p[2], p[1], p[0], c0);
    or (c5, g[4], c5_temp0, c5_temp1, c5_temp2, c5_temp3, c5_temp4);

    wire c6_temp0, c6_temp1, c6_temp2, c6_temp3, c6_temp4, c6_temp5;
    and (c6_temp0, p[5], g[4]);
    and (c6_temp1, p[5], p[4], g[3]);
    and (c6_temp2, p[5], p[4], p[3], g[2]);
    and (c6_temp3, p[5], p[4], p[3], p[2], g[1]);
    and (c6_temp4, p[5], p[4], p[3], p[2], p[1], g[0]);
    and (c6_temp5, p[5], p[4], p[3], p[2], p[1], p[0], c0);
    or (c6, g[5], c6_temp0, c6_temp1, c6_temp2, c6_temp3, c6_temp4, c6_temp5);

    wire c7_temp0, c7_temp1, c7_temp2, c7_temp3, c7_temp4, c7_temp5, c7_temp6;
    and (c7_temp0, p[6], g[5]);
    and (c7_temp1, p[6], p[5], g[4]);
    and (c7_temp2, p[6], p[5], p[4], g[3]);
    and (c7_temp3, p[6], p[5], p[4], p[3], g[2]);
    and (c7_temp4, p[6], p[5], p[4], p[3], p[2], g[1]);
    and (c7_temp5, p[6], p[5], p[4], p[3], p[2], p[1], g[0]);
    and (c7_temp6, p[6], p[5], p[4], p[3], p[2], p[1], p[0], c0);
    or (c7, g[6], c7_temp0, c7_temp1, c7_temp2, c7_temp3, c7_temp4, c7_temp5, c7_temp6);

    wire c8_temp0, c8_temp1, c8_temp2, c8_temp3, c8_temp4, c8_temp5, c8_temp6, c8_temp7;
    and (c8_temp0, p[7], g[6]);
    and (c8_temp1, p[7], p[6], g[5]);
    and (c8_temp2, p[7], p[6], p[5], g[4]);
    and (c8_temp3, p[7], p[6], p[5], p[4], g[3]);
    and (c8_temp4, p[7], p[6], p[5], p[4], p[3], g[2]);
    and (c8_temp5, p[7], p[6], p[5], p[4], p[3], p[2], g[1]);
    and (c8_temp6, p[7], p[6], p[5], p[4], p[3], p[2], p[1], g[0]);
    and (c8_temp7, p[7], p[6], p[5], p[4], p[3], p[2], p[1], p[0], c0);
    or (c8, g[7], c8_temp0, c8_temp1, c8_temp2, c8_temp3, c8_temp4, c8_temp5, c8_temp6, c8_temp7);

    assign cout = c8;
    assign prev   = c7;

    xor (sum[0], a[0], b[0], c0);
    xor (sum[1], a[1], b[1], c1);
    xor (sum[2], a[2], b[2], c2);
    xor (sum[3], a[3], b[3], c3);
    xor (sum[4], a[4], b[4], c4);
    xor (sum[5], a[5], b[5], c5);
    xor (sum[6], a[6], b[6], c6);
    xor (sum[7], a[7], b[7], c7);

    and (P, p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7]);

    wire t6, t5, t4, t3, t2, t1, t0;
    and (t6, p[7], g[6]);
    and (t5, p[7], p[6], g[5]);
    and (t4, p[7], p[6], p[5], g[4]);
    and (t3, p[7], p[6], p[5], p[4], g[3]);
    and (t2, p[7], p[6], p[5], p[4], p[3], g[2]);
    and (t1, p[7], p[6], p[5], p[4], p[3], p[2], g[1]);
    and (t0, p[7], p[6], p[5], p[4], p[3], p[2], p[1], g[0]);
    or (G, g[7], t6, t5, t4, t3, t2, t1, t0);
endmodule

module cla32bit(a, b, cin, cout, sum, carryIn31);
    input [31:0] a, b;
    input cin;
    output cout;
    output [31:0] sum;
    output carryIn31;

    wire c0, c8, c16, c24, c32;
    assign c0 = cin;
    wire P0, G0, P1, G1, P2, G2, P3, G3;

    wire temp0;
    and (temp0, P0, c0);
    or (c8, G0, temp0);

    wire temp1, temp2;
    and (temp1, P1, G0);
    and (temp2, P1, P0, c0);
    or (c16, G1, temp1, temp2);

    wire temp3, temp4, temp5;
    and (temp3, P2, G1);
    and (temp4, P2, P1, G0);
    and (temp5, P2, P1, P0, c0);
    or (c24, G2, temp3, temp4, temp5);

    wire temp6, temp7, temp8, temp9;
    and (temp6, P3, G2);
    and (temp7, P3, P2, G1);
    and (temp8, P3, P2, P1, G0);
    and (temp9, P3, P2, P1, P0, c0);
    or (c32, G3, temp6, temp7, temp8, temp9);

    cla8bit one (.a(a[7:0]), .b(b[7:0]), .cin(c0), .sum(sum[7:0]), .cout(), .P(P0), .G(G0), .prev());
    cla8bit two (.a(a[15:8]), .b(b[15:8]), .cin(c8), .sum(sum[15:8]), .cout(), .P(P1), .G(G1), .prev());
    cla8bit three (.a(a[23:16]), .b(b[23:16]), .cin(c16), .sum(sum[23:16]), .cout(), .P(P2), .G(G2), .prev());
    cla8bit four (.a(a[31:24]), .b(b[31:24]), .cin(c24), .sum(sum[31:24]), .cout(), .P(P3), .G(G3), .prev(carryIn31));
    assign cout = c32;
endmodule

module barrelsll(in, shamt, out);
    input [31:0] in;
    input [4:0] shamt;
    output [31:0] out;

    wire [31:0] step1, step2, step3, step4, step5;

    assign step1 = shamt[0] ? {in[30:0], 1'b0} : in;
    assign step2 = shamt[1] ? {step1[29:0], 2'b00} : step1;
    assign step3 = shamt[2] ? {step2[27:0], 4'b0000} : step2;
    assign step4 = shamt[3] ? {step3[23:0], 8'b00000000} : step3;
    assign step5 = shamt[4] ? {step4[15:0], 16'b0000000000000000} : step4;
    assign out = step5;
endmodule

module barrelsra(in, shamt, out);
    input [31:0] in;
    input [4:0]  shamt;
    output [31:0] out;

    wire [31:0] step1, step2, step3, step4, step5;

    assign step1 = shamt[0] ? {1'b0, in[31:1]} : in;
    assign step2 = shamt[1] ? {2'b00, step1[31:2]} : step1;
    assign step3 = shamt[2] ? {4'b0000, step2[31:4]} : step2;
    assign step4 = shamt[3] ? {8'b00000000, step3[31:8]} : step3;
    assign step5 = shamt[4] ? {16'b0000000000000000, step4[31:16]} : step4;

    wire [31:0] step1temp, step2temp, step3temp, step4temp, step5temp;

    assign step1temp = shamt[0] ? {1'b1, in[31:1]} : in;
    assign step2temp = shamt[1] ? {2'b11, step1temp[31:2]} : step1temp;
    assign step3temp = shamt[2] ? {4'b1111, step2temp[31:4]} : step2temp;
    assign step4temp = shamt[3] ? {8'b11111111, step3temp[31:8]} : step3temp;
    assign step5temp = shamt[4] ? {16'b1111111111111111, step4temp[31:16]} : step4temp;
    
    assign out = in[31] ? step5temp : step5;
endmodule