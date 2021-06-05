master:
	iverilog -o test_master.vvp test_master.v master.v
	vvp test_master.vvp
	gtkwave test_master.vcd

clean:
	rm -rf *.vvp *.vcd
