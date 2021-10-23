library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_gen is
    generic (
        -- config
        -- with 'SIM_TIME' = 0 ns, the clock generator will never stop 
        SIM_TIME   : time := 100 ns;
        CLK_PERIOD : time := 2 ns
    );
    port (
        clk : out std_logic := '0'
    );
end clock_gen;

architecture rtl of clock_gen is
begin
    process
    begin
        -- generate the output clock signal
        if SIM_TIME /= 0 ns then
            -- loop until SIM_TIME is over
            for i in 1 to SIM_TIME / (CLK_PERIOD/2) loop
                wait for CLK_PERIOD/2;
                clk <= not clk;
            end loop;
            wait for SIM_TIME - (CLK_PERIOD/2) * (SIM_TIME / (CLK_PERIOD/2));
            wait;
        else
            -- loop endlessly
            wait for CLK_PERIOD/2;
            clk <= not clk;
        end if;
    end process;
end architecture rtl;