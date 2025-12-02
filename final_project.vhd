library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity final_project is
    port(
        clk:   in    std_logic;
        rst:   in    std_logic;
        
        -- UART (unused here)
        tx:    out   std_logic;
        
        -- VGA
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

    --------------------------------------------------------------------------
    -- Signals
    --------------------------------------------------------------------------
    signal clkfb       : std_logic;
    signal clk_25mhz   : std_logic;
    signal clk_100mhz  : std_logic;
    
    signal hcount   : unsigned(9 downto 0);
    signal vcount   : unsigned(9 downto 0);
    signal blank    : std_logic;
    signal frame    : std_logic;
    
    signal obj_red  : std_logic_vector(1 downto 0);
    signal obj_grn  : std_logic_vector(1 downto 0);
    signal obj_blu  : std_logic_vector(1 downto 0);
    
    -- Game grid dimensions
    constant GRID_WIDTH  : integer := 40;
    constant GRID_HEIGHT : integer := 30;
    constant CELL_SIZE   : integer := 16;
    
    -- Game timing
    signal game_tick_counter : unsigned(23 downto 0) := (others => '0');
    constant GAME_TICK_MAX   : unsigned(23 downto 0) := to_unsigned(2500000, 24); -- ~10 Hz at 25 MHz
    signal game_tick         : std_logic := '0';

    -- Snake head positions
    signal p1_snake_head_x : integer range 0 to GRID_WIDTH-1 := 20;
    signal p1_snake_head_y : integer range 0 to GRID_HEIGHT-1 := 15;
    signal p2_snake_head_x : integer range 0 to GRID_WIDTH-1 := 20;
    signal p2_snake_head_y : integer range 0 to GRID_HEIGHT-1 := 15;

    -- Snake body query results (for VGA)
    signal p1_body_here : std_logic;
    signal p2_body_here : std_logic;

    -- Apples
    signal food_x   : integer range 0 to GRID_WIDTH-1 := 10;
    signal food_y   : integer range 0 to GRID_HEIGHT-1 := 10;
    signal poison_x : integer range 0 to GRID_WIDTH-1 := 15;
    signal poison_y : integer range 0 to GRID_HEIGHT-1 := 15;

    signal p1_ate_food   : std_logic;
    signal p2_ate_food   : std_logic;
    signal p1_poison_hit : std_logic;
    signal p2_poison_hit : std_logic;

    -- Grid position for current pixel
    signal grid_cell_x : integer range 0 to GRID_WIDTH-1;
    signal grid_cell_y : integer range 0 to GRID_HEIGHT-1;

    -- VGA detection flags
    signal is_p1_head     : std_logic;
    signal is_p2_head     : std_logic;
    signal is_food_cell   : std_logic;
    signal is_poison_cell : std_logic;
    signal is_wall_cell   : std_logic;
    signal is_wall_prev   : std_logic;

    -- Random wall geometry outputs (from wall_field)
    signal w1_x0_sig, w2_x0_sig, w3_x0_sig : integer range 0 to GRID_WIDTH-1;
    signal w1_y0_sig, w2_y0_sig, w3_y0_sig : integer range 0 to GRID_HEIGHT-1;
    signal w1_or_sig, w2_or_sig, w3_or_sig : std_logic;
    signal walls_solid_sig : std_logic;

    -- Unused flattened body outputs (to keep entity happy)
    signal dummy_x_flat_p1 : std_logic_vector(16*12-1 downto 0);
    signal dummy_y_flat_p1 : std_logic_vector(16*12-1 downto 0);
    signal dummy_x_flat_p2 : std_logic_vector(16*12-1 downto 0);
    signal dummy_y_flat_p2 : std_logic_vector(16*12-1 downto 0);

begin

    tx <= '1';  -- UART idle high

    --------------------------------------------------------------------------
    -- MMCM: 12 MHz in -> ~25 MHz (VGA) + 100 MHz (unused)
    --------------------------------------------------------------------------
    cmt: MMCME2_BASE
        generic map (
            BANDWIDTH => "OPTIMIZED",
            CLKFBOUT_MULT_F => 50.875,
            CLKFBOUT_PHASE  => 0.0,
            CLKIN1_PERIOD   => 83.333,
            CLKOUT1_DIVIDE  => 6,
            CLKOUT2_DIVIDE  => 1,
            CLKOUT3_DIVIDE  => 1,
            CLKOUT4_DIVIDE  => 1,
            CLKOUT5_DIVIDE  => 1,
            CLKOUT6_DIVIDE  => 1,
            CLKOUT0_DIVIDE_F => 24.250,
            CLKOUT0_DUTY_CYCLE => 0.5,
            CLKOUT1_DUTY_CYCLE => 0.5,
            CLKOUT2_DUTY_CYCLE => 0.5,
            CLKOUT3_DUTY_CYCLE => 0.5,
            CLKOUT4_DUTY_CYCLE => 0.5,
            CLKOUT5_DUTY_CYCLE => 0.5,
            CLKOUT6_DUTY_CYCLE => 0.5,
            CLKOUT0_PHASE => 0.0,
            CLKOUT1_PHASE => 0.0,
            CLKOUT2_PHASE => 0.0,
            CLKOUT3_PHASE => 0.0,
            CLKOUT4_PHASE => 0.0,
            CLKOUT5_PHASE => 0.0,
            CLKOUT6_PHASE => 0.0,
            CLKOUT4_CASCADE => FALSE,
            DIVCLK_DIVIDE   => 1,
            REF_JITTER1     => 0.0,
            STARTUP_WAIT    => FALSE
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
            CLKFBOUTB => open,
            LOCKED   => open,
            CLKIN1   => clk,
            PWRDWN   => '0',
            RST      => '0',
            CLKFBIN  => clkfb
        );

    --------------------------------------------------------------------------
    -- VGA timing
    --------------------------------------------------------------------------
    vga_ctrl : entity work.vga_driver
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
    
    --------------------------------------------------------------------------
    -- Game tick generator (controls game speed)
    --------------------------------------------------------------------------
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
    
    --------------------------------------------------------------------------
    -- Grid position for current pixel
    --------------------------------------------------------------------------
    grid_cell_x <= to_integer(hcount) / CELL_SIZE when hcount < 640 else 0;
    grid_cell_y <= to_integer(vcount) / CELL_SIZE when vcount < 480 else 0;
    
    --------------------------------------------------------------------------
    -- Random walls (border + 3 random walls of length 5)
    --------------------------------------------------------------------------
    walls_inst : entity work.wall_field
        generic map(
            GRID_WIDTH  => GRID_WIDTH,
            GRID_HEIGHT => GRID_HEIGHT
        )
        port map(
            clk       => clk_25mhz,
            rst       => rst,
            game_tick => game_tick,
            snake1_x  => p1_snake_head_x,
            snake1_y  => p1_snake_head_y,
            snake2_x  => p2_snake_head_x,
            snake2_y  => p2_snake_head_y,
            food_x_i  => food_x,
            food_y_i  => food_y,
            x         => grid_cell_x,
            y         => grid_cell_y,
            is_wall         => is_wall_cell,
            is_wall_preview => is_wall_prev,
            w1_x0_o         => w1_x0_sig,
            w1_y0_o         => w1_y0_sig,
            w1_orient_o     => w1_or_sig,
            w2_x0_o         => w2_x0_sig,
            w2_y0_o         => w2_y0_sig,
            w2_orient_o     => w2_or_sig,
            w3_x0_o         => w3_x0_sig,
            w3_y0_o         => w3_y0_sig,
            w3_orient_o     => w3_or_sig,
            walls_solid_o   => walls_solid_sig
        );

    --------------------------------------------------------------------------
    -- Food (normal apple)
    --------------------------------------------------------------------------
    food_ctrl : entity work.food_control
        generic map (
            GRID_WIDTH    => GRID_WIDTH,
            GRID_HEIGHT   => GRID_HEIGHT,
            VISIBLE_TICKS => 80,
            HIDDEN_TICKS  => 30,
            SEED          => "1010101010"
        )
        port map (
            clk          => clk_25mhz,
            rst          => rst,
            game_tick    => game_tick,
            p1_head_x    => p1_snake_head_x,
            p1_head_y    => p1_snake_head_y,
            p2_head_x    => p2_snake_head_x,
            p2_head_y    => p2_snake_head_y,
            w1_x0_i      => w1_x0_sig,
            w1_y0_i      => w1_y0_sig,
            w1_orient_i  => w1_or_sig,
            w2_x0_i      => w2_x0_sig,
            w2_y0_i      => w2_y0_sig,
            w2_orient_i  => w2_or_sig,
            w3_x0_i      => w3_x0_sig,
            w3_y0_i      => w3_y0_sig,
            w3_orient_i  => w3_or_sig,
            walls_solid_i=> walls_solid_sig,
            food_x       => food_x,
            food_y       => food_y,
            p1_ate       => p1_ate_food,
            p2_ate       => p2_ate_food
        );

    --------------------------------------------------------------------------
    -- Poison apple
    --------------------------------------------------------------------------
    poison_ctrl : entity work.poison_control
        generic map (
            GRID_WIDTH    => GRID_WIDTH,
            GRID_HEIGHT   => GRID_HEIGHT,
            VISIBLE_TICKS => 80,
            HIDDEN_TICKS  => 30,
            SEED          => "1100110011"
        )
        port map (
            clk          => clk_25mhz,
            rst          => rst,
            game_tick    => game_tick,
            p1_head_x    => p1_snake_head_x,
            p1_head_y    => p1_snake_head_y,
            p2_head_x    => p2_snake_head_x,
            p2_head_y    => p2_snake_head_y,
            w1_x0_i      => w1_x0_sig,
            w1_y0_i      => w1_y0_sig,
            w1_orient_i  => w1_or_sig,
            w2_x0_i      => w2_x0_sig,
            w2_y0_i      => w2_y0_sig,
            w2_orient_i  => w2_or_sig,
            w3_x0_i      => w3_x0_sig,
            w3_y0_i      => w3_y0_sig,
            w3_orient_i  => w3_or_sig,
            walls_solid_i=> walls_solid_sig,
            poison_x     => poison_x,
            poison_y     => poison_y,
            p1_poison    => p1_poison_hit,
            p2_poison    => p2_poison_hit
        );

    --------------------------------------------------------------------------
    -- Snake control modules p1 and p2
    --------------------------------------------------------------------------
    snake_p1 : entity work.snake_control
        generic map (
            GRID_WIDTH  => GRID_WIDTH,
            GRID_HEIGHT => GRID_HEIGHT,
            MAX_LENGTH  => 16,
            START_X     => 10,
            START_Y     => 15
        )
        port map (
            clk            => clk_25mhz,
            rst            => rst,
            game_tick      => game_tick,
            btn_up         => p1_btn_up,
            btn_down       => p1_btn_down,
            btn_left       => p1_btn_left,
            btn_right      => p1_btn_right,
            grow           => p1_ate_food,
            shrink         => p1_poison_hit,
            w1_x0_i        => w1_x0_sig,
            w1_y0_i        => w1_y0_sig,
            w1_orient_i    => w1_or_sig,
            w2_x0_i        => w2_x0_sig,
            w2_y0_i        => w2_y0_sig,
            w2_orient_i    => w2_or_sig,
            w3_x0_i        => w3_x0_sig,
            w3_y0_i        => w3_y0_sig,
            w3_orient_i    => w3_or_sig,
            walls_solid_i  => walls_solid_sig,
            snake_head_x_o => p1_snake_head_x,
            snake_head_y_o => p1_snake_head_y,
            query_x        => grid_cell_x,
            query_y        => grid_cell_y,
            is_body        => p1_body_here,
            snake_length_o => open,
            self_collision => open,
            body_x_flat_o  => dummy_x_flat_p1,
            body_y_flat_o  => dummy_y_flat_p1
        );
        
    snake_p2 : entity work.snake_control
        generic map (
            GRID_WIDTH  => GRID_WIDTH,
            GRID_HEIGHT => GRID_HEIGHT,
            MAX_LENGTH  => 16,
            START_X     => 30,
            START_Y     => 15
        )
        port map (
            clk            => clk_25mhz,
            rst            => rst,
            game_tick      => game_tick,
            btn_up         => p2_btn_up,
            btn_down       => p2_btn_down,
            btn_left       => p2_btn_left,
            btn_right      => p2_btn_right,
            grow           => p2_ate_food,
            shrink         => p2_poison_hit,
            w1_x0_i        => w1_x0_sig,
            w1_y0_i        => w1_y0_sig,
            w1_orient_i    => w1_or_sig,
            w2_x0_i        => w2_x0_sig,
            w2_y0_i        => w2_y0_sig,
            w2_orient_i    => w2_or_sig,
            w3_x0_i        => w3_x0_sig,
            w3_y0_i        => w3_y0_sig,
            w3_orient_i    => w3_or_sig,
            walls_solid_i  => walls_solid_sig,
            snake_head_x_o => p2_snake_head_x,
            snake_head_y_o => p2_snake_head_y,
            query_x        => grid_cell_x,
            query_y        => grid_cell_y,
            is_body        => p2_body_here,
            snake_length_o => open,
            self_collision => open,
            body_x_flat_o  => dummy_x_flat_p2,
            body_y_flat_o  => dummy_y_flat_p2
        );

    --------------------------------------------------------------------------
    -- Object detection (on grid)
    --------------------------------------------------------------------------
    is_p1_head <= '1' when
        (grid_cell_x = p1_snake_head_x and grid_cell_y = p1_snake_head_y)
        else '0';
    
    is_p2_head <= '1' when
        (grid_cell_x = p2_snake_head_x and grid_cell_y = p2_snake_head_y)
        else '0';
    
    is_food_cell <= '1' when
        (grid_cell_x = food_x and grid_cell_y = food_y)
        else '0';

    is_poison_cell <= '1' when
        (grid_cell_x = poison_x and grid_cell_y = poison_y)
        else '0';

    --------------------------------------------------------------------------
    -- Snake game rendering priority:
    --  P1 head > P2 head > P1 body > P2 body > food > poison > walls > background
    --------------------------------------------------------------------------
    process(is_p1_head, is_p2_head, p1_body_here, p2_body_here,
            is_food_cell, is_poison_cell, is_wall_cell, is_wall_prev)
    begin
        if is_p1_head = '1' then
            -- Player 1 head: bright green
            obj_red <= "00";
            obj_grn <= "11";
            obj_blu <= "00";
        elsif is_p2_head = '1' then
            -- Player 2 head: yellow
            obj_red <= "11";
            obj_grn <= "11";
            obj_blu <= "00";
        elsif p1_body_here = '1' then
            -- Player 1 body: dark green
            obj_red <= "00";
            obj_grn <= "10";
            obj_blu <= "00";
        elsif p2_body_here = '1' then
            -- Player 2 body: orange
            obj_red <= "11";
            obj_grn <= "10";
            obj_blu <= "00";
        elsif is_food_cell = '1' then
            -- Normal food: red
            obj_red <= "11";
            obj_grn <= "00";
            obj_blu <= "00";
        elsif is_poison_cell = '1' then
            -- Poison apple: magenta
            obj_red <= "11";
            obj_grn <= "00";
            obj_blu <= "11";
        elsif is_wall_cell = '1' then
            if is_wall_prev = '1' then
                -- Preview phase: bright white
                obj_red <= "11";
                obj_grn <= "11";
                obj_blu <= "11";
            else
                -- Solid / border walls: gray
                obj_red <= "01";
                obj_grn <= "01";
                obj_blu <= "01";
            end if;
        else
            -- Background: black
            obj_red <= "00";
            obj_grn <= "00";
            obj_blu <= "00";
        end if;
    end process;

    --------------------------------------------------------------------------
    -- VGA output with blanking
    --------------------------------------------------------------------------
    red   <= "00" when blank = '1' else obj_red;
    green <= "00" when blank = '1' else obj_grn;
    blue  <= "00" when blank = '1' else obj_blu;

end arch;
