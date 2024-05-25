library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

entity collision_controller is
    port (
        clock_60Hz : in std_logic;
        bird_pos : in t_bird_pos;
        power_up: in t_power_ups;
        pipe_posns : in t_pipe_pos_arr;
        collision : out boolean; -- Collision detected
        collision_type: out integer range 0 to 8 :=0
    );
end entity;

architecture behaviour of collision_controller is
begin
    process (clock_60Hz)
        variable collision_detected : boolean;
        variable curr_pipe : t_pipe_pos;
    begin
        if (rising_edge(clock_60Hz)) then
            collision_detected := false;
            for i in 0 to 2 loop
                if (
                    bird_pos.x + (SPRITE_BIRD_WIDTH * 2) > pipe_posns(i).x - PIPE_WIDTH / 2 
                    and bird_pos.x < pipe_posns(i).x + PIPE_WIDTH / 2 
                    and (bird_pos.y + (SPRITE_BIRD_HEIGHT * 2) >= (pipe_posns(i).y + PIPE_GAP_RADIUS) or bird_pos.y <= pipe_posns(i).y - PIPE_GAP_RADIUS)
                ) then 
                    collision_detected := true;
                    collision_type<=3; -- 3 means a pipe
                end if;
            end loop;
            if (bird_pos.x + (SPRITE_BIRD_WIDTH * 2) > power_up.x and bird_pos.x < power_up.x+
                (POWERUP_SIZE) and bird_pos.y+(SPRITE_BIRD_HEIGHT * 2)>power_up.y and bird_pos.y < power_up.y+POWERUP_SIZE) 
                then collision_detected := true;
                collision_type<=power_up.p_type;     --0- health, 1-slow down, 2- ghost
                collision <= collision_detected;
            end if;
        end if;
    end process;
end architecture;