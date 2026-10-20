# UNTESTED TEMPLATE. Command names follow common Innovus usage but vary by
# version (legacy vs. flow-style commands). Check against your version's docs.
# Inputs: Genus netlist + SDC from results/genus/.
set DESIGN systolic_array
set OUT    results/innovus
file mkdir $OUT

# ---- edit for your PDK ----
set init_verilog   results/genus/${DESIGN}_netlist.v
set init_top_cell  $DESIGN
set init_lef_file  {/path/tech.lef /path/cells.lef}
set init_mmmc_file scripts/innovus/mmmc.tcl   ;# defines libs, corners, SDC
set init_pwr_net   VDD
set init_gnd_net   VSS
init_design

floorPlan -r 1.0 0.60 10 10 10 10      ;# aspect, utilization, core-to-die margins
globalNetConnect VDD -type pgpin -pin VDD -all
globalNetConnect VSS -type pgpin -pin VSS -all

# Power grid: pick metal layers valid for your PDK
# addRing   -nets {VDD VSS} -layer {top M? bottom M? left M? right M?} ...
# addStripe -nets {VDD VSS} -layer M? -direction vertical ...
# sroute    -nets {VDD VSS}

place_opt_design
ccopt_design
route_design
opt_design -post_route -setup -hold

# Reports for the PPA table
report_timing -max_paths 10 > $OUT/timing_postroute.rpt
report_area                 > $OUT/area.rpt
report_power                > $OUT/power.rpt
verify_drc                  ;# also run signoff DRC/LVS (Pegasus/Calibre)
verify_connectivity

saveNetlist $OUT/${DESIGN}_pnr.v
write_sdf   $OUT/${DESIGN}.sdf
# streamOut $OUT/${DESIGN}.gds -mapFile /path/stream.map -libName DesignLib -units 1000 -mode ALL
exit
