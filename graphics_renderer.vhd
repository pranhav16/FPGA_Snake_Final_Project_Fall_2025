library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.snake_game_pkg.all;

entity graphics_renderer is
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
end graphics_renderer;

architecture Behavioral of graphics_renderer is
    signal grid_x : integer range 0 to GRID_WIDTH-1;
    signal grid_y : integer range 0 to GRID_HEIGHT-1;
    signal is_snake1 : std_logic := '0';
    signal is_snake2 : std_logic := '0';
    signal is_food : std_logic := '0';
    signal is_grid_line : std_logic := '0';
begin

    process(clk)
    begin
        if rising_edge(clk) then
            -- Calculate grid position
            if pixel_x < GRID_WIDTH * CELL_SIZE and pixel_y < GRID_HEIGHT * CELL_SIZE then
                grid_x <= pixel_x / CELL_SIZE;
                grid_y <= pixel_y / CELL_SIZE;
            else
                grid_x <= 0;
                grid_y <= 0;
            end if;
            
            -- Check if current pixel is part of snake 1
            is_snake1 <= '0';
            for i in 0 to MAX_SNAKE_LENGTH-1 loop
                if i < snake1_length then
                    if grid_x = snake1_body(i).x and grid_y = snake1_body(i).y then
                        is_snake1 <= '1';
                    end if;
                end if;
            end loop;
            
            -- Check if current pixel is part of snake 2
            is_snake2 <= '0';
            for i in 0 to MAX_SNAKE_LENGTH-1 loop
                if i < snake2_length then
                    if grid_x = snake2_body(i).x and grid_y = snake2_body(i).y then
                        is_snake2 <= '1';
                    end if;
                end if;
            end loop;
            
            -- Check if current pixel is food
            if grid_x = food_pos.x and grid_y = food_pos.y then
                is_food <= '1';
            else
                is_food <= '0';
            end if;
            
            -- Grid lines (every cell boundary)
            if (pixel_x mod CELL_SIZE = 0) or (pixel_y mod CELL_SIZE = 0) then
                is_grid_line <= '1';
            else
                is_grid_line <= '0';
            end if;
            
            -- Color output
            if video_on = '1' then
                if game_over = '1' then
                    -- Game over screen
                    if winner = "01" then
                        -- Player 1 wins - green screen
                        red <= "0000";
                        green <= "1111";
                        blue <= "0000";
                    elsif winner = "10" then
                        -- Player 2 wins - blue screen
                        red <= "0000";
                        green <= "0000";
                        blue <= "1111";
                    else
                        -- Draw - yellow screen
                        red <= "1111";
                        green <= "1111";
                        blue <= "0000";
                    end if;
                elsif pixel_x >= GRID_WIDTH * CELL_SIZE or pixel_y >= GRID_HEIGHT * CELL_SIZE then
                    -- Outside game area - black
                    red <= "0000";
                    green <= "0000";
                    blue <= "0000";
                elsif is_snake1 = '1' then
                    -- Snake 1 - Green
                    if (pixel_x mod CELL_SIZE) < CELL_SIZE - 1 and 
                       (pixel_y mod CELL_SIZE) < CELL_SIZE - 1 then
                        red <= "0000";
                        green <= "1100";
                        blue <= "0000";
                    else
                        -- Border
                        red <= "0010";
                        green <= "0010";
                        blue <= "0010";
                    end if;
                elsif is_snake2 = '1' then
                    -- Snake 2 - Blue
                    if (pixel_x mod CELL_SIZE) < CELL_SIZE - 1 and 
                       (pixel_y mod CELL_SIZE) < CELL_SIZE - 1 then
                        red <= "0000";
                        green <= "0000";
                        blue <= "1100";
                    else
                        -- Border
                        red <= "0010";
                        green <= "0010";
                        blue <= "0010";
                    end if;
                elsif is_food = '1' then
                    -- Food - Red
                    if (pixel_x mod CELL_SIZE) > 2 and (pixel_x mod CELL_SIZE) < CELL_SIZE - 3 and
                       (pixel_y mod CELL_SIZE) > 2 and (pixel_y mod CELL_SIZE) < CELL_SIZE - 3 then
                        red <= "1111";
                        green <= "0000";
                        blue <= "0000";
                    else
                        red <= "0000";
                        green <= "0000";
                        blue <= "0000";
                    end if;
                elsif is_grid_line = '1' then
                    -- Grid lines - dark gray
                    red <= "0001";
                    green <= "0001";
                    blue <= "0001";
                else
                    -- Background - black
                    red <= "0000";
                    green <= "0000";
                    blue <= "0000";
                end if;
            else
                -- Video off - black
                red <= "0000";
                green <= "0000";
                blue <= "0000";
            end if;
        end if;
    end process;

end Behavioral;
