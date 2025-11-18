library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package snake_game_pkg is
    -- Game grid dimensions
    constant GRID_WIDTH : integer := 40;
    constant GRID_HEIGHT : integer := 30;
    
    -- VGA timing constants (640x480 @ 60Hz)
    constant H_DISPLAY : integer := 640;
    constant H_FRONT : integer := 16;
    constant H_SYNC : integer := 96;
    constant H_BACK : integer := 48;
    constant H_TOTAL : integer := 800;
    
    constant V_DISPLAY : integer := 480;
    constant V_FRONT : integer := 10;
    constant V_SYNC : integer := 2;
    constant V_BACK : integer := 33;
    constant V_TOTAL : integer := 525;
    
    -- Pixel size for each grid cell
    constant CELL_SIZE : integer := 16;
    
    -- Game speed (clock divider for movement)
    constant GAME_SPEED : integer := 10000000; -- 10M cycles = 0.1s at 100MHz
    
    -- Direction encoding
    constant DIR_UP : std_logic_vector(1 downto 0) := "00";
    constant DIR_DOWN : std_logic_vector(1 downto 0) := "01";
    constant DIR_LEFT : std_logic_vector(1 downto 0) := "10";
    constant DIR_RIGHT : std_logic_vector(1 downto 0) := "11";
    
    -- Maximum snake length
    constant MAX_SNAKE_LENGTH : integer := 100;
    
    -- Position type
    type position is record
        x : integer range 0 to GRID_WIDTH-1;
        y : integer range 0 to GRID_HEIGHT-1;
    end record;
    
    -- Snake body array
    type snake_body_array is array (0 to MAX_SNAKE_LENGTH-1) of position;
    
end package snake_game_pkg;
