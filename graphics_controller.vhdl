library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

LIBRARY altera_mf;
USE altera_mf.all;

entity graphics_controller is
    port (
        CLOCK2_50, clock_60Hz: in std_logic;
        VGA_HS, VGA_VS : out std_logic;
        VGA_R, VGA_G, VGA_B : out std_logic_vector(3 downto 0);
        bird_pos : in t_bird_posn;
        pipe_posns : in t_pipe_positions_array;
        score_string : in string
    );
end entity;

architecture behaviour of graphics_controller is 

    signal clock_25Mhz : std_logic := '0';
    signal row, column : std_logic_vector(9 downto 0);
    signal red_enable, green_enable, blue_enable : std_logic;

    -- As the bird can overlap with the background and pipes, we need 2 read heads 

    -- Used for the bird and collectables
	signal rom_address_a : std_logic_vector (15 downto 0);
    signal rom_data_a : std_logic_vector(11 downto 0);

    -- Used for pipes and background
	signal rom_address_b : std_logic_vector (15 downto 0);
    signal rom_data_b : std_logic_vector(11 downto 0);

    signal char_addr : std_logic_vector(5 downto 0);
    signal char_row, char_col : std_logic_vector(2 downto 0);
    signal char_bit : std_logic;

    signal current_pixel : std_logic_vector(11 downto 0);

    signal score_string_pos : t_gen_posn := (x => 33, y => 25);

    signal render_layer_a, render_layer_b : boolean;

    signal ground_offset: integer := 0;
    signal background_offset : integer := 0;

    component vga_sync is
        PORT(	clock_25Mhz, red, green, blue		: IN	STD_LOGIC;
			red_out, green_out, blue_out, horiz_sync_out, vert_sync_out	: OUT	STD_LOGIC;
			pixel_row, pixel_column: OUT STD_LOGIC_VECTOR(9 DOWNTO 0));
    end component;

    component char_rom is
        PORT
        (
            character_address	:	IN STD_LOGIC_VECTOR (5 DOWNTO 0);
            font_row, font_col	:	IN STD_LOGIC_VECTOR (2 DOWNTO 0);
            clock				: 	IN STD_LOGIC ;
            rom_mux_output		:	OUT STD_LOGIC
        );
    end component;

    -- Used to interface with the spritesheet.
    -- Dual port, as we need to work with sprite transparency.
    component altsyncram is
        generic (
            operation_mode : string;
            width_a  : integer;
            widthad_a : integer;
            numwords_a : integer;
            width_b : integer;
            widthad_b : integer;
            numwords_b : integer;
            lpm_type : string;
            init_file : string;
            intended_device_family : string;
            address_aclr_a : string;
            address_aclr_b : string;
            clock_enable_input_a : string;
            clock_enable_input_b : string;
            clock_enable_output_a : string;
            clock_enable_output_b : string;
            outdata_aclr_a : string;
            outdata_aclr_b : string;
            outdata_reg_a : string;
            outdata_reg_b : string;
            width_byteena_a : integer;
            width_byteena_b : integer
        );
        port (
            clock0 : in std_logic;
            clock1 : in std_logic;
            address_a : in std_logic_vector(widthad_a - 1 downto 0);
            q_a : out std_logic_vector(width_a - 1 downto 0);
            address_b : in std_logic_vector(widthad_b - 1 downto 0);
            q_b : out std_logic_vector(width_b - 1 downto 0)
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

    altsyncram_component : altsyncram
	generic map (
    operation_mode => "BIDIR_DUAL_PORT",
    width_a => 12,
    widthad_a => 16,
    numwords_a => 65536,
    width_b => 12,
    widthad_b => 16,
    numwords_b => 65536,
    lpm_type => "altsyncram",
    init_file  => "sprites/sprites.mif",
    intended_device_family => "Cyclone III",
    address_aclr_a => "NONE",
    address_aclr_b => "NONE",
    clock_enable_input_a => "BYPASS",
    clock_enable_input_b => "BYPASS",
    clock_enable_output_a => "BYPASS",
    clock_enable_output_b => "BYPASS",
    outdata_aclr_a => "NONE",
    outdata_aclr_b => "NONE",
    outdata_reg_a => "UNREGISTERED",
    outdata_reg_b => "UNREGISTERED",
    width_byteena_a => 1,
    width_byteena_b => 1
)
port map (
    clock0 => CLOCK2_50,
    clock1 => CLOCK2_50,
    address_a => rom_address_a,
    q_a => rom_data_a,
    address_b => rom_address_b,
    q_b => rom_data_b
);

    process (CLOCK2_50)
        variable x, y, bg_dX, pi_dX, bi_dX, gr_dX, te_dX, bg_dY, pi_dY, bi_dY, gr_dY, te_dY, char_ord : integer;
        variable current_pixel_computed : std_logic_vector(11 downto 0);
        variable char : character;
        variable pipe_pos : t_pipe_posn;
        variable render_a, render_b : boolean;
        variable x_start, x_end : integer;
        variable rom_b : std_logic_vector(15 downto 0);
    begin
        if (rising_edge(CLOCK2_50)) then

            current_pixel_computed := x"5cc";

            -- For all draw ops involving sprites, the address is set when the 25MHz clock is high and the data is read when it is low.
            -- This is to ensure the ROM has time to stabilise its output.

            if (clock_25MHz = '1') then

                x := to_integer(unsigned(column));
                y := to_integer(unsigned(row));

                rom_b := rom_address_b;

                -- 'B' LAYER (Renders behind 'A' layer)

                render_b := false;

                -- Draw background
                if (y >= BACKGROUND_START_Y and y < GROUND_START_Y) then
                    bg_dX := (x + background_offset) mod (2 * SPRITE_BACKGROUND_WIDTH);
                    bg_dY := y - BACKGROUND_START_Y;
                    rom_b := std_logic_vector(to_unsigned(SPRITE_BACKGROUND_OFFSET + (bg_dY / 2) * SPRITE_BACKGROUND_WIDTH + (bg_dX / 2), 16));
                    render_b := true;
                end if;

                -- Draw pipes
                for i in 0 to 2 loop
                    pipe_pos := pipe_posns(i);
                    if (x >= pipe_pos.x - PIPE_WIDTH / 2 and x <= pipe_pos.x + PIPE_WIDTH / 2 and y < GROUND_START_Y and (y < pipe_pos.y - PIPE_GAP_RADIUS or y >= pipe_pos.y + PIPE_GAP_RADIUS)) then
                        pi_dY := y - pipe_pos.y;
                        if (pi_dY < -PIPE_GAP_RADIUS - 2 * SPRITE_PIPE_HEAD_HEIGHT or pi_dY >= PIPE_GAP_RADIUS + 2 * SPRITE_PIPE_HEAD_HEIGHT) then
                            x_start := pipe_pos.x - SPRITE_PIPE_BODY_WIDTH;
                            x_end := pipe_pos.x + SPRITE_PIPE_BODY_WIDTH;

                            if (x >= x_start and x <= x_end) then
                                pi_dX := x - x_start;
                                rom_b := std_logic_vector(to_unsigned(SPRITE_PIPE_BODY_OFFSET + (pi_dX / 2), 16));
                                if (pi_dX > 0) then
                                    render_b := true;
                                end if;
                            end if;
                        else
                            if (pi_dY >= PIPE_GAP_RADIUS) then
                                pi_dY := pi_dY - PIPE_GAP_RADIUS;
                            elsif pi_dY < -PIPE_GAP_RADIUS then
                                pi_dY := SPRITE_PIPE_HEAD_HEIGHT * 2 + (pi_dY + PIPE_GAP_RADIUS);
                            end if;

                            x_start := pipe_pos.x - SPRITE_PIPE_HEAD_WIDTH;
                            x_end := pipe_pos.x + SPRITE_PIPE_HEAD_WIDTH;

                            pi_dX := x - x_start;
                            rom_b := std_logic_vector(to_unsigned(SPRITE_PIPE_HEAD_OFFSET + (pi_dY / 2) * SPRITE_PIPE_HEAD_WIDTH + (pi_dX / 2), 16));
                            if (pi_dX > 0) then
                                render_b := true;
                            end if;
                        end if;
                    end if;
                end loop;

                -- 'A' LAYER

                render_a := false;

                -- Draw the bird
                if (x >= bird_pos.x and x <= (bird_pos.x + (SPRITE_BIRD_WIDTH * 2)) and y >= bird_pos.y and y < (bird_pos.y + SPRITE_BIRD_HEIGHT * 2)) then
                    bi_dX := x - bird_pos.x;
                    bi_dY := y - bird_pos.y;
                    rom_address_a <= std_logic_vector(to_unsigned(SPRITE_BIRD_OFFSET + (bi_dY / 2) * SPRITE_BIRD_WIDTH + (bi_dX / 2), 16));
                    if (bi_dX > 0) then
                        render_a := true;
                    end if;
                end if;

                -- Draw the ground
                if (y >= GROUND_START_Y) then
                    gr_dX := (x + ground_offset) mod (2 * SPRITE_GROUND_WIDTH);
                    gr_dY := y - GROUND_START_Y;
                    rom_address_a <= std_logic_vector(to_unsigned(SPRITE_GROUND_OFFSET + (gr_dY / 2) * SPRITE_GROUND_WIDTH + (gr_dX / 2), 16));
                    render_a := true;
                end if;
            end if;

            if (clock_25MHz = '0') then
                if (render_layer_b and rom_data_b /= x"000") then
                    current_pixel_computed := rom_data_b;
                end if;
                if (render_layer_a and rom_data_a /= x"000") then
                    current_pixel_computed := rom_data_a;
                end if;
            end if;

            -- Draw text
            if (x >= score_string_pos.x and x < 32 * 2 * TEXT_CHAR_SIZE + score_string_pos.x and y >= score_string_pos.y and y < 2 * TEXT_CHAR_SIZE + score_string_pos.y) then
                te_dX := x - score_string_pos.x;
                te_dY := y - score_string_pos.y;
                char := score_string(te_dX / (2 * TEXT_CHAR_SIZE) + 1);
                if (char /= ' ') then
                    if (clock_25MHz = '1') then
                        char_ord := character'pos(char);
                        char_row <= std_logic_vector(to_unsigned(te_dY / 2, 3));
                        char_col <= std_logic_vector(to_unsigned((te_dX / 2) mod (2 * TEXT_CHAR_SIZE), 3));
                        if (char_ord >= 65 and char_ord < 91) then
                            char_ord := char_ord - 64;
                        end if;
                        char_addr <= std_logic_vector(to_unsigned(char_ord, 6));
                    elsif (char_bit = '1') then
                        current_pixel_computed := x"fff";
                    end if;
                end if;
            end if;

            if (clock_25MHz = '0') then
                if (x = 0) then
                    current_pixel <= x"000";
                else
                    current_pixel <= current_pixel_computed;
                end if;
            end if;

            clock_25Mhz <= not clock_25Mhz;

            rom_address_b <= rom_b;

            render_layer_a <= render_a;
            render_layer_b <= render_b;
        end if;
    end process;

    process (clock_60Hz)
        variable bg_offset, gr_offset: integer;
    begin
        if (rising_edge(clock_60Hz)) then
            bg_offset := background_offset + 1;
            if (bg_offset = 2 * SPRITE_BACKGROUND_WIDTH) then
                bg_offset := 0;
            end if;
            background_offset <= bg_offset;

            gr_offset := ground_offset + 2;
            if (gr_offset = 2 * SPRITE_GROUND_WIDTH) then
                gr_offset := 0;
            end if;
            ground_offset <= gr_offset;
        end if;
    end process;

    VGA_R <= current_pixel(11 downto 8) when red_enable = '1' else "0000";
    VGA_G <= current_pixel(7 downto 4) when green_enable = '1' else "0000";
    VGA_B <= current_pixel(3 downto 0) when blue_enable = '1' else "0000";
end architecture;