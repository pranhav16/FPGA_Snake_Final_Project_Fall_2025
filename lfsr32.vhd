library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lfsr32 is
  port(
    clk    : in  std_logic;
    rstn   : in  std_logic; 
    random : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of lfsr32 is
  signal r : std_logic_vector(31 downto 0) := x"A55A1234";
begin
  process(clk, rstn)
    variable fb : std_logic;
  begin
    if rstn='0' then
      r <= x"A55A1234";
    elsif rising_edge(clk) then
      fb := r(0) xor r(1) xor r(21) xor r(31);
      r  <= fb & r(31 downto 1);
    end if;
  end process;
  random <= r;
end architecture;
