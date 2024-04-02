`include "Defines.v"
module Decode (
	input						clk,
	input		[6:0]		opcode,
	input		[2:0]		func3,
	input		[6:0]		func7,
	input		[4:0]		regWriteNum,
	input		[4:0]		regNum0,
	input		[4:0]		regNum1,
	input		[31:0]	imm,
	output	[31:0]	aluO
	/* output [3:0] aluOp */
);

reg						regsWriteEnable;
wire	[31:0]	regReadData0;
wire	[31:0]	regReadData1;
wire	[31:0]	regWriteData = memReadEnable ? memDataProcessed : aluO; // WAITING
RegsFile RF(clk, regNum0, regNum1, regReadData0, regReadData1, regsWriteEnable, regWriteNum, regWriteData);

reg		[3:0]		aluOp;
reg		[31:0]	aluX;
reg		[31:0]	aluY;
ALU	alu(aluOp, aluX, aluY, aluO);

wire	[31:0]	memAddr = aluO;
reg						memReadEnable;
wire	[31:0]	memReadData;
reg						memWriteEnable;
reg		[31:0]	memWriteData;
reg		[31:0]	PC;
DataMem mem(memAddr, memReadEnable, memReadData, memWriteEnable, memWriteData, PC);

wire	[1:0]		numberOfBytes	= func3[1:0];
reg		[31:0]	memDataProcessed;
always @(posedge clk)
begin
	case (opcode)
		7'b0110011: // FMT R
		begin
			case (func3)
				0: aluOp		<= func7[5] ? `SUB : `ADD;	// add sub
				1: aluOp		<= `ShiftLeftUnsigned;	// sll
				2: aluOp		<= `LesserThanSigned;	// slt
				3: aluOp		<= `LesserThanUnsigned; // sltu
				4: aluOp		<= `XOR; // xor
				5: aluOp		<= func7[5] ?	`ShiftRightSigned : `ShiftRightUnsigned; // srl sra
				6: aluOp		<= `OR; // or
				7: aluOp		<= `AND; // and
			endcase
			aluX					<= regReadData0;
			aluY					<= regReadData1;

			regsWriteEnable <= 1;
		end
		7'b0010011: // FMT I
		begin
			case (func3)
				0: aluOp		<= `ADD;	// addi
				1: aluOp		<= `ShiftLeftUnsigned;	// slli
				2: aluOp		<= `LesserThanSigned;	// slti
				3: aluOp		<= `LesserThanUnsigned; // sltiu
				4: aluOp		<= `XOR; // xori
				5: aluOp		<= imm[10] ?	`ShiftRightSigned : `ShiftRightUnsigned; // srli srai
				6: aluOp		<= `OR; // ori
				7: aluOp		<= `AND; // andi
			endcase
			aluX					<= regReadData0;
			aluY					<= imm;

			regsWriteEnable <= 1;
		end
		7'b0000011: // FMT I lb lh lw lbu lhu
		begin
			aluX					<= regReadData0;
			aluY					<= imm;
			aluOp					<= `ADD;

			memReadEnable	<= 1;
			case (numberOfBytes)
				0: memDataProcessed <= { { 24{ memReadData[7] } }, memReadData[7:0] }; // lb lbu
				1: memDataProcessed <= { { 16{ memReadData[15] } }, memReadData[15:0] }; // lh lhu
				2: memDataProcessed <= memReadData; // lw
			endcase
			regsWriteEnable	<= 1;

			//	WAITING
		end
		7'b0100011: // FMT S sb sh sw
		begin
			aluX					<= regReadData0;
			aluY					<= imm;
			aluOp					<= `ADD;
			
			memAddr				<= aluO;
			case (numberOfBytes)
				0: memWriteData <= { { 24{ regReadData1[7] } }, regReadData1[7:0] }; // sb
				1: memWriteData <= { { 16{ regReadData1[15] } }, regReadData1[15:0] }; // sh
				2: memWriteData <= regReadData1; // sw
			endcase
			memWriteEnable <= 1;

			//	WAITING
		end
		7'b1100011: // FMT B
		begin
			case (func3)
				0: aluOp		<= `Equal; // beq
				1: aluOp		<= `NotEqual; // bne
				4: aluOp		<= `LesserThanSigned; // blt
				5: aluOp		<= `GreaterThanOrEqualSigned; // bge
				6: aluOp		<= `LesserThanUnsigned; // bltu
				7: aluOp		<= `GreaterThanOrEqualUnsigned; // bgeu
			endcase
			aluX					<= regReadData0;
			aluY					<= regReadData1;

			// WAITING
		end
		7'b1101111: // FMT J jal
		begin
			aluX					<= PC; // WAITING
			aluY					<= imm;
			aluOp					<= `ADD;

			regsWriteEnable <= 1;
			regWriteData	<= PC;
			// WAITING
		end
		7'b1100111: // FMT I jalr
		begin
			aluX					<= regReadData0;
			aluY					<= imm;
			aluOp					<= `ADD;
			
			// WAITING PC
		end
		7'b0110111: // FMT U lui
		begin
			// WAITING
		end
		7'b0010111: // FMT U auipc
		begin
			aluX					<= 0; // WAITING
			aluY					<= imm;
			aluOp					<= `ADD;

			// WAITING
		end
	endcase
end
endmodule