
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wall_field is
    generic (
        GRID_WIDTH  : integer := 40;
        GRID_HEIGHT : integer := 30
    );
    port(
        x       : in  integer range 0 to GRID_WIDTH-1;
        y       : in  integer range 0 to GRID_HEIGHT-1;
        is_wall : out std_logic
    );
end entity;

architecture rtl of wall_field is
begin
    process(x, y)
    begin
        is_wall <= '0';

        if (x = 0) or (y = 0) or
           (x = GRID_WIDTH-1) or (y = GRID_HEIGHT-1) then
            is_wall <= '1';

        elsif --(x = 10 and y > 4  and y < GRID_HEIGHT-5 and y /= 12) or
              (x = 20 and y > 2  and y < GRID_HEIGHT-7 and y /= 18) then
              --(x = 30 and y > 6  and y < GRID_HEIGHT-3 and y /=  9) then
            is_wall <= '1';
        end if;
    end process;
end architecture;
