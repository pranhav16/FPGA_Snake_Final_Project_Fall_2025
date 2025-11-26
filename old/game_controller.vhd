library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.snake_game_pkg.all;

entity game_controller is
    Port (
        clk : in std_logic;
        rst : in std_logic;
        -- Player 1 controls (buttons)
        p1_up : in std_logic;
        p1_down : in std_logic;
        p1_left : in std_logic;
        p1_right : in std_logic;
        -- Player 2 controls
        p2_up : in std_logic;
        p2_down : in std_logic;
        p2_left : in std_logic;
        p2_right : in std_logic;
        -- Game state outputs
        snake1_body : out snake_body_array;
        snake1_length : out integer range 0 to MAX_SNAKE_LENGTH;
        snake2_body : out snake_body_array;
        snake2_length : out integer range 0 to MAX_SNAKE_LENGTH;
        food_pos : out position;
        game_over : out std_logic;
        winner : out std_logic_vector(1 downto 0)  -- 00: none, 01: P1, 10: P2, 11: draw
    );
end game_controller;

architecture Behavioral of game_controller is
    signal snake1 : snake_body_array := (others => (x => 0, y => 0));
    signal snake2 : snake_body_array := (others => (x => 0, y => 0));
    signal s1_len : integer range 0 to MAX_SNAKE_LENGTH := 3;
    signal s2_len : integer range 0 to MAX_SNAKE_LENGTH := 3;
    
    signal s1_dir : std_logic_vector(1 downto 0) := DIR_RIGHT;
    signal s2_dir : std_logic_vector(1 downto 0) := DIR_LEFT;
    
    signal food : position := (x => 20, y => 15);
    
    signal move_counter : integer range 0 to GAME_SPEED := 0;
    signal game_over_i : std_logic := '0';
    signal winner_i : std_logic_vector(1 downto 0) := "00";
    
    -- LFSR for pseudo-random food placement
    signal lfsr : std_logic_vector(15 downto 0) := x"ACE1";
    
