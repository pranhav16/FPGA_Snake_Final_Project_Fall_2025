library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.snake_game_pkg.all;

entity snake_game_top_cmod_a7 is
    Port (
        clk : in std_logic;          -- 12 MHz system clock (Cmod A7)
        rst : in std_logic;          -- Reset button
        -- Player 1 controls
        p1_btn_up : in std_logic;
        p1_btn_down : in std_logic;
        p1_btn_left : in std_logic;
        p1_btn_right : in std_logic;
        -- Player 2 controls
        p2_btn_up : in std_logic;
        p2_btn_down : in std_logic;
        p2_btn_left : in std_logic;
        p2_btn_right : in std_logic;
        -- VGA outputs
        vga_hsync : out std_logic;
        vga_vsync : out std_logic;
        vga_red : out std_logic_vector(3 downto 0);
        vga_green : out std_logic_vector(3 downto 0);
        vga_blue : out std_logic_vector(3 downto 0)
    );
end snake_game_top_cmod_a7;

architecture Behavioral of snake_game_top_cmod_a7 is
    -- Component declarations
    component clk_wiz_0
        port (
            clk_out1 : out std_logic;  -- 100 MHz
            clk_out2 : out std_logic;  -- 25 MHz for VGA
            reset : in std_logic;
            locked : out std_logic;
            clk_in1 : in std_logic     -- 12 MHz input
        );
    end component;
    
    component button_debouncer is
        Generic (
            DEBOUNCE_TIME : integer := 1000000
        );
        Port (
            clk : in std_logic;
            rst : in std_logic;
            button_in : in std_logic;
            button_out : out std_logic
        );
    end component;
    
    component vga_controller is
        Port (
            clk : in std_logic;
            rst : in std_logic;
            hsync : out std_logic;
            vsync : out std_logic;
            video_on : out std_logic;
            pixel_x : out integer range 0 to H_TOTAL-1;
            pixel_y : out integer range 0 to V_TOTAL-1
        );
    end component;
    
    component game_controller is
        Port (
            clk : in std_logic;
            rst : in std_logic;
            p1_up : in std_logic;
            p1_down : in std_logic;
            p1_left : in std_logic;
            p1_right : in std_logic;
            p2_up : in std_logic;
            p2_down : in std_logic;
            p2_left : in std_logic;
            p2_right : in std_logic;
            snake1_body : out snake_body_array;
            snake1_length : out integer range 0 to MAX_SNAKE_LENGTH;
            snake2_body : out snake_body_array;
            snake2_length : out integer range 0 to MAX_SNAKE_LENGTH;
            food_pos : out position;
            game_over : out std_logic;
            winner : out std_logic_vector(1 downto 0)
        );
    end component;
    
    component graphics_renderer is
        Port (
            clk : in std_logic;
            video_on : in std_logic;
            pixel_x : in integer range 0 to H_TOTAL-1;
            pixel_y : in integer range 0 to V_TOTAL-1;
            snake1_body : in snake_body_array;
            snake1_length : in integer range 0 to MAX_SNAKE_LENGTH;
            snake2_body : in snake_body_array;
            snake2_length : in integer range 0 to MAX_SNAKE_LENGTH;
            food_pos : in position;
            game_over : in std_logic;
            winner : in std_logic_vector(1 downto 0);
            red : out std_logic_vector(3 downto 0);
            green : out std_logic_vector(3 downto 0);
            blue : out std_logic_vector(3 downto 0)
        );
    end component;
    
    -- Internal signals
    signal clk_100mhz : std_logic;
    signal clk_25mhz : std_logic;
    signal clk_locked : std_logic;
    signal reset_sys : std_logic;
    
    signal video_on : std_logic;
    signal pixel_x : integer range 0 to H_TOTAL-1;
    signal pixel_y : integer range 0 to V_TOTAL-1;
    
    -- Debounced button signals
    signal p1_up_db, p1_down_db, p1_left_db, p1_right_db : std_logic;
    signal p2_up_db, p2_down_db, p2_left_db, p2_right_db : std_logic;
    
    -- Game state signals
    signal snake1_body : snake_body_array;
    signal snake1_length : integer range 0 to MAX_SNAKE_LENGTH;
    signal snake2_body : snake_body_array;
    signal snake2_length : integer range 0 to MAX_SNAKE_LENGTH;
    signal food_pos : position;
    signal game_over : std_logic;
    signal winner : std_logic_vector(1 downto 0);
    
