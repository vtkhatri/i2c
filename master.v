module master(
	// master control
	input  wire        rst,      /* reset */
	input  wire        clk,      /* internal clk */
	input  wire        rw,       /* 1 - read, 0 - write */
	output reg  [7:0]  data_out, /* data out bus */
	input  wire [7:0]  data_in,  /* data in bus */

	// master output
	output wire [3:0]  state,    /* for debugging purposes */

	// i2c interface
	output reg         sclk,     /* serial clock */
	output reg         sda_out,  /* serial data out bus */
	input  wire        sda_in    /* serial data in bus */
);

/* adds more granularity for checking waveforms and states */
reg [2:0] prescale_counter = 3'b000;

parameter [7:0] i2c_slave_address = 8'h5a;

localparam READ = 1'b1, WRITE = 1'b0;

localparam [3:0]
	STATE_IDLE        = 4'd0,
	STATE_START       = 4'd1,
	STATE_ADDRESSING  = 4'd2,
	STATE_WAITING     = 4'd3,
	STATE_ACK_STARTED = 4'd4,
	STATE_ACKD        = 4'd5,
	STATE_READING     = 4'd6,
	STATE_WRITING     = 4'd7,
	STATE_STOP_WAIT   = 4'd8,
	STATE_STOP        = 4'd9;
reg [3:0] state_reg = STATE_IDLE;

assign state = state_reg;

reg [3:0] state_next = STATE_IDLE;

reg [2:0] i_reg = 3'b000;     // bit counter
reg op_done = 1'b0;           // to check if 8 bits r/w is done
reg [7:0] data_input = 8'h00; // internal storage register

reg [1:0] half_ack_received = 2'b00;
reg [1:0] half_nack_received = 2'b00;

reg rw_bit_wait = 1'b0;

initial begin
	sda_out = 1'b1;
	sclk = 1'b0;
	state_reg = STATE_IDLE;
end

/*
 * STATE HANDLING
 */
always @* begin
	state_next = STATE_IDLE;
	if (!rst) begin
		state_next = state_reg;
		case (state_reg)
			/* Start signal - sda goes low when sclk is high
			 *           _____
			 * sclk  ___/
			 *       _____
			 * sda        \___
			 *            ^
			 *            |- start signal
			 */
			STATE_IDLE: begin
				if (sclk && sda_in) state_next = STATE_START;             // both high, can bring sda low to send start
			end
			STATE_START: begin
				if (sda_in && !sclk) state_next = STATE_IDLE;             // window of start signal has been missed
				else if (!sda_in && sclk) state_next = STATE_ADDRESSING;  // after start signal has been sent
				else state_next = STATE_START;
			end
			STATE_ADDRESSING: begin
				if (op_done) state_next = STATE_WAITING;
				else state_next = STATE_ADDRESSING;
			end


			/* ACK signal - sclk pulses low-high-low while sda is held low
			 *      ___          _
			 * sda     \________/
			 *            ___
			 * sclk _____/   \__
			 *      ^  ^  ^  ^
			 *      |  |  |  |- next state here
			 *      |  |  |-  state_ackd here
			 *      |  |- state_ack_started here
			 *      |- state_waiting here
			 */
			STATE_WAITING: begin
				if (!sda_in && !sclk) state_next = STATE_ACK_STARTED;  // conditions are met for sclk pulse, everything low
				else state_next = STATE_WAITING;
			end
			STATE_ACK_STARTED: begin
				if (sda_in) state_next = STATE_WAITING;                // sda has gone high, thus stopping ack midway
				else if (!sda_in && sclk) state_next = STATE_ACKD;     // sda high for pos edge sclk
				else state_next = STATE_WAITING;
			end
			STATE_ACKD: begin
				if (sda_in) state_next = STATE_WAITING;
				else if (!sda_in && !sclk) begin                       // full ack verified
					if (rw == READ) state_next = STATE_READING;
					else state_next = STATE_WRITING;
				end else state_next = STATE_ACKD;
			end


			/* R/W operation - TODO
			 */
			STATE_READING: begin
				if (op_done) state_next = STATE_STOP;
				else state_next = STATE_READING;
			end
			STATE_WRITING: begin
				if (op_done) state_next = STATE_STOP;
				else state_next = STATE_WRITING;
			end


			/* STOP signal - sda going high when sclk is high
			 *      _______
			 * sclk        \_
			 *          _____
			 * sda  ___/
			 *       ^   ^
			 *       |   |- state_stop here
			 *       |- state_stop_wait here
			 */
			STATE_STOP_WAIT: begin
				if (sclk && !sda_in) state_next = STATE_STOP;
				else state_next = STATE_STOP_WAIT;
			end
			STATE_STOP: begin
				if (!sclk) state_next = STATE_STOP_WAIT;
				if (sclk && sda_in) state_next = STATE_IDLE;
				else state_next = STATE_STOP;
			end
		endcase
	end
