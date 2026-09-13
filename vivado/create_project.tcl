# Recreate the project without using files from the development checkout.
set root [file normalize [file join [file dirname [info script]] ..]]
set project_dir [file join $root build JRPaint]

if {[llength [get_projects -quiet]] != 0} {
    error "Close the current Vivado project before running this script."
}
if {[file exists $project_dir]} {
    error "Build directory already exists: $project_dir. Open its JRPaint.xpr instead."
}

set sources {
    final_project_vga_files/FinalProjectJRPaint.v
    final_project_vga_files/VGATimingGenerator.v
    final_project_vga_files/Ps2Interface.vhd
    final_project_vga_files/color_audio_table.vh
    final_project_vga_files/finalprojectJRPaint_assembly.mem
    final_project_vga_files/colors.mem
    final_project_vga_files/cursor.mem
    final_project_vga_files/color_audio.mem
    rachel_processor/proc/RAM.v
    rachel_processor/proc/ROM.v
    rachel_processor/proc/alu.v
    rachel_processor/proc/dffe_ref.v
    rachel_processor/proc/multdiv.v
    rachel_processor/proc/processor.v
    rachel_processor/proc/regfile.v
    rachel_processor/proc/register.v
    rachel_processor/proc/tFlipFlipAndMux.v
    lab9_kit/PWMSerializer.v
}
set source_files {}
foreach source $sources {
    set path [file join $root $source]
    if {![file isfile $path]} {
        error "Missing source: $path"
    }
    lappend source_files $path
}
set constraints [file join $root final_project_vga_files constraints.xdc]
set clock_ip [file join $root vivado ip clk_wiz_0 clk_wiz_0.xci]
foreach path [list $constraints $clock_ip] {
    if {![file isfile $path]} {
        error "Missing project input: $path"
    }
}

create_project JRPaint $project_dir -part xc7a100tcsg324-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
add_files -norecurse $source_files
set_property include_dirs [list [file join $root final_project_vga_files]] [get_filesets sources_1]
set_property file_type {Verilog Header} [get_files [list [file join $root final_project_vga_files color_audio_table.vh]]]
foreach name {finalprojectJRPaint_assembly.mem colors.mem cursor.mem color_audio.mem} {
    set_property file_type {Memory Initialization Files} [get_files [list [file join $root final_project_vga_files $name]]]
}
add_files -fileset constrs_1 -norecurse [list $constraints]

# Import a working copy so generated IP files stay in the ignored build folder.
import_ip [list $clock_ip]
generate_target all [get_ips clk_wiz_0]
set_property top FinalProjectJRPaint [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "Created [file join $project_dir JRPaint.xpr]"
puts "Open this project in Vivado to run synthesis, implementation, and bitstream generation."
