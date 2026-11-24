# Basys 3 pin constraints for the logic analyzer (from Digilent's Basys-3-Master.xdc).
# Note: nextpnr-xilinx ignores [current_design] properties such as CFGBVS /
# CONFIG_VOLTAGE, so they are left out.

## 100 MHz oscillator
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -period 10.00 [get_ports clk]

## USB-UART: data from the PC into the FPGA
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports RsRx]

## USB-UART: data from the FPGA to the PC
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports RsTx]

## centre button = manual trigger
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports btnC]

## 7-segment decimal point (active low)
set_property -dict { PACKAGE_PIN V7 IOSTANDARD LVCMOS33 } [get_ports dp]

## Pmod JB = probe inputs; [0..3] = pins 1-4, [4..7] = pins 7-10
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports {JB[0]}]
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports {JB[1]}]
set_property -dict { PACKAGE_PIN B15 IOSTANDARD LVCMOS33 } [get_ports {JB[2]}]
set_property -dict { PACKAGE_PIN B16 IOSTANDARD LVCMOS33 } [get_ports {JB[3]}]
set_property -dict { PACKAGE_PIN A15 IOSTANDARD LVCMOS33 } [get_ports {JB[4]}]
set_property -dict { PACKAGE_PIN A17 IOSTANDARD LVCMOS33 } [get_ports {JB[5]}]
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 } [get_ports {JB[6]}]
set_property -dict { PACKAGE_PIN C16 IOSTANDARD LVCMOS33 } [get_ports {JB[7]}]

## Pmod JC = test-signal outputs, same pin order as JB
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports {JC[0]}]
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports {JC[1]}]
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports {JC[2]}]
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports {JC[3]}]
set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports {JC[4]}]
set_property -dict { PACKAGE_PIN M19 IOSTANDARD LVCMOS33 } [get_ports {JC[5]}]
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports {JC[6]}]
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports {JC[7]}]

## switches
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]
set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports {sw[4]}]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports {sw[5]}]
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports {sw[6]}]
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports {sw[7]}]
set_property -dict { PACKAGE_PIN V2  IOSTANDARD LVCMOS33 } [get_ports {sw[8]}]
set_property -dict { PACKAGE_PIN T3  IOSTANDARD LVCMOS33 } [get_ports {sw[9]}]
set_property -dict { PACKAGE_PIN T2  IOSTANDARD LVCMOS33 } [get_ports {sw[10]}]
set_property -dict { PACKAGE_PIN R3  IOSTANDARD LVCMOS33 } [get_ports {sw[11]}]
set_property -dict { PACKAGE_PIN W2  IOSTANDARD LVCMOS33 } [get_ports {sw[12]}]
set_property -dict { PACKAGE_PIN U1  IOSTANDARD LVCMOS33 } [get_ports {sw[13]}]
set_property -dict { PACKAGE_PIN T1  IOSTANDARD LVCMOS33 } [get_ports {sw[14]}]
set_property -dict { PACKAGE_PIN R2  IOSTANDARD LVCMOS33 } [get_ports {sw[15]}]

## LEDs
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {led[7]}]
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports {led[8]}]
set_property -dict { PACKAGE_PIN V3  IOSTANDARD LVCMOS33 } [get_ports {led[9]}]
set_property -dict { PACKAGE_PIN W3  IOSTANDARD LVCMOS33 } [get_ports {led[10]}]
set_property -dict { PACKAGE_PIN U3  IOSTANDARD LVCMOS33 } [get_ports {led[11]}]
set_property -dict { PACKAGE_PIN P3  IOSTANDARD LVCMOS33 } [get_ports {led[12]}]
set_property -dict { PACKAGE_PIN N3  IOSTANDARD LVCMOS33 } [get_ports {led[13]}]
set_property -dict { PACKAGE_PIN P1  IOSTANDARD LVCMOS33 } [get_ports {led[14]}]
set_property -dict { PACKAGE_PIN L1  IOSTANDARD LVCMOS33 } [get_ports {led[15]}]

## 7-segment segments CA..CG (active low)
set_property -dict { PACKAGE_PIN W7  IOSTANDARD LVCMOS33 } [get_ports {seg[0]}]
set_property -dict { PACKAGE_PIN W6  IOSTANDARD LVCMOS33 } [get_ports {seg[1]}]
set_property -dict { PACKAGE_PIN U8  IOSTANDARD LVCMOS33 } [get_ports {seg[2]}]
set_property -dict { PACKAGE_PIN V8  IOSTANDARD LVCMOS33 } [get_ports {seg[3]}]
set_property -dict { PACKAGE_PIN U5  IOSTANDARD LVCMOS33 } [get_ports {seg[4]}]
set_property -dict { PACKAGE_PIN V5  IOSTANDARD LVCMOS33 } [get_ports {seg[5]}]
set_property -dict { PACKAGE_PIN U7  IOSTANDARD LVCMOS33 } [get_ports {seg[6]}]

## 7-segment anodes, an[3] = leftmost (active low)
set_property -dict { PACKAGE_PIN U2  IOSTANDARD LVCMOS33 } [get_ports {an[0]}]
set_property -dict { PACKAGE_PIN U4  IOSTANDARD LVCMOS33 } [get_ports {an[1]}]
set_property -dict { PACKAGE_PIN V4  IOSTANDARD LVCMOS33 } [get_ports {an[2]}]
set_property -dict { PACKAGE_PIN W4  IOSTANDARD LVCMOS33 } [get_ports {an[3]}]
