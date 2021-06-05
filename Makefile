master:
	iverilog -o test_master.vvp master.v test_master.v
	vvp test_master.vvp

clean:
	rm -rf *.vvp *.vcd

display:
	gtkwave *.vvp
