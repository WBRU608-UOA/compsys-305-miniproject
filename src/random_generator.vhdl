library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity random_generator is
    port (
        CLOCK2_50 : in std_logic;
        rng : out integer range 0 to 65535
    );
end entity;

architecture behaviour of random_generator is
begin
    process (CLOCK2_50)
        variable rng_internal : std_logic_vector(15 downto 0) := "0000000000000001";
    begin
        if (rising_edge(CLOCK2_50)) then
            if (rng_internal = "0000000000000000") then
                rng_internal := "0000000000000001";
            end if;
            -- Using these 'tap bits' should result in it going through all 65535 states
            rng_internal := rng_internal(14 downto 0) & (rng_internal(15) xor rng_internal(13) xor rng_internal(12) xor rng_internal(10));
            rng <= to_integer(unsigned(rng_internal));
        end if;
    end process;
end architecture;
