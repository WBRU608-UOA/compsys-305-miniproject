library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;

LIBRARY altera_mf;
USE altera_mf.all;

entity graphics_controller is
    port (
        CLOCK2_50: in std_logic;
        VGA_HS, VGA_VS : out std_logic;
        VGA_R, VGA_G, VGA_B : out std_logic_vector(3 downto 0);
        bird_pos : t_bird_posn
    );
end entity;

architecture behaviour of graphics_controller is 

    signal clock_25Mhz : std_logic := '0';
    signal row, column : std_logic_vector(9 downto 0);
    signal red_enable, green_enable, blue_enable : std_logic;

    SIGNAL rom_data		: STD_LOGIC_VECTOR (11 DOWNTO 0);
	SIGNAL rom_address	: STD_LOGIC_VECTOR (7 DOWNTO 0);

    signal current_pixel : std_logic_vector(11 downto 0);

    component vga_sync is
        PORT(	clock_25Mhz, red, green, blue		: IN	STD_LOGIC;
			red_out, green_out, blue_out, horiz_sync_out, vert_sync_out	: OUT	STD_LOGIC;
			pixel_row, pixel_column: OUT STD_LOGIC_VECTOR(9 DOWNTO 0));
    end component;

    -- Used to interface with the spritesheet
    COMPONENT altsyncram is
	GENERIC (
		address_aclr_a			: STRING;
		clock_enable_input_a	: STRING;
		clock_enable_output_a	: STRING;
		init_file				: STRING;
		intended_device_family	: STRING;
		lpm_hint				: STRING;
		lpm_type				: STRING;
		numwords_a				: NATURAL;
		operation_mode			: STRING;
		outdata_aclr_a			: STRING;
		outdata_reg_a			: STRING;
		widthad_a				: NATURAL;
		width_a					: NATURAL;
		width_byteena_a			: NATURAL
	);
	PORT (
		clock0		: IN STD_LOGIC ;
		address_a	: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		q_a			: OUT STD_LOGIC_VECTOR (11 DOWNTO 0)
	);
	END COMPONENT;
begin
    sync: vga_sync port map (
        clock_25Mhz => clock_25Mhz, 
        red => '1', green => '1', blue => '1', 
        red_out => red_enable, green_out => green_enable, blue_out => blue_enable, 
        horiz_sync_out => VGA_HS, vert_sync_out => VGA_VS, 
        pixel_row => row, pixel_column => column
    );

    altsyncram_component : altsyncram
	GENERIC MAP (
		address_aclr_a => "NONE",
		clock_enable_input_a => "BYPASS",
		clock_enable_output_a => "BYPASS",
		init_file => "sprites/sprites.mif",
		intended_device_family => "Cyclone III",
		lpm_hint => "ENABLE_RUNTIME_MOD=NO",
		lpm_type => "altsyncram",
		numwords_a => 204,
		operation_mode => "ROM",
		outdata_aclr_a => "NONE",
		outdata_reg_a => "UNREGISTERED",
		widthad_a => 13,
		width_a => 12,
		width_byteena_a => 1
	)
	PORT MAP (
		clock0 => CLOCK2_50,
		address_a => rom_address,
		q_a => rom_data
	);

    process(CLOCK2_50)
        variable x, y, dX, dY : integer;
        variable current_pixel_hold : std_logic_vector(11 downto 0);
    begin
        if (rising_edge(CLOCK2_50)) then
            x := to_integer(unsigned(column));
            y := to_integer(unsigned(row));

            -- Draw the bird
            if (x >= bird_pos.x and x < (bird_pos.x + 34) and y >= bird_pos.y and y < (bird_pos.y + 24)) then

                -- For an undetermined reason sprites warp at the left edge and this is needed to correct it.
                dX := (x - bird_pos.x + 1) mod 34;
                dY := y - bird_pos.y;
                if (dX = 0) then
                    dY := (dY + 1) mod 24;
                end if;

                rom_address <= std_logic_vector(to_unsigned((dY / 2) * 17 + (dX / 2), 8));
                current_pixel_hold := rom_data;
                if (current_pixel_hold /= x"000") then
                    current_pixel <= current_pixel_hold;
                else
                    current_pixel <= x"19f";
                end if;
            else
                current_pixel <= x"19f";
            end if;

            clock_25Mhz <= not clock_25Mhz;
        end if;
    end process;

    VGA_R <= current_pixel(11 downto 8) when red_enable = '1' else "0000";
    VGA_G <= current_pixel(7 downto 4) when green_enable = '1' else "0000";
    VGA_B <= current_pixel(3 downto 0) when blue_enable = '1' else "0000";
end architecture;