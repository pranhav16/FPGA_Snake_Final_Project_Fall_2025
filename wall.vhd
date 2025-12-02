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
        map_id  : in  std_logic_vector(2 downto 0); -- 0~4
        is_wall : out std_logic
    );
end entity;

architecture rtl of wall_field is

    function internal_wall(
        x       : integer;
        y       : integer;
        map_sel : integer
    ) return boolean is
        constant MID_X : integer := GRID_WIDTH/2;
        constant MID_Y : integer := GRID_HEIGHT/2;
    begin
        case map_sel is
         
            when 0 =>
                return false;

     
            when 1 =>
                if (x = MID_X and y >= 3 and y <= 11) or
                   (x = MID_X and y >= GRID_HEIGHT-11 and y <= GRID_HEIGHT-4) then
                    return true;
                else
                    return false;
                end if;

         
            when 2 =>
                if ((y = 8) or (y = GRID_HEIGHT-9)) and
                   (x >= 4 and x <= GRID_WIDTH-5) then
                    return true;
                else
                    return false;
                end if;

    
            when 3 =>
                if ((x = 5 or x = 6) and (y = 5 or y = 6)) or
                   ((x = GRID_WIDTH-6 or x = GRID_WIDTH-5) and (y = 5 or y = 6)) or
                   ((x = 5 or x = 6) and (y = GRID_HEIGHT-6 or y = GRID_HEIGHT-5)) or
                   ((x = GRID_WIDTH-6 or x = GRID_WIDTH-5) and (y = GRID_HEIGHT-6 or y = GRID_HEIGHT-5)) then
                    return true;
                else
                    return false;
                end if;


            when 4 =>
                if (x = MID_X and y >= 10 and y <= 20) or
                   (y = MID_Y and x >= 15 and x <= 25) then
                    return true;
                else
                    return false;
                end if;

            when others =>
                return false;
        end case;
    end function;

begin
    process(x, y, map_id)
        variable map_sel_int : integer range 0 to 7;
    begin
        is_wall <= '0';

        map_sel_int := to_integer(unsigned(map_id));
        if map_sel_int >= 5 then
            map_sel_int := map_sel_int - 5;
        end if;

        if (x = 0) or (y = 0) or
           (x = GRID_WIDTH-1) or (y = GRID_HEIGHT-1) then
            is_wall <= '1';

        elsif internal_wall(x, y, map_sel_int) then
            is_wall <= '1';

        else
            is_wall <= '0';
        end if;
    end process;
end architecture;
