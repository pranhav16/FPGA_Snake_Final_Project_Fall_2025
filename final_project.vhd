library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;
--use work.snake_game_pkg.all;


entity final_project is
	port(
		clk:   in    std_logic;
		rst:   in    std_logic;
		
		--idk 
		tx:    out   std_logic;
		
		--vga 
		red:   out   std_logic_vector(1 downto 0);
		green: out   std_logic_vector(1 downto 0);
		blue:  out   std_logic_vector(1 downto 0);
		hsync: out   std_logic;
		vsync: out   std_logic;
		
		-- Player 1 controls
        p1_btn_up : in std_logic;
        p1_btn_down : in std_logic;
        p1_btn_left : in std_logic;
        p1_btn_right : in std_logic;
--        -- Player 2 controls
        p2_btn_up : in std_logic;
        p2_btn_down : in std_logic;
        p2_btn_left : in std_logic;
        p2_btn_right : in std_logic
        
	);
end final_project;

architecture arch of final_project is
    
    component vga_driver is
        Port (
            clk : in std_logic;
            rst : in std_logic;
            hsync_o : out std_logic;       
            vsync_o : out std_logic;       
            frame_o : out std_logic;       
            blank_o : out std_logic;       
            hcount_o : out unsigned(9 downto 0);
            vcount_o : out unsigned(9 downto 0)
        );
    end component;
    
    component snake_control is
        Port ( 
        clk : in std_logic;
        rst : in std_logic;
        game_tick : in std_logic;
        
        btn_up : in std_logic;
        btn_down : in std_logic;
        btn_left : in std_logic;
        btn_right : in std_logic;
        
        snake_head_x_o : out integer := 20; --range 0 to GRID_WIDTH-1
        snake_head_y_o : out integer := 15 --range 0 to GRID_HEIGHT-1
    );
    end component;

	signal clkfb:    std_logic;
	signal clkfx:    std_logic;
	
	signal hcount:   unsigned(9 downto 0);
	signal vcount:   unsigned(9 downto 0);
	signal blank:    std_logic;
	signal frame:    std_logic;
	
	signal obj1_red: std_logic_vector(1 downto 0);
	signal obj1_grn: std_logic_vector(1 downto 0);
	signal obj1_blu: std_logic_vector(1 downto 0);
	
--	-- Ball parameters
--	constant BALL_SIZE: integer := 16; -- 16x16 pixel ball
--	signal ball_x: unsigned(9 downto 0) := to_unsigned(320, 10); -- Center X
--	signal ball_y: unsigned(9 downto 0) := to_unsigned(240, 10); -- Center Y
--	signal ball_dx: signed(1 downto 0) := to_signed(1, 2); -- +1 or -1
--	signal ball_dy: signed(1 downto 0) := to_signed(1, 2); -- +1 or -1
	
--	-- Ball boundaries
--	signal ball_x_left:   unsigned(9 downto 0);
--	signal ball_x_right:  unsigned(9 downto 0);
--	signal ball_y_top:    unsigned(9 downto 0);
--	signal ball_y_bot:    unsigned(9 downto 0);
	
	        -- Game grid dimensions
    constant GRID_WIDTH : integer := 40;
    constant GRID_HEIGHT : integer := 30;
    constant CELL_SIZE : integer := 16;
    
    --clock
    signal clk_100mhz : std_logic;
    signal clk_25mhz : std_logic;
    
    
    -- Game timing
    signal game_tick_counter : unsigned(23 downto 0) := (others => '0');
    constant GAME_TICK_MAX : unsigned(23 downto 0) := to_unsigned(2500000, 24); -- ~10 Hz at 25 MHz
    signal game_tick : std_logic := '0';

    -- snake head positions                                                   TODO: add body 
    signal p1_snake_head_x : integer range 0 to GRID_WIDTH-1 := 20;
    signal p1_snake_head_y : integer range 0 to GRID_HEIGHT-1 := 15;
    
    signal p2_snake_head_x : integer range 0 to GRID_WIDTH-1 := 20;
    signal p2_snake_head_y : integer range 0 to GRID_HEIGHT-1 := 15;
    
    -- Food position
    signal food_x : integer range 0 to GRID_WIDTH-1 := 10;
    signal food_y : integer range 0 to GRID_HEIGHT-1 := 10;
    
    -- Grid position calculation
    signal grid_cell_x : integer range 0 to GRID_WIDTH-1;
    signal grid_cell_y : integer range 0 to GRID_HEIGHT-1;
    signal is_snake_head_p1 : std_logic;
    signal is_snake_head_p2 : std_logic;
    signal is_food_cell : std_logic;

    
	
