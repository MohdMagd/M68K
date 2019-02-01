onerror {exit -code 1}
vlib work
vlog -work work MC68K.vo
vlog -work work Waveform68k-V15.0-DE1SoC_Short7us.vwf.vt
vsim -novopt -c -t 1ps -L cyclonev_ver -L altera_ver -L altera_mf_ver -L 220model_ver -L sgate_ver -L altera_lnsim_ver work.MC68K_vlg_vec_tst -voptargs="+acc"
vcd file -direction MC68K.msim.vcd
vcd add -internal MC68K_vlg_vec_tst/*
vcd add -internal MC68K_vlg_vec_tst/i1/*
run -all
quit -f
