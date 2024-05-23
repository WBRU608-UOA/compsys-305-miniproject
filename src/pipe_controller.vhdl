library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

entity pipe_controller is
    port (
        state : in t_game_state;
        clock_60Hz : in std_logic;
        pipe_posns : out t_pipe_positions_array
    );
end entity;

architecture behaviour of pipe_controller is

signal current_pipe_posns : t_pipe_positions_array;

begin
    process (clock_60Hz)
        variable new_pipe_x : integer;
        variable new_pipe_y : integer;
        variable pipe_pos : t_pipe_posn;
        variable lfsr_y : std_logic_vector(15 downto 0) := "0000000000000001"; -- 16-bit LFSR for y
        variable random_y : integer;
    begin
	
	 
        if (rising_edge(clock_60Hz)) then

            -- Reset LFSR
            if (state = S_INIT) then
                lfsr_y := "0000000000000001";

            -- initial x, y
                for i in 0 to 2 loop
                    current_pipe_posns(i).x <= CENTRE_X + ((MAX_X + PIPE_WIDTH) / 3) + i * ((MAX_X + PIPE_WIDTH) / 3);
                    current_pipe_posns(i).y <= ((i * 5201314) mod (PIPE_MAX_Y - PIPE_MIN_Y + 1)) + PIPE_MIN_Y;
                end loop;

            elsif (state = S_GAME) then

                -- random lfsr_y
                lfsr_y := lfsr_y(14 downto 0) & (lfsr_y(15) xor lfsr_y(13));

                -- Generate random y within specified ranges
                random_y := (to_integer(unsigned(lfsr_y)) mod (PIPE_MAX_Y - PIPE_MIN_Y + 1)) + PIPE_MIN_Y;

                -- x y generation
                for i in 0 to 2 loop
                    pipe_pos := current_pipe_posns(i);
                    new_pipe_x := pipe_pos.x - 2;
                    new_pipe_y := pipe_pos.y;
                    if (new_pipe_x < -PIPE_WIDTH / 2) then
                        new_pipe_x := MAX_X + PIPE_WIDTH / 2;
                        new_pipe_y := random_y;
                    end if;
                    current_pipe_posns(i).x <= new_pipe_x;
                    current_pipe_posns(i).y <= new_pipe_y;
                end loop;
            end if;
        end if;
    end process;
	 pipe_posns <= current_pipe_posns;
end architecture;






