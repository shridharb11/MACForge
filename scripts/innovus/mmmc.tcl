# UNTESTED TEMPLATE: single-corner MMMC setup. Edit lib paths.
create_library_set -name lib_tt -timing {/path/to/YOUR_TT_LIB.lib}
create_constraint_mode -name func -sdc_files {constraints/systolic_array.sdc}
create_delay_corner -name tt -library_set lib_tt
create_analysis_view -name av_tt -constraint_mode func -delay_corner tt
set_analysis_view -setup {av_tt} -hold {av_tt}
