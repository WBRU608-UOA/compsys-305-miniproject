library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

entity bird_controller is
    port (
        clock_60Hz, init : in std_logic;
        bird_pos : inout t_bird_posn;
        left_click : in std_logic
    );
end entity;

architecture behaviour of bird_controller is
    signal left_click_mem : boolean := false;
    signal bird_y_vel : integer := 0;
    signal flip_flop : boolean := false;
begin
    process (clock_60Hz)
        variable y_vel, y_pos : integer;
    begin
        if (rising_edge(clock_60Hz)) then
            if (init = '1') then
                bird_pos.y <= MAX_Y / 2 - SPRITE_BIRD_HEIGHT / 2;
            else
                y_pos := bird_pos.y;

                if (flip_flop) then
                    y_vel := bird_y_vel + 1;
                else
                    y_vel := bird_y_vel;
                end if;
                flip_flop <= not flip_flop;

                if (y_vel > BIRD_MAX_VEL) then
                    y_vel := BIRD_MAX_VEL;
                end if;

                if (left_click = '1' and not left_click_mem) then
                    y_vel := BIRD_IMPULSE_VEL;
                    left_click_mem <= true;
                elsif (left_click = '0' and left_click_mem) then
                    left_click_mem <= false;
                end if;

                y_pos := y_pos + y_vel;
                if (y_pos + 2 * SPRITE_BIRD_HEIGHT > GROUND_START_Y) then
                    y_pos := GROUND_START_Y - 2 * SPRITE_BIRD_HEIGHT;
                    y_vel := 0;
                elsif (y_pos < 0) then
                    y_pos := 0;
                    y_vel := 0;
                end if;
                bird_pos.y <= y_pos;
                bird_y_vel <= y_vel;
            end if;
        end if;
    end process;
    bird_pos.x <= 100;
end architecture;