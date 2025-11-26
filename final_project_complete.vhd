library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity final_project is
    port(
        clk:   in    std_logic;
        rst:   in    std_logic;
        
        --uart (unused)
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
        
        -- Player 2 controls
        p2_btn_up : in std_logic;
        p2_btn_down : in std_logic;
        p2_btn_left : in std_logic;
        p2_btn_right : in std_logic
    );
end final_project;

architecture arch of final_project is
    
    ------------------------------------------------------------------
    -- Component Declarations
    ------------------------------------------------------------------
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
            MAX_LENGTH  : integer := 100
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
            
            self_collision : out std_logic;
            wall_collision : out std_logic
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

    ------------------------------------------------------------------
    -- Clock signals
    ------------------------------------------------------------------
    signal clkfb:    std_logic;
    signal clk_100mhz : std_logic;
    signal clk_25mhz : std_logic;
    
    ------------------------------------------------------------------
    -- VGA signals
    ------------------------------------------------------------------
    signal hcount:   unsigned(9 downto 0);
    signal vcount:   unsigned(9 downto 0);
    signal blank:    std_logic;
    signal frame:    std_logic;
    
    signal obj1_red: std_logic_vector(1 downto 0);
    signal obj1_grn: std_logic_vector(1 downto 0);
    signal obj1_blu: std_logic_vector(1 downto 0);
    
    ------------------------------------------------------------------
    -- Game grid dimensions
    ------------------------------------------------------------------
    constant GRID_WIDTH : integer := 40;
    constant GRID_HEIGHT : integer := 30;
    constant CELL_SIZE : integer := 16;
    constant MAX_SNAKE_LENGTH : integer := 100;
    
    ------------------------------------------------------------------
    -- Game timing
    ------------------------------------------------------------------
    signal game_tick_counter : unsigned(23 downto 0) := (others => '0');
    constant GAME_TICK_MAX : unsigned(23 downto 0) := to_unsigned(2500000, 24); -- ~10 Hz at 25 MHz
    signal game_tick : std_logic := '0';

    ------------------------------------------------------------------
    -- Snake signals
    ------------------------------------------------------------------
    -- Player 1
    signal p1_snake_head_x : integer range 0 to GRID_WIDTH-1;
    signal p1_snake_head_y : integer range 0 to GRID_HEIGHT-1;
    signal p1_query_x : integer range 0 to GRID_WIDTH-1;
    signal p1_query_y : integer range 0 to GRID_HEIGHT-1;
    signal p1_is_body : std_logic;
    signal p1_snake_length : integer range 0 to MAX_SNAKE_LENGTH;
    signal p1_self_collision : std_logic;
    signal p1_wall_collision : std_logic;
    
    -- Player 2
    signal p2_snake_head_x : integer range 0 to GRID_WIDTH-1;
    signal p2_snake_head_y : integer range 0 to GRID_HEIGHT-1;
    signal p2_query_x : integer range 0 to GRID_WIDTH-1;
    signal p2_query_y : integer range 0 to GRID_HEIGHT-1;
    signal p2_is_body : std_logic;
    signal p2_snake_length : integer range 0 to MAX_SNAKE_LENGTH;
    signal p2_self_collision : std_logic;
    signal p2_wall_collision : std_logic;
    
    ------------------------------------------------------------------
    -- Food signals
    ------------------------------------------------------------------
    signal food_x : integer range 0 to GRID_WIDTH-1;
    signal food_y : integer range 0 to GRID_HEIGHT-1;
    signal p1_ate : std_logic;
    signal p2_ate : std_logic;
    
    ------------------------------------------------------------------
    -- Score tracking
    ------------------------------------------------------------------
    signal p1_score : unsigned(7 downto 0) := (others => '0');
    signal p2_score : unsigned(7 downto 0) := (others => '0');
    
    ------------------------------------------------------------------
    -- Grid position calculation
    ------------------------------------------------------------------
    signal grid_cell_x : integer range 0 to GRID_WIDTH-1;
    signal grid_cell_y : integer range 0 to GRID_HEIGHT-1;
    
    ------------------------------------------------------------------
    -- Object detection
    ------------------------------------------------------------------
    signal is_p1_snake : std_logic;
    signal is_p2_snake : std_logic;
    signal is_food_cell : std_logic;
    
    ------------------------------------------------------------------
    -- Collision between players
    ------------------------------------------------------------------
    signal p1_p2_collision : std_logic;
    signal p2_p1_collision : std_logic;

