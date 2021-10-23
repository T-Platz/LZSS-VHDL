library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lzss.all;

entity match_finder_single is
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
end entity match_finder_single;

architecture structural of match_finder_single is
    component matcher
        port (
            clk                      : in std_logic;
            i_matcher_in_haystack    : in ram(0 to 17);
            i_matcher_in_needle      : in ram(0 to 17);
            o_matcher_out_length     : out unsigned(4 downto 0)
        );
    end component matcher;

    component comparator
        generic (
            LAYER : natural
        );
        port (
            clk                       : in std_logic;
            i_comparator_in_lengths   : in length_array(0 to 2 ** (LAYER + 1) - 1);
            o_comparator_out_position : out std_logic_vector(LAYER downto 0);
            o_comparator_out_length   : out unsigned(4 downto 0)
        );
    end component comparator;

    signal lengths : length_array(0 to WINDOW_SIZE - 1);

    signal cycle_count : natural range 0 to WINDOW_BITS - 1;

    signal o_comparator_out_position : std_logic_vector(WINDOW_BITS - 1 downto 0);
    signal o_comparator_out_length   : unsigned(4 downto 0);
begin
    -- instantiate matchers, each checking 18 bytes for a match
    mats1 : for i in 0 to WINDOW_SIZE - 18 generate
        mat : matcher port map (
            clk                      => clk,
            i_matcher_in_haystack    => i_match_finder_in_haystack(i to i + 17),
            i_matcher_in_needle      => i_match_finder_in_needle,
            o_matcher_out_length     => lengths(i)
        );
    end generate mats1;

    -- instantiate additional matchers whose inputs wrap around the end of the sliding window
    mats2 : for i in WINDOW_SIZE - 17 to WINDOW_SIZE - 1 generate
        mat : matcher port map (
            clk                      => clk,
            i_matcher_in_haystack    => i_match_finder_in_haystack(i to WINDOW_SIZE - 1) & i_match_finder_in_haystack(0 to 17 - WINDOW_SIZE + i),
            i_matcher_in_needle      => i_match_finder_in_needle,
            o_matcher_out_length     => lengths(i)
        );
    end generate mats2;

    -- a single comparator is instantiated which will instantiate more comparators recursively
    comp : comparator
        generic map (
            LAYER => WINDOW_BITS - 1
        )
        port map (
            clk                       => clk,
            i_comparator_in_lengths   => lengths,
            o_comparator_out_position => o_comparator_out_position,
            o_comparator_out_length   => o_comparator_out_length
        );

    o_match_finder_out_position <= o_comparator_out_position;
    o_match_finder_out_length   <= o_comparator_out_length when o_comparator_out_length <= i_match_finder_in_needle_used else i_match_finder_in_needle_used;

    process(clk, reset)
    begin
        if reset = '1' then
            cycle_count              <= 0;
            o_match_finder_out_valid <= '0';
        elsif rising_edge(clk) then
            -- wait for a fixed amount of cycles depending on the window size
            -- the match finder must be reset every time it receives new input
            if cycle_count = WINDOW_BITS - 1 then
                o_match_finder_out_valid <= '1';
            else
                cycle_count <= cycle_count + 1;
            end if;
        end if;
    end process;
end architecture structural;