begin

    process(clk, rst)
        variable new_head1, new_head2 : position;
        variable collision1, collision2 : std_logic;
        variable food_eaten1, food_eaten2 : std_logic;
    begin
        if rst = '1' then
            -- Initialize snake 1 (player 1 - left side)
            snake1(0) <= (x => 5, y => 15);
            snake1(1) <= (x => 4, y => 15);
            snake1(2) <= (x => 3, y => 15);
            s1_len <= 3;
            s1_dir <= DIR_RIGHT;
            
            -- Initialize snake 2 (player 2 - right side)
            snake2(0) <= (x => 35, y => 15);
            snake2(1) <= (x => 36, y => 15);
            snake2(2) <= (x => 37, y => 15);
            s2_len <= 3;
            s2_dir <= DIR_LEFT;
            
            food <= (x => 20, y => 15);
            move_counter <= 0;
            game_over_i <= '0';
            winner_i <= "00";
            lfsr <= x"ACE1";
            
        elsif rising_edge(clk) then
            
            if game_over_i = '0' then
                -- Handle player 1 direction changes
                if p1_up = '1' and s1_dir /= DIR_DOWN then
                    s1_dir <= DIR_UP;
                elsif p1_down = '1' and s1_dir /= DIR_UP then
                    s1_dir <= DIR_DOWN;
                elsif p1_left = '1' and s1_dir /= DIR_RIGHT then
                    s1_dir <= DIR_LEFT;
                elsif p1_right = '1' and s1_dir /= DIR_LEFT then
                    s1_dir <= DIR_RIGHT;
                end if;
                
                -- Handle player 2 direction changes
                if p2_up = '1' and s2_dir /= DIR_DOWN then
                    s2_dir <= DIR_UP;
                elsif p2_down = '1' and s2_dir /= DIR_UP then
                    s2_dir <= DIR_DOWN;
                elsif p2_left = '1' and s2_dir /= DIR_RIGHT then
                    s2_dir <= DIR_LEFT;
                elsif p2_right = '1' and s2_dir /= DIR_LEFT then
                    s2_dir <= DIR_RIGHT;
                end if;
                
                -- Movement timer
                if move_counter = GAME_SPEED - 1 then
                    move_counter <= 0;
                    
                    -- Calculate new head positions
                    new_head1 := snake1(0);
                    new_head2 := snake2(0);
                    
                    -- Snake 1 movement
                    case s1_dir is
                        when DIR_UP =>
                            if snake1(0).y = 0 then
                                new_head1.y := GRID_HEIGHT - 1;
                            else
                                new_head1.y := snake1(0).y - 1;
                            end if;
                        when DIR_DOWN =>
                            if snake1(0).y = GRID_HEIGHT - 1 then
                                new_head1.y := 0;
                            else
                                new_head1.y := snake1(0).y + 1;
                            end if;
                        when DIR_LEFT =>
                            if snake1(0).x = 0 then
                                new_head1.x := GRID_WIDTH - 1;
                            else
                                new_head1.x := snake1(0).x - 1;
                            end if;
                        when DIR_RIGHT =>
                            if snake1(0).x = GRID_WIDTH - 1 then
                                new_head1.x := 0;
                            else
                                new_head1.x := snake1(0).x + 1;
                            end if;
                        when others =>
                            new_head1 := snake1(0);
                    end case;
                    
                    -- Snake 2 movement
                    case s2_dir is
                        when DIR_UP =>
                            if snake2(0).y = 0 then
                                new_head2.y := GRID_HEIGHT - 1;
                            else
                                new_head2.y := snake2(0).y - 1;
                            end if;
                        when DIR_DOWN =>
                            if snake2(0).y = GRID_HEIGHT - 1 then
                                new_head2.y := 0;
                            else
                                new_head2.y := snake2(0).y + 1;
                            end if;
                        when DIR_LEFT =>
                            if snake2(0).x = 0 then
                                new_head2.x := GRID_WIDTH - 1;
                            else
                                new_head2.x := snake2(0).x - 1;
                            end if;
                        when DIR_RIGHT =>
                            if snake2(0).x = GRID_WIDTH - 1 then
                                new_head2.x := 0;
                            else
                                new_head2.x := snake2(0).x + 1;
                            end if;
                        when others =>
                            new_head2 := snake2(0);
                    end case;
                    
                    -- Check collisions
                    collision1 := '0';
                    collision2 := '0';
                    food_eaten1 := '0';
                    food_eaten2 := '0';
                    
                    -- Check if snake 1 hits itself
                    for i in 1 to s1_len-1 loop
                        if new_head1.x = snake1(i).x and new_head1.y = snake1(i).y then
                            collision1 := '1';
                        end if;
                    end loop;
                    
                    -- Check if snake 2 hits itself
                    for i in 1 to s2_len-1 loop
                        if new_head2.x = snake2(i).x and new_head2.y = snake2(i).y then
                            collision2 := '1';
                        end if;
                    end loop;
                    
                    -- Check if snake 1 hits snake 2's body
                    for i in 0 to s2_len-1 loop
                        if new_head1.x = snake2(i).x and new_head1.y = snake2(i).y then
                            collision1 := '1';
                        end if;
                    end loop;
                    
                    -- Check if snake 2 hits snake 1's body
                    for i in 0 to s1_len-1 loop
                        if new_head2.x = snake1(i).x and new_head2.y = snake1(i).y then
                            collision2 := '1';
                        end if;
                    end loop;
                    
                    -- Check head-to-head collision
                    if new_head1.x = new_head2.x and new_head1.y = new_head2.y then
                        collision1 := '1';
                        collision2 := '1';
                    end if;
                    
                    -- Check food collision
                    if new_head1.x = food.x and new_head1.y = food.y then
                        food_eaten1 := '1';
                    end if;
                    
                    if new_head2.x = food.x and new_head2.y = food.y then
                        food_eaten2 := '1';
                    end if;
                    
                    -- Handle game over
                    if collision1 = '1' or collision2 = '1' then
                        game_over_i <= '1';
                        if collision1 = '1' and collision2 = '1' then
                            winner_i <= "11";  -- Draw
                        elsif collision1 = '1' then
                            winner_i <= "10";  -- Player 2 wins
                        else
                            winner_i <= "01";  -- Player 1 wins
                        end if;
                    else
                        -- Move snake 1
                        for i in s1_len-1 downto 1 loop
                            snake1(i) <= snake1(i-1);
                        end loop;
                        snake1(0) <= new_head1;
                        
                        -- Move snake 2
                        for i in s2_len-1 downto 1 loop
                            snake2(i) <= snake2(i-1);
                        end loop;
                        snake2(0) <= new_head2;
                        
                        -- Handle food
                        if food_eaten1 = '1' or food_eaten2 = '1' then
                            if food_eaten1 = '1' and s1_len < MAX_SNAKE_LENGTH then
                                s1_len <= s1_len + 1;
                            end if;
                            if food_eaten2 = '1' and s2_len < MAX_SNAKE_LENGTH then
                                s2_len <= s2_len + 1;
                            end if;
                            
                            -- Generate new food position using LFSR
                            lfsr <= lfsr(14 downto 0) & (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));
                            food.x <= to_integer(unsigned(lfsr(5 downto 0))) mod GRID_WIDTH;
                            food.y <= to_integer(unsigned(lfsr(10 downto 6))) mod GRID_HEIGHT;
                        end if;
                    end if;
                    
                else
                    move_counter <= move_counter + 1;
                    -- Update LFSR continuously
                    lfsr <= lfsr(14 downto 0) & (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));
                end if;
            end if;
        end if;
    end process;
    
    snake1_body <= snake1;
    snake1_length <= s1_len;
    snake2_body <= snake2;
    snake2_length <= s2_len;
    food_pos <= food;
    game_over <= game_over_i;
    winner <= winner_i;

end Behavioral;
