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
    
    ------------------------------------------------------------------
    -- Component declarations
    ------------------------------------------------------------------
    component vga_driver is
        Port (
            clk      : in std_logic;
            rst      : in std_logic;
            hsync_o  : out std_logic;       
            vsync_o  : out std_logic;       
            frame_o  : out std_logic;       
            blank_o  : out std_logic;       
            hcount_o : out unsigned(9 downto 0);
            vcount_o : out unsigned(9 downto 0)
        );
    end component;
    
    component snake_control is
        generic (
            GRID_WIDTH  : integer := 40;
            GRID_HEIGHT : integer := 30;
            MAX_LENGTH  : integer := 16;
            START_X     : integer := 10;
            START_Y     : integer := 15
        );
        Port ( 
            clk       : in std_logic;
            rst       : in std_logic;
            game_tick : in std_logic;
            
            btn_up    : in std_logic;
            btn_down  : in std_logic;
            btn_left  : in std_logic;
            btn_right : in std_logic;
            
            grow   : in std_logic;
            shrink : in std_logic;

            map_id : in std_logic_vector(2 downto 0);
            
            snake_head_x_o : out integer range 0 to GRID_WIDTH-1;
            snake_head_y_o : out integer range 0 to GRID_HEIGHT-1;
            
            query_x : in integer range 0 to GRID_WIDTH-1;
            query_y : in integer range 0 to GRID_HEIGHT-1;
            is_body : out std_logic;
            
            snake_length_o : out integer range 0 to MAX_LENGTH;
            self_collision : out std_logic;

            body_x_flat_o : out std_logic_vector(MAX_LENGTH*12-1 downto 0);
            body_y_flat_o : out std_logic_vector(MAX_LENGTH*12-1 downto 0)
        );
    end component;
    
    component food_control is
        generic (
            GRID_WIDTH    : integer := 40;
            GRID_HEIGHT   : integer := 30;
            VISIBLE_TICKS : integer := 80;
            HIDDEN_TICKS  : integer := 30;
            SEED          : std_logic_vector(9 downto 0) := "1010101010";
            MAX_APPLES    : integer := 20
        );
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            game_tick : in  std_logic;
            map_id    : in  std_logic_vector(2 downto 0);
            p1_head_x : in  integer range 0 to GRID_WIDTH-1;
            p1_head_y : in  integer range 0 to GRID_HEIGHT-1;
            p2_head_x : in  integer range 0 to GRID_WIDTH-1;
            p2_head_y : in  integer range 0 to GRID_HEIGHT-1;
            food_x    : out integer range 0 to GRID_WIDTH-1;
            food_y    : out integer range 0 to GRID_HEIGHT-1;
            p1_ate    : out std_logic;
            p2_ate    : out std_logic
        );
    end component;

    component poison_control is
        generic (
            GRID_WIDTH    : integer := 40;
            GRID_HEIGHT   : integer := 30;
            VISIBLE_TICKS : integer := 80;
            HIDDEN_TICKS  : integer := 30;
            SEED          : std_logic_vector(9 downto 0) := "1100110011"
        );
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            game_tick : in  std_logic;
            map_id    : in  std_logic_vector(2 downto 0);
            p1_head_x : in  integer range 0 to GRID_WIDTH-1;
            p1_head_y : in  integer range 0 to GRID_HEIGHT-1;
            p2_head_x : in  integer range 0 to GRID_WIDTH-1;
            p2_head_y : in  integer range 0 to GRID_HEIGHT-1;
            poison_x  : out integer range 0 to GRID_WIDTH-1;
            poison_y  : out integer range 0 to GRID_HEIGHT-1;
            p1_poison : out std_logic;
            p2_poison : out std_logic
        );
    end component;

    component wall_field is
        generic (
            GRID_WIDTH  : integer := 40;
            GRID_HEIGHT : integer := 30
        );
        port(
            x       : in  integer range 0 to GRID_WIDTH-1;
            y       : in  integer range 0 to GRID_HEIGHT-1;
            map_id  : in  std_logic_vector(2 downto 0);
            is_wall : out std_logic
        );
    end component;

    ------------------------------------------------------------------
    -- Clocks
    ------------------------------------------------------------------
    signal clkfb      : std_logic;
    signal clk_25mhz  : std_logic;
    signal clk_6mhz : std_logic;
    
    -- VGA signals
    signal hcount : unsigned(9 downto 0);
    signal vcount : unsigned(9 downto 0);
    signal blank  : std_logic;
    signal frame  : std_logic;
    
    -- Grid constants
    constant GRID_W  : integer := 40;
    constant GRID_H  : integer := 30;
    constant CELL_SIZE   : integer := 16;
    constant MAX_LENGTH  : integer := 16;
    
    -- Game timing
    signal game_tick_counter : unsigned(23 downto 0) := (others => '0');
    constant GAME_TICK_MAX   : unsigned(23 downto 0) := to_unsigned(2500000, 24); -- ≈0.1s
    signal game_tick         : std_logic := '0';
    signal game_tick_play    : std_logic := '0'; 
    
    ------------------------------------------------------------------
    -- Player 1 signals
    ------------------------------------------------------------------
    signal p1_head_x  : integer range 0 to GRID_W-1;
    signal p1_head_y  : integer range 0 to GRID_H-1;
    signal p1_query_x : integer range 0 to GRID_W-1;
    signal p1_query_y : integer range 0 to GRID_H-1;
    signal p1_is_body : std_logic;
    signal p1_length  : integer range 0 to MAX_LENGTH;
    signal p1_collision   : std_logic;
    signal p1_body_x_flat : std_logic_vector(MAX_LENGTH*12-1 downto 0);
    signal p1_body_y_flat : std_logic_vector(MAX_LENGTH*12-1 downto 0);
    
    ------------------------------------------------------------------
    -- Player 2 signals
    ------------------------------------------------------------------
    signal p2_head_x  : integer range 0 to GRID_W-1;
    signal p2_head_y  : integer range 0 to GRID_H-1;
    signal p2_query_x : integer range 0 to GRID_W-1;
    signal p2_query_y : integer range 0 to GRID_H-1;
    signal p2_is_body : std_logic;
    signal p2_length  : integer range 0 to MAX_LENGTH;
    signal p2_collision   : std_logic;
    signal p2_body_x_flat : std_logic_vector(MAX_LENGTH*12-1 downto 0);
    signal p2_body_y_flat : std_logic_vector(MAX_LENGTH*12-1 downto 0);
    
    ------------------------------------------------------------------
    -- Food / poison signals
    ------------------------------------------------------------------
    signal food_x : integer range 0 to GRID_W-1;
    signal food_y : integer range 0 to GRID_H-1;
    signal p1_ate : std_logic;
    signal p2_ate : std_logic;

    signal poison_x  : integer range 0 to GRID_W-1;
    signal poison_y  : integer range 0 to GRID_H-1;
    signal p1_poison : std_logic;
    signal p2_poison : std_logic;
    
    ------------------------------------------------------------------
    -- Grid & rendering
    ------------------------------------------------------------------
    signal grid_x : integer range 0 to GRID_W-1;
    signal grid_y : integer range 0 to GRID_H-1;
    
    signal pixel_p1     : std_logic := '0';
    signal pixel_p2     : std_logic := '0';
    signal pixel_food   : std_logic := '0';
    signal pixel_poison : std_logic := '0';
    signal pixel_wall   : std_logic := '0';
    
    signal color_r : std_logic_vector(1 downto 0) := "00";
    signal color_g : std_logic_vector(1 downto 0) := "00";
    signal color_b : std_logic_vector(1 downto 0) := "00";

    ------------------------------------------------------------------
    -- Game state & map ID
    ------------------------------------------------------------------
    type game_state_t is (PLAYING, P1_WIN, P2_WIN, TIE);
    signal game_state : game_state_t := PLAYING;

    signal map_id     : std_logic_vector(2 downto 0) := "000"; -- 0~4
    signal lfsr_map   : std_logic_vector(7 downto 0) := x"5A";
    signal map_locked : std_logic := '0';

