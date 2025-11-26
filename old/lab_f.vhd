--library IEEE;
--use IEEE.std_logic_1164.all;
--use IEEE.numeric_std.all;
--library UNISIM;
--use UNISIM.vcomponents.all;

--entity lab_f is
--	port(
--		clk:   in    std_logic;
--		tx:    out   std_logic;
--		red:   out   std_logic_vector(1 downto 0);
--		green: out   std_logic_vector(1 downto 0);
--		blue:  out   std_logic_vector(1 downto 0);
--		hsync: out   std_logic;
--		vsync: out   std_logic
--	);
--end lab_f;

--architecture arch of lab_f is
--	signal clkfb:    std_logic;
--	signal clkfx:    std_logic;
--	signal hcount:   unsigned(9 downto 0);
--	signal vcount:   unsigned(9 downto 0);
--	signal blank:    std_logic;
--	signal frame:    std_logic;
--	signal obj1_red: std_logic_vector(1 downto 0);
--	signal obj1_grn: std_logic_vector(1 downto 0);
--	signal obj1_blu: std_logic_vector(1 downto 0);
--begin
--	tx<='1';

--	------------------------------------------------------------------
--	-- Clock management tile
--	--
--	-- Input clock: 12 MHz
--	-- Output clock: 25.2 MHz
--	--
--	-- CLKFBOUT_MULT_F: 50.875
--	-- CLKOUT0_DIVIDE_F: 24.250
--	-- DIVCLK_DIVIDE: 1
--	------------------------------------------------------------------
--	cmt: MMCME2_BASE generic map (
--		-- Jitter programming (OPTIMIZED, HIGH, LOW)
--		BANDWIDTH=>"OPTIMIZED",
--		-- Multiply value for all CLKOUT (2.000-64.000).
--		CLKFBOUT_MULT_F=>50.875,
--		-- Phase offset in degrees of CLKFB (-360.000-360.000).
--		CLKFBOUT_PHASE=>0.0,
--		-- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
--		CLKIN1_PERIOD=>83.333,
--		-- Divide amount for each CLKOUT (1-128)
--		CLKOUT1_DIVIDE=>1,
--		CLKOUT2_DIVIDE=>1,
--		CLKOUT3_DIVIDE=>1,
--		CLKOUT4_DIVIDE=>1,
--		CLKOUT5_DIVIDE=>1,
--		CLKOUT6_DIVIDE=>1,
--		-- Divide amount for CLKOUT0 (1.000-128.000):
--		CLKOUT0_DIVIDE_F=>24.250,
--		-- Duty cycle for each CLKOUT (0.01-0.99):
--		CLKOUT0_DUTY_CYCLE=>0.5,
--		CLKOUT1_DUTY_CYCLE=>0.5,
--		CLKOUT2_DUTY_CYCLE=>0.5,
--		CLKOUT3_DUTY_CYCLE=>0.5,
--		CLKOUT4_DUTY_CYCLE=>0.5,
--		CLKOUT5_DUTY_CYCLE=>0.5,
--		CLKOUT6_DUTY_CYCLE=>0.5,
--		-- Phase offset for each CLKOUT (-360.000-360.000):
--		CLKOUT0_PHASE=>0.0,
--		CLKOUT1_PHASE=>0.0,
--		CLKOUT2_PHASE=>0.0,
--		CLKOUT3_PHASE=>0.0,
--		CLKOUT4_PHASE=>0.0,
--		CLKOUT5_PHASE=>0.0,
--		CLKOUT6_PHASE=>0.0,
--		-- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
--		CLKOUT4_CASCADE=>FALSE,
--		-- Master division value (1-106)
--		DIVCLK_DIVIDE=>1,
--		-- Reference input jitter in UI (0.000-0.999).
--		REF_JITTER1=>0.0,
--		-- Delays DONE until MMCM is locked (FALSE, TRUE)
--		STARTUP_WAIT=>FALSE
--	) port map (
--		-- User Configurable Clock Outputs:
--		CLKOUT0=>clkfx,  -- 1-bit output: CLKOUT0
--		CLKOUT0B=>open,  -- 1-bit output: Inverted CLKOUT0
--		CLKOUT1=>open,   -- 1-bit output: CLKOUT1
--		CLKOUT1B=>open,  -- 1-bit output: Inverted CLKOUT1
--		CLKOUT2=>open,   -- 1-bit output: CLKOUT2
--		CLKOUT2B=>open,  -- 1-bit output: Inverted CLKOUT2
--		CLKOUT3=>open,   -- 1-bit output: CLKOUT3
--		CLKOUT3B=>open,  -- 1-bit output: Inverted CLKOUT3
--		CLKOUT4=>open,   -- 1-bit output: CLKOUT4
--		CLKOUT5=>open,   -- 1-bit output: CLKOUT5
--		CLKOUT6=>open,   -- 1-bit output: CLKOUT6
--		-- Clock Feedback Output Ports:
--		CLKFBOUT=>clkfb,-- 1-bit output: Feedback clock
--		CLKFBOUTB=>open, -- 1-bit output: Inverted CLKFBOUT
--		-- MMCM Status Ports:
--		LOCKED=>open,    -- 1-bit output: LOCK
--		-- Clock Input:
--		CLKIN1=>clk,   -- 1-bit input: Clock
--		-- MMCM Control Ports:
--		PWRDWN=>'0',     -- 1-bit input: Power-down
--		RST=>'0',        -- 1-bit input: Reset
--		-- Clock Feedback Input Port:
--		CLKFBIN=>clkfb  -- 1-bit input: Feedback clock
--	);