begin
	tx<='1';

	------------------------------------------------------------------
	-- Clock management tile
	--
	-- Input clock: 12 MHz
	-- Output clock: 25.2 MHz
	--
	-- CLKFBOUT_MULT_F: 50.875
	-- CLKOUT0_DIVIDE_F: 24.250
	-- DIVCLK_DIVIDE: 1
	------------------------------------------------------------------
	cmt: MMCME2_BASE generic map (
		-- Jitter programming (OPTIMIZED, HIGH, LOW)
		BANDWIDTH=>"OPTIMIZED",
		-- Multiply value for all CLKOUT (2.000-64.000).
		CLKFBOUT_MULT_F=>50.875,
		-- Phase offset in degrees of CLKFB (-360.000-360.000).
		CLKFBOUT_PHASE=>0.0,
		-- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
		CLKIN1_PERIOD=>83.333,
		-- Divide amount for each CLKOUT (1-128)
		CLKOUT1_DIVIDE=>6,
		CLKOUT2_DIVIDE=>1,
		CLKOUT3_DIVIDE=>1,
		CLKOUT4_DIVIDE=>1,
		CLKOUT5_DIVIDE=>1,
		CLKOUT6_DIVIDE=>1,
		-- Divide amount for CLKOUT0 (1.000-128.000):
		CLKOUT0_DIVIDE_F=>24.250,
		-- Duty cycle for each CLKOUT (0.01-0.99):
		CLKOUT0_DUTY_CYCLE=>0.5,
		CLKOUT1_DUTY_CYCLE=>0.5,
		CLKOUT2_DUTY_CYCLE=>0.5,
		CLKOUT3_DUTY_CYCLE=>0.5,
		CLKOUT4_DUTY_CYCLE=>0.5,
		CLKOUT5_DUTY_CYCLE=>0.5,
		CLKOUT6_DUTY_CYCLE=>0.5,
		-- Phase offset for each CLKOUT (-360.000-360.000):
		CLKOUT0_PHASE=>0.0,
		CLKOUT1_PHASE=>0.0,
		CLKOUT2_PHASE=>0.0,
		CLKOUT3_PHASE=>0.0,
		CLKOUT4_PHASE=>0.0,
		CLKOUT5_PHASE=>0.0,
		CLKOUT6_PHASE=>0.0,
		-- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
		CLKOUT4_CASCADE=>FALSE,
		-- Master division value (1-106)
		DIVCLK_DIVIDE=>1,
		-- Reference input jitter in UI (0.000-0.999).
		REF_JITTER1=>0.0,
		-- Delays DONE until MMCM is locked (FALSE, TRUE)
		STARTUP_WAIT=>FALSE
	) port map (
		-- User Configurable Clock Outputs:
		CLKOUT0=>clk_25mhz,  -- 1-bit output: CLKOUT0
		CLKOUT0B=>open,  -- 1-bit output: Inverted CLKOUT0
		CLKOUT1=>clk_100mhz,   -- 1-bit output: CLKOUT1
		CLKOUT1B=>open,  -- 1-bit output: Inverted CLKOUT1
		CLKOUT2=>open,   -- 1-bit output: CLKOUT2
		CLKOUT2B=>open,  -- 1-bit output: Inverted CLKOUT2
		CLKOUT3=>open,   -- 1-bit output: CLKOUT3
		CLKOUT3B=>open,  -- 1-bit output: Inverted CLKOUT3
		CLKOUT4=>open,   -- 1-bit output: CLKOUT4
		CLKOUT5=>open,   -- 1-bit output: CLKOUT5
		CLKOUT6=>open,   -- 1-bit output: CLKOUT6
		-- Clock Feedback Output Ports:
		CLKFBOUT=>clkfb,-- 1-bit output: Feedback clock
		CLKFBOUTB=>open, -- 1-bit output: Inverted CLKFBOUT
		-- MMCM Status Ports:
		LOCKED=>open,    -- 1-bit output: LOCK
		-- Clock Input:
		CLKIN1=>clk,   -- 1-bit input: Clock
		-- MMCM Control Ports:
		PWRDWN=>'0',     -- 1-bit input: Power-down
		RST=>'0',        -- 1-bit input: Reset
		-- Clock Feedback Input Port:
		CLKFBIN=>clkfb  -- 1-bit input: Feedback clock
	);


    vga_ctrl : vga_driver
        port map (
            clk => clk_25mhz,
            rst => rst,
            hsync_o => hsync,     
            vsync_o => vsync,      
            frame_o => frame,      
            blank_o => blank,      
            hcount_o => hcount,
            vcount_o => vcount
        );
	
    ------------------------------------------------------------------
    -- Game tick generator (controls game speed)
    ------------------------------------------------------------------
    process(clk_25mhz)
    begin
        if rising_edge(clk_25mhz) then
            if game_tick_counter >= GAME_TICK_MAX then
                game_tick_counter <= (others => '0');
                game_tick <= '1';
            else
                game_tick_counter <= game_tick_counter + 1;
                game_tick <= '0';
            end if;
        end if;
    end process;
    
    
    ------------------------------------------------------------------
    -- Snake control modules p1 and p2
    -----------------------------------------------------------------
    snake_p1 : snake_control
        port map (
            clk => clk_25mhz,
            rst => rst,
            
            game_tick => game_tick,   
              
            btn_up => p1_btn_up,      
            btn_down => p1_btn_down,      
            btn_left => p1_btn_left,      
            btn_right => p1_btn_right,
            
            snake_head_x_o => p1_snake_head_x,
            snake_head_y_o => p1_snake_head_y
        );
        
     snake_p2 : snake_control
        port map (
            clk => clk_25mhz,
            rst => rst,
            
            game_tick => game_tick,   
              
            btn_up => p2_btn_up,      
            btn_down => p2_btn_down,      
            btn_left => p2_btn_left,      
            btn_right => p2_btn_right,
            
            snake_head_x_o => p2_snake_head_x,
            snake_head_y_o => p2_snake_head_y
        );
            
    ------------------------------------------------------------------
    -- Grid position calculation
    ------------------------------------------------------------------
    grid_cell_x <= to_integer(hcount) / CELL_SIZE when hcount < 640 else 0;
    grid_cell_y <= to_integer(vcount) / CELL_SIZE when vcount < 480 else 0;
    
    ------------------------------------------------------------------
    -- Object detection
    ------------------------------------------------------------------
    is_snake_head_p1 <= '1' when (grid_cell_x = p1_snake_head_x and grid_cell_y = p1_snake_head_y) else '0';
    
    is_snake_head_p2 <= '1' when (grid_cell_x = p2_snake_head_x and grid_cell_y = p2_snake_head_y) else '0';
    
    is_food_cell <= '1' when (grid_cell_x = food_x and grid_cell_y = food_y) else '0';

    ------------------------------------------------------------------
    -- Snake game rendering
    ------------------------------------------------------------------
    process(hcount, vcount, is_snake_head_p1, is_snake_head_p2, is_food_cell)
    begin
        if is_snake_head_p1 = '1' then
            -- Green snake head
            obj1_red <= b"00";
            obj1_grn <= b"11";
            obj1_blu <= b"00";
        elsif is_snake_head_p2 = '1' then
            -- Orange snake head
            obj1_red <= b"11";
            obj1_grn <= b"11";
            obj1_blu <= b"00";
        elsif is_food_cell = '1' then
            -- Red food
            obj1_red <= b"11";
            obj1_grn <= b"00";
            obj1_blu <= b"00";
        else
            -- Black background
            obj1_red <= b"00";
            obj1_grn <= b"00";
            obj1_blu <= b"00";
        end if;
    end process;

	------------------------------------------------------------------
	-- VGA output with blanking
	------------------------------------------------------------------
	red<=b"00" when blank='1' else obj1_red;
	green<=b"00" when blank='1' else obj1_grn;
	blue<=b"00" when blank='1' else obj1_blu;

end arch;
