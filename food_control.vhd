library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity food_control is
    generic (
        GRID_WIDTH    : integer := 40;
        GRID_HEIGHT   : integer := 30;
        VISIBLE_TICKS : integer := 80;  -- ~8 s @ 10 Hz
        HIDDEN_TICKS  : integer := 30;  -- ~3 s @ 10 Hz
        SEED          : std_logic_vector(9 downto 0) := "1010101010"
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        game_tick : in  std_logic;

        -- Snake heads for collision detection
        p1_head_x : in  integer range 0 to GRID_WIDTH-1;
        p1_head_y : in  integer range 0 to GRID_WIDTH-1;
        p2_head_x : in  integer range 0 to GRID_WIDTH-1;
        p2_head_y : in  integer range 0 to GRID_WIDTH-1;

        -- Current apple position (grid coordinates)
        food_x    : out integer range 0 to GRID_WIDTH-1;
        food_y    : out integer range 0 to GRID_HEIGHT-1;

        -- One-clock pulses (on clk) when apple is eaten (only when visible)
        p1_ate    : out std_logic;
        p2_ate    : out std_logic
    );
end food_control;

architecture arch of food_control is

    --------------------------------------------------------------------
    -- 10-bit LFSR for pseudo-random positions
    --------------------------------------------------------------------
    signal rand_lfsr : std_logic_vector(9 downto 0);

    --------------------------------------------------------------------
    -- Apple visibility state
    --------------------------------------------------------------------
    signal apple_active : std_logic := '1';  -- '1' = visible, '0' = hidden

    signal vis_count : integer range 0 to VISIBLE_TICKS := 0;
    signal hid_count : integer range 0 to HIDDEN_TICKS  := 0;

    --------------------------------------------------------------------
    -- Registered apple position
    --------------------------------------------------------------------
    signal food_x_r : integer range 0 to GRID_WIDTH-1 := 10;
    signal food_y_r : integer range 0 to GRID_HEIGHT-1 := 10;

    --------------------------------------------------------------------
    -- Eat pulses (registered)
    --------------------------------------------------------------------
    signal p1_ate_r : std_logic := '0';
    signal p2_ate_r : std_logic := '0';

begin

    process(clk)
        variable new_x   : integer;
        variable new_y   : integer;
        variable p1_hit  : boolean;
        variable p2_hit  : boolean;
        variable time_up : boolean;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ----------------------------------------------------------------
                -- Reset everything
                ----------------------------------------------------------------
                rand_lfsr     <= SEED;   -- use generic seed
                apple_active  <= '1';    -- start with visible apple
                vis_count     <= 0;
                hid_count     <= 0;
                food_x_r      <= 10;
                food_y_r      <= 10;
                p1_ate_r      <= '0';
                p2_ate_r      <= '0';

            else
                -- Default: no eat pulses this clock
                p1_ate_r <= '0';
                p2_ate_r <= '0';

                if game_tick = '1' then
                    ------------------------------------------------------------
                    -- Advance LFSR once per game tick
                    ------------------------------------------------------------
                    rand_lfsr <= rand_lfsr(8 downto 0) &
                                 (rand_lfsr(9) xor rand_lfsr(6));

                    if apple_active = '1' then
                        --------------------------------------------------------
                        -- VISIBLE PHASE
                        --------------------------------------------------------
                        time_up := false;

                        -- Visibility timing
                        if vis_count = VISIBLE_TICKS - 1 then
                            time_up   := true;
                            vis_count <= 0;
                        else
                            vis_count <= vis_count + 1;
                        end if;

                        -- Hit detection only when visible
                        p1_hit := (p1_head_x = food_x_r) and (p1_head_y = food_y_r);
                        p2_hit := (p2_head_x = food_x_r) and (p2_head_y = food_y_r);

                        if p1_hit then
                            p1_ate_r <= '1';
                        end if;

                        if p2_hit then
                            p2_ate_r <= '1';
                        end if;

                        -- If time up or eaten -> go to hidden phase NOW
                        if time_up or p1_hit or p2_hit then
                            apple_active <= '0';
                            hid_count    <= 0;
                        end if;

                    else
                        --------------------------------------------------------
                        -- HIDDEN PHASE
                        --------------------------------------------------------
                        if hid_count = HIDDEN_TICKS - 1 then
                            hid_count    <= 0;
                            apple_active <= '1';   -- become visible again

                            ----------------------------------------------------
                            -- Pick new random position
                            ----------------------------------------------------
                            -- X from bits [5:0] -> 0..63, fold into 0..GRID_WIDTH-1
                            new_x := to_integer(unsigned(rand_lfsr(5 downto 0)));
                            if new_x >= GRID_WIDTH then
                                new_x := new_x - GRID_WIDTH;
                                if new_x >= GRID_WIDTH then
                                    new_x := new_x - GRID_WIDTH;
                                end if;
                            end if;

                            -- Y from bits [9:5] -> 0..31, fold into 0..GRID_HEIGHT-1
                            new_y := to_integer(unsigned(rand_lfsr(9 downto 5)));
                            if new_y >= GRID_HEIGHT then
                                new_y := new_y - GRID_HEIGHT;
                            end if;

                            food_x_r  <= new_x;
                            food_y_r  <= new_y;
                            vis_count <= 0;

                        else
                            hid_count <= hid_count + 1;
                        end if;

                    end if; -- apple_active
                end if; -- game_tick
            end if; -- rst
        end if; -- rising_edge
    end process;

    --------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------
    food_x <= food_x_r;
    food_y <= food_y_r;
    p1_ate <= p1_ate_r;
    p2_ate <= p2_ate_r;

end arch;
