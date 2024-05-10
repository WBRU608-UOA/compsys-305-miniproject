library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

package util_pkg is
    constant BIRD_MIN_X : integer := 0;
    constant BIRD_MAX_X : integer := 640 - 34;
    constant BIRD_MIN_Y : integer := 0;
    constant BIRD_MAX_Y : integer := 320 - 24;

    type t_bird_posn is record
        x : integer range BIRD_MIN_X to BIRD_MAX_X;
        y : integer range BIRD_MIN_Y to BIRD_MAX_Y;
    end record;

end package;