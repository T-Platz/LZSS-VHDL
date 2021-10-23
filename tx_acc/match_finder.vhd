library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lzss.all;

entity match_finder is
    -- this component is only used as an abstraction of the two different match finder implementations
    -- therefore, both implementations must use the same interface
    port (
        -- clock & reset
        clk   : in std_logic;
        reset : in std_logic;

        -- input interface
        i_match_finder_in_haystack    : in ram(0 to WINDOW_SIZE - 1);
        i_match_finder_in_needle      : in ram(0 to 17);
        i_match_finder_in_needle_used : in unsigned(4 downto 0);

        -- output interface
        o_match_finder_out_position : out std_logic_vector(WINDOW_BITS - 1 downto 0);
        o_match_finder_out_length   : out unsigned(4 downto 0);
        o_match_finder_out_valid    : out std_logic
    );
end entity match_finder;

architecture structural of match_finder is
    component match_finder_single
        port (
            clk                           : in std_logic;
            reset                         : in std_logic;
            i_match_finder_in_haystack    : in ram(0 to WINDOW_SIZE - 1);
            i_match_finder_in_needle      : in ram(0 to 17);
            i_match_finder_in_needle_used : in unsigned(4 downto 0);
            o_match_finder_out_position   : out std_logic_vector(WINDOW_BITS - 1 downto 0);
            o_match_finder_out_length     : out unsigned(4 downto 0);
            o_match_finder_out_valid      : out std_logic
        );
    end component match_finder_single;

    component match_finder_piped
        port (
            clk                           : in std_logic;
            reset                         : in std_logic;
            i_match_finder_in_haystack    : in ram(0 to WINDOW_SIZE - 1);
            i_match_finder_in_needle      : in ram(0 to 17);
            i_match_finder_in_needle_used : in unsigned(4 downto 0);
            o_match_finder_out_position   : out std_logic_vector(WINDOW_BITS - 1 downto 0);
            o_match_finder_out_length     : out unsigned(4 downto 0);
            o_match_finder_out_valid      : out std_logic
        );
    end component match_finder_piped;
begin
    -- depending on the amount of iterations, eiter a 'match_finder_single'
    -- or 'match_finder_piped' component is instantiated
    single : if ITERATIONS = 1 generate
        finder : match_finder_single port map (
            clk                           => clk,
            reset                         => reset,
            i_match_finder_in_haystack    => i_match_finder_in_haystack,
            i_match_finder_in_needle      => i_match_finder_in_needle,
            i_match_finder_in_needle_used => i_match_finder_in_needle_used,
            o_match_finder_out_position   => o_match_finder_out_position,
            o_match_finder_out_length     => o_match_finder_out_length,
            o_match_finder_out_valid      => o_match_finder_out_valid
        );
    end generate single;
    
    piped : if ITERATIONS > 1 generate
        finder : match_finder_piped port map (
            clk                           => clk,
            reset                         => reset,
            i_match_finder_in_haystack    => i_match_finder_in_haystack,
            i_match_finder_in_needle      => i_match_finder_in_needle,
            i_match_finder_in_needle_used => i_match_finder_in_needle_used,
            o_match_finder_out_position   => o_match_finder_out_position,
            o_match_finder_out_length     => o_match_finder_out_length,
            o_match_finder_out_valid      => o_match_finder_out_valid
        );
    end generate piped;
end architecture structural;
