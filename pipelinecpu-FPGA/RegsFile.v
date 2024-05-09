`include "Defines.v"
module RegsFile(
	input	 [`AddrWidth-1:0]			PC, // AddrWidth = 32
  input												clk, reset, regWriteEnable, // 1 => WRITE
  input  [`DataWidth-1:0]			regWriteData,
  input  [`RegNumWidth-1:0]		regNum0, regNum1, regWriteNum, // RegNumWidth = 5
  output [`DataWidth-1:0]			regReadData0, regReadData1, // DataWidth = 32

	input		[`RegNumWidth-1:0]	regWatchNum,
	output	[`DataWidth-1:0]		regWatchData
);

reg	[`AddrWidth-1:0] pcData[4:0];
reg [`DataWidth-1:0] regs[31:0];

assign regReadData0 = (regNum0 != 0) ? regs[regNum0] : 0;
assign regReadData1 = (regNum1 != 0) ? regs[regNum1] : 0;
assign regWatchData = (regWatchNum != 0) ? regs[regWatchNum] : 0;

integer i;

initial for ( i = 0; i < 32; i=i+1) regs[i] = i + 1;

always @(*) if (reset) for ( i = 0; i < 32; i=i+1) regs[i] = 0;
always @(*) pcData[4] = PC;

always @(negedge clk)
if (regWriteEnable && regWriteNum != 0)
begin
  regs[regWriteNum] <= regWriteData;
  $display("pc = %h: x%d = %h", pcData[0], regWriteNum, regWriteData);
end

always @(posedge clk)
begin
	pcData[0] <= pcData[1];
	pcData[1] <= pcData[2];
	pcData[2] <= pcData[3];
	pcData[3] <= pcData[4];
end

endmodule