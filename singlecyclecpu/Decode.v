`include "Defines.v"
module Decode (
	input											clk,
	input											reset,
	input		[6:0]							opcode,
	input		[2:0]							func3,
	input		[6:0]							func7,
	input		[4:0]							regWriteNum,
	input		[4:0]							regNum0,
	input		[4:0]							regNum1,
	input		[`DataWidth-1:0]	imm, // DataWidth = 32
	output	[`AddrWidth-1:0]	pcReadData // AddrWidth = 32
);

wire										pcWriteEnable;
reg		[`AddrWidth-1:0]	pcWriteData;
reg		[2:0]							pcOp;
ProgramCounter PC(clk, reset, pcReadData, pcWriteEnable, pcWriteData, pcOp);

reg		[3:0]		aluOp;
reg		[`DataWidth-1:0]	aluX;
reg		[`DataWidth-1:0]	aluY;
wire	[`DataWidth-1:0]	aluO;
ALU	alu(aluOp, aluX, aluY, aluO);

wire	[`DataWidth-1:0]	regReadData0;
wire	[`DataWidth-1:0]	regReadData1;
wire										regsWriteEnable;
reg		[`DataWidth-1:0]	regWriteData;
RegsFile RF(clk, reset,regNum0, regNum1, regReadData0, regReadData1, regsWriteEnable, regWriteNum, regWriteData);

reg		[`AddrWidth-1:0]	memAddr;
wire										memReadEnable;
wire	[`DataWidth-1:0]	memReadData;
wire										memWriteEnable;
reg		[`DataWidth-1:0]	memWriteData;
DataMem mem(clk, memAddr, memReadEnable, memReadData, memWriteEnable, memWriteData, pcReadData);

reg		[2:0]		state;
Controller control(state, regsWriteEnable, memReadEnable, memWriteEnable, pcWriteEnable);

always @(*)
begin
	if (reset) begin
		aluOp						=	`ADD;
		aluX						=	0;
		aluY						=	0;
		pcWriteData			=	0;
		pcOp						=	`PCClear;
		regWriteData		=	0;
		memAddr					=	0;
		memWriteData		=	0;
		state						=	`IDLE;
	end
	else if (clk)
	begin
	case (opcode)
		7'b0110011: // FMT R
		begin
			case (func3)
				0: aluOp		=	func7[5] ? `SUB : `ADD;	// add sub
				1: aluOp		=	`ShiftLeftUnsigned;	// sll
				2: aluOp		=	`LesserThanSigned;	// slt
				3: aluOp		=	`LesserThanUnsigned; // sltu
				4: aluOp		=	`XOR; // xor
				5: aluOp		=	func7[5] ?	`ShiftRightSigned : `ShiftRightUnsigned; // srl sra
				6: aluOp		=	`OR; // or
				7: aluOp		=	`AND; // and
			endcase
			aluX					=	regReadData0;
			aluY					=	regReadData1;

			pcOp					=	`PCAdd4;
			regWriteData	=	aluO;
			state					=	`RegsWrite;
		end
		7'b0010011: // FMT I
		begin
			case (func3)
				0: aluOp		=	`ADD;	// addi
				1: aluOp		=	`ShiftLeftUnsigned;	// slli
				2: aluOp		=	`LesserThanSigned;	// slti
				3: aluOp		=	`LesserThanUnsigned; // sltiu
				4: aluOp		=	`XOR; // xori
				5: aluOp		=	imm[10] ?	`ShiftRightSigned : `ShiftRightUnsigned; // srli srai
				6: aluOp		=	`OR; // ori
				7: aluOp		=	`AND; // andi
			endcase
			aluX					=	regReadData0;
			aluY					=	imm;

			pcOp					=	`PCAdd4;
			regWriteData	=	aluO;
			state					=	`RegsWrite;
		end
		7'b0000011: // FMT I lb lh lw lbu lhu
		begin
			aluX					=	regReadData0;
			aluY					=	imm;
			aluOp					=	`ADD;

			pcOp					=	`PCAdd4;
			memAddr				=	aluO;
			state					=	`MemtoRegs;
			case (func3)
				0: regWriteData	=	{ { 24{ memReadData[7] } }, memReadData[7:0] }; // lb lbu
				1: regWriteData =	{ { 16{ memReadData[15] } }, memReadData[15:0] }; // lh lhu
				2: regWriteData =	memReadData; // lw
			endcase
		end
		7'b0100011: // FMT S sb sh sw
		begin
			aluX					=	regReadData0;
			aluY					=	imm;
			aluOp					=	`ADD;
			
			pcOp					=	`PCAdd4;
			memAddr				=	aluO;
			case (func3)
				0: memWriteData	=	{ { 24{ regReadData1[7] } }, regReadData1[7:0] }; // sb
				1: memWriteData =	{ { 16{ regReadData1[15] } }, regReadData1[15:0] }; // sh
				2: memWriteData =	regReadData1; // sw
			endcase
			state					=	`MemWrite;
		end
		7'b1100011: // FMT B
		begin
			case (func3)
				0: aluOp		=	`Equal; // beq
				1: aluOp		=	`NotEqual; // bne
				4: aluOp		=	`LesserThanSigned; // blt
				5: aluOp		=	`GreaterThanOrEqualSigned; // bge
				6: aluOp		=	`LesserThanUnsigned; // bltu
				7: aluOp		=	`GreaterThanOrEqualUnsigned; // bgeu
			endcase
			aluX					=	regReadData0;
			aluY					=	regReadData1;

			pcOp					=	aluO ? `PCAddImm : `PCAdd4;
			pcWriteData		=	imm;
			state					=	`PCWrite;
		end
		7'b1101111: // FMT J jal
		begin
			aluX					=	pcReadData;
			aluY					=	imm;
			aluOp					=	`ADD;

			pcOp					=	`PCSetImm;
			pcWriteData		=	aluO;
			regWriteData	=	pcReadData;
			state					=	`RegsWrite;
		end
		7'b1100111: // FMT I jalr
		begin
			aluX					=	regReadData0;
			aluY					=	imm;
			aluOp					=	`ADD;
			
			pcOp					=	`PCSetImm;
			pcWriteData		=	aluO;
			regWriteData	=	pcReadData;
			state					=	`RegsWrite;
		end
		7'b0110111: // FMT U lui
		begin
			pcOp					=	`PCAdd4;
			regWriteData	=	imm;
			state					=	`RegsWrite;
		end
		7'b0010111: // FMT U auipc
		begin
			aluX					=	pcReadData;
			aluY					=	imm;
			aluOp					=	`ADD;

			pcOp					=	`PCAdd4;
			regWriteData	=	aluO;
			state					=	`RegsWrite;
		end
		default: state	= `IDLE;
	endcase
	end
end
endmodule