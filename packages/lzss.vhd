library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package lzss is
    -- constant defining the size of the sliding window
    constant WINDOW_BITS : natural := 12;
    constant WINDOW_SIZE : natural := 2 ** WINDOW_BITS;

    -- constant defining the amout of iterations the match finder uses to find matches
    -- 'ITERATION_BITS' = 0 will use the match_finder_single implementation
    -- 'ITERATION_BITS' > 0 will use the match_finder_pipe implementation
    constant ITERATION_BITS : natural := 3;
    constant ITERATIONS     : natural := 2 ** ITERATION_BITS;

    type ram is array(natural range <>) of std_logic_vector(7 downto 0);
    type length_array is array(natural range <>) of unsigned(4 downto 0);
end package lzss;
