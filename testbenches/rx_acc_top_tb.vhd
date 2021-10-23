library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

use work.testbench.all;

entity rx_acc_top_tb is
end entity rx_acc_top_tb;

architecture testbench of rx_acc_top_tb is
    component rx_acc_top
        port (
            -- clock & reset
            clk   : in std_logic;
            reset : in std_logic;

            -- RX ACC input
            i_rx_acc_in_data  : in std_logic_vector(255 downto 0);
            i_rx_acc_in_sop   : in std_logic;
            i_rx_acc_in_eop   : in std_logic;
            i_rx_acc_in_valid : in std_logic;
            i_rx_acc_in_empty : in std_logic_vector(4 downto 0);
            o_rx_acc_in_ready : out std_logic;

            -- RX ACC output
            o_rx_acc_out_data  : out std_logic_vector(255 downto 0);
            o_rx_acc_out_sop   : out std_logic;
            o_rx_acc_out_eop   : out std_logic;
            o_rx_acc_out_valid : out std_logic;
            o_rx_acc_out_empty : out std_logic_vector(4 downto 0);
            i_rx_acc_out_ready : in std_logic
        );
    end component;

    signal start : std_logic := '0';

    signal clk   : std_logic;
    signal reset : std_logic := '0';

    -- input to the unit under test
    signal i_rx_acc_in_data  : std_logic_vector(255 downto 0) := (others => '0');
    signal i_rx_acc_in_sop   : std_logic := '0';
    signal i_rx_acc_in_eop   : std_logic := '0';
    signal i_rx_acc_in_valid : std_logic := '0';
    signal i_rx_acc_in_empty : std_logic_vector(4 downto 0) := (others => '0');
    signal o_rx_acc_in_ready : std_logic;

    -- output from the unit under test
    signal o_rx_acc_out_data  : std_logic_vector(255 downto 0);
    signal o_rx_acc_out_sop   : std_logic;
    signal o_rx_acc_out_eop   : std_logic;
    signal o_rx_acc_out_valid : std_logic;
    signal o_rx_acc_out_empty : std_logic_vector(4 downto 0);
    signal i_rx_acc_out_ready : std_logic := '0';
begin
    clock : clock_gen
        generic map (
            SIM_TIME   => 0 ns,
            CLK_PERIOD => 1 ns
        )
        port map (
            clk => clk
        );

    uut : rx_acc_top port map (
        clk                => clk,
        reset              => reset,
        i_rx_acc_in_data   => i_rx_acc_in_data,
        i_rx_acc_in_sop    => i_rx_acc_in_sop,
        i_rx_acc_in_eop    => i_rx_acc_in_eop,
        i_rx_acc_in_valid  => i_rx_acc_in_valid,
        i_rx_acc_in_empty  => i_rx_acc_in_empty,
        o_rx_acc_in_ready  => o_rx_acc_in_ready,
        o_rx_acc_out_data  => o_rx_acc_out_data,
        o_rx_acc_out_sop   => o_rx_acc_out_sop,
        o_rx_acc_out_eop   => o_rx_acc_out_eop,
        o_rx_acc_out_valid => o_rx_acc_out_valid,
        o_rx_acc_out_empty => o_rx_acc_out_empty,
        i_rx_acc_out_ready => i_rx_acc_out_ready
    );

    process
    begin
        wait for RESET_DELAY;
        reset <= '1';
        wait for 1 ns;
        reset <= '0';
        start <= '1';
        wait;
    end process; 

    read_encoded : process
        file file_in  : binary_file;
        variable sop  : std_logic := '1';
    begin
        -- the path of the file, which is to be decoded, may have to be at adjusted appropriately
        file_open(file_in, "testbenches/testdata/encoded", read_mode);
        wait until start = '1';
        
        -- loop until the end of the file is reached
        -- the 'read_from_file' procedure will set the 'i_rx_acc_in_eop' in that case
        while i_rx_acc_in_eop = '0' loop
            wait until rising_edge(clk);

            if o_rx_acc_in_ready = '1' then
                read_from_file(file_in, i_rx_acc_in_data, i_rx_acc_in_eop, i_rx_acc_in_empty);
                i_rx_acc_in_sop   <= sop;
                i_rx_acc_in_valid <= '1';

                sop := '0';
            else
                i_rx_acc_in_valid <= '0';
            end if;

            wait until rising_edge(clk);
        end loop;

        i_rx_acc_in_data  <= (others => '0');
        i_rx_acc_in_sop   <= '0';
        i_rx_acc_in_eop   <= '0';
        i_rx_acc_in_valid <= '0';
        i_rx_acc_in_empty <= (others => '0');
        
        file_close(file_in);
        wait;
    end process read_encoded;

    write_decoded : process
        file file_out : binary_file;
    begin
        -- the path of the output file may have to be at adjusted appropriately
        file_open(file_out, "testbenches/testdata/decoded", write_mode);
        wait until start = '1';

        i_rx_acc_out_ready <= '1';

        -- loop until the unit under test signals the end of the decoded data
        while o_rx_acc_out_eop = '0' loop
            wait until rising_edge(clk);

            if o_rx_acc_out_valid = '1' then
                write_to_file(file_out, o_rx_acc_out_data, o_rx_acc_out_empty);
            end if;
        end loop;

        i_rx_acc_out_ready <= '0';

        file_close(file_out);
        stop;
    end process write_decoded;
end architecture testbench;