end

/*
 * SCALING AND SYNC
 */
always@(posedge clk) begin
	// To sync sda_out and sda_in lines
	sda_out = sda_in;

	if (!rst)  begin
		prescale_counter++;
		if (prescale_counter == 3'b000) sclk = ~sclk;
	end
end

/*
 * DATA HANDLING
 */
always@(posedge clk) begin
	state_reg = state_next;
	case (state_reg)
		/*       ______
		 * sclk        \_
		 *       __
		 * sda     \_____
		 *         ^
		 *         |- start signal
		 */
		STATE_IDLE: begin
			sda_out = 1'b1;
			i_reg = 3'b000;
			rw_bit_wait = 1'b0;
		end
		STATE_START: begin
			sda_out = 1'b0; // Pulling sda down, thus sending start signal
		end
		STATE_ADDRESSING: begin
			if (prescale_counter) begin // sclk is inverted on 000
				if (!sclk) begin
					//if (rw_bit_wait == 1'b1 && i_reg == 3'b111) op_done = 1'b1;

					sda_out = i2c_slave_address[i_reg];

					if (i_reg != 3'b111) i_reg++;
					else op_done = 1'b1; // TODO : check if rw_bit_wait is required
				end
			end
		end
		/* ACK signal
		 *      ___          _
		 * sda     \________/
		 *            ___
		 * sclk _____/   \__
		 *      ^  ^  ^  ^
		 *      |  |  |  |- next state here
		 *      |  |  |-  state_ackd here
		 *      |  |- state_ack_started here
		 *      |- state_waiting here
		 */
		STATE_WAITING: begin
			op_done = 1'b0;
			if (prescale_counter == 3'b111) sda_out = 1'b0;
		end
		STATE_ACK_STARTED: begin
		end
		STATE_ACKD: begin
		end

		/*
		 * Data transfers
		 */
		STATE_READING: begin
			if (prescale_counter == 3'b111) begin // sclk is inverted on 000
				if (!sclk) begin
					//if (rw_bit_wait == 1'b1 && i_reg == 3'b111) op_done = 1'b1;

					data_out[i_reg] = sda_in;

					if (i_reg != 3'b111) i_reg++;
					else op_done = 1'b1; // TODO : check if rw_bit_wait is required
				end
			end
		end
		STATE_WRITING: begin
			if (prescale_counter == 3'b111) begin // sclk is inverted on 000
				if (!sclk) begin
					//if (rw_bit_wait == 1'b1 && i_reg == 3'b111) op_done = 1'b1;

					sda_out = data_in[i_reg];

					if (i_reg != 3'b111) i_reg++;
					else op_done = 1'b1; // TODO : check if rw_bit_wait is required
				end
			end
		end

		/* STOP signal - sda going high when sclk is high
		 *      _______
		 * sclk        \_
		 *          _____
		 * sda  ___/
		 *       ^   ^
		 *       |   |- state_stop here
		 *       |- state_stop_wait here
		 */
		STATE_STOP_WAIT: begin
			op_done = 1'b0;
			sda_out = 1'b0;
		end
		STATE_STOP: begin
			sda_out = 1'b1;
		end
	endcase

	if (rst) begin
		sda_out = 1'b1;
		sclk = 1'b0;
		rw_bit_wait = 1'b0;
		state_reg = STATE_IDLE;
	end

end

endmodule
