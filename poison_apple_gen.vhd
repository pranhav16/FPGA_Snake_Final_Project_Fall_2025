library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity poison_control is
    generic (
        GRID_WIDTH    : integer := 40;
        GRID_HEIGHT   : integer := 30;
        VISIBLE_TICKS : integer := 80;                  -- 保留参数，不强制使用
        HIDDEN_TICKS  : integer := 30;                  -- 保留参数
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

    ------------------------------------------------------------------
    -- LFSR 生成随机位置
    ------------------------------------------------------------------
    signal lfsr : std_logic_vector(9 downto 0) := SEED;

    -- 当前毒苹果位置
    signal poison_x_i : integer range 0 to GRID_WIDTH-1  := 3;
    signal poison_y_i : integer range 0 to GRID_HEIGHT-1 := 3;

    ------------------------------------------------------------------
    -- 地图内部墙函数（要和 snake_control / food_control / wall_field 保持一致）
    ------------------------------------------------------------------
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

    ------------------------------------------------------------------
    -- 某一格是否是墙（包括边框）
    ------------------------------------------------------------------
    function is_wall_cell(
        x           : integer;
        y           : integer;
        map_id_bits : std_logic_vector(2 downto 0)
    ) return boolean is
        variable map_sel_int : integer range 0 to 7;
    begin
        -- 外边框
        if (x = 0) or (y = 0) or
           (x = GRID_WIDTH-1) or (y = GRID_HEIGHT-1) then
            return true;
        end if;

        -- 地图内部墙
        map_sel_int := to_integer(unsigned(map_id_bits));
        if map_sel_int >= 5 then
            map_sel_int := map_sel_int - 5;
        end if;

        return internal_wall(x, y, map_sel_int);
    end function;

begin

    poison_x <= poison_x_i;
    poison_y <= poison_y_i;

    ------------------------------------------------------------------
    -- 主过程：判定是否吃到 + 随机搬家
    ------------------------------------------------------------------
    process(clk)
        variable new_x    : integer range 0 to GRID_WIDTH-1;
        variable new_y    : integer range 0 to GRID_HEIGHT-1;
        variable x_raw    : integer;
        variable y_raw    : integer;
        variable tmp_lfsr : std_logic_vector(9 downto 0);
        variable t        : integer;    -- for 循环计数
        variable p1_hit_v : std_logic;
        variable p2_hit_v : std_logic;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                lfsr        <= SEED;
                poison_x_i  <= 3;
                poison_y_i  <= 3;
                p1_poison   <= '0';
                p2_poison   <= '0';
            else
                -- 默认：输出低电平，只有命中时拉高一个 game_tick
                p1_poison <= '0';
                p2_poison <= '0';

                if game_tick = '1' then
                    --------------------------------------------------
                    -- 1. 判断当前蛇头是否在毒苹果格子上
                    --------------------------------------------------
                    p1_hit_v := '0';
                    p2_hit_v := '0';

                    if (p1_head_x = poison_x_i) and (p1_head_y = poison_y_i) then
                        p1_hit_v := '1';
                    end if;

                    if (p2_head_x = poison_x_i) and (p2_head_y = poison_y_i) then
                        p2_hit_v := '1';
                    end if;

                    if (p1_hit_v = '1') or (p2_hit_v = '1') then
                        -- 拉高脉冲，驱动 snake_control 的 shrink
                        p1_poison <= p1_hit_v;
                        p2_poison <= p2_hit_v;

                        --------------------------------------------------
                        -- 2. 重新随机生成一个不在墙里的位置
                        --------------------------------------------------
                        tmp_lfsr := lfsr;
                        new_x    := poison_x_i;
                        new_y    := poison_y_i;

                        -- 尝试最多 32 次找一个不在墙里的格子
                        for t in 0 to 31 loop
                            -- 推进 LFSR
                            tmp_lfsr := tmp_lfsr(8 downto 0) & (tmp_lfsr(9) xor tmp_lfsr(6));

                            x_raw := to_integer(unsigned(tmp_lfsr(5 downto 0)));
                            y_raw := to_integer(unsigned(tmp_lfsr(9 downto 6)));

                            -- 限制在内部区域 [1, GRID_WIDTH-2]
                            new_x := 1 + (x_raw mod (GRID_WIDTH-2));
                            new_y := 1 + (y_raw mod (GRID_HEIGHT-2));

                            exit when not is_wall_cell(new_x, new_y, map_id);
                        end loop;

                        poison_x_i <= new_x;
                        poison_y_i <= new_y;
                        lfsr       <= tmp_lfsr;
                    end if;  -- 有蛇吃到毒苹果
                end if; -- game_tick
            end if; -- rst
        end if; -- rising_edge
    end process;

end architecture;
