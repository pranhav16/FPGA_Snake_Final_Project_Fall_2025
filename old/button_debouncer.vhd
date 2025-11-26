library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity button_debouncer is
    Generic (
        DEBOUNCE_TIME : integer := 1000000  -- 10ms at 100MHz
    );
    Port (
        clk : in std_logic;
        rst : in std_logic;
        button_in : in std_logic;
        button_out : out std_logic
    );
end button_debouncer;

architecture Behavioral of button_debouncer is
    signal counter : integer range 0 to DEBOUNCE_TIME := 0;
    signal button_sync : std_logic_vector(2 downto 0) := "000";
    signal button_stable : std_logic := '0';
begin

    process(clk, rst)
    begin
        if rst = '1' then
            button_sync <= "000";
            button_stable <= '0';
            counter <= 0;
            button_out <= '0';
        elsif rising_edge(clk) then
            -- Synchronize button input
            button_sync <= button_sync(1 downto 0) & button_in;
            
            -- Debounce logic
            if button_sync(2) /= button_stable then
                counter <= counter + 1;
                if counter >= DEBOUNCE_TIME then
                    button_stable <= button_sync(2);
                    counter <= 0;
                end if;
            else
                counter <= 0;
            end if;
            
            -- Edge detection for button press
            if button_stable = '1' and button_out = '0' then
                button_out <= '1';
            else
                button_out <= '0';
            end if;
        end if;
    end process;

end Behavioral;
