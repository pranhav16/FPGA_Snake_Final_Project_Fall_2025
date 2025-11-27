library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity final_project is
    port(
        clk:   in    std_logic;
        rst:   in    std_logic;
        tx:    out   std_logic;
        
        -- VGA outputs
        red:   out   std_logic_vector(1 downto 0);
        green: out   std_logic_vector(1 downto 0);
        blue:  out   std_logic_vector(1 downto 0);
        hsync: out   std_logic;
        vsync: out   std_logic;
        
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
        generic (
            GRID_WIDTH  : integer := 40;
            GRID_HEIGHT : integer := 30;
            MAX_LENGTH  : integer := 16
        );
        Port ( 
            clk : in std_logic;
            rst : in std_logic;
            game_tick : in std_logic;
            btn_up : in std_logic;
            btn_down : in std_logic;
            btn_left : in std_logic;
            btn_right : in std_logic;
            grow : in std_logic;
            snake_head_x_o : out integer range 0 to GRID_WIDTH-1;
            snake_head_y_o : out integer range 0 to GRID_HEIGHT-1;
            query_x : in integer range 0 to GRID_WIDTH-1;
            query_y : in integer range 0 to GRID_HEIGHT-1;
            is_body : out std_logic;
            snake_length_o : out integer range 0 to MAX_LENGTH;
            self_collision : out std_logic
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
            p1_head_x : in  integer range 0 to GRID_WIDTH-1;
            p1_head_y : in  integer range 0 to GRID_WIDTH-1;
            p2_head_x : in  integer range 0 to GRID_WIDTH-1;
            p2_head_y : in  integer range 0 to GRID_WIDTH-1;
            food_x    : out integer range 0 to GRID_WIDTH-1;
            food_y    : out integer range 0 to GRID_HEIGHT-1;
            p1_ate    : out std_logic;
            p2_ate    : out std_logic
        );
    end component;

    -- Clocks
    signal clkfb      : std_logic;
    signal clk_25mhz  : std_logic;
    
    -- VGA signals
    signal hcount : unsigned(9 downto 0);
    signal vcount : unsigned(9 downto 0);
    signal blank  : std_logic;
    signal frame  : std_logic;
    
    -- Grid constants
    constant GRID_WIDTH  : integer := 40;
    constant GRID_HEIGHT : integer := 30;
    constant CELL_SIZE   : integer := 16;
    constant MAX_LENGTH  : integer := 16;
    
    -- Game timing
    signal game_tick_counter : unsigned(23 downto 0) := (others => '0');
    constant GAME_TICK_MAX : unsigned(23 downto 0) := to_unsigned(2500000, 24);
    signal game_tick : std_logic := '0';

    -- Player 1 signals
    signal p1_head_x  : integer range 0 to GRID_WIDTH-1;
    signal p1_head_y  : integer range 0 to GRID_HEIGHT-1;
    signal p1_query_x : integer range 0 to GRID_WIDTH-1;
    signal p1_query_y : integer range 0 to GRID_HEIGHT-1;
    signal p1_is_body : std_logic;
    signal p1_length  : integer range 0 to MAX_LENGTH;
    signal p1_collision : std_logic;
    
    -- Player 2 signals
    signal p2_head_x  : integer range 0 to GRID_WIDTH-1;
    signal p2_head_y  : integer range 0 to GRID_HEIGHT-1;
    signal p2_query_x : integer range 0 to GRID_WIDTH-1;
    signal p2_query_y : integer range 0 to GRID_HEIGHT-1;
    signal p2_is_body : std_logic;
    signal p2_length  : integer range 0 to MAX_LENGTH;
    signal p2_collision : std_logic;
    
    -- Food signals
    signal food_x : integer range 0 to GRID_WIDTH-1;
    signal food_y : integer range 0 to GRID_HEIGHT-1;
    signal p1_ate : std_logic;
    signal p2_ate : std_logic;
    
    -- Grid calculation
    signal grid_x : integer range 0 to GRID_WIDTH-1;
    signal grid_y : integer range 0 to GRID_HEIGHT-1;
    
    -- Rendering signals (registered for better timing)
    signal pixel_p1   : std_logic := '0';
    signal pixel_p2   : std_logic := '0';
    signal pixel_food : std_logic := '0';
    
    -- Color output registers
    signal color_r : std_logic_vector(1 downto 0) := "00";
    signal color_g : std_logic_vector(1 downto 0) := "00";
    signal color_b : std_logic_vector(1 downto 0) := "00";

begin
    tx <= '1';

    ------------------------------------------------------------------
    -- Clock generation
    ------------------------------------------------------------------
    cmt: MMCME2_BASE 
    generic map (
        BANDWIDTH => "OPTIMIZED",
        CLKFBOUT_MULT_F => 50.875,
        CLKIN1_PERIOD => 83.333,
        CLKOUT0_DIVIDE_F => 24.250,
        DIVCLK_DIVIDE => 1
    ) 
    port map (
        CLKOUT0 => clk_25mhz,
        CLKFBOUT => clkfb,
        CLKIN1 => clk,
        PWRDWN => '0',
        RST => '0',
        CLKFBIN => clkfb,
        CLKOUT0B => open,
        CLKOUT1 => open,
        CLKOUT1B => open,
        CLKOUT2 => open,
        CLKOUT2B => open,
        CLKOUT3 => open,
        CLKOUT3B => open,
        CLKOUT4 => open,
        CLKOUT5 => open,
        CLKOUT6 => open,
        CLKFBOUTB => open,
        LOCKED => open
    );

    ------------------------------------------------------------------
    -- VGA driver
    ------------------------------------------------------------------
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
    -- Game tick generator
    ------------------------------------------------------------------
    process(clk_25mhz)
    begin
        if rising_edge(clk_25mhz) then
            if rst = '1' then
                game_tick_counter <= (others => '0');
                game_tick <= '0';
            else
                if game_tick_counter >= GAME_TICK_MAX then
                    game_tick_counter <= (others => '0');
                    game_tick <= '1';
                else
                    game_tick_counter <= game_tick_counter + 1;
                    game_tick <= '0';
                end if;
            end if;
        end if;
    end process;
    
    ------------------------------------------------------------------
    -- Snake instances
    ------------------------------------------------------------------
    snake_p1 : snake_control
    generic map (
        GRID_WIDTH  => GRID_WIDTH,
        GRID_HEIGHT => GRID_HEIGHT,
        MAX_LENGTH  => MAX_LENGTH
    )
    port map (
        clk => clk_25mhz,
        rst => rst,
        game_tick => game_tick,
        btn_up => p1_btn_up,
        btn_down => p1_btn_down,
        btn_left => p1_btn_left,
        btn_right => p1_btn_right,
        grow => p1_ate,
        snake_head_x_o => p1_head_x,
        snake_head_y_o => p1_head_y,
        query_x => p1_query_x,
        query_y => p1_query_y,
        is_body => p1_is_body,
        snake_length_o => p1_length,
        self_collision => p1_collision
    );
        
    snake_p2 : snake_control
    generic map (
        GRID_WIDTH  => GRID_WIDTH,
        GRID_HEIGHT => GRID_HEIGHT,
        MAX_LENGTH  => MAX_LENGTH
    )
    port map (
        clk => clk_25mhz,
        rst => rst,
        game_tick => game_tick,
        btn_up => p2_btn_up,
        btn_down => p2_btn_down,
        btn_left => p2_btn_left,
        btn_right => p2_btn_right,
        grow => p2_ate,
        snake_head_x_o => p2_head_x,
        snake_head_y_o => p2_head_y,
        query_x => p2_query_x,
        query_y => p2_query_y,
        is_body => p2_is_body,
        snake_length_o => p2_length,
        self_collision => p2_collision
    );
    
    ------------------------------------------------------------------
    -- Food controller
    ------------------------------------------------------------------
    food_ctrl : food_control
    generic map (
        GRID_WIDTH    => GRID_WIDTH,
        GRID_HEIGHT   => GRID_HEIGHT,
        VISIBLE_TICKS => 80,
        HIDDEN_TICKS  => 30,
        SEED          => "1010101010"
    )
    port map (
        clk       => clk_25mhz,
        rst       => rst,
        game_tick => game_tick,
        p1_head_x => p1_head_x,
        p1_head_y => p1_head_y,
        p2_head_x => p2_head_x,
        p2_head_y => p2_head_y,
        food_x    => food_x,
        food_y    => food_y,
        p1_ate    => p1_ate,
        p2_ate    => p2_ate
    );
    
    ------------------------------------------------------------------
    -- Grid calculation (pipelined)
    ------------------------------------------------------------------
    process(clk_25mhz)
        variable hcount_int : integer;
        variable vcount_int : integer;
    begin
        if rising_edge(clk_25mhz) then
            hcount_int := to_integer(hcount);
            vcount_int := to_integer(vcount);
            
            if hcount_int < 640 then
                grid_x <= hcount_int / CELL_SIZE;
            else
                grid_x <= 0;
            end if;
            
            if vcount_int < 480 then
                grid_y <= vcount_int / CELL_SIZE;
            else
                grid_y <= 0;
            end if;
        end if;
    end process;
    
    -- Connect queries
    p1_query_x <= grid_x;
    p1_query_y <= grid_y;
    p2_query_x <= grid_x;
    p2_query_y <= grid_y;
    
    ------------------------------------------------------------------
    -- Object detection (pipelined)
    ------------------------------------------------------------------
    process(clk_25mhz)
    begin
        if rising_edge(clk_25mhz) then
            pixel_p1 <= p1_is_body;
            pixel_p2 <= p2_is_body;
            
            if (grid_x = food_x and grid_y = food_y) then
                pixel_food <= '1';
            else
                pixel_food <= '0';
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Color generation (pipelined)
    ------------------------------------------------------------------
    process(clk_25mhz)
    begin
        if rising_edge(clk_25mhz) then
            if pixel_p1 = '1' then
                -- Green (P1)
                color_r <= "00";
                color_g <= "11";
                color_b <= "00";
            elsif pixel_p2 = '1' then
                -- Yellow (P2)
                color_r <= "11";
                color_g <= "11";
                color_b <= "00";
            elsif pixel_food = '1' then
                -- Red (food)
                color_r <= "11";
                color_g <= "00";
                color_b <= "00";
            else
                -- Black
                color_r <= "00";
                color_g <= "00";
                color_b <= "00";
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- VGA output
    ------------------------------------------------------------------
    red   <= "00" when blank = '1' else color_r;
    green <= "00" when blank = '1' else color_g;
    blue  <= "00" when blank = '1' else color_b;

end arch;