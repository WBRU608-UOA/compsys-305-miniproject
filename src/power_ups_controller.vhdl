library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

entity power_ups_controller is
    port (
        state : in t_game_state;
        clock_60Hz : in std_logic;
        power_up : inout t_power_ups;
        rng : in integer;
        pipe_posns: in t_pipe_pos_arr;
        health : in integer
    );
end entity;

architecture behaviour of power_ups_controller is

signal current_power_up : t_power_ups;

begin
    process (clock_60Hz)
        variable power_up_x : integer;
        variable power_up_type : integer;
        variable power_up_go : boolean :=true ;
    begin	 
        if (rising_edge(clock_60Hz)) then
            if (state = S_INIT) then
                power_up.active <= false;
            elsif (state = S_GAME and not power_up.active) then
                if (rng mod 256 = 0) then
                    for i in 0 to 2 loop
                        if pipe_posns(i).x > 600 then
                            power_up_go := false;
                        end if;
                    end loop;
                    if (power_up_go) then     
                        power_up.active <= true;
                        power_up.x <= SCREEN_MAX_X + 100;
                        power_up.y <= 112 + (rng mod 256);
                        power_up_type := (rng mod 4);
                        if (power_up_type = 1 and health = 3) then
                            power_up_type := 0;
                        end if;
                        power_up.p_type <= power_up_type;
                    end if;
                end if;
            elsif (power_up.active) then
                power_up_x := power_up.x - 2;
                if (power_up_x < -POWERUP_SIZE) then
                    power_up.active <= false;
                end if;
                power_up.x <= power_up_x;
            end if;
        end if;
    end process;
end architecture;