`timescale 1ns/100ps

module master(
	// master control
	input  wire        rst,      /* reset */
	input  wire        clk,      /* internal clk */
	input  wire        rw,       /* 0 - read, 1 - write */
	output reg  [7:0]  data_out, /* data that is read or data to write */
	input  wire [7:0]  data_in,  /* data that is read or data to write */

	// master output
	output wire [2:0]  state,

	// i2c interface
	output reg         sclk,     /* serial clock */
	output reg         sda_out,  /* serial data bus */
	input  wire        sda_in    /* serial data bus */
);

parameter CLK_PERIOD = 10;

parameter [7:0] i2c_slave_address = 8'hee;

localparam READ = 1'b1, WRITE = 1'b0;

localparam [2:0]
	STATE_IDLE = 3'd0,
	STATE_ADDRESSING = 3'd1,
	STATE_WAITING = 3'd2,
	STATE_READING = 3'd3,
	STATE_WRITING = 3'd4,
	STATE_DONE = 3'd5;
reg [2:0] state_reg = STATE_IDLE;

assign state = state_reg;

reg [2:0] i_reg = 3'b000;     /* bit counter */
reg [7:0] data_input = 8'h00; /* internal storage register */

reg half_ack_received = 1'b0;
reg half_nack_received = 1'b0;

always@(posedge clk) #2 sclk = ~sclk;

always@(posedge clk) begin

	if (rst == 1'b1) begin
		sclk = 1'b1;
		sda_out = 1'b1;
		state_reg = STATE_IDLE;
	end
	else begin
		case (state_reg)
		STATE_IDLE: begin /* sending start condition */
			if (sda_in) begin
				sda_out = 1'b0;
			end
			else begin
				state_reg = STATE_ADDRESSING;
			end
		end
		STATE_ADDRESSING: begin
			if (sclk) begin
				if (i_reg == 3'b111) begin
					state_reg = STATE_WAITING; /* next state */
					sda_out = 1'b1;            /* setting up for receiving ACK */
					i_reg++;                   /* resetting i_reg for next set of operations */
				end
			end
			else begin
				sda_out = i2c_slave_address[i_reg];
				if(i_reg != 3'b111) i_reg++;
			end
		end
		STATE_WAITING: begin
			if (sclk) begin
				if (half_ack_received) begin
					if (!sda_in) begin
						if (rw == READ) state_reg = STATE_READING;
						else state_reg = STATE_WRITING;
					end
					else half_ack_received = 1'b0;
				end
			end
			else begin
				if (!sda_in) half_ack_received = 1'b1;
			end
		end
		STATE_READING: begin
			if (sclk) begin
			end
			else begin
				data_out[i_reg] = sda_in;
				if (i_reg == 3'b111) begin
					state_reg = STATE_DONE;
				end
				i_reg++;
			end
		end
		STATE_WRITING: begin
			if (sclk) begin
			end
			else begin
				sda_out = data_in[i_reg];
				if (i_reg == 3'b111) begin
					state_reg = STATE_DONE;
				end
				i_reg++;
			end
		end
		STATE_DONE: begin /* sending stop condition */
			if (!sclk) begin
			end
			else begin
				sda_out = 1'b1;
				state_reg = STATE_IDLE;
			end
		end
		endcase
	end
end

endmodule
