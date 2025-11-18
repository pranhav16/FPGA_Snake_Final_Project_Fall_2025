# Snake Game for Cmod A7-35T - Complete Package

## 📦 What's Included

This is a complete two-player snake game implementation for the Digilent Cmod A7-35T FPGA board with VGA Pmod support.

### Project Files

#### VHDL Source Files
- `snake_game_pkg.vhd` - Package with constants and types
- `button_debouncer.vhd` - Button input debouncing
- `vga_controller.vhd` - VGA timing generator (640x480 @ 60Hz)
- `game_controller.vhd` - Main game logic and collision detection
- `graphics_renderer.vhd` - Graphics rendering engine
- `snake_game_top_cmod_a7.vhd` - **Top module for Cmod A7** ⭐

#### Constraints Files
- `snake_game_cmod_a7.xdc` - **Pin constraints for Cmod A7** ⭐

#### Documentation
- `CMOD_A7_PMOD_VGA_SETUP.md` - **Quick setup guide** (START HERE!)
- `CMOD_A7_SETUP_GUIDE.md` - Detailed implementation guide
- `CMOD_A7_WIRING_DIAGRAM.md` - Breadboard wiring diagrams
- `README.md` - General project documentation
- `QUICK_START.md` - Quick start guide

## 🚀 Quick Start (3 Steps)

### 1️⃣ Hardware Setup
- Connect VGA Pmod to Pmod JA connector
- Wire 8 push buttons to GPIO pins (see pinout)
- Connect VGA monitor
- Connect USB cable

### 2️⃣ Create Clock Wizard IP
**Important:** Cmod A7 has 12 MHz clock, needs 100 MHz + 25 MHz
- Open Vivado → Tools → IP Catalog
- Find "Clocking Wizard"
- Input: 12 MHz → Outputs: 100 MHz + 25 MHz
- Name: `clk_wiz_0`
- Generate

### 3️⃣ Build & Program
- Add all `.vhd` files to Vivado project
- Add `snake_game_cmod_a7.xdc` 
- Set `snake_game_top_cmod_a7` as top module
- Synthesize → Implement → Generate Bitstream → Program

## 🎮 Game Controls

### Player 1 (Green Snake)
- **Up:** GPIO pio[01] button
- **Down:** GPIO pio[02] button
- **Left:** GPIO pio[03] button
- **Right:** GPIO pio[04] button

### Player 2 (Blue Snake)
- **Up:** GPIO pio[05] button
- **Down:** GPIO pio[06] button
- **Left:** GPIO pio[07] button
- **Right:** GPIO pio[08] button

### Reset
- On-board BTN0

## 📌 Key Differences from Basys 3

| Feature | Basys 3 | Cmod A7-35T |
|---------|---------|-------------|
| Clock | 100 MHz | 12 MHz (need Clock Wizard) |
| VGA Port | Built-in | Pmod JA + GPIO pins |
| Buttons | 5 on-board | 2 on-board (need 8 external) |
| Form Factor | Large dev board | Small DIP module |
| Top Module | snake_game_top.vhd | snake_game_top_cmod_a7.vhd |
| Constraints | snake_game.xdc | snake_game_cmod_a7.xdc |

## 🔌 VGA Connection Options

### Option A: VGA Pmod (Recommended)
- Use Digilent VGA Pmod (part 410-097)
- Plug directly into Pmod JA
- Has built-in R-2R DAC
- Some signals use GPIO pins (see XDC)

### Option B: Custom VGA Adapter
- Build R-2R resistor DAC on breadboard
- 24 resistors needed (12x 1kΩ, 12x 2kΩ)
- Connect to Pmod JA + GPIO pins
- See CMOD_A7_WIRING_DIAGRAM.md

## ⚠️ Important Notes

### Must Create Clock Wizard IP
The Clock Wizard IP is **required** and must be created before synthesis:
```
Input:  12 MHz (from Cmod A7 oscillator)
Output: 100 MHz (system clock)
Output: 25 MHz (VGA pixel clock)
Component Name: clk_wiz_0
```

