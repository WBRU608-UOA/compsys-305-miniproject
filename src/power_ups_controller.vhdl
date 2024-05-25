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
        power_up : out t_power_ups;
        rng : in integer;
        pipe_posns: in t_pipe_pos_arr
    );
end entity;

architecture behaviour of power_ups_controller is

signal current_power_up : t_power_ups;

begin
    process (clock_60Hz)
        variable power_ups_x : integer;
        variable power_ups_y : integer;
        variable power_active : boolean := false;
        variable power_up_go:boolean :=true ;
    begin	 
        if (rising_edge(clock_60Hz)) then

            if (state = S_INIT) then
            -- initial x, y

            elsif (state = S_GAME) then
                if (rng mod 1024>50) then
                    for i in 0 to 2 loop
                        if pipe_posns(i).x>600 then
                        power_up_go:=false;
                        end if;
                    end loop;
                    if power_up_go and not power_active then     
                        power_up.active<=true;
                        power_active:=true;
                        power_up.x<=pipe_posns(2).x+ 100;
                        power_up.y<=(rng mod 380);
                        power_up.p_type<=(rng mod 3);
                    end if;
                    if power_active then 
                        power_ups_x := power_ups_x - 2;
                        if (power_ups_x < 0) then 
                            power_active:=false;
                            power_up.active<=false;
                        end if;
                    end if;
                    power_up.x <= power_ups_x;
                end if;
            end if;
        end if;
    end process;
end architecture;