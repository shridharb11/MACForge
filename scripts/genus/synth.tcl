# UNTESTED TEMPLATE (no Cadence license in the environment it was written in).
# Adapt library/paths to your PDK, then:  genus -f scripts/genus/synth.tcl
set DESIGN systolic_array
set OUT    results/genus
file mkdir $OUT

# ---- edit for your PDK (e.g. FreePDK45/NanGate) ----
set LIB_DIR  /path/to/pdk/lib
set_db init_lib_search_path $LIB_DIR
set_db library {YOUR_TT_LIB.lib}
# set_db lef_library {tech.lef cells.lef}   ;# helps physical-aware synthesis

# Parameters (N, DATA_W) are set by the defaults in rtl/systolic_array.sv.
read_hdl -sv {rtl/pe.sv rtl/systolic_array.sv}
elaborate $DESIGN
check_design -unresolved

read_sdc constraints/systolic_array.sdc

set_db syn_generic_effort medium
set_db syn_map_effort     medium
set_db syn_opt_effort     medium
syn_generic
syn_map
syn_opt

report_timing -max_paths 10  > $OUT/timing.rpt
report_area                  > $OUT/area.rpt
report_power                 > $OUT/power.rpt
report_gates                 > $OUT/gates.rpt
write_hdl > $OUT/${DESIGN}_netlist.v
write_sdc > $OUT/${DESIGN}.sdc
exit
