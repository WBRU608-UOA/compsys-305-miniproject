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
        state : in t_game_state;
        CLOCK2_50, clock_60Hz: in std_logic;
        VGA_HS, VGA_VS : out std_logic;
        VGA_R, VGA_G, VGA_B : out std_logic_vector(3 downto 0);
        bird_pos : in t_bird_posn;
        pipe_posns : in t_pipe_positions_array;
        score : in t_score;
        day : in std_logic
    );
end entity;

architecture behaviour of graphics_controller is 
    signal clock_25Mhz : std_logic := '0';
    signal row, column : std_logic_vector(9 downto 0);
    signal red_enable, green_enable, blue_enable : std_logic;

    -- As the bird can overlap with the background and pipes, we need 2 read heads 

    -- Used for the bird and collectables
	signal rom_address_a : std_logic_vector (ADDRESS_WIDTH - 1 downto 0);
    signal rom_data_a : std_logic_vector(11 downto 0);

    -- Used for pipes and background
	signal rom_address_b : std_logic_vector (ADDRESS_WIDTH - 1 downto 0);
    signal rom_data_b : std_logic_vector(11 downto 0);

    signal char_addr : std_logic_vector(6 downto 0);
    signal char_row, char_col : std_logic_vector(2 downto 0);
    signal char_bit : std_logic;
    -- Used for coloured and animated text
    -- Assumes text never overlaps
    signal text_colour : std_logic_vector(11 downto 0);
    signal counter_60Hz : integer range 0 to 60;

    signal current_pixel : std_logic_vector(11 downto 0);

    signal score_string_pos : t_gen_posn := (x => 25, y => 25);

    -- Enables rendering from that layer's ROM for the current pixel
    signal render_layer_a, render_layer_b, render_layer_text : boolean;

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
            character_address	:	IN STD_LOGIC_VECTOR (6 DOWNTO 0);
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
    widthad_a => ADDRESS_WIDTH,
    numwords_a => PIXEL_ALLOCATION,
    width_b => 12,
    widthad_b => ADDRESS_WIDTH,
    numwords_b => PIXEL_ALLOCATION,
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

    render: process (CLOCK2_50)
        variable x : integer range 0 to SCREEN_MAX_X;
        variable y : integer range 0 to SCREEN_MAX_Y;
        variable dX, dY : integer;
        variable current_pixel_computed : std_logic_vector(11 downto 0);
        variable char : character;
        variable pipe_pos : t_pipe_posn;
        variable render_a, render_b, render_text : boolean;
        variable x_start, x_end, y_start, y_end : integer;
        variable rom_b : std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
        variable bg_sprite_offset : integer;
        variable bird_sprite_offset : integer;
        variable start_string : string(1 to 14) := "Click to Start";
        variable score_string : string(1 to 11) := "Score: " 
            & character'val(score(3) + 48) 
            & character'val(score(2) + 48) 
            & character'val(score(1) + 48) 
            & character'val(score(0) + 48);
        variable pipe_bg_fix : boolean;
    begin
        if (rising_edge(CLOCK2_50)) then

            -- Set the background colour and sprite according to the day/night DIP switch
            if (day = '1') then
                current_pixel_computed := x"5cc";
                bg_sprite_offset := SPRITE_BG_DAY_OFFSET;
            else
                current_pixel_computed := x"189";
                bg_sprite_offset := SPRITE_BG_NIGHT_OFFSET;
            end if;

            -- Animate the bird
            if (state = S_GAME) then
                if ((counter_60Hz mod 32) < 11) then
                    bird_sprite_offset := SPRITE_BIRD_3_OFFSET;
                elsif ((counter_60Hz mod 32) < 21) then
                    bird_sprite_offset := SPRITE_BIRD_2_OFFSET;
                else
                    bird_sprite_offset := SPRITE_BIRD_OFFSET;
                end if;
            else
                bird_sprite_offset := SPRITE_BIRD_2_OFFSET;
            end if;

            -- For all draw ops involving sprites, the address is set when the 25MHz clock is high and the data is read when it is low.
            -- This is to ensure the ROM has time to stabilise its output.

            if (clock_25MHz = '1') then

                x := to_integer(unsigned(column));
                y := to_integer(unsigned(row));

                rom_b := rom_address_b;

                -- Rendering is all shifted one pixel to the right, to counteract the ROM propagation delay. This means the leftmost pixel column is rendered black.

                -- 'B' LAYER (renders behind 'A' layer)

                render_b := false;

                -- Draw background
                if (y >= BACKGROUND_START_Y and y < GROUND_START_Y) then
                    -- This usage of `mod` is acceptable as the background sprites are specifically
                    -- 128 pixels wide, meaning it's optimised away to just `and 127`.
                    dX := ((x + background_offset) / 2) mod SPRITE_BG_DAY_WIDTH;
                    dY := (y - BACKGROUND_START_Y) / 2;
                    rom_b := std_logic_vector(to_unsigned(bg_sprite_offset + dY * SPRITE_BG_DAY_WIDTH + dX, ADDRESS_WIDTH));
                    render_b := true;
                end if;

                -- Draw stars
                if (day = '0') then
                    if (y >= STARS_START_Y and y < STARS_START_Y + 2 * SPRITE_BG_STARS_HEIGHT) then
                        -- Same here, sprite is 128 pixels wide
                        dX := (x / 2) mod SPRITE_BG_STARS_WIDTH;
                        dY := (y - STARS_START_Y) / 2;
                        rom_b := std_logic_vector(to_unsigned(SPRITE_BG_STARS_OFFSET + dY * SPRITE_BG_STARS_WIDTH + dX, ADDRESS_WIDTH));
                        render_b := true;
                    end if;
                end if;

                -- Draw pipes
                for i in 0 to 2 loop
                    pipe_pos := pipe_posns(i);
                    -- Check the current pixel is within the pipe horixzontally and not inside the gap
                    if (x >= pipe_pos.x - PIPE_WIDTH / 2 and x <= pipe_pos.x + PIPE_WIDTH / 2 and y < GROUND_START_Y and (y < pipe_pos.y - PIPE_GAP_RADIUS or y >= pipe_pos.y + PIPE_GAP_RADIUS)) then
                        dY := y - pipe_pos.y;

                        -- Check if the pixel is in the body of the pipe
                        if (dY < -PIPE_GAP_RADIUS - 2 * SPRITE_PIPE_HEAD_HEIGHT or dY >= PIPE_GAP_RADIUS + 2 * SPRITE_PIPE_HEAD_HEIGHT) then
                            x_start := pipe_pos.x - SPRITE_PIPE_BODY_WIDTH;
                            x_end := pipe_pos.x + SPRITE_PIPE_BODY_WIDTH;

                            -- This check fixes dragging pixels in the section in front of the background scenery
                            pipe_bg_fix := (x < x_end or (y < BACKGROUND_START_Y and (day = '1' or (y < STARS_START_Y or y >= STARS_START_Y + 2 * SPRITE_BG_STARS_HEIGHT))));

                            -- We need another horizontal check here, as the body's 2 pixels thinner than the pipe overall
                            if (x >= x_start and x <= x_end and pipe_bg_fix) then
                                dX := x - x_start;
                                rom_b := std_logic_vector(to_unsigned(SPRITE_PIPE_BODY_OFFSET + (dX / 2), ADDRESS_WIDTH));
                                if (dX > 0) then
                                    render_b := true;
                                end if;
                            end if;
                        else
                            -- Get the appropriate delta depending on if we're rendering the upper or lower pipe head
                            if (dY >= PIPE_GAP_RADIUS) then
                                dY := dY - PIPE_GAP_RADIUS;
                            elsif dY < -PIPE_GAP_RADIUS then
                                dY := SPRITE_PIPE_HEAD_HEIGHT * 2 - (dY + PIPE_GAP_RADIUS + SPRITE_PIPE_HEAD_HEIGHT * 2) - 1;
                            end if;

                            x_start := pipe_pos.x - SPRITE_PIPE_HEAD_WIDTH;
                            x_end := pipe_pos.x + SPRITE_PIPE_HEAD_WIDTH;

                            -- This check fixes dragging pixels in the section in front of the background scenery
                            pipe_bg_fix := (x < x_end or (y < BACKGROUND_START_Y and (day = '1' or (y < STARS_START_Y or y >= STARS_START_Y + 2 * SPRITE_BG_STARS_HEIGHT))));

                            if (pipe_bg_fix) then
                                dX := x - x_start;
                                rom_b := std_logic_vector(to_unsigned(SPRITE_PIPE_HEAD_OFFSET + (dY / 2) * SPRITE_PIPE_HEAD_WIDTH + (dX / 2), ADDRESS_WIDTH));
                                if (dX > 0) then
                                    render_b := true;
                                end if;
                            end if;
                        end if;
                    end if;
                end loop;

                -- 'A' LAYER (renders behind Text layer)
                -- We assign the ROM address directly in this layer as we assume two sprites in the A layer NEVER overlap.

                render_a := false;

                -- Draw the bird
                if (x >= bird_pos.x and x <= (bird_pos.x + (SPRITE_BIRD_WIDTH * 2)) and y >= bird_pos.y and y < (bird_pos.y + SPRITE_BIRD_HEIGHT * 2)) then
                    dX := x - bird_pos.x;
                    dY := y - bird_pos.y;
                    rom_address_a <= std_logic_vector(to_unsigned(bird_sprite_offset + (dY / 2) * SPRITE_BIRD_WIDTH + (dX / 2), ADDRESS_WIDTH));
                    if (dX > 0) then
                        render_a := true;
                    end if;
                end if;

                -- Draw the ground
                if (y >= GROUND_START_Y) then
                    -- Sprite is 16 pixels wide
                    dX := ((x + ground_offset) / 2) mod SPRITE_GROUND_WIDTH;
                    dY := (y - GROUND_START_Y) / 2;
                    rom_address_a <= std_logic_vector(to_unsigned(SPRITE_GROUND_OFFSET + dY * SPRITE_GROUND_WIDTH + dX, ADDRESS_WIDTH));
                    render_a := true;
                end if;

                -- TEXT LAYER

                render_text := false;

                -- Draw score
                -- char_rom has been modified to use a different, ASCII-compatible font
                if (x >= score_string_pos.x and x < 11 * 2 * TEXT_CHAR_SIZE + score_string_pos.x and y >= score_string_pos.y and y < 2 * TEXT_CHAR_SIZE + score_string_pos.y) then
                    dX := x - score_string_pos.x;
                    dY := y - score_string_pos.y;
                    char := score_string(dX / (2 * TEXT_CHAR_SIZE) + 1);
                    -- This takes the last 3 bits, which works because the characters are 8 pixels in size
                    char_row <= std_logic_vector(to_unsigned(dY / 2, 3));
                    char_col <= std_logic_vector(to_unsigned(dX / 2, 3));

                    -- Get the ASCII ordinal of the character and send that to the ROM
                    char_addr <= std_logic_vector(to_unsigned(character'pos(char), 7));
                    text_colour <= x"fff";
                    render_text := true;
                end if;
                
                -- Draw start text
                if (STATE = S_INIT) then
                    x_start := CENTRE_X - (start_string'length * TEXT_CHAR_SIZE / 2);
                    x_end := CENTRE_X + (start_string'length * TEXT_CHAR_SIZE / 2);
                    y_start := CENTRE_Y - TEXT_CHAR_SIZE / 2;
                    y_end := CENTRE_Y + TEXT_CHAR_SIZE / 2;
                    if (y >= y_start and y < y_end and x >= x_start and x <= x_end) then
                        dX := x - x_start;
                        dY := y - y_start;
                        char := start_string(dX / TEXT_CHAR_SIZE + 1);
                        char_row <= std_logic_vector(to_unsigned(dY, 3));
                        char_col <= std_logic_vector(to_unsigned(dX, 3));

                        char_addr <= std_logic_vector(to_unsigned(character'pos(char), 7));
                        if (counter_60Hz
                 >= 30) then
                            text_colour <= x"888";
                        else
                            text_colour <= x"fff";
                        end if;
                        render_text := true;
                    end if;
                end if;
            end if;

            -- We send pixel data out when the 25MHz is low, so that it's rendered when it goes high
            if (clock_25MHz = '0') then
                -- Render layer B at the back
                if (render_layer_b and rom_data_b /= x"000") then
                    current_pixel_computed := rom_data_b;
                end if;
                -- Render layer A in front of that
                if (render_layer_a and rom_data_a /= x"000") then
                    current_pixel_computed := rom_data_a;
                end if;
                -- Render the text layer at the front
                if (render_layer_text and char_bit = '1') then
                    current_pixel_computed := text_colour;
                end if;

                -- The aforementioned black leftmost column (would be garbage pixels otherwise)
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
            render_layer_text <= render_text;
        end if;
    end process;

    -- Scroll the parallax backgrounds
    parallax_scroll : process (clock_60Hz)
        variable bg_offset, gr_offset: integer;
    begin
        if (rising_edge(clock_60Hz) and STATE = S_GAME ) then
            bg_offset := background_offset + 1;
            if (bg_offset >= BACKGROUND_WIDTH) then
                bg_offset := bg_offset - BACKGROUND_WIDTH;
            end if;
            background_offset <= bg_offset;

            gr_offset := ground_offset + 2;
            if (gr_offset >= 2 * SPRITE_GROUND_WIDTH) then
                gr_offset := gr_offset - 2 * SPRITE_GROUND_WIDTH;
            end if;
            ground_offset <= gr_offset;
        end if;
    end process;

    count : process(clock_60Hz)
        variable counter_temp : integer;
    begin
        if (rising_edge(clock_60Hz)) then
            counter_temp := counter_60Hz + 1;
            if (counter_temp >= 60) then
                counter_temp := 0;
            end if;
            counter_60Hz
     <= counter_temp;
        end if;
    end process;

    VGA_R <= current_pixel(11 downto 8) when red_enable = '1' else "0000";
    VGA_G <= current_pixel(7 downto 4) when green_enable = '1' else "0000";
    VGA_B <= current_pixel(3 downto 0) when blue_enable = '1' else "0000";
end architecture;