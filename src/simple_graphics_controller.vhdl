library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

LIBRARY altera_mf;
USE altera_mf.all;

entity simple_graphics_controller is
    port (
        CLOCK2_50, clock_60Hz: in std_logic;
        VGA_HS, VGA_VS : out std_logic;
        VGA_R, VGA_G, VGA_B : out std_logic_vector(3 downto 0);
        bird_pos : in t_bird_posn;
        pipe_posns : in t_pipe_positions_array;
        score_string : in string
    );
end entity;

architecture behaviour of simple_graphics_controller is 

    signal clock_25Mhz : std_logic := '0';
    signal row, column : std_logic_vector(9 downto 0);
    signal red_enable, green_enable, blue_enable : std_logic;

    signal char_addr : std_logic_vector(6 downto 0);
    signal char_row, char_col : std_logic_vector(2 downto 0);
    signal char_bit : std_logic;

    signal current_pixel : std_logic_vector(11 downto 0);

    signal score_string_pos : t_gen_posn := (x => 33, y => 25);

    component vga_sync is
        PORT(	clock_25Mhz, red, green, blue		: IN	STD_LOGIC;
			red_out, green_out, blue_out, horiz_sync_out, vert_sync_out	: OUT	STD_LOGIC;
			pixel_row, pixel_column: OUT STD_LOGIC_VECTOR(9 DOWNTO 0));
    end component;

    component char_rom is
        PORT
        (
            character_address	:	IN STD_LOGIC_VECTOR (6 DOWNTO 0);
            font_row, font_col	:	IN STD_LOGIC_VECTOR (2 DOWNTO 0);
            clock				: 	IN STD_LOGIC ;
            rom_mux_output		:	OUT STD_LOGIC
        );
    end component;

begin
    sync: vga_sync port map (
        clock_25Mhz => clock_25Mhz, 
        red => '1', green => '1', blue => '1', 
        red_out => red_enable, green_out => green_enable, blue_out => blue_enable, 
        horiz_sync_out => VGA_HS, vert_sync_out => VGA_VS, 
        pixel_row => row, pixel_column => column
    );

    chars: char_rom port map (
        character_address => char_addr,
        font_row => char_row, font_col => char_col,
        clock => CLOCK2_50,
        rom_mux_output => char_bit
    );

    process (CLOCK2_50)
        variable x : integer range 0 to 639;
        variable y : integer range 0 to 479;
        variable dX, dY : integer;
        variable current_pixel_computed : std_logic_vector(11 downto 0);
        variable char : character;
        variable pipe_pos : t_pipe_posn;
    begin
        if (rising_edge(CLOCK2_50)) then

            current_pixel_computed := x"5cc";

            x := to_integer(unsigned(column));
            y := to_integer(unsigned(row));

            -- Draw pipes
            for i in 0 to 2 loop
                pipe_pos := pipe_posns(i);
                if (x >= pipe_pos.x - PIPE_WIDTH / 2 and x <= pipe_pos.x + PIPE_WIDTH / 2 and y < GROUND_START_Y and (y < pipe_pos.y - PIPE_GAP_RADIUS or y >= pipe_pos.y + PIPE_GAP_RADIUS)) then
                    current_pixel_computed := x"0f0";
                end if;
            end loop;

            -- Draw the bird
            if (x >= bird_pos.x and x <= (bird_pos.x + (SPRITE_BIRD_WIDTH * 2)) and y >= bird_pos.y and y < (bird_pos.y + SPRITE_BIRD_HEIGHT * 2)) then
                current_pixel_computed := x"ff0";
            end if;

            -- Draw the ground
            if (y >= GROUND_START_Y) then
                current_pixel_computed := x"7f7";
            end if;

            if (x = 0) then
                current_pixel <= x"000";
            else
                current_pixel <= current_pixel_computed;
            end if;

            clock_25Mhz <= not clock_25Mhz;
        end if;
    end process;

    VGA_R <= current_pixel(11 downto 8) when red_enable = '1' else "0000";
    VGA_G <= current_pixel(7 downto 4) when green_enable = '1' else "0000";
    VGA_B <= current_pixel(3 downto 0) when blue_enable = '1' else "0000";
end architecture;