--	------------------------------------------------------------------
--	-- VGA display counters
--	--
--	-- Pixel clock: 25.175 MHz (actual: 25.2 MHz)
--	-- Horizontal count (active low sync):
--	--     0 to 639: Active video
--	--     640 to 799: Horizontal blank
--	--     656 to 751: Horizontal sync (active low)
--	-- Vertical count (active low sync):
--	--     0 to 479: Active video
--	--     480 to 524: Vertical blank
--	--     490 to 491: Vertical sync (active low)
--	------------------------------------------------------------------
--	process(clkfx)
--	begin
--		if rising_edge(clkfx) then
--			-- Pixel position counters
--			if (hcount>=to_unsigned(799,10)) then
--				hcount<=(others=>'0');
--				if (vcount>=to_unsigned(524,10)) then
--					vcount<=(others=>'0');
--				else
--					vcount<=vcount+1;
--				end if;
--			else
--				hcount<=hcount+1;
--			end if;
--			-- Sync, blank and frame
--			if (hcount>=to_unsigned(656,10)) and
--				(hcount<=to_unsigned(751,10)) then
--				hsync<='0';
--			else
--				hsync<='1';
--			end if;
--			if (vcount>=to_unsigned(490,10)) and
--				(vcount<=to_unsigned(491,10)) then
--				vsync<='0';
--			else
--				vsync<='1';
--			end if;
--			if (hcount>=to_unsigned(640,10)) or
--				(vcount>=to_unsigned(480,10)) then
--				blank<='1';
--			else
--				blank<='0';
--			end if;
--			if (hcount=to_unsigned(640,10)) and
--				(vcount=to_unsigned(479,10)) then
--				frame<='1';
--			else
--				frame<='0';
--			end if;
--		end if;
--	end process;

--	------------------------------------------------------------------
--	-- VGA output with blanking
--	------------------------------------------------------------------
--	red<=b"00" when blank='1' else obj1_red;
--	green<=b"00" when blank='1' else obj1_grn;
--	blue<=b"00" when blank='1' else obj1_blu;

--end arch;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity lab_f is
	port(
		clk:   in    std_logic;
		tx:    out   std_logic;
		red:   out   std_logic_vector(1 downto 0);
		green: out   std_logic_vector(1 downto 0);
		blue:  out   std_logic_vector(1 downto 0);
		hsync: out   std_logic;
		vsync: out   std_logic
	);
