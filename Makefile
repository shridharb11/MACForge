# Usage:  make sim [N=8] [DATA_W=8]      (Verilator)
#         make sim_iv [N=8]              (Icarus Verilog)
#         make sweep                     (regression over several N)
N      ?= 8
DATA_W ?= 8
RTL     = rtl/pe.sv rtl/systolic_array.sv
TB      = tb/tb_systolic_array.sv

sim:
	verilator --binary --timing -Wall -Wno-fatal --top-module tb_systolic_array \
	  -GN=$(N) -GDATA_W=$(DATA_W) $(RTL) $(TB) -Mdir build/n$(N) >/dev/null
	./build/n$(N)/Vtb_systolic_array | tee build/sim_n$(N).log
	@grep -q "TB PASS" build/sim_n$(N).log

sim_iv:
	mkdir -p build
	iverilog -g2012 -Ptb_systolic_array.N=$(N) -Ptb_systolic_array.DATA_W=$(DATA_W) \
	  -o build/sim_iv_n$(N) $(RTL) $(TB)
	vvp build/sim_iv_n$(N) | tee build/sim_iv_n$(N).log
	@grep -q "TB PASS" build/sim_iv_n$(N).log

sweep:
	for n in 1 2 3 4 8 16; do $(MAKE) --no-print-directory sim N=$$n || exit 1; done

clean:
	rm -rf build sim.vcd
