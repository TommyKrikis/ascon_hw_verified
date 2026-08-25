@echo off
call C:\Xilinx\Vivado\2023.1\settings64.bat
call xvlog -sv -L uvm -i uvm s_box.sv p_add_const.sv p_sub.sv p_diff.sv p_round.sv ascon_perm.sv ascon_aead.sv uvm\ascon_if.sv uvm\ascon_pkg.sv uvm\ascon_tb_top.sv
call xelab -L uvm ascon_tb_top -s ascon_sim
call xsim ascon_sim -R -testplusarg "UVM_TESTNAME=ascon_kat_test"