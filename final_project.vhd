library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity final_project is
    port(
        clk   : in  std_logic;
        rst   : in  std_logic;  -- mapped to BTN0 in XDC
        
        -- Board buttons (from XDC: btn[1] = BTN1)
        btn   : in  std_logic_vector(1 downto 0);
        -- btn(1) will be used for start/pause
        
        -- UART (unused in this design, kept for completeness)
        tx    : out std_logic;
        
        -- VGA outputs
        red   : out std_logic_vector(1 downto 0);
        green : out std_logic_vector(1 downto 0);
        blue  : out std_logic_vector(1 downto 0);
        hsync : out std_logic;
        vsync : out std_logic;
        
        -- Player 1 controls
        p1_btn_up    : in std_logic;
        p1_btn_down  : in std_logic;
        p1_btn_left  : in std_logic;
        p1_btn_right : in std_logic;
        -- Player 2 controls
        p2_btn_up    : in std_logic;
        p2_btn_down  : in std_logic;
        p2_btn_left  : in std_logic;
        p2_btn_right : in std_logic
    );
end final_project;

architecture arch of final_project is

    --------------------------------------------------------------------
    -- Component declarations
    --------------------------------------------------------------------
    component vga_driver is
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            hsync_o  : out std_logic;
            vsync_o  : out std_logic;
            frame_o  : out std_logic;
            blank_o  : out std_logic;
            hcount_o : out unsigned(9 downto 0);
            vcount_o : out unsigned(9 downto 0)
        );
    end component;

    component snake_control is
        port ( 
            clk  : in std_logic;
            rst  : in std_logic;
            game_tick : in std_logic;
            
            btn_up    : in std_logic;
            btn_down  : in std_logic;
            btn_left  : in std_logic;
            btn_right : in std_logic;
            
            snake_head_x_o : out integer := 20;
            snake_head_y_o : out integer := 15
        );
    end component;

    component food_control is
        generic (
            GRID_WIDTH    : integer := 40;
            GRID_HEIGHT   : integer := 30;
            VISIBLE_TICKS : integer := 80;
            HIDDEN_TICKS  : integer := 30;
            SEED          : std_logic_vector(9 downto 0) := "1010101010"
        );
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            game_tick : in  std_logic;

            p1_head_x : in  integer;
            p1_head_y : in  integer;
            p2_head_x : in  integer;
            p2_head_y : in  integer;

            food_x    : out integer;
            food_y    : out integer;

            food_valid : out std_logic;

            p1_ate    : out std_logic;
            p2_ate    : out std_logic
        );
    end component;

    component game_control is
        port (
            clk            : in  std_logic;
            rst            : in  std_logic;
            btn_start_pause: in  std_logic;
            tick_in        : in  std_logic;
            tick_out       : out std_logic
        );
    end component;

    --------------------------------------------------------------------
    -- Clocking / VGA timing
    --------------------------------------------------------------------
    signal clkfb      : std_logic;
    signal clk_25mhz  : std_logic;
    signal clk_100mhz : std_logic;

    signal hcount   : unsigned(9 downto 0);
    signal vcount   : unsigned(9 downto 0);
    signal blank    : std_logic;
    signal frame    : std_logic;

    -- Pixel color from game logic
    signal obj_red  : std_logic_vector(1 downto 0);
    signal obj_grn  : std_logic_vector(1 downto 0);
    signal obj_blu  : std_logic_vector(1 downto 0);

    --------------------------------------------------------------------
    -- Game grid configuration
    --------------------------------------------------------------------
    constant GRID_WIDTH  : integer := 40;
    constant GRID_HEIGHT : integer := 30;
    constant CELL_SIZE   : integer := 16;

    --------------------------------------------------------------------
    -- Game tick (controls snake / apple speed)
    --------------------------------------------------------------------
    signal game_tick_counter : unsigned(23 downto 0) := (others => '0');
    constant GAME_TICK_MAX   : unsigned(23 downto 0) := to_unsigned(2500000, 24); -- ~10 Hz
    signal game_tick         : std_logic := '0';  -- free-running
    signal game_step         : std_logic := '0';  -- gated by game_control

    --------------------------------------------------------------------
    -- Snake heads (from snake_control)
    --------------------------------------------------------------------
    signal p1_snake_head_x : integer range 0 to GRID_WIDTH-1 := 20;
    signal p1_snake_head_y : integer range 0 to GRID_HEIGHT-1 := 15;

    signal p2_snake_head_x : integer range 0 to GRID_WIDTH-1 := 20;
    signal p2_snake_head_y : integer range 0 to GRID_HEIGHT-1 := 15;

    --------------------------------------------------------------------
    -- Snake length bookkeeping
    --------------------------------------------------------------------
    constant INITIAL_LEN : integer := 4;
    constant MAX_LEN     : integer := 64;
    signal p1_len        : integer range 1 to MAX_LEN := INITIAL_LEN;
    signal p2_len        : integer range 1 to MAX_LEN := INITIAL_LEN;

    --------------------------------------------------------------------
    -- Multiple apples (3 instances)
    --------------------------------------------------------------------
    signal food_x0, food_x1, food_x2 : integer range 0 to GRID_WIDTH-1;
    signal food_y0, food_y1, food_y2 : integer range 0 to GRID_HEIGHT-1;

    signal food_valid0, food_valid1, food_valid2 : std_logic;

    signal p1_ate0, p1_ate1, p1_ate2 : std_logic;
    signal p2_ate0, p2_ate1, p2_ate2 : std_logic;

    --------------------------------------------------------------------
    -- Grid position and object flags
    --------------------------------------------------------------------
    signal grid_cell_x      : integer range 0 to GRID_WIDTH-1;
    signal grid_cell_y      : integer range 0 to GRID_HEIGHT-1;
    signal is_snake_head_p1 : std_logic;
    signal is_snake_head_p2 : std_logic;
    signal is_food_cell     : std_logic;

