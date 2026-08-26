@echo off
call C:\Xilinx\Vivado\2023.1\settings64.bat
call xvlog -sv -L uvm -i uvm rtl\s_box.sv rtl\p_add_const.sv rtl\p_sub.sv rtl\p_diff.sv rtl\p_round.sv rtl\ascon_perm.sv rtl\ascon_aead.sv uvm\ascon_if.sv uvm\ascon_pkg.sv uvm\ascon_tb_top.sv
call xelab -L uvm ascon_tb_top -s ascon_sim
call xsim ascon_sim -R -testplusarg "UVM_TESTNAME=ascon_kat_test"