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

	#15 rst = 0; // enable
	$display("Master out of reset");
	#5000;
	$display("Stopping after 5000 time units");
	$finish;
end

always #5 clk = ~clk;

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
	MASTER_STATE_IDLE: begin
	end

	MASTER_STATE_ADDRESSING: begin
		if (!sclk) begin
			$display("slave addressing, sda[i] = %b[%d]", sda_out, i);
			i++;
		end
	end

	MASTER_STATE_WAITING: begin
		$display("sending ack, sclk=%b sda-in_out=%b_%b, half-ack=%b", sclk, sda_in, sda_out, half_ack);
		if (half_ack) sda_in = 1'b1;
		if (!sclk) sda_in = 1'b0;
		else half_ack = 1'b1;
	end

	MASTER_STATE_READING: begin
		sda_in = DATA_READ[i];
		i++;
		$display("master reading, data_bit = %b_%b", data_out, sda_out);
	end
	MASTER_STATE_WRITING: begin
		$display("ACK received, Master writing");
	end

	MASTER_STATE_DONE: $stop;
	endcase

end


endmodule //tb_master
