module tb_master;

// inputs
reg clk, rst, rw;
reg [7:0] data_in;

// master clock to make sure tb is always first
reg clk_m;

// ouputs
wire [3:0] state;
wire [7:0] data_out;

// i2c interface
wire sclk;
reg  sda_in;
wire sda_out;

master
i2c_m (
	.rst(rst),
	.clk(clk_m),
	.rw(rw),
	.data_in(data_in),
	.data_out(data_out),
	.state(state),
	.sclk(sclk),
	.sda_in(sda_in),
	.sda_out(sda_out)
);

// Local variables
reg [2:0] i = 3'b000;
reg first_bit_wait = 1'b0;
reg rw_bit_wait = 1'b0;
localparam READ = 1'b1, WRITE = 1'b0;
localparam [7:0] DATA_READ = 8'hf6;
localparam [7:0] DATA_WRITE = 8'ha6;
reg [2:0] prescale_counter = 0;

initial begin
	// dumping
	$dumpfile("test_master.vcd");
	$dumpvars(0, tb_master);
	$dumpvars(1, i2c_m);

	$display("============");
	$display("Starting Sim");
	$display("============");

	// starting variables
	clk = 0;
	clk_m = 0;
	rst = 1;
	rw = READ;
	sda_in = 1;
	first_bit_wait = 1;
	rw_bit_wait = 0;
	prescale_counter = 0;

	#17 rst = 0; // enable
	$display("Master out of reset");
	#5000;
	$display("Stopping after 5000 time units");
	$finish;
end

localparam [3:0]
	MASTER_STATE_IDLE        = 4'd0,
	MASTER_STATE_START       = 4'd1,
	MASTER_STATE_ADDRESSING  = 4'd2,
	MASTER_STATE_WAITING     = 4'd3,
	MASTER_STATE_ACK_STARTED = 4'd4,
	MASTER_STATE_ACKD        = 4'd5,
	MASTER_STATE_READING     = 4'd6,
	MASTER_STATE_WRITING     = 4'd7,
	MASTER_STATE_STOP_WAIT   = 4'd8,
	MASTER_STATE_STOP        = 4'd9;
reg half_ack = 1'b0;

always #5 clk_m = ~clk_m;

always clk = #1 clk_m;

always@(posedge clk)
begin
	if (!rst) prescale_counter++;
	sda_in = sda_out;

	case(state)
	/*       ______
	 * sclk        \_
	 *       __
	 * sda     \_____
	 *         ^
	 *         |- start signal
	 */
	MASTER_STATE_IDLE: begin
		/*
		if (!rst) begin
			if (sclk) begin
				if (sda_out) $display("master will send start signal");
				else $display("start signal");
			end
			else begin
				if (sda_out) $display("¯\\_(ツ)_/¯");
				else $display("start signal received");
			end
		end
		*/
	end

	MASTER_STATE_START: begin
	end

	MASTER_STATE_ADDRESSING: begin
		if (sclk && prescale_counter == 3'b111) begin
			if (first_bit_wait && i == 0) begin
				first_bit_wait = 1'b0;
				if (rw_bit_wait) begin
					if (sda_out) $display("sda = %b, reading", sda_out);
					else $display("sda = %b, writing", sda_out);
					rw_bit_wait = 1'b0;
				end
				else rw_bit_wait = 1'b1;
			end
			else begin
				if (i == 7) first_bit_wait = 1'b1;
				$display("slave addressing, sda[i] = %b[%d]", sda_out, i);
				i++;
			end
		end
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
	MASTER_STATE_WAITING: begin
		sda_in = 1'b0;
	end

	MASTER_STATE_ACK_STARTED: begin
	end

	MASTER_STATE_ACKD: begin
	end

	MASTER_STATE_READING: begin
		if (!sclk && prescale_counter == 3'b111) begin
			$display("master reading, data<-bit    = %b<-%b[%d]", data_out, DATA_READ[i], i);
			sda_in = DATA_READ[i];
			i++;
		end
	end

	MASTER_STATE_WRITING: begin
		$display("ACK received, master writing");
	end

	MASTER_STATE_STOP_WAIT: begin
		$display("master read done, final data = %b", data_out);
	end

	MASTER_STATE_STOP: begin
		$display("master stop signal received", data_out);
		$finish;
	end
	endcase

end

endmodule //tb_master
