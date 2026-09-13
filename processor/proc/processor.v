/**
 * READ THIS DESCRIPTION!
 *
 * This is your processor module that will contain the bulk of your code submission. You are to implement
 * a 5-stage pipelined processor in this module, accounting for hazards and implementing bypasses as
 * necessary.
 *
 * Ultimately, your processor will be tested by a master skeleton, so the
 * testbench can see which controls signal you active when. Therefore, there needs to be a way to
 * "inject" imem, dmem, and regfile interfaces from some external controller module. The skeleton
 * file, Wrapper.v, acts as a small wrapper around your processor for this purpose. Refer to Wrapper.v
 * for more details.
 *
 * As a result, this module will NOT contain the RegFile nor the memory modules. Study the inputs 
 * very carefully - the RegFile-related I/Os are merely signals to be sent to the RegFile instantiated
 * in your Wrapper module. This is the same for your memory elements. 
 *
 *
 */
module processor(
    // Control signals
    clock,                          // I: The master clock
    reset,                          // I: A reset signal

    // Imem
    address_imem,                   // O: The address of the data to get from imem
    q_imem,                         // I: The data from imem

    // Dmem
    address_dmem,                   // O: The address of the data to get or put from/to dmem
    data,                           // O: The data to write to dmem
    wren,                           // O: Write enable for dmem
    q_dmem,                         // I: The data from dmem

    // Regfile
    ctrl_writeEnable,               // O: Write enable for RegFile
    ctrl_writeReg,                  // O: Register to write to in RegFile
    ctrl_readRegA,                  // O: Register to read from port A of RegFile
    ctrl_readRegB,                  // O: Register to read from port B of RegFile
    data_writeReg,                  // O: Data to write to for RegFile
    data_readRegA,                  // I: Data from port A of RegFile
    data_readRegB                   // I: Data from port B of RegFile
	 
	);

	// Control signals
	input clock, reset;
	
	// Imem
    output [31:0] address_imem;
	input [31:0] q_imem;

	// Dmem
	output [31:0] address_dmem, data;
	output wren;
	input [31:0] q_dmem;

	// Regfile
	output ctrl_writeEnable;
	output [4:0] ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
	output [31:0] data_writeReg;
	input [31:0] data_readRegA, data_readRegB;

	/* YOUR CODE STARTS HERE */

    wire [31:0] pc_curr, pc_next, pc_plus1;
    wire pc_cout, pc_c31;
    add_sub pcAdd(.a(pc_curr), .b(32'b1), .is_sub(1'b0), .sum(pc_plus1), .cout(pc_cout), .c31(pc_c31));

    wire [31:0] fd_insn_q, fd_pcplus1_q;
    wire [31:0] fd_insn_in;
    wire [31:0] fd_pcplus1_in;
    wire fd_en;

    wire [31:0] dx_insn_q, dx_pcplus1_q, dx_val_a_q, dx_val_b_q;
    wire [31:0] dx_insn_in, dx_pcplus1_in, dx_val_a_in, dx_val_b_in;
    wire dx_en;

    wire [31:0] xm_result_q, xm_store_q, xm_r30val_q, xm_pcplus1_q;
    wire [4:0] xm_rd_q, xm_store_src_q;
    wire xm_we_q, xm_memToReg_q, xm_is_sw_q, xm_force_r30_q;
    wire [31:0] xm_result_in, xm_store_in, xm_r30val_in, xm_pcplus1_in;
    wire [4:0] xm_rd_in, xm_store_src_in;
    wire xm_we_in, xm_memToReg_in, xm_is_sw_in, xm_force_r30_in;

    wire [31:0] mw_result_q, mw_mem_q, mw_r30val_q, mw_pcplus1_q;
    wire [4:0] mw_rd_q;
    wire mw_we_q, mw_memToReg_q, mw_force_r30_q;
    wire [31:0] mw_result_in, mw_mem_in, mw_r30val_in, mw_pcplus1_in;
    wire [4:0] mw_rd_in;
    wire mw_we_in, mw_memToReg_in, mw_force_r30_in;

    wire [4:0] fd_opcode;
    wire [4:0] fd_rd, fd_rs, fd_rt;
    assign fd_opcode = fd_insn_q[31:27];
    assign fd_rd = fd_insn_q[26:22];
    assign fd_rs = fd_insn_q[21:17];
    assign fd_rt = fd_insn_q[16:12];

    wire fd_is_rtype, fd_is_addi, fd_is_lw, fd_is_sw, fd_is_bne, fd_is_blt, fd_is_j, fd_is_jal, fd_is_jr, fd_is_bex, fd_is_setx;
    assign fd_is_rtype = (fd_opcode == 5'b00000);
    assign fd_is_j = (fd_opcode == 5'b00001);
    assign fd_is_bne = (fd_opcode == 5'b00010);
    assign fd_is_jal = (fd_opcode == 5'b00011);
    assign fd_is_jr = (fd_opcode == 5'b00100);
    assign fd_is_addi = (fd_opcode == 5'b00101);
    assign fd_is_blt = (fd_opcode == 5'b00110);
    assign fd_is_sw = (fd_opcode == 5'b00111);
    assign fd_is_lw = (fd_opcode == 5'b01000);
    assign fd_is_setx = (fd_opcode == 5'b10101);
    assign fd_is_bex = (fd_opcode == 5'b10110);

    wire [4:0] readA_sel, readB_sel;

	assign readA_sel = fd_is_rtype ? fd_rs : fd_is_addi ? fd_rs : fd_is_lw ? fd_rs : 
		fd_is_sw ? fd_rs : fd_is_bne ? fd_rd : fd_is_blt ? fd_rd : fd_is_jr ? fd_rd : fd_is_bex ? 5'd30 : 5'd0;
	assign readB_sel = fd_is_rtype ? fd_rt : fd_is_sw ? fd_rd : fd_is_bne ? fd_rs : fd_is_blt ? fd_rs : 5'd0;

    assign ctrl_readRegA = readA_sel;
    assign ctrl_readRegB = readB_sel;

    assign dx_val_a_in = data_readRegA;
    assign dx_val_b_in = data_readRegB;

    wire [4:0] dx_opcode;
    wire [4:0] dx_rd, dx_rs, dx_rt;
    wire [4:0] dx_aluop_r, dx_shamt;
    wire [16:0] dx_imm17;
    wire [26:0] dx_target27;

    assign dx_opcode = dx_insn_q[31:27];
    assign dx_rd = dx_insn_q[26:22];
    assign dx_rs = dx_insn_q[21:17];
    assign dx_rt = dx_insn_q[16:12];
    assign dx_shamt = dx_insn_q[11:7];
    assign dx_aluop_r = dx_insn_q[6:2];
    assign dx_imm17 = dx_insn_q[16:0];
    assign dx_target27 = dx_insn_q[26:0];

    wire [31:0] dx_imm_sext;
    assign dx_imm_sext = {{15{dx_imm17[16]}}, dx_imm17};

    wire dx_is_rtype, dx_is_addi, dx_is_lw, dx_is_sw, dx_is_bne, dx_is_blt, dx_is_j, dx_is_jal, dx_is_jr, dx_is_bex, dx_is_setx;
    assign dx_is_rtype = (dx_opcode == 5'b00000);
    assign dx_is_j = (dx_opcode == 5'b00001);
    assign dx_is_bne = (dx_opcode == 5'b00010);
    assign dx_is_jal = (dx_opcode == 5'b00011);
    assign dx_is_jr = (dx_opcode == 5'b00100);
    assign dx_is_addi = (dx_opcode == 5'b00101);
    assign dx_is_blt = (dx_opcode == 5'b00110);
    assign dx_is_sw = (dx_opcode == 5'b00111);
    assign dx_is_lw = (dx_opcode == 5'b01000);
    assign dx_is_setx = (dx_opcode == 5'b10101);
    assign dx_is_bex = (dx_opcode == 5'b10110);

    wire dx_is_mul, dx_is_div;
    assign dx_is_mul = dx_is_rtype & (dx_aluop_r == 5'b00110);
    assign dx_is_div = dx_is_rtype & (dx_aluop_r == 5'b00111);
    wire dx_is_md;
    assign dx_is_md = dx_is_mul | dx_is_div;

    wire [31:0] target32;
    assign target32 = {5'b0, dx_target27};

    wire [31:0] branch_base, branch_target;
    assign branch_base = dx_pcplus1_q;
    wire br_cout, br_c31;
    add_sub brAdd(.a(branch_base), .b(dx_imm_sext), .is_sub(1'b0), .sum(branch_target), .cout(br_cout), .c31(br_c31));

    wire [4:0] dx_srcA, dx_srcB;

	assign dx_srcA = dx_is_rtype ? dx_rs : dx_is_addi ? dx_rs : dx_is_lw ? dx_rs : 
		dx_is_sw ? dx_rs : dx_is_bne ? dx_rd : dx_is_blt ? dx_rd : dx_is_jr ? dx_rd : dx_is_bex ? 5'd30 : 5'd0;
	assign dx_srcB = dx_is_rtype ? dx_rt : dx_is_sw ? dx_rd : dx_is_bne ? dx_rs : dx_is_blt ? dx_rs : 5'd0;

    wire [4:0] xm_bypass_rd;
    wire [31:0] xm_bypass_data;
    wire xm_can_bypass;

    assign xm_bypass_rd = xm_force_r30_q ? 5'd30 : xm_rd_q;
    assign xm_bypass_data = xm_force_r30_q ? xm_r30val_q : xm_result_q;
    assign xm_can_bypass = xm_we_q & ~xm_memToReg_q & (xm_bypass_rd != 5'd0);

    wire [4:0] mw_bypass_rd;
    wire [31:0] mw_bypass_data;
    wire mw_can_bypass;

    assign mw_bypass_rd = mw_force_r30_q ? 5'd30 : mw_rd_q;

    assign mw_bypass_data = mw_force_r30_q ? mw_r30val_q : (mw_memToReg_q ? mw_mem_q : mw_result_q);

    assign mw_can_bypass = mw_we_q & (mw_bypass_rd != 5'd0);

        wire [4:0] wb_bypass_rd;
    wire [31:0] wb_bypass_data;
    wire wb_can_bypass;

    assign wb_bypass_rd = ctrl_writeReg;
    assign wb_bypass_data = data_writeReg;
    assign wb_can_bypass = ctrl_writeEnable & (wb_bypass_rd != 5'd0);

    wire [31:0] dx_opA, dx_opB_raw;

    assign dx_opA =
        (xm_can_bypass && (dx_srcA == xm_bypass_rd)) ? xm_bypass_data :
        (mw_can_bypass && (dx_srcA == mw_bypass_rd)) ? mw_bypass_data :
        (wb_can_bypass && (dx_srcA == wb_bypass_rd)) ? wb_bypass_data :
        dx_val_a_q;

    assign dx_opB_raw =
        (xm_can_bypass && (dx_srcB == xm_bypass_rd)) ? xm_bypass_data :
        (mw_can_bypass && (dx_srcB == mw_bypass_rd)) ? mw_bypass_data :
        (wb_can_bypass && (dx_srcB == wb_bypass_rd)) ? wb_bypass_data :
        dx_val_b_q;

    wire [4:0] aluOpcode_in;
    assign aluOpcode_in =
        (dx_is_addi | dx_is_lw | dx_is_sw) ? 5'b00000 :
        (dx_is_bne | dx_is_blt) ? 5'b00001 :
        dx_is_rtype ? dx_aluop_r :
        5'b00000;

    wire [31:0] aluB_in;
    mux2 #(.W(32)) aluBMux(.out(aluB_in), .select(dx_is_addi | dx_is_lw | dx_is_sw), .a(dx_opB_raw), .b(dx_imm_sext));

    wire [31:0] alu_out;
    wire alu_neq, alu_lt, alu_ovf;
    alu theALU(.data_operandA(dx_opA), .data_operandB(aluB_in), .ctrl_ALUopcode(aluOpcode_in), .ctrl_shiftamt(dx_shamt),
        .data_result(alu_out), .isNotEqual(alu_neq), .isLessThan(alu_lt), .overflow(alu_ovf));

    wire [32:0] bex_or;
    assign bex_or[0] = 1'b0;
    genvar bi;
    generate
        for (bi = 0; bi < 32; bi = bi + 1) begin:BEXNZ
            or(bex_or[bi+1], bex_or[bi], dx_opA[bi]);
        end
    endgenerate
    wire bex_nz;
    assign bex_nz = bex_or[32];

    wire take_bne, take_blt, take_j, take_jal, take_jr, take_bex;
    assign take_bne = dx_is_bne & alu_neq;
    assign take_blt = dx_is_blt & alu_lt;
    assign take_j = dx_is_j;
    assign take_jal = dx_is_jal;
    assign take_jr = dx_is_jr;
    assign take_bex = dx_is_bex & bex_nz;

    wire take_ctrl;
    assign take_ctrl = take_bne | take_blt | take_j | take_jal | take_jr | take_bex;

    wire [31:0] ctrl_target;
    assign ctrl_target = (take_jr ? dx_opA : ((take_bne | take_blt) ? branch_target :
		((take_bex | take_j | take_jal) ? target32 : pc_plus1)));

    assign pc_next = take_ctrl ? ctrl_target : pc_plus1;

    wire [31:0] md_result;
    wire md_exc, md_rdy;

    wire md_busy_q, md_busy_d;
    wire md_start_mul, md_start_div;
    wire md_finish;

    wire [31:0] pw_result_q;
    wire [4:0] pw_rd_q;
    wire pw_is_mul_q, pw_is_div_q;
    wire pw_exc_q;
    wire pw_valid_q;

    assign md_start_mul = dx_is_mul & ~md_busy_q;
    assign md_start_div = dx_is_div & ~md_busy_q;

    wire [31:0] md_operandA_q, md_operandB_q;
    wire [31:0] md_operandA, md_operandB;

    multdiv MD(.data_operandA(md_operandA), .data_operandB(md_operandB), .ctrl_MULT(md_start_mul),
        .ctrl_DIV(md_start_div), .clock(clock), .data_result(md_result), .data_exception(md_exc), .data_resultRDY(md_rdy));

    wire md_start;
    assign md_start = md_start_mul | md_start_div;

    register #(.W(32)) mdOpA( .clock(clock), .out(md_operandA_q), .in(dx_opA), .enable(md_start), .reset(reset));
    register #(.W(32)) mdOpB(.clock(clock), .out(md_operandB_q), .in(dx_opB_raw), .enable(md_start), .reset(reset));

    assign md_operandA = md_busy_q ? md_operandA_q : dx_opA;
    assign md_operandB = md_busy_q ? md_operandB_q : dx_opB_raw;
    assign md_finish = md_busy_q & md_rdy;
    assign md_busy_d = reset ? 1'b0 : ((md_start_mul | md_start_div) ? 1'b1 : (md_finish ? 1'b0 : md_busy_q));
    dffe_ref mdBusy(.q(md_busy_q), .d(md_busy_d), .clk(clock), .en(1'b1), .clr(1'b0));
    register #(.W(5)) pwRd(.clock(~clock), .out(pw_rd_q), .in(dx_rd), .enable(dx_is_md), .reset(reset));
    register #(.W(1)) pwMul(.clock(~clock), .out(pw_is_mul_q), .in(dx_is_mul), .enable(dx_is_md), .reset(reset));
    register #(.W(1)) pwDiv(.clock(~clock), .out(pw_is_div_q), .in(dx_is_div), .enable(dx_is_md), .reset(reset));
    register #(.W(32)) pwRes(.clock(~clock), .out(pw_result_q), .in(md_result), .enable(md_finish), .reset(reset));

    register #(.W(1)) pwExc(.clock(~clock), .out(pw_exc_q), .in(md_exc), .enable(md_finish), .reset(reset));

    wire pw_valid_d;
    assign pw_valid_d = reset ? 1'b0 : (pw_valid_q ? 1'b0 : (md_finish ? 1'b1 : 1'b0));

    dffe_ref pwValid(.q(pw_valid_q), .d(pw_valid_d), .clk(~clock), .en(1'b1), .clr(1'b0));

    wire stall_md;
    assign stall_md = dx_is_md | md_busy_q;

    wire release_md;
    assign release_md = md_finish;

    wire stall_lw;
    assign stall_lw = dx_is_lw && (dx_rd != 5'd0) && (((readA_sel == dx_rd) && (readA_sel != 5'd0)) ||
        ((readB_sel == dx_rd) && (readB_sel != 5'd0) && ~fd_is_sw));

    wire [4:0] md_done_rd;
    wire stall_md_dep;

    assign md_done_rd = md_exc ? 5'd30 : pw_rd_q;

    assign stall_md_dep = release_md && (md_done_rd != 5'd0) && (((readA_sel == md_done_rd) && (readA_sel != 5'd0)) ||
        ((readB_sel == md_done_rd) && (readB_sel != 5'd0)));

    wire flush;
    assign flush = take_ctrl;

    assign fd_en = (~(stall_md | stall_lw | stall_md_dep)) | (release_md & ~stall_md_dep);
    assign dx_en = (~stall_md) | release_md;

    register #(.W(32)) pcReg(.clock(~clock), .out(pc_curr), .in(pc_next),
        .enable((~(stall_md | stall_lw | stall_md_dep)) | (release_md & ~stall_md_dep)), .reset(reset));
    assign address_imem = pc_curr;

    assign fd_insn_in = flush ? 32'b0 : q_imem;
    assign dx_insn_in = flush ? 32'b0 : (stall_lw ? 32'b0 : (stall_md_dep ? 32'b0 : fd_insn_q));
    assign dx_pcplus1_in = fd_pcplus1_q;
    assign fd_pcplus1_in = pc_plus1;

    register #(.W(32)) fdInsn(.clock(~clock), .out(fd_insn_q), .in(fd_insn_in), .enable(fd_en), .reset(reset));
    register #(.W(32)) fdPc1(.clock(~clock), .out(fd_pcplus1_q), .in(fd_pcplus1_in), .enable(fd_en), .reset(reset));
	register #(.W(32)) dxInsn(.clock(~clock), .out(dx_insn_q), .in(dx_insn_in), .enable(dx_en), .reset(reset));
	register #(.W(32)) dxPc1(.clock(~clock), .out(dx_pcplus1_q), .in(dx_pcplus1_in), .enable(dx_en), .reset(reset));
	register #(.W(32)) dxA(.clock(~clock), .out(dx_val_a_q), .in(dx_val_a_in), .enable(dx_en), .reset(reset));
	register #(.W(32)) dxB(.clock(~clock), .out(dx_val_b_q), .in(dx_val_b_in), .enable(dx_en), .reset(reset));

    wire [31:0] x_exec_result;
    assign x_exec_result = (dx_is_jal ? dx_pcplus1_q : (dx_is_setx ? target32 : alu_out));

    wire x_memToReg, x_is_sw;
    assign x_memToReg = dx_is_lw;
    assign x_is_sw = dx_is_sw;

    wire [31:0] x_store_data;
    assign x_store_data = dx_opB_raw;

    wire [4:0] x_dest_rd;
    assign x_dest_rd = dx_is_jal ? 5'd31 : (dx_is_setx ? 5'd30 : dx_rd);

    wire x_is_rtype_nmd;
    assign x_is_rtype_nmd = dx_is_rtype & ~dx_is_md;

    wire x_writes_rd;
    assign x_writes_rd = (x_is_rtype_nmd | dx_is_addi | dx_is_lw | dx_is_jal | dx_is_setx);

    wire dest_is_r0_x;
    assign dest_is_r0_x = (x_dest_rd == 5'd0);

    wire dx_is_add, dx_is_sub;
    assign dx_is_add = dx_is_rtype & (dx_aluop_r == 5'b00000);
    assign dx_is_sub = dx_is_rtype & (dx_aluop_r == 5'b00001);

    wire [31:0] ovf_code_x;
    assign ovf_code_x = dx_is_add ? 32'd1 : dx_is_addi ? 32'd2 : dx_is_sub ? 32'd3 : 32'd0;

    wire ovf_alu_trap;
    assign ovf_alu_trap = alu_ovf & (dx_is_add | dx_is_addi | dx_is_sub);

    wire force_r30_x;
    assign force_r30_x = dx_is_setx | ovf_alu_trap;

    wire [31:0] r30_value_x;
    assign r30_value_x = dx_is_setx ? target32 : ovf_code_x;

    wire we_non_trap_x;
    assign we_non_trap_x = x_writes_rd & ~dest_is_r0_x & ~force_r30_x;

    wire we_final_x;
    assign we_final_x = we_non_trap_x | force_r30_x;

    assign xm_rd_in = x_dest_rd;
    assign xm_result_in = x_exec_result;
    assign xm_store_in = x_store_data;
    assign xm_store_src_in = dx_srcB;
    assign xm_we_in = we_final_x;
    assign xm_memToReg_in = x_memToReg & ~force_r30_x;
    assign xm_is_sw_in = x_is_sw & ~force_r30_x;
    assign xm_force_r30_in = force_r30_x;
    assign xm_r30val_in = r30_value_x;
    assign xm_pcplus1_in = dx_pcplus1_q;

    wire xm_en;
    assign xm_en = 1'b1;

	register #(.W(5)) xmRd(.clock(~clock), .out(xm_rd_q), .in(xm_rd_in), .enable(xm_en), .reset(reset));
	register #(.W(32)) xmRes(.clock(~clock), .out(xm_result_q), .in(xm_result_in), .enable(xm_en), .reset(reset));
	register #(.W(32)) xmStore(.clock(~clock), .out(xm_store_q), .in(xm_store_in), .enable(xm_en), .reset(reset));
	register #(.W(5)) xmStoreSrc(.clock(~clock), .out(xm_store_src_q), .in(xm_store_src_in), .enable(xm_en), .reset(reset));
	register #(.W(1)) xmWe(.clock(~clock), .out(xm_we_q), .in(xm_we_in), .enable(xm_en), .reset(reset));
	register #(.W(1)) xmM2R(.clock(~clock), .out(xm_memToReg_q), .in(xm_memToReg_in), .enable(xm_en), .reset(reset));
	register #(.W(1)) xmSw(.clock(~clock), .out(xm_is_sw_q), .in(xm_is_sw_in), .enable(xm_en), .reset(reset));
	register #(.W(1)) xmFR30(.clock(~clock), .out(xm_force_r30_q), .in(xm_force_r30_in), .enable(xm_en), .reset(reset));
	register #(.W(32)) xmR30v(.clock(~clock), .out(xm_r30val_q), .in(xm_r30val_in), .enable(xm_en), .reset(reset));
	register #(.W(32)) xmPc1(.clock(~clock), .out(xm_pcplus1_q), .in(xm_pcplus1_in), .enable(xm_en), .reset(reset));

    wire [31:0] mem_store_data;
    assign mem_store_data =
        (xm_is_sw_q && mw_can_bypass && (xm_store_src_q == mw_bypass_rd)) ? mw_bypass_data :
        (xm_is_sw_q && wb_can_bypass && (xm_store_src_q == wb_bypass_rd)) ? wb_bypass_data : xm_store_q;

    assign address_dmem = xm_result_q;
    assign data = mem_store_data;
    assign wren = xm_is_sw_q;

    assign mw_rd_in = xm_rd_q;
    assign mw_result_in = xm_result_q;
    assign mw_mem_in = q_dmem;
    assign mw_we_in = xm_we_q;
    assign mw_memToReg_in = xm_memToReg_q;
    assign mw_force_r30_in = xm_force_r30_q;
    assign mw_r30val_in = xm_r30val_q;
    assign mw_pcplus1_in = xm_pcplus1_q;

    wire mw_en;
    assign mw_en = 1'b1;
	register #(.W(5)) mwRd(.clock(~clock), .out(mw_rd_q), .in(mw_rd_in), .enable(mw_en), .reset(reset));
	register #(.W(32)) mwRes(.clock(~clock), .out(mw_result_q), .in(mw_result_in), .enable(mw_en), .reset(reset));
	register #(.W(32)) mwMem(.clock(~clock), .out(mw_mem_q), .in(mw_mem_in), .enable(mw_en), .reset(reset));
	register #(.W(1)) mwWe(.clock(~clock), .out(mw_we_q), .in(mw_we_in), .enable(mw_en), .reset(reset));
	register #(.W(1)) mwM2R(.clock(~clock), .out(mw_memToReg_q), .in(mw_memToReg_in), .enable(mw_en), .reset(reset));
	register #(.W(1)) mwFR30(.clock(~clock), .out(mw_force_r30_q), .in(mw_force_r30_in), .enable(mw_en), .reset(reset));
	register #(.W(32)) mwR30v(.clock(~clock), .out(mw_r30val_q), .in(mw_r30val_in), .enable(mw_en), .reset(reset));
	register #(.W(32)) mwPc1(.clock(~clock), .out(mw_pcplus1_q), .in(mw_pcplus1_in), .enable(mw_en), .reset(reset));
    wire [31:0] wb_from_mem;
    assign wb_from_mem = mw_mem_q;

    wire [31:0] wb_nontrap_data;
    assign wb_nontrap_data = mw_memToReg_q ? wb_from_mem : mw_result_q;

    wire [31:0] wb_pipe_data;
    assign wb_pipe_data = mw_force_r30_q ? mw_r30val_q : wb_nontrap_data;

    wire [4:0] wb_pipe_reg;
    assign wb_pipe_reg = mw_force_r30_q ? 5'd30 : mw_rd_q;

    wire wb_pipe_we;
    assign wb_pipe_we = mw_we_q;

    wire pw_force_r30;
    assign pw_force_r30 = pw_exc_q;

    wire [31:0] pw_r30val;
    assign pw_r30val = pw_is_mul_q ? 32'd4 : (pw_is_div_q ? 32'd5 : 32'd0);

    wire [4:0] wb_pw_reg;
    assign wb_pw_reg = pw_force_r30 ? 5'd30 : pw_rd_q;

    wire [31:0] wb_pw_data;
    assign wb_pw_data = pw_force_r30 ? pw_r30val : pw_result_q;

    wire wb_pw_we;
    assign wb_pw_we = pw_valid_q;

    assign ctrl_writeReg = wb_pw_we ? wb_pw_reg : wb_pipe_reg;
    assign data_writeReg = wb_pw_we ? wb_pw_data : wb_pipe_data;
    assign ctrl_writeEnable = wb_pw_we ? 1'b1 : wb_pipe_we;

	/* END CODE */

endmodule