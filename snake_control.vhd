library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity snake_control is
    generic (
        GRID_WIDTH  : integer := 40;
        GRID_HEIGHT : integer := 30;
        MAX_LENGTH  : integer := 16;
        START_X     : integer := 10;  -- spawn X
        START_Y     : integer := 15   -- spawn Y
    );
    Port ( 
        clk       : in std_logic;
        rst       : in std_logic;
        game_tick : in std_logic;
        
        -- Button inputs (active low)
        btn_up    : in std_logic;
        btn_down  : in std_logic;
        btn_left  : in std_logic;
        btn_right : in std_logic;
        
        -- Length change
        grow   : in std_logic;  -- normal apple
        shrink : in std_logic;  -- poison apple

        -- Dynamic random-wall geometry (from wall_field)
        w1_x0_i        : in integer range 0 to GRID_WIDTH-1;
        w1_y0_i        : in integer range 0 to GRID_HEIGHT-1;
        w1_orient_i    : in std_logic;
        w2_x0_i        : in integer range 0 to GRID_WIDTH-1;
        w2_y0_i        : in integer range 0 to GRID_HEIGHT-1;
        w2_orient_i    : in std_logic;
        w3_x0_i        : in integer range 0 to GRID_WIDTH-1;
        w3_y0_i        : in integer range 0 to GRID_HEIGHT-1;
        w3_orient_i    : in std_logic;
        walls_solid_i  : in std_logic;
        
        -- Snake head position
        snake_head_x_o : out integer range 0 to GRID_WIDTH-1;
        snake_head_y_o : out integer range 0 to GRID_HEIGHT-1;
        
        -- Query interface (for VGA)
        query_x : in integer range 0 to GRID_WIDTH-1;
        query_y : in integer range 0 to GRID_HEIGHT-1;
        is_body : out std_logic;
        
        -- Status outputs
        snake_length_o : out integer range 0 to MAX_LENGTH;
        self_collision : out std_logic;   --撞墙 + 自撞

        -- Body flattened (for top-level to check hit other snake body)
        body_x_flat_o : out std_logic_vector(MAX_LENGTH*12-1 downto 0);
        body_y_flat_o : out std_logic_vector(MAX_LENGTH*12-1 downto 0)
    );
end snake_control;

architecture arch of snake_control is

    type direction_type is (DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT);
    signal snake_dir      : direction_type := DIR_RIGHT;
    signal snake_next_dir : direction_type := DIR_RIGHT;
    
    -- Body arrays
    type body_x_array is array (0 to MAX_LENGTH-1) of integer range 0 to GRID_WIDTH-1;
    type body_y_array is array (0 to MAX_LENGTH-1) of integer range 0 to GRID_HEIGHT-1;
    signal body_x : body_x_array;
    signal body_y : body_y_array;
    
    signal snake_length : integer range 0 to MAX_LENGTH := 3;
    signal head_idx     : integer range 0 to MAX_LENGTH-1 := 2;  -- circular buffer head index
    
    signal grow_pending   : std_logic := '0';
    signal shrink_pending : std_logic := '0';
    
    signal head_x : integer range 0 to GRID_WIDTH-1  := START_X;
    signal head_y : integer range 0 to GRID_HEIGHT-1 := START_Y;
    
    signal collision    : std_logic := '0';
    signal query_result : std_logic := '0';

    signal body_x_flat : std_logic_vector(MAX_LENGTH*12-1 downto 0);
    signal body_y_flat : std_logic_vector(MAX_LENGTH*12-1 downto 0);

    -- Test next cell for wall (border + random walls in solid phase)
    function is_wall_cell(
        x : integer;
        y : integer;
        w1_x0   : integer;
        w2_x0   : integer;
        w3_x0   : integer;
        w1_y0   : integer;
        w2_y0   : integer;
        w3_y0   : integer;
        w1_or   : std_logic;
        w2_or   : std_logic;
        w3_or   : std_logic;
        walls_s : std_logic
    ) return boolean is
    begin
        -- border (always a hard wall)
        if (x = 0) or (y = 0) or
           (x = GRID_WIDTH-1) or (y = GRID_HEIGHT-1) then
            return true;
        end if;

        -- Dynamic random walls only when in solid (VISIBLE) phase
        if walls_s = '1' then
            -- Wall 1
            if w1_or = '0' then
                if (y = w1_y0) and (x >= w1_x0) and (x <= w1_x0 + 4) then
                    return true;
                end if;
            else
                if (x = w1_x0) and (y >= w1_y0) and (y <= w1_y0 + 4) then
                    return true;
                end if;
            end if;

            -- Wall 2
            if w2_or = '0' then
                if (y = w2_y0) and (x >= w2_x0) and (x <= w2_x0 + 4) then
                    return true;
                end if;
            else
                if (x = w2_x0) and (y >= w2_y0) and (y <= w2_y0 + 4) then
                    return true;
                end if;
            end if;

            -- Wall 3
            if w3_or = '0' then
                if (y = w3_y0) and (x >= w3_x0) and (x <= w3_x0 + 4) then
                    return true;
                end if;
            else
                if (x = w3_x0) and (y >= w3_y0) and (y <= w3_y0 + 4) then
                    return true;
                end if;
            end if;
        end if;

        return false;
    end function;

