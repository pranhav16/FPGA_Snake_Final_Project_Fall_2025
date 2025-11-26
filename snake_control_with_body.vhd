library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity snake_control is
    generic (
        GRID_WIDTH  : integer := 40;
        GRID_HEIGHT : integer := 30;
        MAX_LENGTH  : integer := 100  -- Maximum snake length
    );
    Port ( 
        clk : in std_logic;
        rst : in std_logic;
        game_tick : in std_logic;
        
        -- Button inputs
        btn_up : in std_logic;
        btn_down : in std_logic;
        btn_left : in std_logic;
        btn_right : in std_logic;
        
        -- Growth signal (when food is eaten)
        grow : in std_logic;
        
        -- Snake head position output
        snake_head_x_o : out integer range 0 to GRID_WIDTH-1;
        snake_head_y_o : out integer range 0 to GRID_HEIGHT-1;
        
        -- Snake body query interface
        query_x : in integer range 0 to GRID_WIDTH-1;
        query_y : in integer range 0 to GRID_HEIGHT-1;
        is_body : out std_logic;
        
        -- Snake length
        snake_length_o : out integer range 0 to MAX_LENGTH;
        
        -- Collision detection outputs
        self_collision : out std_logic;
        wall_collision : out std_logic
    );
end snake_control;

architecture arch of snake_control is

    -- Snake direction type
    type direction_type is (DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT);
    signal snake_dir : direction_type := DIR_RIGHT;
    signal snake_next_dir : direction_type := DIR_RIGHT;
    
    -- Snake body storage (circular buffer)
    type position_array is array (0 to MAX_LENGTH-1) of integer range 0 to GRID_WIDTH-1;
    signal body_x : position_array := (others => 0);
    signal body_y : position_array := (others => 0);
    
    -- Snake management
    signal snake_length : integer range 0 to MAX_LENGTH := 3;  -- Start with length 3
    signal head_index : integer range 0 to MAX_LENGTH-1 := 0;  -- Points to head position in circular buffer
    signal grow_pending : std_logic := '0';  -- Flag to grow on next move
    
    -- Head position (for easier access)
    signal snake_head_x : integer range 0 to GRID_WIDTH-1 := 20;
    signal snake_head_y : integer range 0 to GRID_HEIGHT-1 := 15;
    
    -- Collision flags
    signal self_collision_flag : std_logic := '0';
    signal wall_collision_flag : std_logic := '0';

