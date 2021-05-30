module master(
	// master control
	input rst;       /* reset */
	input clk;       /* internal clk */
	input rw;        /* 0 - read, 1 - write */
	inout data[7:0]; /* data that is read or data to write */

	// i2c interface
	inout sclk;      /* serial clock */
	inout sda;       /* serial data bus */
);

parameter [7:0] i2c_slave_address = 8'h01;

reg [3:0] i = 3'b000;     /* bit counter */
reg [7:0] i_data = 8'h00; /* internal storage register */

always@(posedge clk)
begin
	if (rst) begin
		sclk <= 1'b1;
		sda <= 1'b1;
	end
	else begin
	end
end

endmodule
