library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.snake_game_pkg.all;

entity vga_controller is
    Port (
        clk : in std_logic;           -- 25.175 MHz pixel clock
        rst : in std_logic;
        hsync : out std_logic;
        vsync : out std_logic;
        video_on : out std_logic;
        pixel_x : out integer range 0 to H_TOTAL-1;
        pixel_y : out integer range 0 to V_TOTAL-1
    );
end vga_controller;

architecture Behavioral of vga_controller is
    signal h_count : integer range 0 to H_TOTAL-1 := 0;
    signal v_count : integer range 0 to V_TOTAL-1 := 0;
    signal hsync_i : std_logic := '1';
    signal vsync_i : std_logic := '1';
    signal video_on_i : std_logic := '0';
begin

    process(clk, rst)
    begin
        if rst = '1' then
            h_count <= 0;
            v_count <= 0;
            hsync_i <= '1';
            vsync_i <= '1';
            video_on_i <= '0';
        elsif rising_edge(clk) then
            -- Horizontal counter
            if h_count = H_TOTAL - 1 then
                h_count <= 0;
                -- Vertical counter
                if v_count = V_TOTAL - 1 then
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
                end if;
            else
                h_count <= h_count + 1;
            end if;
            
            -- Horizontal sync
            if h_count >= (H_DISPLAY + H_FRONT) and 
               h_count < (H_DISPLAY + H_FRONT + H_SYNC) then
                hsync_i <= '0';
            else
                hsync_i <= '1';
            end if;
            
            -- Vertical sync
            if v_count >= (V_DISPLAY + V_FRONT) and 
               v_count < (V_DISPLAY + V_FRONT + V_SYNC) then
                vsync_i <= '0';
            else
                vsync_i <= '1';
            end if;
            
            -- Video enable
            if h_count < H_DISPLAY and v_count < V_DISPLAY then
                video_on_i <= '1';
            else
                video_on_i <= '0';
            end if;
        end if;
    end process;
    
    hsync <= hsync_i;
    vsync <= vsync_i;
    video_on <= video_on_i;
    pixel_x <= h_count;
    pixel_y <= v_count;

end Behavioral;
