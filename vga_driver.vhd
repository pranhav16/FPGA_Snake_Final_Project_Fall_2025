library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_driver is
    Port (
        clk : in std_logic;           -- 25.175 MHz pixel clock
        rst : in std_logic;
        hsync_o : out std_logic;
        vsync_o : out std_logic;
        frame_o : out std_logic;
        blank_o : out std_logic;
        hcount_o : out unsigned(9 downto 0);
        vcount_o : out unsigned(9 downto 0)
    );
end vga_driver;

architecture arch of vga_driver is
    signal hcount:   unsigned(9 downto 0) := (others => '0');
    signal vcount:   unsigned(9 downto 0) := (others => '0');
    signal blank:  std_logic := '0';
    signal frame:  std_logic := '0';
    signal hsync:  std_logic := '1';
    signal vsync:  std_logic := '1';
begin

    	------------------------------------------------------------------
	-- VGA display counters
	--
	-- Pixel clock: 25.175 MHz (actual: 25.2 MHz)
	-- Horizontal count (active low sync):
	--     0 to 639: Active video
	--     640 to 799: Horizontal blank
	--     656 to 751: Horizontal sync (active low)
	-- Vertical count (active low sync):
	--     0 to 479: Active video
	--     480 to 524: Vertical blank
	--     490 to 491: Vertical sync (active low)
	------------------------------------------------------------------
	process(clk)
	begin
	       
		if rising_edge(clk) then
			-- Pixel position counters
			if (hcount>=to_unsigned(799,10)) then
				hcount<=(others=>'0');
				if (vcount>=to_unsigned(524,10)) then
					vcount<=(others=>'0');
				else
					vcount<=vcount+1;
				end if;
			else
				hcount<=hcount+1;
			end if;
			-- Sync, blank and frame
			if (hcount>=to_unsigned(656,10)) and
				(hcount<=to_unsigned(751,10)) then
				hsync<='0';
			else
				hsync<='1';
			end if;
			if (vcount>=to_unsigned(490,10)) and
				(vcount<=to_unsigned(491,10)) then
				vsync<='0';
			else
				vsync<='1';
			end if;
			if (hcount>=to_unsigned(640,10)) or
				(vcount>=to_unsigned(480,10)) then
				blank<='1';
			else
				blank<='0';
			end if;
			if (hcount=to_unsigned(640,10)) and
				(vcount=to_unsigned(479,10)) then
				frame<='1';
			else
				frame<='0';
			end if;
		end if;
	end process;
    
    hsync_o <= hsync;
    vsync_o <= vsync;
    blank_o <= blank;
    frame_o <= frame;
    hcount_o <= hcount;
    vcount_o <= vcount;

end arch;
