library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lzss.all;

entity matcher is
    port (
        -- clock
        clk : in std_logic;

        -- input interface
        i_matcher_in_haystack    : in ram(0 to 17);
        i_matcher_in_needle      : in ram(0 to 17);

        -- output interface
        o_matcher_out_length : out unsigned(4 downto 0)
    );
end entity matcher;

architecture behavioral of matcher is
begin
    process (clk)
    begin
        if rising_edge(clk) then
            -- check how many of the first bytes of the two input array match
            -- matches of length < 3 are not considered, as this would not decrease the file size
            if (i_matcher_in_haystack(0 to 17) = i_matcher_in_needle(0 to 17)) then
                o_matcher_out_length <= "10010";
            elsif (i_matcher_in_haystack(0 to 16) = i_matcher_in_needle(0 to 16)) then
                o_matcher_out_length <= "10001";
            elsif (i_matcher_in_haystack(0 to 15) = i_matcher_in_needle(0 to 15)) then
                o_matcher_out_length <= "10000";
            elsif (i_matcher_in_haystack(0 to 14) = i_matcher_in_needle(0 to 14)) then
                o_matcher_out_length <= "01111";
            elsif (i_matcher_in_haystack(0 to 13) = i_matcher_in_needle(0 to 13)) then
                o_matcher_out_length <= "01110";
            elsif (i_matcher_in_haystack(0 to 12) = i_matcher_in_needle(0 to 12)) then
                o_matcher_out_length <= "01101";
            elsif (i_matcher_in_haystack(0 to 11) = i_matcher_in_needle(0 to 11)) then
                o_matcher_out_length <= "01100";
            elsif (i_matcher_in_haystack(0 to 10) = i_matcher_in_needle(0 to 10)) then
                o_matcher_out_length <= "01011";
            elsif (i_matcher_in_haystack(0 to 9) = i_matcher_in_needle(0 to 9)) then
                o_matcher_out_length <= "01010";
            elsif (i_matcher_in_haystack(0 to 8) = i_matcher_in_needle(0 to 8)) then
                o_matcher_out_length <= "01001";
            elsif (i_matcher_in_haystack(0 to 7) = i_matcher_in_needle(0 to 7)) then
                o_matcher_out_length <= "01000";
            elsif (i_matcher_in_haystack(0 to 6) = i_matcher_in_needle(0 to 6)) then
                o_matcher_out_length <= "00111";
            elsif (i_matcher_in_haystack(0 to 5) = i_matcher_in_needle(0 to 5)) then
                o_matcher_out_length <= "00110";
            elsif (i_matcher_in_haystack(0 to 4) = i_matcher_in_needle(0 to 4)) then
                o_matcher_out_length <= "00101";
            elsif (i_matcher_in_haystack(0 to 3) = i_matcher_in_needle(0 to 3)) then
                o_matcher_out_length <= "00100";
            elsif (i_matcher_in_haystack(0 to 2) = i_matcher_in_needle(0 to 2)) then
                o_matcher_out_length <= "00011";
            else
                o_matcher_out_length <= "00000";
            end if;
        end if;
    end process;
end architecture behavioral;
