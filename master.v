module master(
	// master control
	input rst;       /* reset */
	input clk;       /* internal clk */
	input rw;        /* 0 - read, 1 - write */
	inout data[7:0]; /* data that is read or data to write */

	// i2c interface
	output sclk;     /* serial clock */
	inout sda;       /* serial data bus */
);

parameter [7:0] i2c_slave_address = 8'h01;

localparam [3:0]
	STATE_IDLE = 3'd0,
	STATE_ADDRESSING = 3'd1,
	STATE_WAITING = 3'd2,
	STATE_READING = 3'd3,
	STATE_WRITING = 3'd4;
	STATE_DONE = 3'd5;

reg [3:0] state_reg = STATE_IDLE;
reg [3:0] i_reg = 3'b000;     /* bit counter */
reg [7:0] i_data_reg = 8'h00; /* internal storage register */

always@(posedge clk)
begin
	if (rst) begin
		sclk <= 1'b1;
		sda <= 1'b1;
	end
	else begin
		case (state_reg)
		STATE_IDLE: begin /* sending start condition */
			if (sda) sda = 1'b0;
			else begin
				sclk = 1'b0;
				state_reg = STATE_ADDRESSING;
				end
			end
		STATE_ADDRESSING:
		STATE_WAITING:
		STATE_READING:
		STATE_WRITING:
		STATE_DONE:
		endcase
	end
end

endmodule
