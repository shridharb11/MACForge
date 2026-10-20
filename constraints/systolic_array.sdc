# Template SDC -- adjust period/IO budgets to your target.
set clk_period 2.0   ;# ns, sweep this for your PPA table

create_clock -name clk -period $clk_period [get_ports clk]
set_clock_uncertainty 0.10 [get_clocks clk]
set_clock_transition  0.10 [get_clocks clk]

set data_in [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay  -clock clk [expr {$clk_period * 0.30}] $data_in
set_output_delay -clock clk [expr {$clk_period * 0.30}] [all_outputs]

# Load / driving cell: set to cells that exist in YOUR library, e.g.
# set_driving_cell -lib_cell BUF_X2 $data_in
# set_load 0.02 [all_outputs]