### Use Correct Top Module
- ✅ Use: `snake_game_top_cmod_a7.vhd`
- ❌ Don't use: `snake_game_top.vhd` (requires 100 MHz input)

### Pin Assignments
All pin assignments in the XDC file are for:
- Pmod JA connector (VGA Red and Green)
- GPIO pins (VGA Blue, Sync, and buttons)
- Verify your connections match the XDC file

## 📊 Resource Usage

Typical utilization on Cmod A7-35T (Artix-7):
- **LUTs:** ~2,500 (12% of 20,800)
- **FFs:** ~1,800 (4% of 41,600)
- **Block RAM:** 0
- **DSPs:** 0
- **Clock Wizard:** 1 MMCM

## 🐛 Troubleshooting

### Synthesis Error: "clk_wiz_0 not found"
→ Create the Clock Wizard IP first (see Quick Start step 2)

### No Display on Monitor
→ Check VGA Pmod connection to Pmod JA
→ Verify Clock Wizard generated correctly
→ Check clk_locked signal is high

### Buttons Don't Respond
→ Verify button connections to correct GPIO pins
→ Check button polarity (active low)
→ Test with multimeter for continuity

### Wrong Colors or Flickering
→ Check VGA Pmod orientation
→ Verify all ground connections
→ Ensure stable 25 MHz pixel clock

## 📚 Documentation Guide

**Start here:**
1. Read `CMOD_A7_PMOD_VGA_SETUP.md` for quick setup

**For detailed info:**
2. `CMOD_A7_SETUP_GUIDE.md` - Step-by-step instructions
3. `CMOD_A7_WIRING_DIAGRAM.md` - Physical connections

**For general reference:**
4. `README.md` - Project overview
5. `QUICK_START.md` - Generic quick start

## 🎯 Project Features

- ✅ Two-player competitive gameplay
- ✅ 40x30 grid playing field
- ✅ Collision detection (self, opponent, head-to-head)
- ✅ Random food generation
- ✅ Snake growth mechanics
- ✅ Winner detection with visual feedback
- ✅ Wraparound screen edges
- ✅ 640x480 @ 60Hz VGA output
- ✅ Debounced button inputs
- ✅ Color-coded snakes and food

## 🛠️ Customization

### Change Game Speed
Edit `snake_game_pkg.vhd`:
```vhdl
constant GAME_SPEED : integer := 10000000;  -- Lower = faster
```

### Change Colors
Edit `graphics_renderer.vhd`:
```vhdl
-- Snake 1 color (Green)
red <= "0000";
green <= "1100";
blue <= "0000";
```

### Change Grid Size
Edit `snake_game_pkg.vhd`:
```vhdl
constant GRID_WIDTH : integer := 40;
constant GRID_HEIGHT : integer := 30;
```

## 📖 External Resources

- [Cmod A7 Product Page](https://digilent.com/shop/cmod-a7-35t-breadboardable-artix-7-fpga-module/)
- [Cmod A7 Reference Manual](https://digilent.com/reference/programmable-logic/cmod-a7/reference-manual)
- [VGA Pmod Documentation](https://digilent.com/reference/pmod/pmodvga/start)
- [Master XDC File](https://github.com/Digilent/digilent-xdc/blob/master/Cmod-A7-Master.xdc)

## 💡 Tips for Success

✅ Create Clock Wizard IP before synthesis
✅ Use snake_game_top_cmod_a7.vhd as top module
✅ Connect VGA Pmod to Pmod JA connector
✅ Test buttons individually before full game
✅ Keep wires short to minimize noise

## 🆘 Getting Help

If you encounter issues:
1. Check the troubleshooting section above
2. Verify all connections match the XDC file
3. Use ILA to debug internal signals
4. Check synthesis warnings and timing reports

## 📝 License

This project is open source and free for educational use.

---

**Ready to play?** Start with `CMOD_A7_PMOD_VGA_SETUP.md`! 🐍🎮
