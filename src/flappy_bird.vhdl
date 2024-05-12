library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

entity flappy_bird is
    port (
        CLOCK2_50: in std_logic;
        KEY : in std_logic_vector(0 downto 0);
        LEDR : out std_logic_vector(7 downto 0);
        VGA_HS, VGA_VS : out std_logic;
        VGA_R, VGA_G, VGA_B : out std_logic_vector(3 downto 0);
        PS2_CLK, PS2_DAT : inout std_logic;
        HEX0, HEX1, HEX2, HEX3 : out std_logic_vector(6 downto 0)
    );
end entity;

architecture behaviour of flappy_bird is

    -- Bird position
    signal bird_pos : t_bird_posn := (x => 75, y => 240);

    signal pipe_posns : t_pipe_positions_array;

    -- Goes high at 60Hz, but spends most of the time at low - use this for rising edge detection only!
    signal clock_60Hz : std_logic;

    -- Used to drive 60Hz clock, as we know its period is also 60Hz
    signal vertical_sync : std_logic;

    signal left_button, right_button : std_logic;
    signal mouse_row, mouse_column : std_logic_vector(9 downto 0);

    signal score_string : string(1 to 11) := (others => (' '));

    signal init : std_logic;

    signal score : t_score;

    component BCD_to_SevenSeg is
        port (BCD_digit : in std_logic_vector(3 downto 0);
        SevenSeg_out : out std_logic_vector(6 downto 0));
    end component;

    component graphics_controller is
        port (
            CLOCK2_50, clock_60Hz: in std_logic;
            VGA_HS, VGA_VS : out std_logic;
            VGA_R, VGA_G, VGA_B : out std_logic_vector(3 downto 0);
            bird_pos : t_bird_posn;
            pipe_posns : t_pipe_positions_array;
            score_string : string
        );
    end component;

    component simple_graphics_controller is
        port (
            CLOCK2_50, clock_60Hz: in std_logic;
            VGA_HS, VGA_VS : out std_logic;
            VGA_R, VGA_G, VGA_B : out std_logic_vector(3 downto 0);
            bird_pos : t_bird_posn;
            pipe_posns : t_pipe_positions_array;
            score_string : string
        );
    end component;

    component mouse_controller is
        port (
            CLOCK2_50, reset : in std_logic;
            left_button, right_button : out std_logic;
            cursor_row, cursor_column : out std_logic_vector(9 downto 0);
            PS2_CLK, PS2_DAT : inout std_logic
        );
    end component;

    component bird_controller is
        port (
            clock_60Hz : in std_logic;
            bird_pos : inout t_bird_posn;
            left_click : in std_logic
        );
    end component;

    component score_controller is
        port (
            clock_60Hz : in std_logic;
            pipes : in t_pipe_positions_array;
            bird : in t_bird_posn;
            score_out : out t_score;
            init : in std_logic
        );
    end component;
begin
    score_thousands : BCD_to_SevenSeg port map (
        BCD_digit => std_logic_vector(to_unsigned(score(3), 4)), SevenSeg_out => HEX3
    );
    score_hundreds : BCD_to_SevenSeg port map (
        BCD_digit => std_logic_vector(to_unsigned(score(2), 4)), SevenSeg_out => HEX2
    );
    score_tens : BCD_to_SevenSeg port map (
        BCD_digit => std_logic_vector(to_unsigned(score(1), 4)), SevenSeg_out => HEX1
    );
    score_ones : BCD_to_SevenSeg port map (
        BCD_digit => std_logic_vector(to_unsigned(score(0), 4)), SevenSeg_out => HEX0
    );

    graphics: graphics_controller port map (
        CLOCK2_50 => CLOCK2_50, clock_60Hz => clock_60Hz,
        VGA_HS => VGA_HS, VGA_VS => vertical_sync, 
        VGA_R => VGA_R, VGA_G => VGA_G, VGA_B => VGA_B,
        bird_pos => bird_pos, pipe_posns => pipe_posns,
        score_string => score_string
    );

    mouse: mouse_controller port map (
        CLOCK2_50 => CLOCK2_50, reset => init,
        left_button => left_button, right_button => right_button,
        cursor_row => mouse_row, cursor_column => mouse_column,
        PS2_CLK => PS2_CLK, PS2_DAT => PS2_DAT
    );

    bird : bird_controller port map (
        clock_60Hz => clock_60Hz,
        bird_pos => bird_pos,
        left_click => left_button
    );

    scorer : score_controller port map (
        clock_60Hz => clock_60Hz,
        pipes => pipe_posns,
        bird => bird_pos,
        score_out => score,
        init => init
    );

    -- Test movement
    process (clock_60Hz)
        variable new_pipe_x : integer;
        variable pipe_pos : t_pipe_posn;
        variable score_temp : natural;
    begin
        if (init = '1') then
            for i in 0 to 2 loop
                pipe_posns(i).x <= (640 / 3) + i * (640 / 3);
                pipe_posns(i).y <= PIPE_MIN_Y + ((i * 1793) mod (PIPE_MAX_Y - PIPE_MIN_Y));
            end loop;
        elsif (rising_edge(clock_60Hz)) then
            for i in 0 to 2 loop
                pipe_pos := pipe_posns(i);
                new_pipe_x := pipe_pos.x - 2;
                if (new_pipe_x < -PIPE_WIDTH / 2) then
                    new_pipe_x := MAX_X + PIPE_WIDTH / 2;
                end if;
                pipe_posns(i).x <= new_pipe_x;
            end loop;
        end if;
    end process;

    score_string <= "Score: " & character'val(score(3)) & character'val(score(2)) & character'val(score(1)) & character'val(score(0));

    VGA_VS <= vertical_sync;
    clock_60Hz <= not vertical_sync;

    init <= not KEY(0);
end architecture;