all: master

master:
	iverilog -o test_master.vvp master.v test_master.v
	vvp test_master.vvp

clean:
	rm -f *.vvp *.vcd

display:
	gtkwave *.vcd
