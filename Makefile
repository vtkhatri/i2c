master:
	iverilog -o test_master.vvp master.v test_master.v
	vvp test_master.vvp
	gtkwave test_master.vcd

clean:
	rm -rf *.vvp *.vcd
