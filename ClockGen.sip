set_global_assignment -entity "ClockGen" -library "lib_ClockGen" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "ClockGen" -library "lib_ClockGen" -name IP_TOOL_VERSION "15.0"
set_global_assignment -entity "ClockGen" -library "lib_ClockGen" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_ClockGen" -name SPD_FILE [file join $::quartus(sip_path) "ClockGen.spd"]

set_global_assignment -library "lib_ClockGen" -name MISC_FILE [file join $::quartus(sip_path) "ClockGen_sim/ClockGen.vho"]
