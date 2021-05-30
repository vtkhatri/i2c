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
assign sda = !rst ? sda_reg : 1'b1;

assign data = (state_reg == STATE_IDLE) ? i_data_reg : 8'bz;

reg half_ack_received = 1'b0;
reg half_nack_received = 1'b0;

always@(posedge clk)
begin
	if (rst) begin
		sclk <= 1'b1;
		sda_reg <= 1'b1;
	end
	else begin
		case (state_reg)
		STATE_IDLE: begin /* sending start condition */
			if (sda) sda_reg <= 1'b0;
			else begin
				state_reg <= STATE_ADDRESSING;
				sclk <= #2 1'b0;
			end
		end
		STATE_ADDRESSING: begin
			if (sclk) begin
				if (i_reg == 3'b111) begin
					state_reg <= STATE_WAITING; /* next state */
					sda_reg <= 1'b1; /* setting up for receiving ACK */
					i_reg++; /* resetting i_reg for next set of operations */
				end
				sclk <= #2 1'b0;
			end
			else begin
				sda_reg <= i2c_slave_address[i_reg];
				if(i_reg != 3'b111) i_reg++;
				sclk <= #2 1'b1;
			end
		end
		STATE_WAITING: begin
			if (sclk) begin
				if (half_ack_received) begin
					if (!sda) begin
						if (rw) state_reg <= STATE_WRITING;
						else state_reg <= STATE_READING;
					end
					else half_ack_received <= 1'b0;
				end
				sclk <= #2 1'b0;
			end
			else begin
				if (!sda) half_ack_received <= 1'b1;
				sclk <= #2 1'b1;
			end
		end
		STATE_READING: begin
			if (sclk) begin
				sclk <= #2 1'b0;
			end
			else begin
				sclk <= #2 1'b1;
			end
		end
		STATE_WRITING: begin
			if (sclk) begin
				sclk <= #2 1'b0;
			end
			else begin
				sclk <= #2 1'b1;
			end
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
