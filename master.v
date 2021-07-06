module master(
	// master control
	input  wire        rst,      /* reset */
	input  wire        clk,      /* internal clk */
	input  wire        rw,       /* 1 - read, 0 - write */
	output reg  [7:0]  data_out, /* data out bus */
	input  wire [7:0]  data_in,  /* data in bus */

	// master output
	output wire [2:0]  state,    /* for debugging purposes */

	// i2c interface
	output reg         sclk,     /* serial clock */
	output reg         sda_out,  /* serial data out bus */
	input  wire        sda_in    /* serial data in bus */
);

/* adds more granularity for checking waveforms and states */
reg [2:0] tic_counter = 3'b000;

parameter [7:0] i2c_slave_address = 8'h5a;

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

reg [1:0] half_ack_received = 2'b00;
reg [1:0] half_nack_received = 2'b00;

reg rw_bit_wait = 1'b0;

initial begin
	sda_out = 1'b1;
	sclk = 1'b0;
	state_reg = STATE_IDLE;
end

always@(posedge clk) begin
	if (!rst)  begin
		tic_counter++;
		if (!tic_counter) sclk = ~sclk;
	end
end

always@(posedge clk) begin
	if (rst == 1'b1) begin
		sda_out = 1'b1;
		sclk = 1'b0;
		rw_bit_wait = 1'b0;
		state_reg = STATE_IDLE;
	end
	else begin

		/* To sync sda_out and sda_in lines */
		sda_out = sda_in;

		case (state_reg)
		STATE_IDLE: begin
			/*       ______
			 * sclk        \_
			 *       __
			 * sda     \_____
			 *         ^
			 *         |- start signal
			 */
			if (sclk) begin
				if (sda_in && tic_counter == 4) begin
					sda_out = 1'b0;
				end
			end
			else begin
				if (!sda_in) state_reg = STATE_ADDRESSING;
			end
		end
		STATE_ADDRESSING: begin
			if (!tic_counter) begin
				if (sclk) begin
					if (i_reg == 3'b111) begin
						if (rw_bit_wait) begin
						end
						else begin
							state_reg = STATE_WAITING; /* next state */
							sda_out = 1'b1;            /* setting up for receiving ACK */
							i_reg++;                   /* resetting i_reg for next set of operations */
						end
					end
				end
				else begin
					sda_out = i2c_slave_address[i_reg];
					if (i_reg != 3'b111) begin
						rw_bit_wait = 1'b1;
						i_reg++;
					end
					else begin
						if (rw_bit_wait) sda_out = i2c_slave_address[i_reg];
						else  sda_out = rw;
						rw_bit_wait = 1'b0;
					end
				end
			end
		end
		/* ACK signal
		 *      _          _
		 * sda   \________/
		 *          ___
		 * sclk ___/   \__
		 *        ^  ^  ^
		 *        |  |  |- half-ack reset and next state set here, as full ack is sent
		 *        |  |- half-ack set to 2 here, as sda has been held low for sclk high
		 *        |- half-ack set to 1 here, as sda held low for 1 sclk edge
		 */
		STATE_WAITING: begin
			if (sclk) begin
				if (half_ack_received == 2'b01) begin
					if (sda_in) begin
						half_ack_received = 2'b00;
					end
					else begin
						half_ack_received = 2'b10;
					end
				end
			end
			else begin
				if (sda_in) begin
					half_ack_received = 2'b00;
				end
				else begin
					if (half_ack_received == 2'b00) half_ack_received = 2'b01;
					if (half_ack_received == 2'b10) begin
						half_ack_received = 2'b00;
						if (rw == READ) state_reg = STATE_READING;
						else state_reg = STATE_WRITING;
					end
				end
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
		STATE_DONE: begin
			/*       ______
			 * sclk        \_
			 *          _____
			 * sda   __/
			 *         ^
			 *         |- stop signal
			 */
			if (!sclk) begin
			end
			else begin
				sda_out = 1'b1;
			end
		end
		endcase
	end

end

endmodule
