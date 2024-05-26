library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

entity powerup_controller is
    port (
        state : in t_game_state;
        clock_60Hz : in std_logic;
        powerup : inout t_powerup;
        rng : in integer;
        pipe_posns: in t_pipe_pos_arr;
        health : in integer;
        difficulty : in integer
    );
end entity;

architecture behaviour of powerup_controller is
begin
    process (clock_60Hz)
        variable powerup_x : integer;
        variable powerup_type : integer;
        variable can_spawn_powerup : boolean;
    begin	 
        if (rising_edge(clock_60Hz)) then
            if (state = S_INIT) then
                powerup.active <= false;
            elsif (state = S_GAME and not powerup.active) then
                if (rng mod 64 = 0) then
                    can_spawn_powerup := true;
                    for i in 0 to 2 loop
                        if pipe_posns(i).x > 630 then
                            can_spawn_powerup := false;
                        end if;
                    end loop;
                    if (can_spawn_powerup) then     
                        powerup.active <= true;
                        powerup.x <= SCREEN_MAX_X;
                        powerup.y <= 112 + (rng mod 256);
                        powerup_type := (rng mod 4);
                        if (powerup_type = 1 and health = 3) then
                            powerup_type := 0;
                        end if;
                        powerup.p_type <= powerup_type;
                    end if;
                end if;
            elsif (state = S_GAME and powerup.active) then
                powerup_x := powerup.x - 2 * difficulty;
                if (powerup_x < -POWERUP_SIZE) then
                    powerup.active <= false;
                end if;
                powerup.x <= powerup_x;
            end if;
        end if;
    end process;
end architecture;