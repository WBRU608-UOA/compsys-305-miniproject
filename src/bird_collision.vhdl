library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

entity bird_collision is
    port (
        clock_60Hz, reset : in std_logic;
        bird_pos_coll : in t_bird_posn;
        collide : out STD_LOGIC -- Collision detected
        pipe_pos_coll : in t_pipe_positions_array;
    );
end entity;

architecture behaviour of bird_collision is

begin

    process (clock_60Hz,reset)

    begin
        if (rising_edge(clock_60Hz)) then
            if (reset = '1') then
                collide <= 0;
            elsif bird_pos_coll(i).y>=GROUND_START_Y then
                collide <= 1;
            end if;
            for i in 0 to 2 loop
                if (bird_pos.x + (SPRITE_BIRD_WIDTH * 2)> pipe_pos_coll(i).x - PIPE_WIDTH / 2 and bird_pos.x < pipe_pos_coll(i).x + PIPE_WIDTH / 2 and (bird_pos.y >= (pipe_pos_coll(i).y + PIPE_GAP_RADIUS) or bird_pos.y <= pipe_pos_coll(i).y - PIPE_GAP_RADIUS)) then 
                collide <= 1;
                end if;
        end if;
        
    end process;