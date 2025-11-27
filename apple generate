library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity apple_gen is
  generic(
    GRID_W        : integer := 40;
    GRID_H        : integer := 30
  );
  port(
    clk       : in  std_logic;
    rstn      : in  std_logic;
    tick_cell : in  std_logic;  
    consume   : in  std_logic;  
    pos_x     : out unsigned(5 downto 0);
    pos_y     : out unsigned(5 downto 0)
  );
end entity;

architecture rtl of apple_gen is
  component lfsr32
    port(clk:in std_logic; rstn:in std_logic; random:out std_logic_vector(31 downto 0));
  end component;

  signal rnd   : std_logic_vector(31 downto 0);
  signal ax, ay: unsigned(5 downto 0) := to_unsigned(5,6);

  function is_wall_pos(xi, yi : integer) return boolean is
  begin
    if (xi = 0) or (yi = 0) or
       (xi = GRID_W-1) or (yi = GRID_H-1) then
      return true;
    end if;

    if (xi=10 and yi>4 and yi<GRID_H-5 and yi/=12) or
       (xi=20 and yi>2 and yi<GRID_H-7 and yi/=18) or
       (xi=30 and yi>6 and yi<GRID_H-3 and yi/=9) then
      return true;
    end if;
    return false;
  end function;
begin
  u_lfsr: lfsr32 port map(clk=>clk, rstn=>rstn, random=>rnd);

  process(clk, rstn)
    variable rx, ry : integer;
  begin
    if rstn='0' then
      ax <= to_unsigned(5,6);
      ay <= to_unsigned(5,6);
    elsif rising_edge(clk) then
      if (consume='1') or (tick_cell='1') then
        rx := to_integer(unsigned(rnd(7 downto 0))) mod GRID_W;
        ry := to_integer(unsigned(rnd(15 downto 8))) mod GRID_H;

        if not is_wall_pos(rx, ry) then
          ax <= to_unsigned(rx, 6);
          ay <= to_unsigned(ry, 6);
        end if;
      end if;
    end if;
  end process;

  pos_x <= ax;
  pos_y <= ay;
end architecture;
