use work.sprites_pkg.all;

package util_pkg is
    constant SCREEN_MAX_X : integer := 639;
    constant SCREEN_MAX_Y : integer := 479;
    constant CENTRE_X : integer := SCREEN_MAX_X / 2;
    constant CENTRE_Y : integer := SCREEN_MAX_Y / 2;

    constant BIRD_MIN_X : integer := 0;
    constant BIRD_SCREEN_MAX_X : integer := SCREEN_MAX_X - SPRITE_BIRD_WIDTH * 2;
    constant BIRD_MIN_Y : integer := 0;
    constant BIRD_SCREEN_MAX_Y : integer := SCREEN_MAX_X - SPRITE_BIRD_HEIGHT * 2;

    constant BACKGROUND_WIDTH : integer := SPRITE_BG_DAY_WIDTH * 2;

    constant STARS_START_Y : integer := 150;

    constant PIPE_GAP_RADIUS : integer := 64;

    constant PIPE_MIN_Y : integer := PIPE_GAP_RADIUS + 59;
    constant PIPE_MAX_Y : integer := SCREEN_MAX_Y - PIPE_GAP_RADIUS - 60;

    constant PIPE_WIDTH : integer := SPRITE_PIPE_HEAD_WIDTH * 2;

    constant TEXT_CHAR_SIZE : integer := 8;

    constant GROUND_START_Y : integer := SCREEN_MAX_Y - 2 * SPRITE_GROUND_HEIGHT + 1;
    constant BACKGROUND_START_Y : integer := GROUND_START_Y - 2 * SPRITE_BG_DAY_HEIGHT;

    constant BIRD_MAX_VEL : integer := 10;
    constant BIRD_IMPULSE_VEL : integer := -8;

    type t_gen_posn is record
        x : integer;
        y : integer;
    end record;

    type t_bird_pos is record
        x : integer range BIRD_MIN_X to BIRD_SCREEN_MAX_X;
        y : integer range BIRD_MIN_Y to BIRD_SCREEN_MAX_Y;
    end record;

    type t_pipe_pos is record
        x : integer range -PIPE_WIDTH / 2 to SCREEN_MAX_X + PIPE_WIDTH / 2 + SCREEN_MAX_X; -- Temp lots of blanking space
        y : integer range 29 to PIPE_MAX_Y;
    end record;
    
    type t_pipe_pos_arr is array (0 to 2) of t_pipe_pos;

    type t_score is array (0 to 3) of integer range 0 to 10;

    type t_game_state is (
        S_INIT, S_GAME, S_DEATH
    );

    -- Don't use this unless absolutely necessary, adds a couple thousand L.E.s
    function utoa(n : integer) return string;
end package;

package body util_pkg is
    function utoa(n : integer) return string is
        variable temp : integer;
        variable ret : string(1 to 4) := (others => ' ');
    begin
        temp := n;
        for i in 0 to 3 loop
            ret(4 - i) := character'val((temp mod 10) + 48);
            temp := temp / 10;
        end loop;
        return ret;
    end function;
end package body;