all: master

master:
	iverilog -o test_master.vvp master.v test_master.v
	vvp test_master.vvp
	gtkwave test_master.vcd test_master_save.gtkw

clean:
	rm -f *.vvp *.vcd *.gtkw
