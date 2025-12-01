library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity food_control is
    generic (
        GRID_WIDTH    : integer := 40;
        GRID_HEIGHT   : integer := 30;
        VISIBLE_TICKS : integer := 80;
        HIDDEN_TICKS  : integer := 30;
        SEED          : std_logic_vector(9 downto 0) := "1010101010"
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        game_tick : in  std_logic;
        p1_head_x : in  integer range 0 to GRID_WIDTH-1;
        p1_head_y : in  integer range 0 to GRID_HEIGHT-1;
        p2_head_x : in  integer range 0 to GRID_WIDTH-1;
        p2_head_y : in  integer range 0 to GRID_HEIGHT-1;
        food_x    : out integer range 0 to GRID_WIDTH-1;
        food_y    : out integer range 0 to GRID_HEIGHT-1;
        p1_ate    : out std_logic;
        p2_ate    : out std_logic
    );
end entity;

architecture rtl of food_control is

    signal lfsr : std_logic_vector(9 downto 0) := SEED;

    signal food_x_i : integer range 0 to GRID_WIDTH-1  := 5;
    signal food_y_i : integer range 0 to GRID_HEIGHT-1 := 5;

    type state_t is (VISIBLE, HIDDEN);
    signal st : state_t := VISIBLE;

    signal hide_cnt : integer range 0 to HIDDEN_TICKS := 0;

    -- 用和 snake_control / wall_field 相同的墙规则
    function is_wall_cell(
        x : integer;
        y : integer
    ) return boolean is
        constant MID_X : integer := GRID_WIDTH/2;
    begin
        if (x = 0) or (y = 0) or
           (x = GRID_WIDTH-1) or (y = GRID_HEIGHT-1) then
            return true;
        elsif (x = MID_X and y >= 5 and y <= GRID_HEIGHT-6) then
            return true;
        else
            return false;
        end if;
    end function;

begin

    food_x <= food_x_i;
    food_y <= food_y_i;

    process(clk, rst)
        variable new_x     : integer range 0 to GRID_WIDTH-1;
        variable new_y     : integer range 0 to GRID_HEIGHT-1;
        variable x_raw     : integer;
        variable y_raw     : integer;
        variable nxt_lfsr  : std_logic_vector(9 downto 0);
        variable p1_hit    : boolean;
        variable p2_hit    : boolean;
        variable j         : integer;
    begin
        if rst = '1' then
            lfsr      <= SEED;
            food_x_i  <= 5;
            food_y_i  <= 5;
            st        <= VISIBLE;
            hide_cnt  <= 0;
            p1_ate    <= '0';
            p2_ate    <= '0';
        elsif rising_edge(clk) then
            p1_ate <= '0';
            p2_ate <= '0';

            if game_tick = '1' then
                -- LFSR
                nxt_lfsr := lfsr(8 downto 0) & (lfsr(9) xor lfsr(6));
                lfsr     <= nxt_lfsr;

                case st is
                    when VISIBLE =>
                        p1_hit := (p1_head_x = food_x_i) and (p1_head_y = food_y_i);
                        p2_hit := (p2_head_x = food_x_i) and (p2_head_y = food_y_i);

                        if p1_hit or p2_hit then
                            if p1_hit then p1_ate <= '1'; end if;
                            if p2_hit then p2_ate <= '1'; end if;

                            -- 生成新苹果位置：内部区域、避开墙
                            x_raw := to_integer(unsigned(nxt_lfsr(5 downto 0)));
                            y_raw := to_integer(unsigned(nxt_lfsr(9 downto 6)));

                            new_x := 1 + (x_raw mod (GRID_WIDTH-2));
                            new_y := 1 + (y_raw mod (GRID_HEIGHT-2));

                            for j in 0 to 7 loop
                                exit when not is_wall_cell(new_x, new_y);
                                new_x := 1 + ((new_x - 1 + 1) mod (GRID_WIDTH-2));
                                new_y := 1 + ((new_y - 1 + 1) mod (GRID_HEIGHT-2));
                            end loop;

                            food_x_i <= new_x;
                            food_y_i <= new_y;

                            st       <= HIDDEN;
                            hide_cnt <= 0;
                        end if;

                    when HIDDEN =>
                        if hide_cnt >= HIDDEN_TICKS then
                            st       <= VISIBLE;
                            hide_cnt <= 0;
                        else
                            hide_cnt <= hide_cnt + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

end architecture;
