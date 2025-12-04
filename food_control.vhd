library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity final_project is
    port(
        clk:   in    std_logic;   -- 12MHz 外部时钟
        rst:   in    std_logic;   -- 同步复位，高有效
        tx:    out   std_logic;   -- 未用，拉高

        -- VGA outputs
        red:   out   std_logic_vector(1 downto 0);
        green: out   std_logic_vector(1 downto 0);
        blue:  out   std_logic_vector(1 downto 0);
        hsync: out   std_logic;
        vsync: out   std_logic;

        -- Player 1 controls（按键低有效）
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
            MAX_LENGTH  : integer := 7;
            START_X     : integer := 10;
            START_Y     : integer := 15
        );
        Port ( 
            clk       : in std_logic;
            rst       : in std_logic;
            game_tick : in std_logic;
            next_level: in std_logic;

            -- Button inputs (active low)
            btn_up    : in std_logic;
            btn_down  : in std_logic;
            btn_left  : in std_logic;
            btn_right : in std_logic;
            
            -- Length change
            grow   : in std_logic;
            shrink : in std_logic;

            -- Map ID
            map_id : in std_logic_vector(2 downto 0);

            -- Snake head position
            snake_head_x_o : out integer range 0 to GRID_WIDTH-1;
            snake_head_y_o : out integer range 0 to GRID_HEIGHT-1;
            
            -- Query interface (for VGA)
            query_x : in integer range 0 to GRID_WIDTH-1;
            query_y : in integer range 0 to GRID_HEIGHT-1;
            is_body : out std_logic;
            
            -- Status outputs
            snake_length_o : out integer range 0 to MAX_LENGTH;
            self_collision : out std_logic;  

            -- Body flattened
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
    signal clk_6mhz   : std_logic;  -- 保留不用

    -- VGA signals
    signal hcount : unsigned(9 downto 0);
    signal vcount : unsigned(9 downto 0);
    signal blank  : std_logic;
    signal frame  : std_logic;

    -- Grid constants
    constant GRID_W  : integer := 40;
    constant GRID_H  : integer := 30;
    constant CELL_SIZE  : integer := 16;
    constant MAX_LEN    : integer := 7;   -- 对应 snake_control 的 MAX_LENGTH

    -- Game timing
    signal game_tick_counter : unsigned(23 downto 0) := (others => '0');
    constant GAME_TICK_MAX   : unsigned(23 downto 0) := to_unsigned(2500000, 24); -- ~0.1s @ 25MHz
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
    signal p1_length  : integer range 0 to MAX_LEN;
    signal p1_collision   : std_logic;
    signal p1_body_x_flat : std_logic_vector(MAX_LEN*12-1 downto 0);
    signal p1_body_y_flat : std_logic_vector(MAX_LEN*12-1 downto 0);

    ------------------------------------------------------------------
    -- Player 2 signals
    ------------------------------------------------------------------
    signal p2_head_x  : integer range 0 to GRID_W-1;
    signal p2_head_y  : integer range 0 to GRID_H-1;
    signal p2_query_x : integer range 0 to GRID_W-1;
    signal p2_query_y : integer range 0 to GRID_H-1;
    signal p2_is_body : std_logic;
    signal p2_length  : integer range 0 to MAX_LEN;
    signal p2_collision   : std_logic;
    signal p2_body_x_flat : std_logic_vector(MAX_LEN*12-1 downto 0);
    signal p2_body_y_flat : std_logic_vector(MAX_LEN*12-1 downto 0);

    ------------------------------------------------------------------
    -- Food / poison signals
    ------------------------------------------------------------------
    signal food_x : integer range 0 to GRID_W-1;
    signal food_y : integer range 0 to GRID_H-1;
    signal p1_ate : std_logic;
    signal p2_ate : std_logic;

    -- 多个毒苹果
    type poison_coord_x_array_t is array(0 to 8) of integer range 0 to GRID_W-1;
    type poison_coord_y_array_t is array(0 to 8) of integer range 0 to GRID_H-1;
    type poison_flag_array_t    is array(0 to 8) of std_logic;

    signal poison_x_arr   : poison_coord_x_array_t;
    signal poison_y_arr   : poison_coord_y_array_t;
    signal p1_poison_vec  : poison_flag_array_t;
    signal p2_poison_vec  : poison_flag_array_t;

    -- OR 之后给蛇的 shrink
    signal p1_poison : std_logic;
    signal p2_poison : std_logic;

    -- 当前启用的毒苹果个数（Round1=1, R2=3, R3=5, R4=7, R5+=9）
    signal active_poison_count : integer range 1 to 9;

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
    -- Game state & random map & round + 5局/死亡计数
    ------------------------------------------------------------------
    type game_state_t is (ROUND_SHOW, PLAYING, P1_WIN, P2_WIN, TIE);
    signal game_state : game_state_t := ROUND_SHOW;

    signal map_id     : std_logic_vector(2 downto 0) := "000"; -- 0~4
    signal lfsr_map   : std_logic_vector(7 downto 0) := x"5A";
    signal map_locked : std_logic := '0';
    
    signal button_press: std_logic := '0';
    signal next_level  : std_logic := '0';
    signal num_level   : unsigned(5 downto 0) := (others => '0');  -- 0 -> Round1
    signal round_timer : unsigned(7 downto 0) := (others => '0');  -- 控制 ROUND 显示时间

    -- 比赛统计：每局胜场、死亡次数(0~10)、已完成的局数、比赛是否结束
    signal p1_round_wins : unsigned(2 downto 0) := (others => '0');
    signal p2_round_wins : unsigned(2 downto 0) := (others => '0');
    signal p1_deaths     : unsigned(3 downto 0) := (others => '0');  -- up to 10
    signal p2_deaths     : unsigned(3 downto 0) := (others => '0');  -- up to 10
    signal round_count   : unsigned(2 downto 0) := (others => '0');  -- 已完成局数：0~5
    signal match_over    : std_logic := '0'; -- 比赛是否已经决出总冠军

begin
    ------------------------------------------------------------------
    -- 同时按下两边的"上"键，开始下一局（仅在比赛未结束 & P1/P2 Win 时有效）
    ------------------------------------------------------------------
    button_press <= '1' when (p2_btn_up = '0' and p1_btn_up = '0') else '0';
    next_level   <= '1'
        when (match_over = '0' and button_press = '1' and 
              (game_state = P1_WIN or game_state = P2_WIN))
        else '0';

    ------------------------------------------------------------------
    -- UART TX: idle high
    ------------------------------------------------------------------
    tx <= '1';

    ------------------------------------------------------------------
    -- Clock generation：12MHz -> 25MHz (再分一个 6MHz 备用)
    ------------------------------------------------------------------
    cmt: MMCME2_BASE 
    generic map (
        BANDWIDTH        => "OPTIMIZED",
        CLKFBOUT_MULT_F  => 50.875,
        CLKIN1_PERIOD    => 83.333,
        DIVCLK_DIVIDE    => 1,
        CLKOUT0_DIVIDE_F => 24.250,
        CLKOUT1_DIVIDE   => 102
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
    -- Game tick generator：与蛇/苹果/毒苹果同域 (25MHz)
    ------------------------------------------------------------------
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

    -- 只有 PLAYING 状态蛇才会动
    game_tick_play <= game_tick when game_state = PLAYING else '0';

    ------------------------------------------------------------------
    -- Map LFSR：上电或下一关时随机锁定一张地图
    ------------------------------------------------------------------
    process(clk_25mhz)
        variable idx : integer range 0 to 7;
    begin
        if rising_edge(clk_25mhz) then
            lfsr_map <= lfsr_map(6 downto 0) & (lfsr_map(7) xor lfsr_map(5));

            if rst = '1' or next_level = '1' then
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
    -- 根据关卡决定启用多少毒苹果：Round1=1, Round2=3, Round3=5, Round4=7, Round5+=9
    ------------------------------------------------------------------
    process(num_level)
        variable lvl : integer;
    begin
        lvl := to_integer(num_level);      -- 0->R1, 1->R2, ...
        if lvl = 0 then
            active_poison_count <= 1;      -- Round1
        elsif lvl = 1 then
            active_poison_count <= 3;      -- Round2
        elsif lvl = 2 then
            active_poison_count <= 5;      -- Round3
        elsif lvl = 3 then
            active_poison_count <= 7;      -- Round4
        else
            active_poison_count <= 9;      -- Round5+
        end if;
    end process;

    ------------------------------------------------------------------
    -- Snake instances
    ------------------------------------------------------------------
    snake_p1 : snake_control
    generic map (
        GRID_WIDTH  => GRID_W,
        GRID_HEIGHT => GRID_H,
        MAX_LENGTH  => MAX_LEN,
        START_X     => 8,              -- 左边偏里一点
        START_Y     => GRID_H/2
    )
    port map (
        clk       => clk_25mhz,
        rst       => rst,
        game_tick => game_tick_play,
        next_level=> next_level,
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
        MAX_LENGTH  => MAX_LEN,
        START_X     => GRID_W-9,       -- 右边偏里一点
        START_Y     => GRID_H/2
    )
    port map (
        clk       => clk_25mhz,
        rst       => rst,
        game_tick => game_tick_play,
        next_level=> next_level,
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
    -- Food controller（红苹果：最多 20 个，内部已经避免墙上生成）
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
    -- 多个 Poison controller（蓝毒苹果），一共 9 个
    ------------------------------------------------------------------
    -- 实例 0
    poison_ctrl_0 : poison_control
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
        poison_x  => poison_x_arr(0),
        poison_y  => poison_y_arr(0),
        p1_poison => p1_poison_vec(0),
        p2_poison => p2_poison_vec(0)
    );

    -- 实例 1
    poison_ctrl_1 : poison_control
    generic map (
        GRID_WIDTH    => GRID_W,
        GRID_HEIGHT   => GRID_H,
        VISIBLE_TICKS => 80,
        HIDDEN_TICKS  => 30,
        SEED          => "1011001100"
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
        poison_x  => poison_x_arr(1),
        poison_y  => poison_y_arr(1),
        p1_poison => p1_poison_vec(1),
        p2_poison => p2_poison_vec(1)
    );

    -- 实例 2
    poison_ctrl_2 : poison_control
    generic map (
        GRID_WIDTH    => GRID_W,
        GRID_HEIGHT   => GRID_H,
        VISIBLE_TICKS => 80,
        HIDDEN_TICKS  => 30,
        SEED          => "0110011001"
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
        poison_x  => poison_x_arr(2),
        poison_y  => poison_y_arr(2),
        p1_poison => p1_poison_vec(2),
        p2_poison => p2_poison_vec(2)
    );

    -- 实例 3
    poison_ctrl_3 : poison_control
    generic map (
        GRID_WIDTH    => GRID_W,
        GRID_HEIGHT   => GRID_H,
        VISIBLE_TICKS => 80,
        HIDDEN_TICKS  => 30,
        SEED          => "0011110001"
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
        poison_x  => poison_x_arr(3),
        poison_y  => poison_y_arr(3),
        p1_poison => p1_poison_vec(3),
        p2_poison => p2_poison_vec(3)
    );

    -- 实例 4
    poison_ctrl_4 : poison_control
    generic map (
        GRID_WIDTH    => GRID_W,
        GRID_HEIGHT   => GRID_H,
        VISIBLE_TICKS => 80,
        HIDDEN_TICKS  => 30,
        SEED          => "0101010101"
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
        poison_x  => poison_x_arr(4),
        poison_y  => poison_y_arr(4),
        p1_poison => p1_poison_vec(4),
        p2_poison => p2_poison_vec(4)
    );

    -- 实例 5
    poison_ctrl_5 : poison_control
    generic map (
        GRID_WIDTH    => GRID_W,
        GRID_HEIGHT   => GRID_H,
        VISIBLE_TICKS => 80,
        HIDDEN_TICKS  => 30,
        SEED          => "1110001110"
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
        poison_x  => poison_x_arr(5),
        poison_y  => poison_y_arr(5),
        p1_poison => p1_poison_vec(5),
        p2_poison => p2_poison_vec(5)
    );

    -- 实例 6
    poison_ctrl_6 : poison_control
    generic map (
        GRID_WIDTH    => GRID_W,
        GRID_HEIGHT   => GRID_H,
        VISIBLE_TICKS => 80,
        HIDDEN_TICKS  => 30,
        SEED          => "1001100110"
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
        poison_x  => poison_x_arr(6),
        poison_y  => poison_y_arr(6),
        p1_poison => p1_poison_vec(6),
        p2_poison => p2_poison_vec(6)
    );

    -- 实例 7
    poison_ctrl_7 : poison_control
    generic map (
        GRID_WIDTH    => GRID_W,
        GRID_HEIGHT   => GRID_H,
        VISIBLE_TICKS => 80,
        HIDDEN_TICKS  => 30,
        SEED          => "0011001100"
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
        poison_x  => poison_x_arr(7),
        poison_y  => poison_y_arr(7),
        p1_poison => p1_poison_vec(7),
        p2_poison => p2_poison_vec(7)
    );

    -- 实例 8
    poison_ctrl_8 : poison_control
    generic map (
        GRID_WIDTH    => GRID_W,
        GRID_HEIGHT   => GRID_H,
        VISIBLE_TICKS => 80,
        HIDDEN_TICKS  => 30,
        SEED          => "0100100110"
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
        poison_x  => poison_x_arr(8),
        poison_y  => poison_y_arr(8),
        p1_poison => p1_poison_vec(8),
        p2_poison => p2_poison_vec(8)
    );

    ------------------------------------------------------------------
    -- 把多个 p?_poison_vec OR 成一个信号，只看前 active_poison_count 个
    ------------------------------------------------------------------
    process(p1_poison_vec, p2_poison_vec, active_poison_count)
        variable p1_or, p2_or : std_logic;
        variable i            : integer;
    begin
        p1_or := '0';
        p2_or := '0';
        for i in 0 to 8 loop
            exit when i >= active_poison_count;
            if p1_poison_vec(i) = '1' then
                p1_or := '1';
            end if;
            if p2_poison_vec(i) = '1' then
                p2_or := '1';
            end if;
        end loop;
        p1_poison <= p1_or;
        p2_poison <= p2_or;
    end process;

    ------------------------------------------------------------------
    -- Wall instance（5 张地图 + 外边框）
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
    -- Grid calculation：像素 -> 格子坐标
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
    -- Object detection：当前格子是不是蛇/苹果/毒苹果
    ------------------------------------------------------------------
    process(clk_25mhz)
        variable any_poison : std_logic;
        variable i          : integer;
    begin
        if rising_edge(clk_25mhz) then
            -- 蛇身体
            pixel_p1 <= p1_is_body;
            pixel_p2 <= p2_is_body;

            -- 红苹果
            if (grid_x = food_x and grid_y = food_y) then
                pixel_food <= '1';
            else
                pixel_food <= '0';
            end if;

            -- 多个蓝毒苹果
            any_poison := '0';
            for i in 0 to 8 loop
                exit when i >= active_poison_count;
                if (grid_x = poison_x_arr(i)) and (grid_y = poison_y_arr(i)) then
                    any_poison := '1';
                end if;
            end loop;
            pixel_poison <= any_poison;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Game state & mutual collision + 满长度获胜 + 5局 + 死亡次数>=10直接输
    ------------------------------------------------------------------
    process(clk_25mhz)
        variable k           : integer;
        variable seg_x       : integer range 0 to GRID_W-1;
        variable seg_y       : integer range 0 to GRID_H-1;
        variable p1_dead_v   : std_logic;
        variable p2_dead_v   : std_logic;
        variable p1_hit_other: std_logic;
        variable p2_hit_other: std_logic;
        variable base        : integer;
        variable p1_full_v   : std_logic;
        variable p2_full_v   : std_logic;

        variable p1_deaths_next    : unsigned(3 downto 0);
        variable p2_deaths_next    : unsigned(3 downto 0);
        variable p1_round_next     : unsigned(2 downto 0);
        variable p2_round_next     : unsigned(2 downto 0);
        variable round_count_next  : unsigned(2 downto 0);

        variable round_end    : boolean;
        variable round_win_id : integer range -1 to 2; -- -1:平局, 0:P1, 1:P2, 2:无
    begin
        if rising_edge(clk_25mhz) then
            if rst = '1' then
                game_state   <= ROUND_SHOW;         -- 上电先显示 ROUND1
                num_level    <= (others => '0');    -- Round1
                round_timer  <= (others => '0');
                p1_round_wins <= (others => '0');
                p2_round_wins <= (others => '0');
                p1_deaths     <= (others => '0');
                p2_deaths     <= (others => '0');
                round_count   <= (others => '0');
                match_over    <= '0';
            else
                -- 1) ROUND_SHOW：只显示关卡，延时后进入 PLAYING（比赛未结束时）
                if game_state = ROUND_SHOW then
                    if match_over = '1' then
                        -- 比赛已经结束，则保持后面 MATCH 画面，不再进入 PLAYING
                        game_state <= game_state;
                    else
                        if frame = '1' then  -- 每帧加一
                            if round_timer < to_unsigned(60, 8) then  -- ~60 帧 ≈ 1 秒
                                round_timer <= round_timer + 1;
                            else
                                round_timer <= (others => '0');
                                game_state  <= PLAYING;
                            end if;
                        end if;
                    end if;

                -- 2) PLAYING：正常判断碰撞、长度、关卡
                elsif (game_state = PLAYING) and (game_tick = '1') then
                    p1_dead_v    := p1_collision;
                    p2_dead_v    := p2_collision;
                    p1_hit_other := '0';
                    p2_hit_other := '0';

                    -- P1 头撞 P2 身体
                    for k in 0 to MAX_LEN-1 loop
                        exit when k >= p2_length;
                        base  := k*12;
                        seg_x := to_integer(unsigned(p2_body_x_flat(base+11 downto base)));
                        seg_y := to_integer(unsigned(p2_body_y_flat(base+11 downto base)));
                        if (seg_x = p1_head_x) and (seg_y = p1_head_y) then
                            p1_hit_other := '1';
                        end if;
                    end loop;

                    -- P2 头撞 P1 身体
                    for k in 0 to MAX_LEN-1 loop
                        exit when k >= p1_length;
                        base  := k*12;
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

                    -- 蛇长度为 0 也算死亡
                    if p1_length = 0 then
                        p1_dead_v := '1';
                    end if;
                    if p2_length = 0 then
                        p2_dead_v := '1';
                    end if;

                    -- 满长度标志
                    p1_full_v := '0';
                    p2_full_v := '0';
                    if p1_length = MAX_LEN then
                        p1_full_v := '1';
                    end if;
                    if p2_length = MAX_LEN then
                        p2_full_v := '1';
                    end if;

                    -- 判断本局结果（round_end & round_win_id）
                    round_end    := false;
                    round_win_id := 2;  -- 暂无

                    -- 先看"长满获胜"
                    if (p1_full_v = '1') and (p2_full_v = '0') then
                        round_end    := true;
                        round_win_id := 0;     -- P1 赢
                        game_state   <= P1_WIN;
                    elsif (p2_full_v = '1') and (p1_full_v = '0') then
                        round_end    := true;
                        round_win_id := 1;     -- P2 赢
                        game_state   <= P2_WIN;
                    elsif (p1_full_v = '1') and (p2_full_v = '1') then
                        round_end    := true;
                        round_win_id := -1;    -- 平局
                        game_state   <= TIE;

                    -- 再看死亡
                    elsif (p1_dead_v = '1') and (p2_dead_v = '0') then
                        round_end    := true;
                        round_win_id := 1;     -- P2 赢
                        game_state   <= P2_WIN;
                    elsif (p2_dead_v = '1') and (p1_dead_v = '0') then
                        round_end    := true;
                        round_win_id := 0;     -- P1 赢
                        game_state   <= P1_WIN;
                    elsif (p1_dead_v = '1') and (p2_dead_v = '1') then
                        round_end    := true;
                        round_win_id := -1;    -- 平局
                        game_state   <= TIE;
                    else
                        game_state <= PLAYING;
                    end if;

                    -- 如果本局结束，更新统计 & 判断是否整场比赛结束
                    if round_end = true then
                        p1_deaths_next   := p1_deaths;
                        p2_deaths_next   := p2_deaths;
                        p1_round_next    := p1_round_wins;
                        p2_round_next    := p2_round_wins;
                        round_count_next := round_count + 1;

                        -- 死亡次数：谁在这一局中死了就 +1
                        if p1_dead_v = '1' then
                            p1_deaths_next := p1_deaths_next + 1;
                        end if;
                        if p2_dead_v = '1' then
                            p2_deaths_next := p2_deaths_next + 1;
                        end if;

                        -- 胜场：谁赢这一局就 +1
                        if round_win_id = 0 then
                            p1_round_next := p1_round_next + 1;
                        elsif round_win_id = 1 then
                            p2_round_next := p2_round_next + 1;
                        end if;

                        -- 默认认为比赛还没结束
                        -- 然后检查：
                        -- 1) 已经打完 5 局；或
                        -- 2) p1_deaths_next >=10；或
                        -- 3) p2_deaths_next >=10
                        if (round_count_next >= to_unsigned(5, 3)) or
                           (p1_deaths_next >= to_unsigned(10, 4)) or
                           (p2_deaths_next >= to_unsigned(10, 4)) then
                            match_over <= '1';

                            -- 决定整场比赛最终 winner，用 game_state 显示：
                            if (p1_deaths_next >= to_unsigned(10, 4)) and 
                               (p2_deaths_next <  to_unsigned(10, 4)) then
                                -- P1 死亡 >=10 次，P2 获胜
                                game_state <= P2_WIN;
                            elsif (p2_deaths_next >= to_unsigned(10, 4)) and 
                                  (p1_deaths_next <  to_unsigned(10, 4)) then
                                -- P2 死亡 >=10 次，P1 获胜
                                game_state <= P1_WIN;
                            else
                                -- 死亡都没到 10 或同时到 10，按胜场比较
                                if p1_round_next > p2_round_next then
                                    game_state <= P1_WIN;
                                elsif p2_round_next > p1_round_next then
                                    game_state <= P2_WIN;
                                else
                                    game_state <= TIE;
                                end if;
                            end if;
                        else
                            -- 比赛还没结束，可以继续下一局
                            num_level <= num_level + 1;
                        end if;

                        -- 写回统计寄存器
                        p1_deaths     <= p1_deaths_next;
                        p2_deaths     <= p2_deaths_next;
                        p1_round_wins <= p1_round_next;
                        p2_round_wins <= p2_round_next;
                        round_count   <= round_count_next;
                    end if; -- round_end

                -- 3) WIN / TIE：若比赛未结束，等待 next_level，进入下一局 ROUND_SHOW
                elsif (game_state = P1_WIN or game_state = P2_WIN or game_state = TIE) then
                    if (match_over = '0') then
                        if next_level = '1' then
                            game_state  <= ROUND_SHOW;
                            round_timer <= (others => '0');
                        end if;
                    else
                        -- match_over=1 时，停留在最终 winner 画面
                        game_state <= game_state;
                    end if;
                end if; -- state cases
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Color generation：包括 ROUND 展示 + 游戏中 + 最终 GAME OVER
    ------------------------------------------------------------------
    process(clk_25mhz)
        variable round_int : integer;
        variable lx        : integer;
    begin
        if rising_edge(clk_25mhz) then
            if game_state = ROUND_SHOW then
                -- 当前 Round = num_level + 1，最多显示到 5
                round_int := to_integer(num_level) + 1;
                if round_int > 5 then
                    round_int := 5;
                end if;

                -- 背景黑
                color_r <= "00";
                color_g <= "00";
                color_b <= "00";

                -- 在屏幕中间画 1~5 根竖条来表示 Round 数
                if (grid_y >= 8) and (grid_y <= GRID_H-8) then
                    -- 把 x 平移到中间附近（大概 5 根条拼在一起）
                    lx := grid_x - (GRID_W/2 - 10);

                    -- 每根条宽度 2~3 格，中间隔 1 格
                    -- 第 1 根
                    if (round_int >= 1) and (lx >= 0) and (lx <= 2) then
                        color_r <= "00";  -- 青色条
                        color_g <= "11";
                        color_b <= "11";

                    -- 第 2 根
                    elsif (round_int >= 2) and (lx >= 4) and (lx <= 6) then
                        color_r <= "00";
                        color_g <= "11";
                        color_b <= "11";

                    -- 第 3 根
                    elsif (round_int >= 3) and (lx >= 8) and (lx <= 10) then
                        color_r <= "00";
                        color_g <= "11";
                        color_b <= "11";

                    -- 第 4 根
                    elsif (round_int >= 4) and (lx >= 12) and (lx <= 14) then
                        color_r <= "00";
                        color_g <= "11";
                        color_b <= "11";

                    -- 第 5 根
                    elsif (round_int >= 5) and (lx >= 16) and (lx <= 18) then
                        color_r <= "00";
                        color_g <= "11";
                        color_b <= "11";
                    end if;
                end if;

            elsif game_state = PLAYING then
                -- 正常游戏画面
                if pixel_p1 = '1' then
                    color_r <= "00";  -- Green (P1)
                    color_g <= "11";
                    color_b <= "00";
                elsif pixel_p2 = '1' then
                    color_r <= "11";  -- Yellow (P2)
                    color_g <= "11";
                    color_b <= "00";
                elsif pixel_food = '1' then
                    color_r <= "11";  -- Red (苹果)
                    color_g <= "00";
                    color_b <= "00";
                elsif pixel_poison = '1' then
                    color_r <= "00";  -- Blue (毒苹果)
                    color_g <= "00";
                    color_b <= "11";
                elsif pixel_wall = '1' then
                    color_r <= "01";  -- Gray (墙)
                    color_g <= "01";
                    color_b <= "01";
                else
                    color_r <= "11";  -- 背景白一点，方便看
                    color_g <= "11";
                    color_b <= "11";
                end if;

            else
                -- GAME OVER 画面：上半屏红，下半屏胜者颜色（既用于每局结束也用于整场结束）
                if grid_y < GRID_H/2 then
                    color_r <= "11";  -- red banner
                    color_g <= "00";
                    color_b <= "00";
                else
                    case game_state is
                        when P1_WIN =>
                            color_r <= "00";  -- P1 green
                            color_g <= "11";
                            color_b <= "00";
                        when P2_WIN =>
                            color_r <= "11";  -- P2 yellow
                            color_g <= "11";
                            color_b <= "00";
                        when TIE =>
                            color_r <= "11";  -- white
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
