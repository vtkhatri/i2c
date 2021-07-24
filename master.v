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
	STATE_IDLE        = 3'd0,
	STATE_START_WAIT  = 3'd1,
	STATE_ADDRESSING  = 3'd2,
	STATE_WAITING     = 3'd3,
	STATE_ACK_STARTED = 3'd4,
	STATE_ACKD        = 3'd5,
	STATE_READING     = 3'd6,
	STATE_WRITING     = 3'd7,
	STATE_DONE_WAIT   = 3'd8;
	STATE_DONE        = 3'd9;
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
				if (sclk && sda_out) state_next = STATE_START;             // both high, can bring sda low to send start
			end
			STATE_START: begin
				if (sda_out && !sclk) state_next = STATE_IDLE;             // window of start signal has been missed
				else if (!sda_out && sclk) state_next = STATE_ADDRESSING;  // after start signal has been sent
				else state_next = STATE_START;
			end
			STATE_ADDRESSING: begin
				if (op_done) begin                                         // all 8-bits of slave address sent
					op_done = 1'b0;
					state_next = STATE_WAITING;
				end else state_next = STATE_ADDRESSING;
			end
			/* ACK signal - sclk pulses low-high-low while sda is held low
			 *      _          _
			 * sda   \________/
			 *          ___
			 * sclk ___/   \__
			 *        ^  ^  ^
			 *        |  |  |- next state here
			 *        |  |-  state_ackd here
			 *        |- state_ack_started here
			 */
			STATE_WAITING: begin
				if (!sda and !sclk) state_next = STATE_ACK_STARTED;  // conditions are met for clk pulse, everything low
				else state_next = STATE_WAITING;
			end
			STATE_ACK_STARTED: begin
				if (sda) state_next = STATE_WAITING;                 // sda has gone high, thus stopping ack midway
				else if (!sda && sclk) state_next = STATE_ACKD;      // sda high for pos edge sclk
				else state_next = STATE_WAITING;
			end
			STATE_ACKD: begin
				if (sda) state_next = STATE_WAITING;
				else if (!sda and !sclk) begin                            // full ack verified
					if (rw == READ) state_next = STATE_READING;
					else state_next = STATE_WRITING;
				end else state_next = STATE_ACKD;
			end
			STATE_READING: begin
				if (op_done) begin
					op_done = 1'b0;
					state_next = STATE_DONE;
				end else state_next = STATE_READING;
			end
			STATE_WRITING: begin
				if (op_done) begin
					op_done = 1'b0;
					state_next = STATE_DONE;
				end else state_next = STATE_WRITING;
			end
			/* STOP signal - sda going high when sclk is high
			 *       ______
			 * sclk        \_
			 *          _____
			 * sda   __/
			 *         ^
			 *         |- stop signal
			 */
			STATE_DONE_WAIT: begin
				if (sclk && !sda) state_next = STATE_DONE;
				else state_next = STATE_DONE_WAIT;
			end
			STATE_DONE: begin
				if (!sclk) state_next = STATE_DONE_WAIT;
				if (sclk && sda) state_next = STATE_IDLE;
				else state_next = STATE_DONE;
			end
		endcase
	end
end

always@(posedge clk) begin
	state_reg = state_next;
	if (!rst)  begin
		prescale_counter++;
		if (!prescale_counter) sclk = ~sclk;
	end
end

always@(posedge clk) begin

	// To sync sda_out and sda_in lines
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
			if (sda_in && prescale_counter != 0) begin
				sda_out = 1'b0;
			end
		end
		else begin
			if (!sda_in) state_reg = STATE_ADDRESSING;
		end
	end
	STATE_ADDRESSING: begin
		if (!prescale_counter) begin
			if (sclk) begin
				if (i_reg == 3'b111) begin
					if (rw_bit_wait) begin
					end
					else begin
						state_reg = STATE_WAITING; // next state
						sda_out = 1'b1;            // setting up for receiving ACK
						i_reg++;                   // resetting i_reg for next set of operations
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
		if (!sclk) begin
		end
		else begin
			sda_out = 1'b1;
		end
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