end lab_f;

architecture arch of lab_f is
	signal clkfb:    std_logic;
	signal clkfx:    std_logic;
	signal hcount:   unsigned(9 downto 0);
	signal vcount:   unsigned(9 downto 0);
	signal blank:    std_logic;
	signal frame:    std_logic;
	signal obj1_red: std_logic_vector(1 downto 0);
	signal obj1_grn: std_logic_vector(1 downto 0);
	signal obj1_blu: std_logic_vector(1 downto 0);
	
	-- Ball parameters
	constant BALL_SIZE: integer := 16; -- 16x16 pixel ball
	signal ball_x: unsigned(9 downto 0) := to_unsigned(320, 10); -- Center X
	signal ball_y: unsigned(9 downto 0) := to_unsigned(240, 10); -- Center Y
	signal ball_dx: signed(1 downto 0) := to_signed(1, 2); -- +1 or -1
	signal ball_dy: signed(1 downto 0) := to_signed(1, 2); -- +1 or -1
	
	-- Ball boundaries
	signal ball_x_left:   unsigned(9 downto 0);
	signal ball_x_right:  unsigned(9 downto 0);
	signal ball_y_top:    unsigned(9 downto 0);
	signal ball_y_bot:    unsigned(9 downto 0);
	
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
		CLKOUT1_DIVIDE=>1,
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
		CLKOUT0=>clkfx,  -- 1-bit output: CLKOUT0
		CLKOUT0B=>open,  -- 1-bit output: Inverted CLKOUT0
		CLKOUT1=>open,   -- 1-bit output: CLKOUT1
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

	------------------------------------------------------------------
	-- VGA display counters
	--
	-- Pixel clock: 25.175 MHz (actual: 25.2 MHz)
	-- Horizontal count (active low sync):
	--     0 to 639: Active video
	--     640 to 799: Horizontal blank
	--     656 to 751: Horizontal sync (active low)
	-- Vertical count (active low sync):
	--     0 to 479: Active video
	--     480 to 524: Vertical blank
	--     490 to 491: Vertical sync (active low)
	------------------------------------------------------------------
	process(clkfx)
	begin
		if rising_edge(clkfx) then
			-- Pixel position counters
			if (hcount>=to_unsigned(799,10)) then
				hcount<=(others=>'0');
				if (vcount>=to_unsigned(524,10)) then
					vcount<=(others=>'0');
				else
					vcount<=vcount+1;
				end if;
			else
				hcount<=hcount+1;
			end if;
			-- Sync, blank and frame
			if (hcount>=to_unsigned(656,10)) and
				(hcount<=to_unsigned(751,10)) then
				hsync<='0';
			else
				hsync<='1';
			end if;
			if (vcount>=to_unsigned(490,10)) and
				(vcount<=to_unsigned(491,10)) then
				vsync<='0';
			else
				vsync<='1';
			end if;
			if (hcount>=to_unsigned(640,10)) or
				(vcount>=to_unsigned(480,10)) then
				blank<='1';
			else
				blank<='0';
			end if;
			if (hcount=to_unsigned(640,10)) and
				(vcount=to_unsigned(479,10)) then
				frame<='1';
			else
				frame<='0';
			end if;
		end if;
	end process;

	------------------------------------------------------------------
	-- Ball position update (movement and collision detection)
	------------------------------------------------------------------
	process(clkfx)
	begin
		if rising_edge(clkfx) then
			if frame='1' then
				-- Update ball position
				ball_x <= unsigned(signed(ball_x) + ball_dx);
				ball_y <= unsigned(signed(ball_y) + ball_dy);
				
				-- Check horizontal collisions
				if ball_x_right >= to_unsigned(638, 10) then --639
					ball_dx <= to_signed(-1, 2); -- Bounce left
				elsif ball_x_left <= to_unsigned(1, 10) then --0
					ball_dx <= to_signed(1, 2); -- Bounce right
				end if;
				
				-- Check vertical collisions
				if ball_y_bot >= to_unsigned(478, 10) then --479
					ball_dy <= to_signed(-1, 2); -- Bounce up
				elsif ball_y_top <= to_unsigned(1, 10) then --0
					ball_dy <= to_signed(1, 2); -- Bounce down
				end if;
			end if;
		end if;
	end process;

