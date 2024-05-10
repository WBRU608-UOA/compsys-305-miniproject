library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;

entity flappy_bird is
    port (
        CLOCK2_50: in std_logic;
        KEY : in std_logic_vector(0 downto 0);
        LEDR : out std_logic_vector(0 downto 0);
        VGA_HS, VGA_VS : out std_logic;
        VGA_R, VGA_G, VGA_B : out std_logic_vector(3 downto 0)
    );
end entity;

architecture behaviour of flappy_bird is

    -- BIRD POSITIONM
    signal bird_pos : t_bird_posn := (x => 50, y => 76);

    -- Goes high at 60Hz, but spends most of the time at low - use this for rising edge detection only!
    signal clock_60Hz : std_logic;

    -- Used to drive 60Hz clock, as we know its period is also 60Hz
    signal vertical_sync : std_logic;

    component graphics_controller is
        port (
            CLOCK2_50: in std_logic;
            VGA_HS, VGA_VS : out std_logic;
            VGA_R, VGA_G, VGA_B : out std_logic_vector(3 downto 0);
            bird_pos : t_bird_posn
        );
    end component;
begin
    controller: graphics_controller port map (
        CLOCK2_50 => CLOCK2_50, 
        VGA_HS => VGA_HS, VGA_VS => vertical_sync, 
        VGA_R => VGA_R, VGA_G => VGA_G, VGA_B => VGA_B,
        bird_pos => bird_pos
    );

    -- Test movement
    process (clock_60Hz)
    begin
        if (rising_edge(clock_60Hz)) then
            bird_pos.x <= (bird_pos.x + 1) mod BIRD_MAX_X;
        end if;
    end process;

    VGA_VS <= vertical_sync;
    clock_60Hz <= not vertical_sync;
end architecture;