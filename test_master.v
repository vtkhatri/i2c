module tb_master;

// inputs
reg clk, rst, rw;
reg [7:0] data_in;

// master clock to make sure tb is always first
reg clk_m;

// ouputs
wire [2:0] state;
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

	#17 rst = 0; // enable
	$display("Master out of reset");
	#5000;
	$display("Stopping after 5000 time units");
	$finish;
end

localparam [2:0]
	MASTER_STATE_IDLE = 3'd0,
	MASTER_STATE_ADDRESSING = 3'd1,
	MASTER_STATE_WAITING = 3'd2,
	MASTER_STATE_READING = 3'd3,
	MASTER_STATE_WRITING = 3'd4,
	MASTER_STATE_DONE = 3'd5;
reg half_ack = 1'b0;

always #5 clk = ~clk;

always clk_m = #1 clk;

always@(posedge clk)
begin
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
		if (!rst) begin
			if (sclk) begin
				if (sda_out) $display("master will send start signal");
			end
			else begin
				if (!sda_out)  $display("start signal received");
			end
		end
	end

	MASTER_STATE_ADDRESSING: begin
		if (sclk) begin
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

	/* ACK signal
	 *      _      _
	 * sda   \____/
	 *         __
	 * sclk __/  \__
	 *        ^  ^
	 *        |  |- half-ack set to 0 here, as full ack is sent
	 *        |- half-ack set to 1 here, as sda held low for 1 sclk edge
	 */
	MASTER_STATE_WAITING: begin
		if (half_ack) begin
			$display("full ack sent");
			sda_in = 1'b1;
			half_ack = 1'b0;
			first_bit_wait = 1'b1;
		end
		if (!sclk) begin
			sda_in = 1'b0;
		end
		else begin
			$display("half ack sent");
			half_ack = 1'b1;
		end
	end

	MASTER_STATE_READING: begin
		if (!sclk) begin
			$display("master reading, data<-bit    = %b<-%b[%d]", data_out, DATA_READ[i], i);
			sda_in = DATA_READ[i];
			i++;
		end
	end
	MASTER_STATE_WRITING: begin
		$display("ACK received, Master writing");
	end

	MASTER_STATE_DONE: begin
		$display("master read done, final data = %b", data_out);
		$finish;
	end
	endcase

end

endmodule //tb_master
