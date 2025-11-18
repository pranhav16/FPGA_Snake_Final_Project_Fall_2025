## Snake Game Constraints File for Cmod A7-35T
## 
## IMPORTANT NOTES:
## - The Cmod A7 has a 12 MHz clock (NOT 100 MHz like Basys 3)
## - Only 2 on-board buttons available (btn[0] and btn[1])
## - Must use GPIO pins (pio) for additional button inputs
## - VGA requires external circuitry - use Pmod connector + resistor DAC
##
## Pin assignments use the 48-pin DIP connector GPIO (pio) pins
## Modify as needed based on your specific breadboard setup

## Clock signal - 12 MHz on Cmod A7
set_property -dict { PACKAGE_PIN L17   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 83.33 -waveform {0 41.66} [get_ports clk]

## Reset - Using on-board button 0
set_property -dict { PACKAGE_PIN A18   IOSTANDARD LVCMOS33 } [get_ports rst]

## Player 1 Controls - Using GPIO pins (breadboard connections)
## Connect push buttons between these pins and GND (active low)
## UP
set_property -dict { PACKAGE_PIN M3    IOSTANDARD LVCMOS33 } [get_ports p1_btn_up]
## DOWN
set_property -dict { PACKAGE_PIN L3    IOSTANDARD LVCMOS33 } [get_ports p1_btn_down]
## LEFT
set_property -dict { PACKAGE_PIN A16   IOSTANDARD LVCMOS33 } [get_ports p1_btn_left]
## RIGHT
set_property -dict { PACKAGE_PIN K3    IOSTANDARD LVCMOS33 } [get_ports p1_btn_right]

## Player 2 Controls - Using GPIO pins
## UP
set_property -dict { PACKAGE_PIN C15   IOSTANDARD LVCMOS33 } [get_ports p2_btn_up]
## DOWN
set_property -dict { PACKAGE_PIN H1    IOSTANDARD LVCMOS33 } [get_ports p2_btn_down]
## LEFT
set_property -dict { PACKAGE_PIN A14   IOSTANDARD LVCMOS33 } [get_ports p2_btn_left]
## RIGHT
set_property -dict { PACKAGE_PIN A13   IOSTANDARD LVCMOS33 } [get_ports p2_btn_right]

## VGA Connector - Using Pmod JA (12-pin connector)
## NOTE: This assumes you have a Pmod VGA adapter or custom VGA Pmod
## Digilent VGA Pmod uses 12 pins for 4-bit RGB + H/V sync
##
## Standard Pmod VGA Pinout:
## Top Row:  JA1  JA2  JA3  JA4  (pins 1-4)
## Bottom:   JA7  JA8  JA9  JA10 (pins 7-10)
##
## Pmod JA Pin Mapping:
## JA1  (G17): Red[0]
## JA2  (G19): Red[1]  
## JA3  (N18): Red[2]
## JA4  (L18): Red[3]
## JA7  (H17): Green[0]
## JA8  (H19): Green[1]
## JA9  (J19): Green[2]
## JA10 (K18): Green[3]
##
## For Blue and Sync, we need additional Pmod or GPIO pins
## Using nearby GPIO pins for Blue[3:0], H-sync, V-sync

## VGA Red[3:0] - Pmod JA Top Row
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports {vga_red[0]}]
set_property -dict { PACKAGE_PIN G19   IOSTANDARD LVCMOS33 } [get_ports {vga_red[1]}]
set_property -dict { PACKAGE_PIN N18   IOSTANDARD LVCMOS33 } [get_ports {vga_red[2]}]
set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports {vga_red[3]}]

## VGA Green[3:0] - Pmod JA Bottom Row
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports {vga_green[0]}]
set_property -dict { PACKAGE_PIN H19   IOSTANDARD LVCMOS33 } [get_ports {vga_green[1]}]
set_property -dict { PACKAGE_PIN J19   IOSTANDARD LVCMOS33 } [get_ports {vga_green[2]}]
set_property -dict { PACKAGE_PIN K18   IOSTANDARD LVCMOS33 } [get_ports {vga_green[3]}]

