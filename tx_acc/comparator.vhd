library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lzss.all;

entity comparator is
    generic (
        LAYER : natural
    );
    port (
        -- clock
        clk : in std_logic;

        -- input interface
        i_comparator_in_lengths : in length_array(0 to 2 ** (LAYER + 1) - 1);

        -- output interface
        o_comparator_out_position : out std_logic_vector(LAYER downto 0);
        o_comparator_out_length   : out unsigned(4 downto 0)
    );
end entity comparator;

architecture strctural of comparator is
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
    end component;
begin
    -- on layer 0, this component is a single comparator with only 2 inputs
    recursive_end : if LAYER = 0 generate
        process (clk)
        begin
            if rising_edge(clk) then
                if i_comparator_in_lengths(0) >= i_comparator_in_lengths(1) then
                    o_comparator_out_length   <= i_comparator_in_lengths(0);
                    o_comparator_out_position <= "0";
                else
                    o_comparator_out_length   <= i_comparator_in_lengths(1);
                    o_comparator_out_position <= "1";
                end if;
            end if;
        end process;
    end generate recursive_end;
    
    -- on layer > 0, two more comparators are instantiated
    -- these comparators are fed with the left and right half of this component's input
    recursive_step : if LAYER > 0 generate
        signal position_left  : std_logic_vector(LAYER - 1 downto 0);
        signal position_right : std_logic_vector(LAYER - 1 downto 0);
        signal length_left    : unsigned(4 downto 0);
        signal length_right   : unsigned(4 downto 0);
    begin
        comp_left : comparator
            generic map (
                LAYER => LAYER - 1
            )
            port map (
                clk                       => clk,
                i_comparator_in_lengths   => i_comparator_in_lengths(0 to 2 ** LAYER - 1),
                o_comparator_out_position => position_left,
                o_comparator_out_length   => length_left
            );

        comp_right : comparator
            generic map (
                LAYER => LAYER - 1
            )
            port map (
                clk                       => clk,
                i_comparator_in_lengths   => i_comparator_in_lengths(2 ** LAYER to 2 ** (LAYER + 1) - 1),
                o_comparator_out_position => position_right,
                o_comparator_out_length   => length_right
            );

        process (clk)
        begin
            if rising_edge(clk) then
                -- compare the outputs of the two instantiated comparators
                -- the position of the maximum length match is built up recursively
                if length_left >= length_right then
                    o_comparator_out_length   <= length_left;
                    o_comparator_out_position <= "0" & position_left;
                else
                    o_comparator_out_length   <= length_right;
                    o_comparator_out_position <= "1" & position_right;
                end if;
            end if;
        end process;
    end generate recursive_step;
end architecture strctural;