begin

    ------------------------------------------------------------------
    -- Button input handling (direction control)
    -- Prevents 180-degree turns
    ------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                snake_next_dir <= DIR_RIGHT;
            else
                if btn_up = '0' and snake_dir /= DIR_DOWN then
                    snake_next_dir <= DIR_UP;
                elsif btn_down = '0' and snake_dir /= DIR_UP then
                    snake_next_dir <= DIR_DOWN;
                elsif btn_left = '0' and snake_dir /= DIR_RIGHT then
                    snake_next_dir <= DIR_LEFT;
                elsif btn_right = '0' and snake_dir /= DIR_LEFT then
                    snake_next_dir <= DIR_RIGHT;
                end if;
            end if;
        end if;
    end process;
    
    ------------------------------------------------------------------
    -- Snake movement and body management
    ------------------------------------------------------------------
    process(clk)
        variable new_head_x : integer range 0 to GRID_WIDTH-1;
        variable new_head_y : integer range 0 to GRID_HEIGHT-1;
        variable new_head_index : integer range 0 to MAX_LENGTH-1;
        variable tail_index : integer range 0 to MAX_LENGTH-1;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Reset snake to initial position
                snake_head_x <= 20;
                snake_head_y <= 15;
                snake_dir <= DIR_RIGHT;
                snake_length <= 3;
                head_index <= 2;  -- Start with 3 segments
                grow_pending <= '0';
                self_collision_flag <= '0';
                wall_collision_flag <= '0';
                
                -- Initialize starting body (horizontal line)
                body_x(0) <= 18;  -- Tail
                body_y(0) <= 15;
                body_x(1) <= 19;  -- Middle
                body_y(1) <= 15;
                body_x(2) <= 20;  -- Head
                body_y(2) <= 15;
                
                -- Clear rest of array
                for i in 3 to MAX_LENGTH-1 loop
                    body_x(i) <= 0;
                    body_y(i) <= 0;
                end loop;
                
            elsif game_tick = '1' then
                -- Update direction
                snake_dir <= snake_next_dir;
                
                -- Calculate new head position based on direction
                new_head_x := snake_head_x;
                new_head_y := snake_head_y;
                
                case snake_next_dir is
                    when DIR_UP =>
                        if snake_head_y > 0 then
                            new_head_y := snake_head_y - 1;
                            wall_collision_flag <= '0';
                        else
                            new_head_y := GRID_HEIGHT - 1;  -- Wrap around
                            wall_collision_flag <= '0';
                            -- For wall collision detection, uncomment:
                            -- wall_collision_flag <= '1';
                        end if;
                    when DIR_DOWN =>
                        if snake_head_y < GRID_HEIGHT - 1 then
                            new_head_y := snake_head_y + 1;
                            wall_collision_flag <= '0';
                        else
                            new_head_y := 0;  -- Wrap around
                            wall_collision_flag <= '0';
                            -- For wall collision detection, uncomment:
                            -- wall_collision_flag <= '1';
                        end if;
                    when DIR_LEFT =>
                        if snake_head_x > 0 then
                            new_head_x := snake_head_x - 1;
                            wall_collision_flag <= '0';
                        else
                            new_head_x := GRID_WIDTH - 1;  -- Wrap around
                            wall_collision_flag <= '0';
                            -- For wall collision detection, uncomment:
                            -- wall_collision_flag <= '1';
                        end if;
                    when DIR_RIGHT =>
                        if snake_head_x < GRID_WIDTH - 1 then
                            new_head_x := snake_head_x + 1;
                            wall_collision_flag <= '0';
                        else
                            new_head_x := 0;  -- Wrap around
                            wall_collision_flag <= '0';
                            -- For wall collision detection, uncomment:
                            -- wall_collision_flag <= '1';
                        end if;
                end case;
                
                -- Check for self-collision (new head hits body)
                self_collision_flag <= '0';
                for i in 0 to MAX_LENGTH-1 loop
                    if i < snake_length then
                        -- Calculate actual position in circular buffer
                        if body_x(i) = new_head_x and body_y(i) = new_head_y then
                            self_collision_flag <= '1';
                        end if;
                    end if;
                end loop;
                
                -- Move snake if no collision
                if self_collision_flag = '0' then
                    -- Calculate new head index (circular buffer)
                    if head_index = MAX_LENGTH - 1 then
                        new_head_index := 0;
                    else
                        new_head_index := head_index + 1;
                    end if;
                    
                    -- Add new head position
                    body_x(new_head_index) <= new_head_x;
                    body_y(new_head_index) <= new_head_y;
                    snake_head_x <= new_head_x;
                    snake_head_y <= new_head_y;
                    head_index <= new_head_index;
                    
                    -- Handle growth
                    if grow = '1' then
                        grow_pending <= '1';
                    end if;
                    
                    if grow_pending = '1' then
                        -- Don't remove tail, effectively growing
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
    -- Body query process (check if a grid cell contains snake body)
    ------------------------------------------------------------------
    process(query_x, query_y, body_x, body_y, head_index, snake_length)
        variable idx : integer range 0 to MAX_LENGTH-1;
        variable found : std_logic;
    begin
        found := '0';
        
        -- Check all body segments
        for i in 0 to MAX_LENGTH-1 loop
            -- Calculate actual index in circular buffer
            if i < snake_length then
                if head_index >= i then
                    idx := head_index - i;
                else
                    idx := MAX_LENGTH + head_index - i;
                end if;
                
                -- Check if this segment matches query position
                if body_x(idx) = query_x and body_y(idx) = query_y then
                    found := '1';
                end if;
            end if;
        end loop;
        
        is_body <= found;
    end process;
    
    ------------------------------------------------------------------
    -- Output assignments
    ------------------------------------------------------------------
    snake_head_x_o <= snake_head_x;
    snake_head_y_o <= snake_head_y;
    snake_length_o <= snake_length;
    self_collision <= self_collision_flag;
    wall_collision <= wall_collision_flag;
    
end arch;
