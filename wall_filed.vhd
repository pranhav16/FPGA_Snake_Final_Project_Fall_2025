library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wall_field is
    generic (
        GRID_WIDTH  : integer := 40;
        GRID_HEIGHT : integer := 30
    );
    port(
        -- clock / timing
        clk       : in  std_logic;
        rst       : in  std_logic;
        game_tick : in  std_logic;  -- ~10 Hz tick from top level

        -- objects to avoid for random walls (for drawing overlap)
        snake1_x  : in integer range 0 to GRID_WIDTH-1;
        snake1_y  : in integer range 0 to GRID_HEIGHT-1;
        snake2_x  : in integer range 0 to GRID_WIDTH-1;
        snake2_y  : in integer range 0 to GRID_HEIGHT-1;
        food_x_i  : in integer range 0 to GRID_WIDTH-1;
        food_y_i  : in integer range 0 to GRID_HEIGHT-1;

        -- current grid cell to test (for VGA drawing)
        x       : in  integer range 0 to GRID_WIDTH-1;
        y       : in  integer range 0 to GRID_HEIGHT-1;

        -- outputs for VGA (visual)
        is_wall         : out std_logic;  -- border + solid random walls
        is_wall_preview : out std_logic;  -- preview random walls only

        -- outputs for collision: random-wall geometry + phase
        w1_x0_o        : out integer range 0 to GRID_WIDTH-1;
        w1_y0_o        : out integer range 0 to GRID_HEIGHT-1;
        w1_orient_o    : out std_logic;
        w2_x0_o        : out integer range 0 to GRID_WIDTH-1;
        w2_y0_o        : out integer range 0 to GRID_HEIGHT-1;
        w2_orient_o    : out std_logic;
        w3_x0_o        : out integer range 0 to GRID_WIDTH-1;
        w3_y0_o        : out integer range 0 to GRID_HEIGHT-1;
        w3_orient_o    : out std_logic;
        walls_solid_o  : out std_logic    -- '1' only in solid (VISIBLE) phase
    );
end entity;

architecture rtl of wall_field is

    --------------------------------------------------------------------------
    -- Timing: 2 s invisible, 2 s preview, 3 s visible (game_tick ≈ 10 Hz)
    --------------------------------------------------------------------------
    constant INVISIBLE_TICKS : integer := 20; -- 2 s * 10 Hz
    constant PREVIEW_TICKS   : integer := 20; -- 2 s * 10 Hz
    constant VISIBLE_TICKS   : integer := 30; -- 3 s * 10 Hz

    type wall_state_type is (W_INVISIBLE, W_PREVIEW, W_VISIBLE);

    signal wall_state  : wall_state_type := W_INVISIBLE;
    signal phase_count : integer range 0 to VISIBLE_TICKS := 0;

    --------------------------------------------------------------------------
    -- LFSR for pseudo-random generation
    --------------------------------------------------------------------------
    signal lfsr_reg : std_logic_vector(7 downto 0) := "10101011"; -- non-zero seed

    -- dynamic wall parameters: 3 walls, each 5 cells, orientation H/V
    -- orientation: '0' = horizontal, '1' = vertical
    signal w1_x0, w2_x0, w3_x0 : integer range 0 to GRID_WIDTH-1 := 1;
    signal w1_y0, w2_y0, w3_y0 : integer range 0 to GRID_HEIGHT-1 := 1;
    signal w1_orient, w2_orient, w3_orient : std_logic := '0';

    signal walls_active : std_logic := '0';

    --------------------------------------------------------------------------
    -- Helper function: next LFSR state (8-bit, taps 8,6,5,4)
    --------------------------------------------------------------------------
    function lfsr_next(s: std_logic_vector(7 downto 0)) return std_logic_vector is
        variable v  : std_logic_vector(7 downto 0);
        variable fb : std_logic;
    begin
        fb := s(7) xor s(5) xor s(4) xor s(3);
        v  := s(6 downto 0) & fb;
        return v;
    end function;