begin

    ------------------------------------------------------------------
    -- Direction control（禁止直接 180° 掉头）
    ------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                snake_next_dir <= DIR_RIGHT;
            elsif btn_up = '0' and snake_dir /= DIR_DOWN then
                snake_next_dir <= DIR_UP;
            elsif btn_down = '0' and snake_dir /= DIR_UP then
                snake_next_dir <= DIR_DOWN;
            elsif btn_left = '0' and snake_dir /= DIR_RIGHT then
                snake_next_dir <= DIR_LEFT;
            elsif btn_right = '0' and snake_dir /= DIR_LEFT then
                snake_next_dir <= DIR_RIGHT;
            end if;
        end if;
    end process;
    
    ------------------------------------------------------------------
    -- Main game logic
    ------------------------------------------------------------------
    process(clk)
        variable nx       : integer range 0 to GRID_WIDTH-1;
        variable ny       : integer range 0 to GRID_HEIGHT-1;
        variable new_idx  : integer range 0 to MAX_LENGTH-1;
        variable hit      : std_logic;
        variable seg_x    : integer range 0 to GRID_WIDTH-1;
        variable seg_y    : integer range 0 to GRID_HEIGHT-1;
        variable hit_wall : std_logic;
        variable idx      : integer range 0 to MAX_LENGTH-1;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                head_x        <= START_X;
                head_y        <= START_Y;
                snake_dir     <= DIR_RIGHT;
                snake_length  <= 3;
                head_idx      <= 2;
                grow_pending   <= '0';
                shrink_pending <= '0';
                collision     <= '0';
                
                -- initial 3-segment body going right
                body_x(0) <= START_X-2; body_y(0) <= START_Y;
                body_x(1) <= START_X-1; body_y(1) <= START_Y;
                body_x(2) <= START_X;   body_y(2) <= START_Y;
                
            else
                -- latch grow/shrink events
                if grow = '1' then
                    grow_pending <= '1';
                end if;
                if shrink = '1' then
                    shrink_pending <= '1';
                end if;
                
                if game_tick = '1' then
                    -- update direction
                    snake_dir <= snake_next_dir;
                    
                    -- candidate new head position
                    nx := head_x;
                    ny := head_y;
                    
                    case snake_next_dir is
                        when DIR_UP =>
                            if head_y > 0 then
                                ny := head_y - 1;
                            end if;
                        when DIR_DOWN =>
                            if head_y < GRID_HEIGHT-1 then
                                ny := head_y + 1;
                            end if;
                        when DIR_LEFT =>
                            if head_x > 0 then
                                nx := head_x - 1;
                            end if;
                        when DIR_RIGHT =>
                            if head_x < GRID_WIDTH-1 then
                                nx := head_x + 1;
                            end if;
                    end case;
                    
                    -- wall hit? (border + random walls in solid phase)
                    if is_wall_cell(
                        nx, ny,
                        w1_x0_i, w2_x0_i, w3_x0_i,
                        w1_y0_i, w2_y0_i, w3_y0_i,
                        w1_orient_i, w2_orient_i, w3_orient_i,
                        walls_solid_i
                    ) then
                        hit_wall := '1';
                    else
                        hit_wall := '0';
                    end if;

                    -- self collision: check all body segments
                    hit := '0';
                    for i in 0 to MAX_LENGTH-1 loop
                        exit when i >= snake_length;
                        if head_idx >= i then
                            idx := head_idx - i;
                        else
                            idx := head_idx + MAX_LENGTH - i;
                        end if;
                        seg_x := body_x(idx);
                        seg_y := body_y(idx);
                        if (seg_x = nx) and (seg_y = ny) then
                            hit := '1';
                        end if;
                    end loop;

                    if hit_wall = '1' then
                        hit := '1';
                    end if;

                    collision <= hit;
                    
                    -- move only if no collision
                    if hit = '0' then
                        -- compute new head index in circular buffer
                        if head_idx < MAX_LENGTH-1 then
                            new_idx := head_idx + 1;
                        else
                            new_idx := 0;
                        end if;
                        
                        body_x(new_idx) <= nx;
                        body_y(new_idx) <= ny;
                        
                        head_x   <= nx;
                        head_y   <= ny;
                        head_idx <= new_idx;
                        
                        -- length change
                        if (grow_pending = '1') and (shrink_pending = '0') then
                            if snake_length < MAX_LENGTH then
                                snake_length <= snake_length + 1;
                            end if;
                            grow_pending   <= '0';
                        elsif (shrink_pending = '1') and (grow_pending = '0') then
                            if snake_length > 1 then
                                snake_length <= snake_length - 1;
                            end if;
                            shrink_pending <= '0';
                        else
                            -- both hit -> cancel
                            grow_pending   <= '0';
                            shrink_pending <= '0';
                        end if;
                    end if; -- hit=0
                end if; -- game_tick
            end if; -- rst
        end if; -- rising_edge
    end process;
    
    ------------------------------------------------------------------
    -- Query handler：给 VGA 看"这个格是不是蛇身"
    ------------------------------------------------------------------
    process(clk)
        variable found    : std_logic;
        variable idx      : integer range 0 to MAX_LENGTH-1;
        variable check_x  : integer range 0 to GRID_WIDTH-1;
        variable check_y  : integer range 0 to GRID_HEIGHT-1;
    begin
        if rising_edge(clk) then
            found := '0';
            
            for i in 0 to MAX_LENGTH-1 loop
                exit when i >= snake_length;
                if head_idx >= i then
                    idx := head_idx - i;
                else
                    idx := head_idx + MAX_LENGTH - i;
                end if;
                check_x := body_x(idx);
                check_y := body_y(idx);
                if (check_x = query_x) and (check_y = query_y) then
                    found := '1';
                end if;
            end loop;
            
            query_result <= found;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Flatten body arrays for top-level usage
    ------------------------------------------------------------------
    process(body_x, body_y, snake_length, head_idx)
        variable xf, yf : std_logic_vector(MAX_LENGTH*12-1 downto 0);
        variable base   : integer;
        variable idx    : integer;
    begin
        xf := (others => '0');
        yf := (others => '0');
        for i in 0 to MAX_LENGTH-1 loop
            base := i * 12;
            if i < snake_length then
                if head_idx >= i then
                    idx := head_idx - i;
                else
                    idx := head_idx + MAX_LENGTH - i;
                end if;
                xf(base+11 downto base) := std_logic_vector(to_unsigned(body_x(idx), 12));
                yf(base+11 downto base) := std_logic_vector(to_unsigned(body_y(idx), 12));
            else
                xf(base+11 downto base) := (others => '0');
                yf(base+11 downto base) := (others => '0');
            end if;
        end loop;
        body_x_flat <= xf;
        body_y_flat <= yf;
    end process;

    body_x_flat_o <= body_x_flat;
    body_y_flat_o <= body_y_flat;
    
    ------------------------------------------------------------------
    -- Outputs
    ------------------------------------------------------------------
    snake_head_x_o <= head_x;
    snake_head_y_o <= head_y;
    snake_length_o <= snake_length;
    self_collision <= collision;
    is_body        <= query_result;
    
end arch;
