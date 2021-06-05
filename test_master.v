`timescale 1ns/100ps

module tb_master;

// inputs
reg clk, rst, rw;
wire [7:0] inout_data;
reg [7:0] inout_data_drive;
assign inout_data = inout_data_drive;

// ouput state monitor
wire [3:0] state;

// i2c interface
wire sclk;
wire inout_sda;
reg inout_sda_drive;
assign inout_sda = inout_sda_drive;

master
i2c_m (
      .rst(rst),
      .clk(clk),
      .rw(rw),
      .data(inout_data),
      .state(state),
      .sclk(sclk),
      .sda(inout_sda)
);

// Local variables
reg [2:0] i = 3'b000;

initial begin
	// dumping
	$dumpfile("test_master.vcd");
	$dumpvars(0, tb_master);

	// starting variables
	clk = 0;
	rst = 1;
	rw = 0;

	#15 rst = 0 // enable
end

always #5 clk = ~clk;

localparam [3:0]
	STATE_MASTER_IDLE = 3'd0,
	STATE_MASTER_ADDRESSING = 3'd1,
	STATE_MASTER_WAITING = 3'd2,
	STATE_MASTER_READING = 3'd3,
	STATE_MASTER_WRITING = 3'd4,
	STATE_MASTER_DONE = 3'd5;
reg half_ack = 1'b0;

always@(posedge clk)
begin

	if (state === STATE_MASTER_ADDRESSING) begin
		$display("slave addressing, sda = %b", inout_sda);
	end

	if (state === STATE_MASTER_WAITING) begin
		$display("sending ack, sclk_sda_half-ack = %b_%b_%b", sclk, inout_sda, half_ack);
		if (half_ack) inout_sda_drive <=1'b1;
		if (!sclk) inout_sda_drive <= 1'b0;
		else half_ack = 1'b1
	end

	if (state === STATE_MASTER_READING) begin
		localparam data_read [7:0] = 8'hf6;
		inout_sda_drive <= data_read[i];
		i++;
		$display("master reading, data_bit = %b_%b", inout_data, inout_sda);
	end
	if (state === STATE_MASTER_WRITING) begin
		$display("ACK received, Master writing");
	end

	if (state === STATE_DONE) $stop;

end


endmodule //tb_master
