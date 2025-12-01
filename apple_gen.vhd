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
        p1_head_y : in  integer range 0 to GRID_WIDTH-1; 
        p2_head_x : in  integer range 0 to GRID_WIDTH-1;
        p2_head_y : in  integer range 0 to GRID_HEIGHT-1;

        food_x    : out integer range 0 to GRID_WIDTH-1;
        food_y    : out integer range 0 to GRID_HEIGHT-1;
        p1_ate    : out std_logic;
        p2_ate    : out std_logic
    );
end entity;

architecture rtl of food_control is

    -- LFSR 10-bit
    signal lfsr : std_logic_vector(9 downto 0) := SEED;

    signal food_x_i : integer range 0 to GRID_WIDTH-1 := 5;
    signal food_y_i : integer range 0 to GRID_HEIGHT-1 := 5;

    type state_t is (VISIBLE, HIDDEN);
    signal st : state_t := VISIBLE;

    signal hide_cnt : integer range 0 to HIDDEN_TICKS := 0;

begin

    food_x <= food_x_i;
    food_y <= food_y_i;

    process(clk, rst)
        variable new_x  : integer;
        variable new_y  : integer;
        variable nxt_lfsr : std_logic_vector(9 downto 0);
        variable p1_hit, p2_hit : boolean;
    begin
        if rst = '1' then
            lfsr    <= SEED;
            food_x_i <= 5;
            food_y_i <= 5;
            st      <= VISIBLE;
            hide_cnt <= 0;
            p1_ate <= '0';
            p2_ate <= '0';
        elsif rising_edge(clk) then
            p1_ate <= '0';
            p2_ate <= '0';

            if game_tick = '1' then
               
                nxt_lfsr := lfsr(8 downto 0) & (lfsr(9) xor lfsr(6));
                lfsr     <= nxt_lfsr;

                case st is
                    when VISIBLE =>
                        p1_hit := (p1_head_x = food_x_i) and (p1_head_y = food_y_i);
                        p2_hit := (p2_head_x = food_x_i) and (p2_head_y = food_y_i);

                        if p1_hit or p2_hit then
                            if p1_hit then p1_ate <= '1'; end if;
                            if p2_hit then p2_ate <= '1'; end if;

                            -- 生成新位置（先藏起来，等一会再出现）
                            new_x := to_integer(unsigned(nxt_lfsr(5 downto 0))) mod GRID_WIDTH;
                            new_y := to_integer(unsigned(nxt_lfsr(9 downto 6))) mod GRID_HEIGHT;

                            food_x_i <= new_x;
                            food_y_i <= new_y;

                            st       <= HIDDEN;
                            hide_cnt <= 0;
                        else
                            null;
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
