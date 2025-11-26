library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity snake_control is
    Port ( 
        clk : in std_logic;
        rst : in std_logic;
        game_tick : in std_logic;
        
        btn_up : in std_logic;
        btn_down : in std_logic;
        btn_left : in std_logic;
        btn_right : in std_logic;
        
        snake_head_x_o : out integer := 20; --range 0 to GRID_WIDTH-1
        snake_head_y_o : out integer := 15 --range 0 to GRID_HEIGHT-1
    );
end snake_control;

architecture arch of snake_control is

    constant GRID_WIDTH : integer := 40;
    constant GRID_HEIGHT : integer := 30;

    -- Snake state
    type direction_type is (DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT);
    signal snake_dir : direction_type := DIR_RIGHT;
    signal snake_next_dir : direction_type := DIR_RIGHT;
    
    -- Simple snake positions (just head for now, we'll add body later)
    signal snake_head_x : integer range 0 to GRID_WIDTH-1 := 20;
    signal snake_head_y : integer range 0 to GRID_HEIGHT-1 := 15;

begin

    ------------------------------------------------------------------
    -- Button input handling (direction control)
    ------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
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
    end process;
    
    ------------------------------------------------------------------
    -- Snake movement
    ------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                snake_head_x <= 20;
                snake_head_y <= 15;
                snake_dir <= DIR_RIGHT;
            elsif game_tick = '1' then
                snake_dir <= snake_next_dir;
                
                -- Move snake head
                case snake_dir is
                    when DIR_UP =>
                        if snake_head_y > 0 then
                            snake_head_y <= snake_head_y - 1;
                        else
                            snake_head_y <= GRID_HEIGHT - 1; -- Wrap around
                        end if;
                    when DIR_DOWN =>
                        if snake_head_y < GRID_HEIGHT - 1 then
                            snake_head_y <= snake_head_y + 1;
                        else
                            snake_head_y <= 0; -- Wrap around
                        end if;
                    when DIR_LEFT =>
                        if snake_head_x > 0 then
                            snake_head_x <= snake_head_x - 1;
                        else
                            snake_head_x <= GRID_WIDTH - 1; -- Wrap around
                        end if;
                    when DIR_RIGHT =>
                        if snake_head_x < GRID_WIDTH - 1 then
                            snake_head_x <= snake_head_x + 1;
                        else
                            snake_head_x <= 0; -- Wrap around
                        end if;
                end case;
            end if;
        end if;
    end process;

    snake_head_x_o <= snake_head_x;
    snake_head_y_o <= snake_head_y;
    
end arch;