begin

    -- System reset: reset OR clock not locked
    reset_sys <= rst or (not clk_locked);

    -- Clock Wizard: 12 MHz -> 100 MHz and 25 MHz
    -- NOTE: You must create this IP core in Vivado:
    -- 1. Tools -> Create and Package New IP -> Next
    -- 2. Click IP Catalog -> Clocking Wizard
    -- 3. Set input frequency to 12 MHz
    -- 4. Enable clk_out1 at 100 MHz
    -- 5. Enable clk_out2 at 25 MHz
    -- 6. Generate
    clk_wizard : clk_wiz_0
        port map (
            clk_out1 => clk_100mhz,
            clk_out2 => clk_25mhz,
            reset => rst,
            locked => clk_locked,
            clk_in1 => clk
        );
    
    -- Button debouncers for Player 1
    -- Adjusted debounce time for 100 MHz (1M cycles = 10ms)
    p1_up_debouncer : button_debouncer
        generic map (
            DEBOUNCE_TIME => 1000000
        )
        port map (
            clk => clk_100mhz,
            rst => reset_sys,
            button_in => p1_btn_up,
            button_out => p1_up_db
        );
    
    p1_down_debouncer : button_debouncer
        generic map (
            DEBOUNCE_TIME => 1000000
        )
        port map (
            clk => clk_100mhz,
            rst => reset_sys,
            button_in => p1_btn_down,
            button_out => p1_down_db
        );
    
    p1_left_debouncer : button_debouncer
        generic map (
            DEBOUNCE_TIME => 1000000
        )
        port map (
            clk => clk_100mhz,
            rst => reset_sys,
            button_in => p1_btn_left,
            button_out => p1_left_db
        );
    
    p1_right_debouncer : button_debouncer
        generic map (
            DEBOUNCE_TIME => 1000000
        )
        port map (
            clk => clk_100mhz,
            rst => reset_sys,
            button_in => p1_btn_right,
            button_out => p1_right_db
        );
    
    -- Button debouncers for Player 2
    p2_up_debouncer : button_debouncer
        generic map (
            DEBOUNCE_TIME => 1000000
        )
        port map (
            clk => clk_100mhz,
            rst => reset_sys,
            button_in => p2_btn_up,
            button_out => p2_up_db
        );
    
    p2_down_debouncer : button_debouncer
        generic map (
            DEBOUNCE_TIME => 1000000
        )
        port map (
            clk => clk_100mhz,
            rst => reset_sys,
            button_in => p2_btn_down,
            button_out => p2_down_db
        );
    
    p2_left_debouncer : button_debouncer
        generic map (
            DEBOUNCE_TIME => 1000000
        )
        port map (
            clk => clk_100mhz,
            rst => reset_sys,
            button_in => p2_btn_left,
            button_out => p2_left_db
        );
    
    p2_right_debouncer : button_debouncer
        generic map (
            DEBOUNCE_TIME => 1000000
        )
        port map (
            clk => clk_100mhz,
            rst => reset_sys,
            button_in => p2_btn_right,
            button_out => p2_right_db
        );
    
    -- VGA controller (uses 25 MHz pixel clock)
    vga_ctrl : vga_controller
        port map (
            clk => clk_25mhz,
            rst => reset_sys,
            hsync => vga_hsync,
            vsync => vga_vsync,
            video_on => video_on,
            pixel_x => pixel_x,
            pixel_y => pixel_y
        );
    
    -- Game controller (uses 100 MHz system clock)
    game_ctrl : game_controller
        port map (
            clk => clk_100mhz,
            rst => reset_sys,
            p1_up => p1_up_db,
            p1_down => p1_down_db,
            p1_left => p1_left_db,
            p1_right => p1_right_db,
            p2_up => p2_up_db,
            p2_down => p2_down_db,
            p2_left => p2_left_db,
            p2_right => p2_right_db,
            snake1_body => snake1_body,
            snake1_length => snake1_length,
            snake2_body => snake2_body,
            snake2_length => snake2_length,
            food_pos => food_pos,
            game_over => game_over,
            winner => winner
        );
    
    -- Graphics renderer (uses 25 MHz pixel clock)
    gfx_render : graphics_renderer
        port map (
            clk => clk_25mhz,
            video_on => video_on,
            pixel_x => pixel_x,
            pixel_y => pixel_y,
            snake1_body => snake1_body,
            snake1_length => snake1_length,
            snake2_body => snake2_body,
            snake2_length => snake2_length,
            food_pos => food_pos,
            game_over => game_over,
            winner => winner,
            red => vga_red,
            green => vga_green,
            blue => vga_blue
        );

end Behavioral;
