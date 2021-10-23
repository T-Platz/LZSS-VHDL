library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package testbench is
    -- constant defining the time at which the reset signal shall be sent
    constant RESET_DELAY : time := 0 ns;

    type binary_file is file of character;

    component clock_gen
        generic (
            SIM_TIME   : time;
            CLK_PERIOD : time
        );
        port (
            clk : out std_logic
        );
    end component;

    procedure stop;

    procedure read_from_file(file file_in : binary_file; signal data : out std_logic_vector(255 downto 0); signal eop : out std_logic; signal empty : out std_logic_vector(4 downto 0));
    procedure write_to_file(file file_out : binary_file; signal data : in std_logic_vector(255 downto 0); signal empty : in std_logic_vector(4 downto 0));
end package testbench;

package body testbench is
    -- procedure for terminating a simulation
    procedure stop is
    begin
        assert false report "End of simulation reached" severity failure;
    end procedure stop;

    -- read 256 bits from a file and notify the caller if the file is empty
    procedure read_from_file(file file_in : binary_file; signal data : out std_logic_vector(255 downto 0); signal eop : out std_logic; signal empty : out std_logic_vector(4 downto 0)) is
        variable i    : integer range 0 to 32 := 0;
        variable char : character;
    begin
        while (not endfile(file_in)) and i < 32 loop
            read(file_in, char);
            data(255 - 8 * i downto 248 - 8 * i) <= std_logic_vector(to_unsigned(character'POS(char), 8));

            i := i + 1;
        end loop;
        
        if i < 32 or endfile(file_in) then
            eop <= '1';
        else
            eop <= '0';
        end if;
        empty <= std_logic_vector(to_unsigned(32 - i, empty'length));
    end procedure read_from_file;

    -- write up to 256 bits to an output file
    procedure write_to_file(file file_out : binary_file; signal data : in std_logic_vector(255 downto 0); signal empty : in std_logic_vector(4 downto 0)) is
        variable i    : integer range 0 to 32 := 0;
        variable char : character;
    begin
        while i < 32 - to_integer(unsigned(empty)) loop
            char := character'val(to_integer(unsigned(data(255 - 8 * i downto 248 - 8 * i))));
            write(file_out, char);

            i := i + 1;
        end loop;
    end procedure write_to_file;
end package body testbench;