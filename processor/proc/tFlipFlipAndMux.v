module mux2 #(parameter W=8)(out,select,a,b);
    input select;
    input [W-1:0] a,b;
    output [W-1:0] out;
    assign out = select ? b : a;
endmodule

module mux4 #(parameter W=8)(out,select,a0,a1,a2,a3);
    input [1:0] select;
    input [W-1:0] a0,a1,a2,a3;
    output [W-1:0] out;
    wire [W-1:0] t0,t1;

    mux2 #(W) choose0or1(t0,select[0],a0,a1);
    mux2 #(W) choose2or3(t1,select[0],a2,a3);
    mux2 #(W) lastMux(out,select[1],t0,t1);
endmodule

module mux8 #(parameter W=8)(out,select,a0,a1,a2,a3,a4,a5,a6,a7);
    input [2:0] select;
    input [W-1:0] a0,a1,a2,a3,a4,a5,a6,a7;
    output [W-1:0] out;
    wire [W-1:0] m0,m1;

    mux4 #(W) choose0or1or2or3(m0,select[1:0],a0,a1,a2,a3);
    mux4 #(W) choose4or5or6or7(m1,select[1:0],a4,a5,a6,a7);
    mux2 #(W) u2(out,select[2],m0,m1);
endmodule

module tFlipFlop(t, clock, reset, q);
    input t, clock, reset;
    output q;

    wire d;
    wire tNot;
    wire qNot;
    wire andTop;
    wire andBottom;

    not invt(tNot, t);
    not invq(qNot, q);
    and and1(andTop, q, tNot);
    and and2(andBottom, qNot, t);
    or or1(d, andTop, andBottom);
    dffe_ref ff(.q(q), .d(d), .clk(clock), .en(1'b1), .clr(reset));

endmodule