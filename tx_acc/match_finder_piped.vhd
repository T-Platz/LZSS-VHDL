library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lzss.all;

entity match_finder_piped is
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
end entity match_finder_piped;

architecture structural of match_finder_piped is
    -- size of the portion of the sliding window, which is scanned in one iteration
    constant HAYSTACK_SIZE : natural := (WINDOW_SIZE / ITERATIONS);

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

    signal haystack : ram(0 to HAYSTACK_SIZE - 1);
    signal lengths  : length_array(0 to HAYSTACK_SIZE - 1);

    signal cycle_count : natural range 0 to WINDOW_BITS - ITERATION_BITS + ITERATIONS + 2;

    signal haystack_offset_in  : unsigned(WINDOW_BITS - 1 downto 0);
    signal haystack_offset_out : unsigned(WINDOW_BITS - 1 downto 0);

    signal best_position : std_logic_vector(WINDOW_BITS - 1 downto 0);
    signal best_length   : unsigned(4 downto 0);

    signal o_comparator_out_position : std_logic_vector(WINDOW_BITS - ITERATION_BITS - 1 downto 0);
    signal o_comparator_out_length   : unsigned(4 downto 0);
begin
    -- instantiate matchers, each checking 18 bytes for a match
    mats1 : for i in 0 to HAYSTACK_SIZE - 18 generate
        mat : matcher port map (
            clk                      => clk,
            i_matcher_in_haystack    => haystack(i to i + 17),
            i_matcher_in_needle      => i_match_finder_in_needle,
            o_matcher_out_length     => lengths(i)
        );
    end generate mats1;

    -- to reduce the amount of logic this implementation of the match finder requires, matches which
    -- wrap around the window will not be considered
    mats2 : for i in HAYSTACK_SIZE - 17 to HAYSTACK_SIZE - 1 generate
        lengths(i) <= (others => '0');
    end generate mats2;

    -- a single comparator is instantiated which will instantiate more comparators recursively
    comp : comparator
        generic map (
            LAYER => WINDOW_BITS - ITERATION_BITS - 1
        )
        port map (
            clk                       => clk,
            i_comparator_in_lengths   => lengths,
            o_comparator_out_position => o_comparator_out_position,
            o_comparator_out_length   => o_comparator_out_length
        );
    
    process (clk, reset)
    begin
        if reset = '1' then
            haystack                 <= (others => (others => '0'));
            cycle_count              <= 0;
            haystack_offset_in       <= (others => '0');
            haystack_offset_out      <= (others => '0');
            best_position            <= (others => '0');
            best_length              <= (others => '0');
            o_match_finder_out_valid <= '0';
        elsif rising_edge(clk) then
            -- in the first 'ITERATION' cycles, the data is fed into the matchers
            if cycle_count < ITERATIONS then
                -- the next portion of the window must be scanned for a match
                haystack           <= i_match_finder_in_haystack(to_integer(haystack_offset_in) to to_integer(haystack_offset_in) + HAYSTACK_SIZE - 1);
                haystack_offset_in <= to_unsigned(to_integer(haystack_offset_in) + HAYSTACK_SIZE, WINDOW_BITS);
            end if;

            -- after some cycles (WINDOW_BITS - ITERATION_BITS for the comparators and one for the matchers),
            -- the data has passed through the pipeline
            if cycle_count > WINDOW_BITS - ITERATION_BITS + 1 then
                -- check whether the maximum length of the last iteration is bigger than the maximum length so far
                if o_comparator_out_length > best_length then
                    best_position <= std_logic_vector(resize(unsigned(o_comparator_out_position), WINDOW_BITS) + haystack_offset_out);
                    best_length   <= o_comparator_out_length;
                end if;

                haystack_offset_out <= to_unsigned(to_integer(haystack_offset_out) + HAYSTACK_SIZE, WINDOW_BITS);
            end if;

            -- check if the matching process is finished
            if cycle_count = WINDOW_BITS - ITERATION_BITS + ITERATIONS + 2 then
                -- the whole window has been scanned for a match, so the output is valid
                -- the match finder must be reset in order to be able to accept new input
                o_match_finder_out_position <= best_position;
                if best_length <= i_match_finder_in_needle_used then
                    o_match_finder_out_length <= best_length;
                else
                    o_match_finder_out_length <= i_match_finder_in_needle_used;
                end if;

                o_match_finder_out_valid <= '1';
            else
                -- next cycle
                cycle_count <= cycle_count + 1;
            end if;
        end if;
    end process;
end architecture structural;