begin
    ------------------------------------------------------------------
    -- UART TX: idle high
    ------------------------------------------------------------------
    tx <= '1';

    ------------------------------------------------------------------
    -- Clock generation: 12MHz -> 25MHz
    ------------------------------------------------------------------
    cmt: MMCME2_BASE 
    generic map (
        BANDWIDTH        => "OPTIMIZED",
        CLKFBOUT_MULT_F  => 50.875,
        CLKIN1_PERIOD    => 83.333,
        DIVCLK_DIVIDE    => 1,
        
        CLKOUT0_DIVIDE_F => 24.250,
        CLKOUT1_DIVIDE => 102
    ) 
    port map (
        CLKOUT0  => clk_25mhz,
        CLKFBOUT => clkfb,
        CLKIN1   => clk,
        PWRDWN   => '0',
        RST      => '0',
        CLKFBIN  => clkfb,
        CLKOUT0B => open,
        CLKOUT1  => clk_6mhz,
        CLKOUT1B => open,
        CLKOUT2  => open,
        CLKOUT2B => open,
        CLKOUT3  => open,
        CLKOUT3B => open,
        CLKOUT4  => open,
        CLKOUT5  => open,
        CLKOUT6  => open,
        CLKFBOUTB => open,
        LOCKED    => open
    );

    ------------------------------------------------------------------
    -- VGA driver
    ------------------------------------------------------------------
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

    game_tick_play <= game_tick when game_state = PLAYING else '0';

  
    process(clk_25mhz)
        variable idx : integer range 0 to 7;
    begin
        if rising_edge(clk_25mhz) then
            lfsr_map <= lfsr_map(6 downto 0) & (lfsr_map(7) xor lfsr_map(5));

            if rst = '1' then
                map_locked <= '0';
            elsif (map_locked = '0' and game_tick = '1') then
                idx := to_integer(unsigned(lfsr_map(2 downto 0)));
                if idx >= 5 then
                    idx := idx - 5;
                end if;
                map_id     <= std_logic_vector(to_unsigned(idx, 3));
                map_locked <= '1';
            end if;
        end if;
    end process;
    
    ------------------------------------------------------------------
    -- Snake instances
    ------------------------------------------------------------------
    snake_p1 : snake_control
    generic map (
        GRID_WIDTH  => GRID_W,
        GRID_HEIGHT => GRID_H,
        MAX_LENGTH  => MAX_LENGTH,
        START_X     => 8,               
        START_Y     => GRID_H/2
    )
    port map (
        clk       => clk_25mhz,
        rst       => rst,
        game_tick => game_tick_play,
        btn_up    => p1_btn_up,
        btn_down  => p1_btn_down,
        btn_left  => p1_btn_left,
        btn_right => p1_btn_right,
        grow      => p1_ate,
        shrink    => p1_poison,
        map_id    => map_id,
        snake_head_x_o => p1_head_x,
        snake_head_y_o => p1_head_y,
        query_x   => p1_query_x,
        query_y   => p1_query_y,
        is_body   => p1_is_body,
        snake_length_o => p1_length,
        self_collision => p1_collision,
        body_x_flat_o  => p1_body_x_flat,
        body_y_flat_o  => p1_body_y_flat
    );
        
    snake_p2 : snake_control
    generic map (
        GRID_WIDTH  => GRID_W,
        GRID_HEIGHT => GRID_H,
        MAX_LENGTH  => MAX_LENGTH,
        START_X     => GRID_W-9,       
        START_Y     => GRID_H/2
    )
    port map (
        clk       => clk_25mhz,
        rst       => rst,
        game_tick => game_tick_play,
        btn_up    => p2_btn_up,
        btn_down  => p2_btn_down,
        btn_left  => p2_btn_left,
        btn_right => p2_btn_right,
        grow      => p2_ate,
        shrink    => p2_poison,
        map_id    => map_id,
        snake_head_x_o => p2_head_x,
        snake_head_y_o => p2_head_y,
        query_x   => p2_query_x,
        query_y   => p2_query_y,
        is_body   => p2_is_body,
        snake_length_o => p2_length,
        self_collision => p2_collision,
        body_x_flat_o  => p2_body_x_flat,
        body_y_flat_o  => p2_body_y_flat
    );
    
    ------------------------------------------------------------------
    -- Food controller
    ------------------------------------------------------------------
    food_ctrl_i : food_control
    generic map (
        GRID_WIDTH    => GRID_W,
        GRID_HEIGHT   => GRID_H,
        VISIBLE_TICKS => 80,
        HIDDEN_TICKS  => 30,
        SEED          => "1010101010",
        MAX_APPLES    => 20
    )
    port map (
        clk       => clk_25mhz,
        rst       => rst,
        game_tick => game_tick_play,
        map_id    => map_id,
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
    -- Poison controller
    ------------------------------------------------------------------
    poison_ctrl_i : poison_control
    generic map (
        GRID_WIDTH    => GRID_W,
        GRID_HEIGHT   => GRID_H,
        VISIBLE_TICKS => 80,
        HIDDEN_TICKS  => 30,
        SEED          => "1100110011"
    )
    port map (
        clk       => clk_25mhz,
        rst       => rst,
        game_tick => game_tick_play,
        map_id    => map_id,
        p1_head_x => p1_head_x,
        p1_head_y => p1_head_y,
        p2_head_x => p2_head_x,
        p2_head_y => p2_head_y,
        poison_x  => poison_x,
        poison_y  => poison_y,
        p1_poison => p1_poison,
        p2_poison => p2_poison
    );

    ------------------------------------------------------------------
    -- Wall instance
    ------------------------------------------------------------------
    wall_inst : wall_field
    generic map (
        GRID_WIDTH  => GRID_W,
        GRID_HEIGHT => GRID_H
    )
    port map (
        x       => grid_x,
        y       => grid_y,
        map_id  => map_id,
        is_wall => pixel_wall
    );
    
    ------------------------------------------------------------------
    -- Grid calculation
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
    
    p1_query_x <= grid_x;
    p1_query_y <= grid_y;
    p2_query_x <= grid_x;
    p2_query_y <= grid_y;
    
    ------------------------------------------------------------------
    -- Object detection
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

            if (grid_x = poison_x and grid_y = poison_y) then
                pixel_poison <= '1';
            else
                pixel_poison <= '0';
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Game state & mutual collision
    ------------------------------------------------------------------
    process(clk_25mhz)
        variable i           : integer;
        variable seg_x       : integer range 0 to GRID_W-1;
        variable seg_y       : integer range 0 to GRID_H-1;
        variable p1_dead_v   : std_logic;
        variable p2_dead_v   : std_logic;
        variable p1_hit_other: std_logic;
        variable p2_hit_other: std_logic;
        variable base        : integer;
    begin
        if rising_edge(clk_25mhz) then
            if rst = '1' then
                game_state <= PLAYING;
            else
                if (game_state = PLAYING) and (game_tick = '1') then
                    p1_dead_v    := p1_collision;
                    p2_dead_v    := p2_collision;
                    p1_hit_other := '0';
                    p2_hit_other := '0';

                    for i in 0 to MAX_LENGTH-1 loop
                        exit when i >= p2_length;
                        base  := i*12;
                        seg_x := to_integer(unsigned(p2_body_x_flat(base+11 downto base)));
                        seg_y := to_integer(unsigned(p2_body_y_flat(base+11 downto base)));
                        if (seg_x = p1_head_x) and (seg_y = p1_head_y) then
                            p1_hit_other := '1';
                        end if;
                    end loop;

                    for i in 0 to MAX_LENGTH-1 loop
                        exit when i >= p1_length;
                        base  := i*12;
                        seg_x := to_integer(unsigned(p1_body_x_flat(base+11 downto base)));
                        seg_y := to_integer(unsigned(p1_body_y_flat(base+11 downto base)));
                        if (seg_x = p2_head_x) and (seg_y = p2_head_y) then
                            p2_hit_other := '1';
                        end if;
                    end loop;

                    if p1_hit_other = '1' then
                        p1_dead_v := '1';
                    end if;
                    if p2_hit_other = '1' then
                        p2_dead_v := '1';
                    end if;

                    if (p1_dead_v = '1') and (p2_dead_v = '0') then
                        game_state <= P2_WIN;
                    elsif (p2_dead_v = '1') and (p1_dead_v = '0') then
                        game_state <= P1_WIN;
                    elsif (p1_dead_v = '1') and (p2_dead_v = '1') then
                        game_state <= TIE;
                    else
                        game_state <= PLAYING;
                    end if;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Color generation
    ------------------------------------------------------------------
    process(clk_25mhz)
    begin
        if rising_edge(clk_25mhz) then
            if game_state = PLAYING then
                if pixel_p1 = '1' then
                    color_r <= "00";  -- Green
                    color_g <= "11";
                    color_b <= "00";
                elsif pixel_p2 = '1' then
                    color_r <= "11";  -- Yellow
                    color_g <= "11";
                    color_b <= "00";
                elsif pixel_food = '1' then
                    color_r <= "11";  -- Red
                    color_g <= "00";
                    color_b <= "00";
                elsif pixel_poison = '1' then
                    color_r <= "00";  -- Blue
                    color_g <= "00";
                    color_b <= "11";
                elsif pixel_wall = '1' then
                    color_r <= "01";  -- Gray
                    color_g <= "01";
                    color_b <= "01";
                else
                    color_r <= "00";  -- Black
                    color_g <= "00";
                    color_b <= "00";
                end if;
            else
                -- GAME OVER 
                if grid_y < GRID_H/2 then
                    color_r <= "11";  -- red
                    color_g <= "00";
                    color_b <= "00";
                else
                    case game_state is
                        when P1_WIN =>
                            color_r <= "00";
                            color_g <= "11";
                            color_b <= "00";
                        when P2_WIN =>
                            color_r <= "11";
                            color_g <= "11";
                            color_b <= "00";
                        when TIE =>
                            color_r <= "11";
                            color_g <= "11";
                            color_b <= "11";
                        when others =>
                            color_r <= "00";
                            color_g <= "00";
                            color_b <= "00";
                    end case;
                end if;
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
