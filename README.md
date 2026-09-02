
AMD Xilinx Spartan-6 DSP48A1 Slice Architecture

This repository contains the RTL design, verification, and FPGA design flow implementation of a fully parameterized AMD Xilinx Spartan-6 DSP48A1 Slice in Verilog HDL. The architecture models multi-stage pipelined arithmetic functionality, including pre-adders/subtractors, an $18 \times 18$ multiplier, dynamic operation multiplexing, dynamic/static cascade routing, and post-adders/accumulators.

├── rtl/                  # Parameterized Verilog HDL implementation of DSP48A1

├── tb/                   # Self-checking testbench with directed path stimulus

├── scripts/              # Tcl (.do) automation scripts for Siemens QuestaSim flow

├── constraints/          # Timing constraints XDC targeting 100 MHz clock frequency

├── docs/                 # Elaboration, Synthesis, Implementation reports & Schematics

└── README.md             # Project documentation
