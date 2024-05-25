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
        SW : in std_logic_vector(0 downto 0);
        LEDR : out std_logic_vector(7 downto 0);
        VGA_HS, VGA_VS : out std_logic;
        VGA_R, VGA_G, VGA_B : out std_logic_vector(3 downto 0);
        PS2_CLK, PS2_DAT : inout std_logic;
        HEX0, HEX1, HEX2, HEX5 : out std_logic_vector(6 downto 0)
    );
end entity;

architecture behaviour of flappy_bird is
    signal state : t_game_state := S_INIT;

    -- Bird position
    signal bird_pos : t_bird_pos := (x => 75, y => 240);

    signal pipe_posns : t_pipe_pos_arr;

    -- Goes high at 60Hz, but spends most of the time at low - use this for rising edge detection only!
    signal clock_60Hz : std_logic;

    signal health: integer range 0 to 3 :=3;

    -- Used to drive 60Hz clock, as we know its period is also 60Hz
    signal vertical_sync : std_logic;

    signal left_button, right_button : std_logic;
    signal mouse_row, mouse_column : std_logic_vector(9 downto 0);

    signal init : std_logic;

    signal score : t_score;

    signal day : std_logic;

    --SM-I added this
    signal collision_detected : boolean;
    signal collide_mem : boolean := false;

    signal rng : integer range 0 to 65535;

    component BCD_to_SevenSeg is
        port (BCD_digit : in std_logic_vector(3 downto 0);
        SevenSeg_out : out std_logic_vector(6 downto 0));
    end component;

    component graphics_controller is
        port (
            state : in t_game_state;
            CLOCK2_50, clock_60Hz: in std_logic;
            VGA_HS, VGA_VS : out std_logic;
            VGA_R, VGA_G, VGA_B : out std_logic_vector(3 downto 0);
            bird_pos : in t_bird_pos;
            pipe_posns : in t_pipe_pos_arr;
            score : in t_score;
            day : in std_logic;
            health : in integer
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
            state : t_game_state;
            clock_60Hz : in std_logic;
            bird_pos : inout t_bird_pos;
            left_click : in std_logic
        );
    end component;

    component score_controller is
        port (
            clock_60Hz : in std_logic;
            pipes : in t_pipe_pos_arr;
            bird : in t_bird_pos;
            score_out : out t_score;
            state : in t_game_state
        );
    end component;

    component pipe_controller is
        port (
            state : in t_game_state;
            clock_60Hz : in std_logic;
            pipe_posns : out t_pipe_pos_arr;
            rng : in integer
        );
    end component;

    component random_generator is
        port (
            CLOCK2_50 : in std_logic;
            rng : out integer range 0 to 65535
        );
    end component;

    component collision_controller is
        port (
            clock_60Hz : in std_logic;
            bird_pos : in t_bird_pos;
            pipe_posns : in t_pipe_pos_arr;
            collision : out boolean -- Collision detected
        );
    end component;

begin
    score_hundreds : BCD_to_SevenSeg port map (
        BCD_digit => std_logic_vector(to_unsigned(score(2), 4)), SevenSeg_out => HEX2
    );
    score_tens : BCD_to_SevenSeg port map (
        BCD_digit => std_logic_vector(to_unsigned(score(1), 4)), SevenSeg_out => HEX1
    );
    score_ones : BCD_to_SevenSeg port map (
        BCD_digit => std_logic_vector(to_unsigned(score(0), 4)), SevenSeg_out => HEX0
    );

    health_bcd : BCD_to_SevenSeg port map (
        BCD_DIGIT => std_logic_vector(to_unsigned(health, 4)), SevenSeg_out => HEX5
    );

    -- Use `simple_graphics_controller` for basic output
    graphics: graphics_controller port map (
        state => state,
        CLOCK2_50 => CLOCK2_50, clock_60Hz => clock_60Hz,
        VGA_HS => VGA_HS, VGA_VS => vertical_sync, 
        VGA_R => VGA_R, VGA_G => VGA_G, VGA_B => VGA_B,
        bird_pos => bird_pos, pipe_posns => pipe_posns,
        score => score,
        day => day,
        health => health
    );

    mouse: mouse_controller port map (
        CLOCK2_50 => CLOCK2_50, reset => init,
        left_button => left_button, right_button => right_button,
        cursor_row => mouse_row, cursor_column => mouse_column,
        PS2_CLK => PS2_CLK, PS2_DAT => PS2_DAT
    );

    bird : bird_controller port map (
        state => state,
        clock_60Hz => clock_60Hz,
        bird_pos => bird_pos,
        left_click => left_button
    );

    scorer : score_controller port map (
        clock_60Hz => clock_60Hz,
        pipes => pipe_posns,
        bird => bird_pos,
        score_out => score,
        state => state
    );

    pipe : pipe_controller port map (
        state => state,
        clock_60Hz => clock_60Hz,
        pipe_posns => pipe_posns,
        rng => rng
    );

    random : random_generator port map (
        CLOCK2_50 => CLOCK2_50,
        rng => rng
    );

    collision : collision_controller port map (
        clock_60Hz => clock_60Hz,
        bird_pos => bird_pos,
        pipe_posns => pipe_posns,
        collision => collision_detected
    );

    state_machine : process (clock_60Hz)
    begin
        if (rising_edge(clock_60Hz)) then
            if (init = '1') then
                state <= S_INIT;
                health <= 3;
            else
                if (left_button = '1' and state = S_INIT) then
                    state <= S_GAME;
                    health <= 3;
                end if;
            end if;
            -- This is done here so that it's vsynced
            day <= not SW(0);

            if (health > 0 and collision_detected and not collide_mem) then 
                health <= health - 1;
                collide_mem <= true;
            elsif (not collision_detected and collide_mem) then
                collide_mem <= false;
            end if;

        end if;
    end process;

    VGA_VS <= vertical_sync;
    clock_60Hz <= not vertical_sync;

    LEDR(0) <= '1' when collision_detected else '0';
    LEDR(1) <= init;

    init <= not KEY(0);
end architecture;