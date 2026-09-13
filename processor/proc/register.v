module register #(parameter W=32)(clock,out,in,enable,reset);
    input clock,enable,reset;
    input [W-1:0] in;
    output [W-1:0] out;
    genvar i;
    generate
    for(i=0;i<W;i=i+1) begin:genDFFs
    dffe_ref ff(out[i],in[i],clock,enable,reset);
    end
    endgenerate
endmodule