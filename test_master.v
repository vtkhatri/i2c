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

always #5 clk = ~clk;

initial begin
	// starting variables
	clk = 0;
	rst = 1;
	rw = 0;

	// dumping
	$dumpfile("test_master.vcd");
	$dumpvars(0, tb_master);
end

endmodule //tb_master
