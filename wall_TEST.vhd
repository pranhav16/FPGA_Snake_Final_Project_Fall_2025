library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wall_field is
    generic (
        GRID_WIDTH    : integer := 40;
        GRID_HEIGHT   : integer := 30;
        MAX_LENGTH    : integer := 16;  
        UPDATE_TICKS  : integer := 50;  
        NUM_WALLS     : integer := 20  
    );
    port(
        clk       : in  std_logic;
        rst       : in  std_logic;
        game_tick : in  std_logic;

        p1_body_x_flat : in std_logic_vector(MAX_LENGTH*12-1 downto 0);
        p1_body_y_flat : in std_logic_vector(MAX_LENGTH*12-1 downto 0);
        p1_length      : in integer range 0 to MAX_LENGTH;

        p2_body_x_flat : in std_logic_vector(MAX_LENGTH*12-1 downto 0);
        p2_body_y_flat : in std_logic_vector(MAX_LENGTH*12-1 downto 0);
        p2_length      : in integer range 0 to MAX_LENGTH;

        x       : in  integer range 0 to GRID_WIDTH-1;
        y       : in  integer range 0 to GRID_HEIGHT-1;

        is_wall : out std_logic
    );
end entity;

architecture rtl of wall_field is

    type wall_array_t is array (0 to GRID_WIDTH-1, 0 to GRID_HEIGHT-1) of std_logic;
    signal walls : wall_array_t;

    signal lfsr : std_logic_vector(9 downto 0) := "1010101101";

    signal tick_cnt : integer range 0 to UPDATE_TICKS := 0;

begin


    process(clk, rst)
        variable lfsr_v     : std_logic_vector(9 downto 0);
        variable x_raw      : integer;
        variable y_raw      : integer;
        variable new_x      : integer range 0 to GRID_WIDTH-1;
        variable new_y      : integer range 0 to GRID_HEIGHT-1;
        variable on_snake   : boolean;
        variable base       : integer;
        variable sx, sy     : integer;
        variable w          : integer;
        variable i          : integer;
    begin
        if rst = '1' then
            for ix in 0 to GRID_WIDTH-1 loop
                for iy in 0 to GRID_HEIGHT-1 loop
                    walls(ix, iy) <= '0';
                end loop;
            end loop;
            tick_cnt <= 0;
            lfsr     <= "1010101101";
        elsif rising_edge(clk) then
            if game_tick = '1' then
                if tick_cnt >= UPDATE_TICKS then
                    tick_cnt <= 0;

                    for ix in 0 to GRID_WIDTH-1 loop
                        for iy in 0 to GRID_HEIGHT-1 loop
                            walls(ix, iy) <= '0';
                        end loop;
                    end loop;

                    lfsr_v := lfsr;

                    for w in 0 to NUM_WALLS-1 loop
                        lfsr_v := lfsr_v(8 downto 0) & (lfsr_v(9) xor lfsr_v(6));

                        x_raw := to_integer(unsigned(lfsr_v(5 downto 0)));
                        y_raw := to_integer(unsigned(lfsr_v(9 downto 6)));

                        new_x := 1 + (x_raw mod (GRID_WIDTH-2));
                        new_y := 1 + (y_raw mod (GRID_HEIGHT-2));

                        on_snake := false;

                        for i in 0 to MAX_LENGTH-1 loop
                            exit when i >= p1_length;
                            base := i*12;
                            sx   := to_integer(unsigned(p1_body_x_flat(base+11 downto base)));
                            sy   := to_integer(unsigned(p1_body_y_flat(base+11 downto base)));
                            if (sx = new_x) and (sy = new_y) then
                                on_snake := true;
                            end if;
                        end loop;

                        for i in 0 to MAX_LENGTH-1 loop
                            exit when i >= p2_length;
                            base := i*12;
                            sx   := to_integer(unsigned(p2_body_x_flat(base+11 downto base)));
                            sy   := to_integer(unsigned(p2_body_y_flat(base+11 downto base)));
                            if (sx = new_x) and (sy = new_y) then
                                on_snake := true;
                            end if;
                        end loop;

                        if not on_snake then
                            walls(new_x, new_y) <= '1';
                        end if;
                    end loop;

                    lfsr <= lfsr_v;
                else
                    tick_cnt <= tick_cnt + 1;
                end if;
            end if;
        end if;
    end process;


    process(x, y, walls)
    begin
        is_wall <= '0';

        if (x = 0) or (y = 0) or
           (x = GRID_WIDTH-1) or (y = GRID_HEIGHT-1) then
            is_wall <= '1';
        elsif walls(x, y) = '1' then
            is_wall <= '1';
        else
            is_wall <= '0';
        end if;
    end process;

end architecture;