begin

    --------------------------------------------------------------------
    -- UART TX (unused, keep high)
    --------------------------------------------------------------------
    tx <= '1';

    --------------------------------------------------------------------
    -- MMCM: generate 25 MHz (VGA) and 100 MHz from input clk (12 MHz)
    --------------------------------------------------------------------
    cmt: MMCME2_BASE
        generic map (
            BANDWIDTH          => "OPTIMIZED",
            CLKFBOUT_MULT_F    => 50.875,
            CLKFBOUT_PHASE     => 0.0,
            CLKIN1_PERIOD      => 83.333,
            CLKOUT1_DIVIDE     => 6,
            CLKOUT2_DIVIDE     => 1,
            CLKOUT3_DIVIDE     => 1,
            CLKOUT4_DIVIDE     => 1,
            CLKOUT5_DIVIDE     => 1,
            CLKOUT6_DIVIDE     => 1,
            CLKOUT0_DIVIDE_F   => 24.250,
            CLKOUT0_DUTY_CYCLE => 0.5,
            CLKOUT1_DUTY_CYCLE => 0.5,
            CLKOUT2_DUTY_CYCLE => 0.5,
            CLKOUT3_DUTY_CYCLE => 0.5,
            CLKOUT4_DUTY_CYCLE => 0.5,
            CLKOUT5_DUTY_CYCLE => 0.5,
            CLKOUT6_DUTY_CYCLE => 0.5,
            CLKOUT0_PHASE      => 0.0,
            CLKOUT1_PHASE      => 0.0,
            CLKOUT2_PHASE      => 0.0,
            CLKOUT3_PHASE      => 0.0,
            CLKOUT4_PHASE      => 0.0,
            CLKOUT5_PHASE      => 0.0,
            CLKOUT6_PHASE      => 0.0,
            CLKOUT4_CASCADE    => FALSE,
            DIVCLK_DIVIDE      => 1,
            REF_JITTER1        => 0.0,
            STARTUP_WAIT       => FALSE
        )
        port map (
            CLKOUT0  => clk_25mhz,
            CLKOUT0B => open,
            CLKOUT1  => clk_100mhz,
            CLKOUT1B => open,
            CLKOUT2  => open,
            CLKOUT2B => open,
            CLKOUT3  => open,
            CLKOUT3B => open,
            CLKOUT4  => open,
            CLKOUT5  => open,
            CLKOUT6  => open,
            CLKFBOUT => clkfb,
            CLKFBOUTB=> open,
            LOCKED   => open,
            CLKIN1   => clk,
            PWRDWN   => '0',
            RST      => '0',
            CLKFBIN  => clkfb
        );

    --------------------------------------------------------------------
    -- VGA timing generator (unchanged)
    --------------------------------------------------------------------
    vga_ctrl : vga_driver
        port map (
            clk      => clk_25mhz,
            rst      => rst,
            hsync_o  => hsync,
            vsync_o  => vsync,
            frame_o  => frame,
            blank_o  => blank,
            hcount_o => hcount,
            vcount_o => vcount
        );

    --------------------------------------------------------------------
    -- Game tick generator (~10 Hz from 25 MHz)
    --------------------------------------------------------------------
    process(clk_25mhz)
    begin
        if rising_edge(clk_25mhz) then
            if rst = '1' then
                game_tick_counter <= (others => '0');
                game_tick         <= '0';
            else
                if game_tick_counter >= GAME_TICK_MAX then
                    game_tick_counter <= (others => '0');
                    game_tick         <= '1';
                else
                    game_tick_counter <= game_tick_counter + 1;
                    game_tick         <= '0';
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Game control: start/pause using btn(1)
    --------------------------------------------------------------------
    gc: game_control
        port map (
            clk            => clk_25mhz,
            rst            => rst,        -- BTN0 global reset
            btn_start_pause=> btn(1),     -- BTN1
            tick_in        => game_tick,
            tick_out       => game_step
        );

    --------------------------------------------------------------------
    -- Snake controllers (P1, P2) driven by game_step
    --------------------------------------------------------------------
    snake_p1 : snake_control
        port map (
            clk            => clk_25mhz,
            rst            => rst,
            game_tick      => game_step,
            btn_up         => p1_btn_up,
            btn_down       => p1_btn_down,
            btn_left       => p1_btn_left,
            btn_right      => p1_btn_right,
            snake_head_x_o => p1_snake_head_x,
            snake_head_y_o => p1_snake_head_y
        );

    snake_p2 : snake_control
        port map (
            clk            => clk_25mhz,
            rst            => rst,
            game_tick      => game_step,
            btn_up         => p2_btn_up,
            btn_down       => p2_btn_down,
            btn_left       => p2_btn_left,
            btn_right      => p2_btn_right,
            snake_head_x_o => p2_snake_head_x,
            snake_head_y_o => p2_snake_head_y
        );

    --------------------------------------------------------------------
    -- Three independent apples (food_control instances)
    --------------------------------------------------------------------
    apple0 : food_control
        generic map (
            GRID_WIDTH    => GRID_WIDTH,
            GRID_HEIGHT   => GRID_HEIGHT,
            VISIBLE_TICKS => 80,
            HIDDEN_TICKS  => 30,
            SEED          => "1010101010"
        )
        port map (
            clk        => clk_25mhz,
            rst        => rst,
            game_tick  => game_step,
            p1_head_x  => p1_snake_head_x,
            p1_head_y  => p1_snake_head_y,
            p2_head_x  => p2_snake_head_x,
            p2_head_y  => p2_snake_head_y,
            food_x     => food_x0,
            food_y     => food_y0,
            food_valid => food_valid0,
            p1_ate     => p1_ate0,
            p2_ate     => p2_ate0
        );

    apple1 : food_control
        generic map (
            GRID_WIDTH    => GRID_WIDTH,
            GRID_HEIGHT   => GRID_HEIGHT,
            VISIBLE_TICKS => 80,
            HIDDEN_TICKS  => 30,
            SEED          => "1100100101"
        )
        port map (
            clk        => clk_25mhz,
            rst        => rst,
            game_tick  => game_step,
            p1_head_x  => p1_snake_head_x,
            p1_head_y  => p1_snake_head_y,
            p2_head_x  => p2_snake_head_x,
            p2_head_y  => p2_snake_head_y,
            food_x     => food_x1,
            food_y     => food_y1,
            food_valid => food_valid1,
            p1_ate     => p1_ate1,
            p2_ate     => p2_ate1
        );

    apple2 : food_control
        generic map (
            GRID_WIDTH    => GRID_WIDTH,
            GRID_HEIGHT   => GRID_HEIGHT,
            VISIBLE_TICKS => 80,
            HIDDEN_TICKS  => 30,
            SEED          => "0110011010"
        )
        port map (
            clk        => clk_25mhz,
            rst        => rst,
            game_tick  => game_step,
            p1_head_x  => p1_snake_head_x,
            p1_head_y  => p1_snake_head_y,
            p2_head_x  => p2_snake_head_x,
            p2_head_y  => p2_snake_head_y,
            food_x     => food_x2,
            food_y     => food_y2,
            food_valid => food_valid2,
            p1_ate     => p1_ate2,
            p2_ate     => p2_ate2
        );

    --------------------------------------------------------------------
    -- Snake length update: grow by 1 when any *existing* apple is eaten
    --------------------------------------------------------------------
    process(clk_25mhz)
    begin
        if rising_edge(clk_25mhz) then
            if rst = '1' then
                p1_len <= INITIAL_LEN;
                p2_len <= INITIAL_LEN;
            elsif game_step = '1' then
                if (p1_ate0 = '1' or p1_ate1 = '1' or p1_ate2 = '1') and (p1_len < MAX_LEN) then
                    p1_len <= p1_len + 1;
                end if;
                if (p2_ate0 = '1' or p2_ate1 = '1' or p2_ate2 = '1') and (p2_len < MAX_LEN) then
                    p2_len <= p2_len + 1;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Map pixel (hcount, vcount) to grid cell coordinates
    --------------------------------------------------------------------
    grid_cell_x <= to_integer(hcount) / CELL_SIZE when hcount < 640 else 0;
    grid_cell_y <= to_integer(vcount) / CELL_SIZE when vcount < 480 else 0;

    --------------------------------------------------------------------
    -- Object detection
    --------------------------------------------------------------------
    is_snake_head_p1 <= '1' when 
        (grid_cell_x = p1_snake_head_x and grid_cell_y = p1_snake_head_y)
        else '0';

    is_snake_head_p2 <= '1' when 
        (grid_cell_x = p2_snake_head_x and grid_cell_y = p2_snake_head_y)
        else '0';

    -- Any existing apple occupying this cell
    is_food_cell <= '1' when
        (food_valid0 = '1' and grid_cell_x = food_x0 and grid_cell_y = food_y0) or
        (food_valid1 = '1' and grid_cell_x = food_x1 and grid_cell_y = food_y1) or
        (food_valid2 = '1' and grid_cell_x = food_x2 and grid_cell_y = food_y2)
    else
        '0';

    --------------------------------------------------------------------
    -- Rendering: snake heads + apples
    --------------------------------------------------------------------
    process(is_snake_head_p1, is_snake_head_p2, is_food_cell)
    begin
        if is_snake_head_p1 = '1' then
            -- Player 1 snake head: green
            obj_red <= "00";
            obj_grn <= "11";
            obj_blu <= "00";
        elsif is_snake_head_p2 = '1' then
            -- Player 2 snake head: yellow
            obj_red <= "11";
            obj_grn <= "11";
            obj_blu <= "00";
        elsif is_food_cell = '1' then
            -- Any existing apple: red
            obj_red <= "11";
            obj_grn <= "00";
            obj_blu <= "00";
        else
            -- Background: black
            obj_red <= "00";
            obj_grn <= "00";
            obj_blu <= "00";
        end if;
    end process;

    --------------------------------------------------------------------
    -- VGA output with blanking
    --------------------------------------------------------------------
    red   <= "00" when blank = '1' else obj_red;
    green <= "00" when blank = '1' else obj_grn;
    blue  <= "00" when blank = '1' else obj_blu;

end arch;
