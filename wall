library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wall_field is
  generic(
    GRID_W : integer := 40;
    GRID_H : integer := 30
  );
  port(
    cell_x  : in  unsigned(5 downto 0); -- 0..GRID_W-1
    cell_y  : in  unsigned(5 downto 0); -- 0..GRID_H-1
    is_wall : out std_logic
  );
end entity;

architecture rtl of wall_field is
begin
  process(cell_x, cell_y)
    variable w : std_logic := '0';
  begin
    if (cell_x = 0) or (cell_y = 0) or
       (cell_x = to_unsigned(GRID_W-1, cell_x'length)) or
       (cell_y = to_unsigned(GRID_H-1, cell_y'length)) then
      w := '1';
    else
-- the inside walls can be changed
      if (cell_x = to_unsigned(10,6) and cell_y >  to_unsigned(4,6) and cell_y < to_unsigned(GRID_H-5,6) and cell_y /= to_unsigned(12,6)) or
         (cell_x = to_unsigned(20,6) and cell_y >  to_unsigned(2,6) and cell_y < to_unsigned(GRID_H-7,6) and cell_y /= to_unsigned(18,6)) or
         (cell_x = to_unsigned(30,6) and cell_y >  to_unsigned(6,6) and cell_y < to_unsigned(GRID_H-3,6) and cell_y /= to_unsigned(9,6)) then
        w := '1';
      else
        w := '0';
      end if;
    end if;
    is_wall <= w;
  end process;
end architecture;
