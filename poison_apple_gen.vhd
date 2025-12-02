library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity poison_control is
    generic (
        GRID_WIDTH    : integer := 40;
        GRID_HEIGHT   : integer := 30;
        VISIBLE_TICKS : integer := 80;
        HIDDEN_TICKS  : integer := 30;
        SEED          : std_logic_vector(9 downto 0) := "1100110011"
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        game_tick : in  std_logic;
        map_id    : in  std_logic_vector(2 downto 0);
        p1_head_x : in  integer range 0 to GRID_WIDTH-1;
        p1_head_y : in  integer range 0 to GRID_HEIGHT-1;
        p2_head_x : in  integer range 0 to GRID_WIDTH-1;
        p2_head_y : in  integer range 0 to GRID_HEIGHT-1;
        poison_x  : out integer range 0 to GRID_WIDTH-1;
        poison_y  : out integer range 0 to GRID_HEIGHT-1;
        p1_poison : out std_logic;
        p2_poison : out std_logic
    );
end entity;

architecture rtl of poison_control is

    type state_t is (VISIBLE, HIDDEN);
    signal st : state_t := VISIBLE;

    signal lfsr : std_logic_vector(9 downto 0) := SEED;

    signal poison_x_i : integer range 0 to GRID_WIDTH-1  := 3;
    signal poison_y_i : integer range 0 to GRID_HEIGHT-1 := 3;

    signal hide_cnt : integer range 0 to HIDDEN_TICKS := 0;

    -- 与墙一致
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

    function is_wall_cell(
        x      : integer;
        y      : integer;
        map_id_bits : std_logic_vector(2 downto 0)
    ) return boolean is
        variable map_sel_int : integer range 0 to 7;
    begin
        if (x = 0) or (y = 0) or
           (x = GRID_WIDTH-1) or (y = GRID_HEIGHT-1) then
            return true;
        end if;

        map_sel_int := to_integer(unsigned(map_id_bits));
        if map_sel_int >= 5 then
            map_sel_int := map_sel_int - 5;
        end if;

        return internal_wall(x, y, map_sel_int);
    end function;

begin

    poison_x <= poison_x_i;
    poison_y <= poison_y_i;

    process(clk, rst)
        variable new_x     : integer range 0 to GRID_WIDTH-1;
        variable new_y     : integer range 0 to GRID_HEIGHT-1;
        variable x_raw     : integer;
        variable y_raw     : integer;
        variable nxt_lfsr  : std_logic_vector(9 downto 0);
        variable p1_hit    : boolean;
        variable p2_hit    : boolean;
    begin
        if rst = '1' then
            lfsr        <= SEED;
            poison_x_i  <= 3;
            poison_y_i  <= 3;
            st          <= VISIBLE;
            hide_cnt    <= 0;
            p1_poison   <= '0';
            p2_poison   <= '0';
        elsif rising_edge(clk) then
            p1_poison <= '0';
            p2_poison <= '0';

            if game_tick = '1' then
                -- LFSR
                nxt_lfsr := lfsr(8 downto 0) & (lfsr(9) xor lfsr(6));
                lfsr     <= nxt_lfsr;

                case st is
                    when VISIBLE =>
                        p1_hit := (p1_head_x = poison_x_i) and (p1_head_y = poison_y_i);
                        p2_hit := (p2_head_x = poison_x_i) and (p2_head_y = poison_y_i);

                        if p1_hit or p2_hit then
                            if p1_hit then p1_poison <= '1'; end if;
                            if p2_hit then p2_poison <= '1'; end if;

                            -- 新位置候选
                            x_raw := to_integer(unsigned(nxt_lfsr(5 downto 0)));
                            y_raw := to_integer(unsigned(nxt_lfsr(9 downto 6)));
                            new_x := 1 + (x_raw mod (GRID_WIDTH-2));
                            new_y := 1 + (y_raw mod (GRID_HEIGHT-2));

                            if not is_wall_cell(new_x, new_y, map_id) then
                                poison_x_i <= new_x;
                                poison_y_i <= new_y;
                            end if;

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