--	process(clkfx)
--		variable next_x: unsigned(9 downto 0);
--		variable next_y: unsigned(9 downto 0);
--		variable next_x_left: unsigned(9 downto 0);
--		variable next_x_right: unsigned(9 downto 0);
--		variable next_y_top: unsigned(9 downto 0);
--		variable next_y_bot: unsigned(9 downto 0);
--		variable new_dx: signed(1 downto 0);
--		variable new_dy: signed(1 downto 0);
--	begin
--		if rising_edge(clkfx) then
--			if frame='1' then
--				-- Calculate next position
--				next_x := unsigned(signed(ball_x) + ball_dx);
--				next_y := unsigned(signed(ball_y) + ball_dy);
				
--				-- Calculate next boundaries
--				next_x_left  := next_x - to_unsigned(BALL_SIZE/2, 10);
--				next_x_right := next_x + to_unsigned(BALL_SIZE/2 - 1, 10);
--				next_y_top   := next_y - to_unsigned(BALL_SIZE/2, 10);
--				next_y_bot   := next_y + to_unsigned(BALL_SIZE/2 - 1, 10);
				
--				-- Start with current direction
--				new_dx := ball_dx;
--				new_dy := ball_dy;
				
--				-- Check horizontal collisions and reverse if needed
--				if next_x_right >= to_unsigned(639, 10) then
--					new_dx := to_signed(-1, 2); -- Bounce left
--					next_x := to_unsigned(639 - BALL_SIZE/2 + 1, 10);
--				elsif next_x_left <= to_unsigned(0, 10) then
--					new_dx := to_signed(1, 2); -- Bounce right
--					next_x := to_unsigned(BALL_SIZE/2, 10);
--				end if;
				
--				-- Check vertical collisions and reverse if needed
--				if next_y_bot >= to_unsigned(479, 10) then
--					new_dy := to_signed(-1, 2); -- Bounce up
--					next_y := to_unsigned(479 - BALL_SIZE/2 + 1, 10);
--				elsif next_y_top <= to_unsigned(0, 10) then
--					new_dy := to_signed(1, 2); -- Bounce down
--					next_y := to_unsigned(BALL_SIZE/2, 10);
--				end if;
				
--				-- Update position and direction
--				ball_x <= next_x;
--				ball_y <= next_y;
--				ball_dx <= new_dx;
--				ball_dy <= new_dy;
--			end if;
--		end if;
--	end process;
	
	------------------------------------------------------------------
	-- Ball boundary calculation
	------------------------------------------------------------------
	ball_x_left  <= ball_x - to_unsigned(BALL_SIZE/2, 10);
	ball_x_right <= ball_x + to_unsigned(BALL_SIZE/2 - 1, 10);
	ball_y_top   <= ball_y - to_unsigned(BALL_SIZE/2, 10);
	ball_y_bot   <= ball_y + to_unsigned(BALL_SIZE/2 - 1, 10);
	
	------------------------------------------------------------------
	-- Ball drawing logic
	------------------------------------------------------------------
	process(hcount, vcount, ball_x_left, ball_x_right, ball_y_top, ball_y_bot)
	begin
		-- Check if current pixel is within ball boundaries
		if (hcount >= ball_x_left) and (hcount <= ball_x_right) and
		   (vcount >= ball_y_top) and (vcount <= ball_y_bot) then
			obj1_red <= b"11"; -- White ball
			obj1_grn <= b"11";
			obj1_blu <= b"11";
		else
			obj1_red <= b"00"; -- Black background
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
