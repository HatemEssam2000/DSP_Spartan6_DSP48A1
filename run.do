vlib work
vlog DSP48A1.v DSP48A1_tb.v
vsim -voptargs=+acc work.DSP48A1_tb
add wave *
run -all
#quit -sim



#vlib work
#vmap work work

#vlog -sv dsp48a1.v dsp48a1_tb.v

#vsim -voptargs="+acc" work.DSP48A1_tb

#onfinish stop

#add wave -radix hexadecimal -group TB    /DSP48A1_tb/*
#add wave -radix hexadecimal -group DUT   /DSP48A1_tb/dut/*

#run -all

#wave zoom full