begin
    tx <= '1';  -- Keep UART TX high

    ------------------------------------------------------------------
    -- Clock management tile
    -- Input clock: 12 MHz
    -- Output clock: 25.2 MHz (VGA) and 100 MHz (unused)
    ------------------------------------------------------------------
    cmt: MMCME2_BASE generic map (
        BANDWIDTH=>"OPTIMIZED",
        CLKFBOUT_MULT_F=>50.875,
        CLKFBOUT_PHASE=>0.0,
        CLKIN1_PERIOD=>83.333,
        CLKOUT1_DIVIDE=>6,
        CLKOUT2_DIVIDE=>1,
        CLKOUT3_DIVIDE=>1,
        CLKOUT4_DIVIDE=>1,
        CLKOUT5_DIVIDE=>1,
        CLKOUT6_DIVIDE=>1,
        CLKOUT0_DIVIDE_F=>24.250,
        CLKOUT0_DUTY_CYCLE=>0.5,
        CLKOUT1_DUTY_CYCLE=>0.5,
        CLKOUT2_DUTY_CYCLE=>0.5,
        CLKOUT3_DUTY_CYCLE=>0.5,
        CLKOUT4_DUTY_CYCLE=>0.5,
        CLKOUT5_DUTY_CYCLE=>0.5,
        CLKOUT6_DUTY_CYCLE=>0.5,
        CLKOUT0_PHASE=>0.0,
        CLKOUT1_PHASE=>0.0,
        CLKOUT2_PHASE=>0.0,
        CLKOUT3_PHASE=>0.0,
        CLKOUT4_PHASE=>0.0,
        CLKOUT5_PHASE=>0.0,
        CLKOUT6_PHASE=>0.0,
        CLKOUT4_CASCADE=>FALSE,
        DIVCLK_DIVIDE=>1,
        REF_JITTER1=>0.0,
        STARTUP_WAIT=>FALSE
    ) port map (
        CLKOUT0=>clk_25mhz,
        CLKOUT0B=>open,
        CLKOUT1=>clk_100mhz,
        CLKOUT1B=>open,
        CLKOUT2=>open,
        CLKOUT2B=>open,
        CLKOUT3=>open,
        CLKOUT3B=>open,
        CLKOUT4=>open,
        CLKOUT5=>open,
        CLKOUT6=>open,
        CLKFBOUT=>clkfb,
        CLKFBOUTB=>open,
        LOCKED=>open,
        CLKIN1=>clk,
        PWRDWN=>'0',
        RST=>'0',
        CLKFBIN=>clkfb
    );

    ------------------------------------------------------------------
    -- VGA driver instantiation
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
    -- Game tick generator (controls game speed)
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
    -- Snake control modules
    ------------------------------------------------------------------
    snake_p1 : snake_control
        generic map (
            GRID_WIDTH  => GRID_WIDTH,
            GRID_HEIGHT => GRID_HEIGHT,
            MAX_LENGTH  => MAX_SNAKE_LENGTH
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
            snake_head_x_o => p1_snake_head_x,
            snake_head_y_o => p1_snake_head_y,
            query_x => p1_query_x,
            query_y => p1_query_y,
            is_body => p1_is_body,
            snake_length_o => p1_snake_length,
            self_collision => p1_self_collision,
            wall_collision => p1_wall_collision
        );
        
    snake_p2 : snake_control
        generic map (
            GRID_WIDTH  => GRID_WIDTH,
            GRID_HEIGHT => GRID_HEIGHT,
            MAX_LENGTH  => MAX_SNAKE_LENGTH
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
            snake_head_x_o => p2_snake_head_x,
            snake_head_y_o => p2_snake_head_y,
            query_x => p2_query_x,
            query_y => p2_query_y,
            is_body => p2_is_body,
            snake_length_o => p2_snake_length,
            self_collision => p2_self_collision,
            wall_collision => p2_wall_collision
        );
    
    ------------------------------------------------------------------
    -- Food control module
    ------------------------------------------------------------------
    food_ctrl : food_control
        generic map (
            GRID_WIDTH    => GRID_WIDTH,
            GRID_HEIGHT   => GRID_HEIGHT,
            VISIBLE_TICKS => 80,   -- 8 seconds visible
            HIDDEN_TICKS  => 30,   -- 3 seconds hidden
            SEED          => "1010101010"
        )
        port map (
            clk       => clk_25mhz,
            rst       => rst,
            game_tick => game_tick,
            p1_head_x => p1_snake_head_x,
            p1_head_y => p1_snake_head_y,
            p2_head_x => p2_snake_head_x,
            p2_head_y => p2_snake_head_y,
            food_x    => food_x,
            food_y    => food_y,
            p1_ate    => p1_ate,
            p2_ate    => p2_ate
        );
    
    ------------------------------------------------------------------
    -- Score tracking
    ------------------------------------------------------------------
    process(clk_25mhz)
    begin
        if rising_edge(clk_25mhz) then
            if rst = '1' then
                p1_score <= (others => '0');
                p2_score <= (others => '0');
            else
                if p1_ate = '1' then
                    p1_score <= p1_score + 1;
                end if;
                if p2_ate = '1' then
                    p2_score <= p2_score + 1;
                end if;
            end if;
        end if;
    end process;
    
    ------------------------------------------------------------------
    -- Grid position calculation
    ------------------------------------------------------------------
    grid_cell_x <= to_integer(hcount) / CELL_SIZE when to_integer(hcount) < 640 else 0;
    grid_cell_y <= to_integer(vcount) / CELL_SIZE when to_integer(vcount) < 480 else 0;
    
    ------------------------------------------------------------------
    -- Query snake bodies at current grid position
    ------------------------------------------------------------------
    p1_query_x <= grid_cell_x;
    p1_query_y <= grid_cell_y;
    p2_query_x <= grid_cell_x;
    p2_query_y <= grid_cell_y;
    
    ------------------------------------------------------------------
    -- Object detection
    ------------------------------------------------------------------
    is_p1_snake <= p1_is_body;
    is_p2_snake <= p2_is_body;
    is_food_cell <= '1' when (grid_cell_x = food_x and grid_cell_y = food_y) else '0';
    
    ------------------------------------------------------------------
    -- Inter-player collision detection
    -- (Check if one snake's head hits the other's body)
    ------------------------------------------------------------------
    process(clk_25mhz)
    begin
        if rising_edge(clk_25mhz) then
            if rst = '1' then
                p1_p2_collision <= '0';
                p2_p1_collision <= '0';
            elsif game_tick = '1' then
                -- Check if P1 head hits P2 body
                if (p1_snake_head_x = p2_query_x and p1_snake_head_y = p2_query_y and p2_is_body = '1') then
                    p1_p2_collision <= '1';
                else
                    p1_p2_collision <= '0';
                end if;
                
                -- Check if P2 head hits P1 body
                if (p2_snake_head_x = p1_query_x and p2_snake_head_y = p1_query_y and p1_is_body = '1') then
                    p2_p1_collision <= '1';
                else
                    p2_p1_collision <= '0';
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Snake game rendering
    -- Priority: P1 snake > P2 snake > Food > Background
    ------------------------------------------------------------------
    process(is_p1_snake, is_p2_snake, is_food_cell)
    begin
        if is_p1_snake = '1' then
            -- Green snake (Player 1)
            obj1_red <= b"00";
            obj1_grn <= b"11";
            obj1_blu <= b"00";
        elsif is_p2_snake = '1' then
            -- Orange/Yellow snake (Player 2)
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
    red   <= b"00" when blank='1' else obj1_red;
    green <= b"00" when blank='1' else obj1_grn;
    blue  <= b"00" when blank='1' else obj1_blu;

end arch;
