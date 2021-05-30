module master(
	// master control
	input wire  rst,  /* reset */
	input wire  clk,  /* internal clk */
	input wire  rw,   /* 0 - read, 1 - write */
	inout [7:0] data, /* data that is read or data to write */

	// master output
	output wire [3:0] state,

	// i2c interface
	output reg sclk,  /* serial clock */
	inout      sda    /* serial data bus */
);

parameter [7:0] i2c_slave_address = 8'h01;

localparam [3:0]
	STATE_IDLE = 3'd0,
	STATE_ADDRESSING = 3'd1,
	STATE_WAITING = 3'd2,
	STATE_READING = 3'd3,
	STATE_WRITING = 3'd4,
	STATE_DONE = 3'd5;
reg [3:0] state_reg = STATE_IDLE;

assign state = state_reg;

reg [3:0] i_reg = 3'b000;     /* bit counter */
reg [7:0] i_data_reg = 8'h00; /* internal storage register */

reg sda_reg;
assign sda = !rst ? sda_reg : 1'bz;

assign data = (state_reg == STATE_IDLE) ? i_data_reg : 8'bz;

always@(posedge clk)
begin
	if (rst) begin
		sclk <= 1'b1;
		sda_reg <= 1'b1;
	end
	else begin
		case (state_reg)
		STATE_IDLE: begin /* sending start condition */
			if (sda_reg) sda_reg <= 1'b0;
			else begin
				sclk <= 1'b0;
				state_reg <= STATE_ADDRESSING;
			end
		end
		STATE_ADDRESSING: begin
			if (sclk) sclk <= 1'b0;
			else begin
				sda_reg <= i2c_slave_address[i_reg];
				i_reg++;
				sclk <= 1'b1;
			end
		end
		STATE_WAITING: begin
		end
		STATE_READING: begin
		end
		STATE_WRITING: begin
		end
		STATE_DONE: begin /* sending stop condition */
			if (!sclk) sclk <= 1'b1;
			else begin
				sda_reg <= 1'b1;
				state_reg <= STATE_IDLE;
			end
		end
		endcase
	end
end

endmodule
