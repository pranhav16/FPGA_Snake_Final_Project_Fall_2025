library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity snake_control is
    generic (
        GRID_WIDTH  : integer := 40;
        GRID_HEIGHT : integer := 30;
        MAX_LENGTH  : integer := 16  -- Small fixed size for efficiency
    );
    Port ( 
        clk : in std_logic;
        rst : in std_logic;
        game_tick : in std_logic;
        
        -- Button inputs (active low)
        btn_up : in std_logic;
        btn_down : in std_logic;
        btn_left : in std_logic;
        btn_right : in std_logic;
        
        -- Growth signal
        grow : in std_logic;
        
        -- Snake head position
        snake_head_x_o : out integer range 0 to GRID_WIDTH-1;
        snake_head_y_o : out integer range 0 to GRID_HEIGHT-1;
        
        -- Query interface (registered for timing)
        query_x : in integer range 0 to GRID_WIDTH-1;
        query_y : in integer range 0 to GRID_HEIGHT-1;
        is_body : out std_logic;
        
        -- Status outputs
        snake_length_o : out integer range 0 to MAX_LENGTH;
        self_collision : out std_logic
    );
end snake_control;

architecture arch of snake_control is

    type direction_type is (DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT);
    signal snake_dir : direction_type := DIR_RIGHT;
    signal snake_next_dir : direction_type := DIR_RIGHT;
    
    -- Body storage: packed [Y(5:0), X(5:0)] = 12 bits per segment
    type body_mem_type is array (0 to MAX_LENGTH-1) of std_logic_vector(11 downto 0);
    signal body_x : body_mem_type;
    signal body_y : body_mem_type;
    
    -- Force Block RAM
    attribute ram_style : string;
    attribute ram_style of body_x : signal is "block";
    attribute ram_style of body_y : signal is "block";
    
    signal snake_length : integer range 0 to MAX_LENGTH := 3;
    signal head_idx : integer range 0 to MAX_LENGTH-1 := 2;
    signal grow_pending : std_logic := '0';
    
    signal head_x : integer range 0 to GRID_WIDTH-1 := 20;
    signal head_y : integer range 0 to GRID_HEIGHT-1 := 15;
    
    signal collision : std_logic := '0';
    
    -- Query result (pipelined)
    signal query_result : std_logic := '0';

begin

    ------------------------------------------------------------------
    -- Direction control
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
        variable nx, ny : integer range 0 to GRID_WIDTH-1;
        variable new_idx : integer range 0 to MAX_LENGTH-1;
        variable hit : std_logic;
        variable seg_x, seg_y : integer range 0 to GRID_WIDTH-1;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                head_x <= 20;
                head_y <= 15;
                snake_dir <= DIR_RIGHT;
                snake_length <= 3;
                head_idx <= 2;
                grow_pending <= '0';
                collision <= '0';
                
                -- Initialize snake body
                body_x(0) <= std_logic_vector(to_unsigned(18, 12));
                body_y(0) <= std_logic_vector(to_unsigned(15, 12));
                body_x(1) <= std_logic_vector(to_unsigned(19, 12));
                body_y(1) <= std_logic_vector(to_unsigned(15, 12));
                body_x(2) <= std_logic_vector(to_unsigned(20, 12));
                body_y(2) <= std_logic_vector(to_unsigned(15, 12));
                
            elsif game_tick = '1' then
                snake_dir <= snake_next_dir;
                
                -- Calculate new position
                nx := head_x;
                ny := head_y;
                
                case snake_next_dir is
                    when DIR_UP =>
                        if head_y > 0 then
                            ny := head_y - 1;
                        else
                            ny := GRID_HEIGHT - 1;
                        end if;
                    when DIR_DOWN =>
                        if head_y < GRID_HEIGHT-1 then
                            ny := head_y + 1;
                        else
                            ny := 0;
                        end if;
                    when DIR_LEFT =>
                        if head_x > 0 then
                            nx := head_x - 1;
                        else
                            nx := GRID_WIDTH - 1;
                        end if;
                    when DIR_RIGHT =>
                        if head_x < GRID_WIDTH-1 then
                            nx := head_x + 1;
                        else
                            nx := 0;
                        end if;
                end case;
                
                -- Check self-collision (only check first few segments for speed)
                hit := '0';
                for i in 0 to 15 loop  -- Only check first 8 segments
                    if i < snake_length then
                        seg_x := to_integer(unsigned(body_x(i)));
                        seg_y := to_integer(unsigned(body_y(i)));
                        if seg_x = nx and seg_y = ny then
                            hit := '1';
                        end if;
                    end if;
                end loop;
                
                collision <= hit;
                
                -- Move if no collision
                if hit = '0' then
                    -- Calculate new index
                    if head_idx < MAX_LENGTH-1 then
                        new_idx := head_idx + 1;
                    else
                        new_idx := 0;
                    end if;
                    
                    body_x(new_idx) <= std_logic_vector(to_unsigned(nx, 12));
                    body_y(new_idx) <= std_logic_vector(to_unsigned(ny, 12));
                    
                    head_x <= nx;
                    head_y <= ny;
                    head_idx <= new_idx;
                    
                    -- Growth logic
                    if grow = '1' or grow_pending = '1' then
                        if snake_length < MAX_LENGTH then
                            snake_length <= snake_length + 1;
                        end if;
                        grow_pending <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    ------------------------------------------------------------------
    -- Query handler (simplified - only checks a subset)
    ------------------------------------------------------------------
    process(clk)
        variable found : std_logic;
        variable idx : integer range 0 to MAX_LENGTH-1;
        variable check_x, check_y : integer range 0 to GRID_WIDTH-1;
    begin
        if rising_edge(clk) then
            found := '0';
            
            -- Only check visible segments (not whole array)
            for i in 0 to 15 loop
                if i < snake_length then
                    if head_idx >= i then
                        idx := head_idx - i;
                    else
                        idx := MAX_LENGTH + head_idx - i;
                    end if;
                    
                    check_x := to_integer(unsigned(body_x(idx)));
                    check_y := to_integer(unsigned(body_y(idx)));
                    
                    if check_x = query_x and check_y = query_y then
                        found := '1';
                    end if;
                end if;
            end loop;
            
            query_result <= found;
        end if;
    end process;
    
    ------------------------------------------------------------------
    -- Outputs
    ------------------------------------------------------------------
    snake_head_x_o <= head_x;
    snake_head_y_o <= head_y;
    snake_length_o <= snake_length;
    self_collision <= collision;
    is_body <= query_result;
    
end arch;