begin

    --------------------------------------------------------------------------
    -- State machine for wall visibility and random generation
    -- Cycle: INVISIBLE (2 s) -> PREVIEW (2 s) -> VISIBLE (3 s) -> INVISIBLE ...
    --------------------------------------------------------------------------
    process(clk)
        variable s    : std_logic_vector(7 downto 0);
        variable tmp6 : integer;
        variable tmp5 : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                wall_state   <= W_INVISIBLE;
                phase_count  <= 0;
                lfsr_reg     <= "10101011";
                walls_active <= '0';
            else
                if game_tick = '1' then
                    case wall_state is

                        ------------------------------------------------------------------
                        -- INVISIBLE: nothing on screen, counting until preview
                        ------------------------------------------------------------------
                        when W_INVISIBLE =>
                            if phase_count >= INVISIBLE_TICKS - 1 then
                                -- Time to generate new random walls and go to PREVIEW
                                s := lfsr_reg;

                                ------------------------------------------------------------------
                                -- Wall 1
                                ------------------------------------------------------------------
                                s := lfsr_next(s);
                                w1_orient <= s(0);
                                if w1_orient = '0' then
                                    -- horizontal: length 5, inside border
                                    tmp6 := to_integer(unsigned(s(6 downto 1)));
                                    if tmp6 >= (GRID_WIDTH-2-4) then
                                        tmp6 := tmp6 - (GRID_WIDTH-2-4);
                                    end if;
                                    w1_x0 <= tmp6 + 1;

                                    tmp5 := to_integer(unsigned(s(5 downto 1)));
                                    if tmp5 >= (GRID_HEIGHT-2) then
                                        tmp5 := tmp5 - (GRID_HEIGHT-2);
                                    end if;
                                    w1_y0 <= tmp5 + 1;
                                else
                                    -- vertical: length 5, inside border
                                    tmp6 := to_integer(unsigned(s(6 downto 1)));
                                    if tmp6 >= (GRID_WIDTH-2) then
                                        tmp6 := tmp6 - (GRID_WIDTH-2);
                                    end if;
                                    w1_x0 <= tmp6 + 1;

                                    tmp5 := to_integer(unsigned(s(5 downto 1)));
                                    if tmp5 >= (GRID_HEIGHT-2-4) then
                                        tmp5 := tmp5 - (GRID_HEIGHT-2-4);
                                    end if;
                                    w1_y0 <= tmp5 + 1;
                                end if;

                                ------------------------------------------------------------------
                                -- Wall 2
                                ------------------------------------------------------------------
                                s := lfsr_next(s);
                                w2_orient <= s(0);
                                if w2_orient = '0' then
                                    tmp6 := to_integer(unsigned(s(6 downto 1)));
                                    if tmp6 >= (GRID_WIDTH-2-4) then
                                        tmp6 := tmp6 - (GRID_WIDTH-2-4);
                                    end if;
                                    w2_x0 <= tmp6 + 1;

                                    tmp5 := to_integer(unsigned(s(5 downto 1)));
                                    if tmp5 >= (GRID_HEIGHT-2) then
                                        tmp5 := tmp5 - (GRID_HEIGHT-2);
                                    end if;
                                    w2_y0 <= tmp5 + 1;
                                else
                                    tmp6 := to_integer(unsigned(s(6 downto 1)));
                                    if tmp6 >= (GRID_WIDTH-2) then
                                        tmp6 := tmp6 - (GRID_WIDTH-2);
                                    end if;
                                    w2_x0 <= tmp6 + 1;

                                    tmp5 := to_integer(unsigned(s(5 downto 1)));
                                    if tmp5 >= (GRID_HEIGHT-2-4) then
                                        tmp5 := tmp5 - (GRID_HEIGHT-2-4);
                                    end if;
                                    w2_y0 <= tmp5 + 1;
                                end if;

                                ------------------------------------------------------------------
                                -- Wall 3
                                ------------------------------------------------------------------
                                s := lfsr_next(s);
                                w3_orient <= s(0);
                                if w3_orient = '0' then
                                    tmp6 := to_integer(unsigned(s(6 downto 1)));
                                    if tmp6 >= (GRID_WIDTH-2-4) then
                                        tmp6 := tmp6 - (GRID_WIDTH-2-4);
                                    end if;
                                    w3_x0 <= tmp6 + 1;

                                    tmp5 := to_integer(unsigned(s(5 downto 1)));
                                    if tmp5 >= (GRID_HEIGHT-2) then
                                        tmp5 := tmp5 - (GRID_HEIGHT-2);
                                    end if;
                                    w3_y0 <= tmp5 + 1;
                                else
                                    tmp6 := to_integer(unsigned(s(6 downto 1)));
                                    if tmp6 >= (GRID_WIDTH-2) then
                                        tmp6 := tmp6 - (GRID_WIDTH-2);
                                    end if;
                                    w3_x0 <= tmp6 + 1;

                                    tmp5 := to_integer(unsigned(s(5 downto 1)));
                                    if tmp5 >= (GRID_HEIGHT-2-4) then
                                        tmp5 := tmp5 - (GRID_HEIGHT-2-4);
                                    end if;
                                    w3_y0 <= tmp5 + 1;
                                end if;

                                lfsr_reg     <= s;
                                wall_state   <= W_PREVIEW;
                                phase_count  <= 0;
                                walls_active <= '1';

                            else
                                phase_count <= phase_count + 1;
                            end if;

                        ------------------------------------------------------------------
                        -- PREVIEW: show lighter color, no collision (handled elsewhere)
                        ------------------------------------------------------------------
                        when W_PREVIEW =>
                            if phase_count >= PREVIEW_TICKS - 1 then
                                wall_state  <= W_VISIBLE;
                                phase_count <= 0;
                            else
                                phase_count <= phase_count + 1;
                            end if;

                        ------------------------------------------------------------------
                        -- VISIBLE: solid walls for 3 s, then disappear
                        ------------------------------------------------------------------
                        when W_VISIBLE =>
                            if phase_count >= VISIBLE_TICKS - 1 then
                                wall_state   <= W_INVISIBLE;
                                phase_count  <= 0;
                                walls_active <= '0';
                            else
                                phase_count <= phase_count + 1;
                            end if;

                    end case;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------------
    -- Combinational wall logic for current grid cell (for VGA drawing)
    --------------------------------------------------------------------------
    process(x, y,
            snake1_x, snake1_y,
            snake2_x, snake2_y,
            food_x_i, food_y_i,
            wall_state, walls_active,
            w1_x0, w1_y0, w1_orient,
            w2_x0, w2_y0, w2_orient,
            w3_x0, w3_y0, w3_orient)
        variable border_here      : std_logic;
        variable dyn_solid_here   : std_logic;
        variable dyn_preview_here : std_logic;
        variable occupant_here    : std_logic;
    begin
        -- Border walls (always active, solid)
        border_here := '0';
        if (x = 0) or (y = 0) or
           (x = GRID_WIDTH-1) or (y = GRID_HEIGHT-1) then
            border_here := '1';
        end if;

        dyn_solid_here   := '0';
        dyn_preview_here := '0';

        if walls_active = '1' then
            ------------------------------------------------------------------
            -- Solid or preview dynamic walls, depending on state
            ------------------------------------------------------------------
            if wall_state = W_VISIBLE then
                -- Solid phase
                -- Wall 1
                if w1_orient = '0' then
                    if (y = w1_y0) and (x >= w1_x0) and (x <= w1_x0 + 4) then
                        dyn_solid_here := '1';
                    end if;
                else
                    if (x = w1_x0) and (y >= w1_y0) and (y <= w1_y0 + 4) then
                        dyn_solid_here := '1';
                    end if;
                end if;

                -- Wall 2
                if w2_orient = '0' then
                    if (y = w2_y0) and (x >= w2_x0) and (x <= w2_x0 + 4) then
                        dyn_solid_here := '1';
                    end if;
                else
                    if (x = w2_x0) and (y >= w2_y0) and (y <= w2_y0 + 4) then
                        dyn_solid_here := '1';
                    end if;
                end if;

                -- Wall 3
                if w3_orient = '0' then
                    if (y = w3_y0) and (x >= w3_x0) and (x <= w3_x0 + 4) then
                        dyn_solid_here := '1';
                    end if;
                else
                    if (x = w3_x0) and (y >= w3_y0) and (y <= w3_y0 + 4) then
                        dyn_solid_here := '1';
                    end if;
                end if;

            elsif wall_state = W_PREVIEW then
                -- Preview phase: same geometry, different color
                -- Wall 1
                if w1_orient = '0' then
                    if (y = w1_y0) and (x >= w1_x0) and (x <= w1_x0 + 4) then
                        dyn_preview_here := '1';
                    end if;
                else
                    if (x = w1_x0) and (y >= w1_y0) and (y <= w1_y0 + 4) then
                        dyn_preview_here := '1';
                    end if;
                end if;

                -- Wall 2
                if w2_orient = '0' then
                    if (y = w2_y0) and (x >= w2_x0) and (x <= w2_x0 + 4) then
                        dyn_preview_here := '1';
                    end if;
                else
                    if (x = w2_x0) and (y >= w2_y0) and (y <= w2_y0 + 4) then
                        dyn_preview_here := '1';
                    end if;
                end if;

                -- Wall 3
                if w3_orient = '0' then
                    if (y = w3_y0) and (x >= w3_x0) and (x <= w3_x0 + 4) then
                        dyn_preview_here := '1';
                    end if;
                else
                    if (x = w3_x0) and (y >= w3_y0) and (y <= w3_y0 + 4) then
                        dyn_preview_here := '1';
                    end if;
                end if;
            end if;
        end if;

        -- Objects that random walls should not visually overwrite
        occupant_here := '0';
        if (x = snake1_x and y = snake1_y) or
           (x = snake2_x and y = snake2_y) or
           (x = food_x_i and y = food_y_i) then
            occupant_here := '1';
        end if;

        -- Final VGA outputs:
        --  - is_wall: border + solid dynamic walls
        --  - is_wall_preview: preview dynamic walls only
        if border_here = '1' then
            is_wall <= '1';
        elsif (dyn_solid_here = '1') and (occupant_here = '0') then
            is_wall <= '1';
        else
            is_wall <= '0';
        end if;

        if (dyn_preview_here = '1') and (occupant_here = '0') then
            is_wall_preview <= '1';
        else
            is_wall_preview <= '0';
        end if;
    end process;

    --------------------------------------------------------------------------
    -- Geometry / phase outputs for collision modules
    --------------------------------------------------------------------------
    w1_x0_o     <= w1_x0;
    w1_y0_o     <= w1_y0;
    w1_orient_o <= w1_orient;

    w2_x0_o     <= w2_x0;
    w2_y0_o     <= w2_y0;
    w2_orient_o <= w2_orient;

    w3_x0_o     <= w3_x0;
    w3_y0_o     <= w3_y0;
    w3_orient_o <= w3_orient;

    -- "Solid" means random walls are currently real obstacles
    walls_solid_o <= '1' when (walls_active = '1' and wall_state = W_VISIBLE) else '0';

end architecture;
