`timescale 1ns/100ps

module tb_master;

// inputs
reg clk, rst, rw;
reg [7:0] data_in;

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
      .clk(clk),
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
reg first_bit_wait = 1'b1;
localparam READ = 1'b1, WRITE = 1'b0;
localparam [7:0] DATA_READ = 8'hf6;

initial begin
	// dumping
	$dumpfile("test_master.vcd");
	$dumpvars(0, tb_master);

	// starting variables
	clk = 0;
	rst = 1;
	rw = READ;
	sda_in = 1;
	first_bit_wait = 1;

	#15 rst = 0; // enable
	$display("Master out of reset");
	#5000;
	$display("Stopping after 5000 time units");
	$finish;
end

always #5 clk = ~clk;

//always #1 $display("clk, sclk, sda = %b %b %b", clk, sclk, sda_out);

localparam [2:0]
	MASTER_STATE_IDLE = 3'd0,
	MASTER_STATE_ADDRESSING = 3'd1,
	MASTER_STATE_WAITING = 3'd2,
	MASTER_STATE_READING = 3'd3,
	MASTER_STATE_WRITING = 3'd4,
	MASTER_STATE_DONE = 3'd5;
reg half_ack = 1'b0;

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
		if (sclk) begin
			if (!sda_out) $display("start signal rx");
		end
	end

	MASTER_STATE_ADDRESSING: begin
		if (sclk) begin
			if (first_bit_wait) begin
				first_bit_wait = 1'b0;
			end
			else begin
				$display("slave addressing, sda[i] = %b[%d]", sda_out, i);
				if (i == 3'b110) first_bit_wait = 1'b1;
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
		if (first_bit_wait) begin
			$display("slave addressing, sda[i] = %b[%d] (received while master is in wait state)", sda_out, i);
			first_bit_wait = 1'b0;
		end
		else begin
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
	end

	MASTER_STATE_READING: begin
		if (!sclk) begin
			$display("master reading, data<-bit = %b<-%b[%d]", data_out, DATA_READ[i], i);
			sda_in = DATA_READ[i];
			i++;
		end
	end
	MASTER_STATE_WRITING: begin
		$display("ACK received, Master writing");
	end

	MASTER_STATE_DONE: begin
		$display("done, data = %b", data_out);
		$finish;
	end
	endcase

end


endmodule //tb_master
