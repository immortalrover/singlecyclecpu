module Flush (
	input			clk,
	input			pcWriteEnable,
	output		flush
);
integer i = 0;
assign flush = i > 0;

always @(posedge pcWriteEnable)
begin
	if (pcWriteEnable) i = 3;
end

always @(posedge clk) if (flush) i = i - 1;

endmodule
