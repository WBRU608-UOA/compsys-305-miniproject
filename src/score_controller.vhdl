library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

entity score_controller is
    port (
        clock_60Hz : in std_logic;
        pipes : in t_pipe_positions_array;
        bird : in t_bird_posn;
        score_out : out t_score;
        init : in std_logic
    );
end entity;

architecture behaviour of score_controller is
    signal score : t_score;
    signal old_pipes : t_pipe_positions_array;
begin
    -- Test movement
    process (clock_60Hz)
        variable new_pipe_x : integer;
        variable pipe_pos : t_pipe_posn;
        variable score_temp : natural;
        variable score_hold : t_score;
    begin
        if (init = '1') then
            score <= (others => 0);
        elsif (rising_edge(clock_60Hz)) then
            score_hold := score;
            for i in 0 to 2 loop
                if (old_pipes(i).x >= bird.x and pipes(i).x < bird.x) then
                    score_hold(0) := score_hold(0) + 1;
                    if (score_hold(0) = 10) then
                        score_hold(0) := 0;
                        score_hold(1) := score_hold(1) + 1;
                        if (score_hold(1) = 10) then
                            score_hold(1) := 0;
                            score_hold(2) := score_hold(2) + 1;
                            if (score_hold(2) = 10) then
                                score_hold(2) := 0;
                                score_hold(3) := score_hold(3) + 1;
                            end if;
                        end if;
                    end if;
                end if;

                old_pipes(i) <= pipes(i);
            end loop;

            score <= score_hold;
        end if;
    end process;

    score_out <= score;
end architecture;