## VGA Blue[3:0] - Using GPIO pins (connect to VGA Pmod if it has extended pins)
## Blue bit 0 (LSB)
set_property -dict { PACKAGE_PIN J2    IOSTANDARD LVCMOS33 } [get_ports {vga_blue[0]}]
## Blue bit 1
set_property -dict { PACKAGE_PIN J3    IOSTANDARD LVCMOS33 } [get_ports {vga_blue[1]}]
## Blue bit 2
set_property -dict { PACKAGE_PIN K1    IOSTANDARD LVCMOS33 } [get_ports {vga_blue[2]}]
## Blue bit 3 (MSB)
set_property -dict { PACKAGE_PIN L1    IOSTANDARD LVCMOS33 } [get_ports {vga_blue[3]}]

## VGA Sync Signals - Using GPIO pins
## H-Sync
set_property -dict { PACKAGE_PIN P17   IOSTANDARD LVCMOS33 } [get_ports vga_hsync]
## V-Sync
set_property -dict { PACKAGE_PIN M2    IOSTANDARD LVCMOS33 } [get_ports vga_vsync]

## Configuration options
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

#############################################################################
## IMPORTANT IMPLEMENTATION NOTES:
##
## 1. CLOCK FREQUENCY CHANGE:
##    The Cmod A7 has a 12 MHz clock, NOT 100 MHz.
##    You MUST modify the top module to handle this:
##    - Use snake_game_top_cmod_a7.vhd (includes Clock Wizard)
##    - Create Xilinx Clock Wizard IP: 12 MHz → 100 MHz + 25 MHz
##    - Component name must be: clk_wiz_0
##
## 2. VGA OUTPUT via PMOD:
##    Option A: Digilent VGA Pmod (410-097)
##       - Connect to Pmod JA connector
##       - Red[3:0] use JA top row (pins 1-4)
##       - Green[3:0] use JA bottom row (pins 7-10)
##       - Blue[3:0] and sync use GPIO pins (see pinout above)
##       - Pmod has built-in R-2R DAC, just plug and play!
##
##    Option B: Custom VGA Adapter
##       - Build R-2R resistor DAC on breadboard
##       - Connect Pmod JA pins to your DAC circuit
##       - See wiring diagram for resistor ladder details
##
##    Option C: 12-Pin Extended VGA Pmod
##       - If you have a 12-pin VGA Pmod that uses both rows
##       - May need to adjust Blue and Sync pin assignments
##
## 3. PMOD JA PINOUT (for reference):
##    Top Row:    JA1(G17)  JA2(G19)  JA3(N18)  JA4(L18)
##    Bottom Row: JA7(H17)  JA8(H19)  JA9(J19)  JA10(K18)
##    GND/VCC:    Shared across connector
##
## 4. BUTTON CONNECTIONS:
##    - All buttons use GPIO pins on the 48-pin DIP connector
##    - Connect buttons between assigned pin and GND (active low)
##    - Buttons can be connected directly or via breadboard
##    - Pins are at 0.1" spacing for breadboard use
##
## 5. POWER:
##    - Can power from USB or external 3.3-5.5V on pin 24 (VU)
##    - USB power is sufficient for FPGA + buttons + VGA
##    - Be careful with current draw if using many LEDs
##
## 6. TESTING STEPS:
##    a) Create Clock Wizard IP first (Tools → IP Catalog)
##    b) Add all VHDL files to project
##    c) Set snake_game_top_cmod_a7 as top module
##    d) Run synthesis and check for errors
##    e) Connect VGA Pmod to JA connector
##    f) Connect buttons to GPIO pins
##    g) Program and test!
##
## 7. IF VGA DOESN'T WORK:
##    - Verify Clock Wizard is generating 25 MHz (use ILA)
##    - Check that clk_locked signal goes high
##    - Use oscilloscope to verify H-sync and V-sync
##    - Monitor should detect signal even if image is wrong
##
#############################################################################

## Reference: Full Cmod A7 pin mapping at
## https://github.com/Digilent/digilent-xdc/blob/master/Cmod-A7-Master.xdc
##
## VGA Pmod Information:
## https://digilent.com/shop/pmod-vga-video-graphics-array/
