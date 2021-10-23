library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lzss.all;

entity rx_acc_top is
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
end entity rx_acc_top;

architecture state_machine of rx_acc_top is
    type state_t is (fetch_data, read_flags, check_flag, uncoded, coded_first, coded_second, write_coded_to_output, write_coded_to_window, send, sending);

    -- state is the current state of the state machine
    -- resturn state is used define to which state shall be "returned" in the 'fetch_data' and 'sending' state
    signal state        : state_t;
    signal return_state : state_t;

    -- sliding window
    signal window     : ram(0 to WINDOW_SIZE - 1);
    signal window_ptr : unsigned(WINDOW_BITS - 1 downto 0);

    -- several buffers and pointers
    signal input_buffer       : ram(0 to 31);
    signal input_buffer_ptr   : unsigned(4 downto 0);
    signal input_buffer_empty : std_logic;
    signal input_buffer_last  : unsigned(4 downto 0);

    signal output_buffer      : ram(0 to 31);
    signal output_buffer_ptr  : unsigned(4 downto 0);
    signal output_buffer_full : std_logic;

    signal flags_buffer       : std_logic_vector(0 to 7);
    signal flags_buffer_ptr   : unsigned(2 downto 0);
    signal flags_buffer_empty : std_logic;

    signal decode_buffer : ram(0 to 17);

    -- signals for storing the output of the match finder
    -- 'match_pos_2' and 'match_len_2' are copies of 'match_pos' and 'match_len' respectively
    signal match_pos   : unsigned(WINDOW_BITS - 1 downto 0);
    signal match_len   : unsigned(4 downto 0);
    signal match_pos_2 : unsigned(WINDOW_BITS - 1 downto 0);
    signal match_len_2 : unsigned(4 downto 0);

    -- signals for storing the eop and sop inputs
    signal sop_received : std_logic;
    signal eop_received : std_logic;
begin
    process (clk, reset)
    begin
        if reset = '1' then
            -- asynchronous reset
            state              <= fetch_data;
            return_state       <= read_flags;
            window             <= (others => x"20");
            window_ptr         <= (others => '0');
            input_buffer       <= (others => (others => '0'));
            input_buffer_ptr   <= (others => '0');
            input_buffer_empty <= '0';
            input_buffer_last  <= "11111";
            output_buffer      <= (others => (others => '0'));
            output_buffer_ptr  <= (others => '0');
            output_buffer_full <= '0';
            flags_buffer       <= (others => '0');
            flags_buffer_ptr   <= (others => '0');
            flags_buffer_empty <= '0';
            decode_buffer      <= (others => (others => '0'));
            match_pos          <= (others => '0');
            match_len          <= (others => '0');
            sop_received       <= '0';
            eop_received       <= '0';

            o_rx_acc_in_ready  <= '1';
            o_rx_acc_out_data  <= (others => '0');
            o_rx_acc_out_sop   <= '0';
            o_rx_acc_out_eop   <= '0';
            o_rx_acc_out_valid <= '0';
            o_rx_acc_out_empty <= (others => '0');
        elsif rising_edge(clk) then
            case state is
                when fetch_data =>
                    if eop_received = '1' then
                        -- package is done
                        state        <= send;
                        return_state <= fetch_data;
                    elsif i_rx_acc_in_valid = '1' then
                        -- fetch data from the input
                        for i in 0 to 31 loop
                            input_buffer(i) <= i_rx_acc_in_data((255 - 8 * i) downto (248 - 8 * i));
                        end loop;

                        -- inititalize the input buffer pointers
                        input_buffer_ptr   <= (others => '0');
                        input_buffer_empty <= '0';
                        if i_rx_acc_in_eop = '1' then
                            input_buffer_last <= (31 - unsigned(i_rx_acc_in_empty));
                        else
                            input_buffer_last <= (others => '1');
                        end if;

                        -- store the sop and eop signals
                        sop_received       <= i_rx_acc_in_sop;
                        eop_received       <= i_rx_acc_in_eop;

                        -- advance to the next state
                        o_rx_acc_in_ready <= '0';
                        state             <= return_state;
                    end if;

                when read_flags =>
                    if input_buffer_empty = '1' then
                        -- fetch data if the input is empty
                        o_rx_acc_in_ready <= '1';

                        state        <= fetch_data;
                        return_state <= read_flags;
                    else
                        -- store the flags
                        flags_buffer       <= input_buffer(to_integer(input_buffer_ptr));
                        flags_buffer_ptr   <= (others => '0');
                        flags_buffer_empty <= '0';

                        -- advance the input buffer pointer
                        input_buffer_ptr <= input_buffer_ptr + 1;
                        if input_buffer_ptr = input_buffer_last then
                            input_buffer_empty <= '1';
                        else
                            input_buffer_empty <= '0';
                        end if;
                        
                        state <= check_flag;
                    end if;

                when check_flag =>
                    if flags_buffer_empty = '1' then
                        state <= read_flags;
                    elsif flags_buffer(to_integer(flags_buffer_ptr)) = '0' then
                        -- the next symbol is uncoded
                        flags_buffer_ptr   <= flags_buffer_ptr + 1;
                        if flags_buffer_ptr = 7 then
                            flags_buffer_empty <= '1';
                        else
                            flags_buffer_empty <= '0';
                        end if;
                        
                        state <= uncoded;
                    else
                        -- the next symbol is encoded
                        flags_buffer_ptr   <= flags_buffer_ptr + 1;
                        if flags_buffer_ptr = 7 then
                            flags_buffer_empty <= '1';
                        else
                            flags_buffer_empty <= '0';
                        end if;

                        state <= coded_first;
                    end if;

                when uncoded =>
                    if input_buffer_empty = '1' then
                        o_rx_acc_in_ready <= '1';

                        state        <= fetch_data;
                        return_state <= uncoded;
                    elsif output_buffer_full = '1' then
                        state        <= send;
                        return_state <= uncoded;
                    else
                        -- write the uncoded byte to the output and window
                        output_buffer(to_integer(output_buffer_ptr)) <= input_buffer(to_integer(input_buffer_ptr));
                        window(to_integer(window_ptr))               <= input_buffer(to_integer(input_buffer_ptr));
                        
                        window_ptr        <= window_ptr + 1;
                        input_buffer_ptr  <= input_buffer_ptr + 1;
                        output_buffer_ptr <= output_buffer_ptr + 1;
                        
                        -- check whether the input and output buffers are empty/full now
                        if input_buffer_ptr = input_buffer_last then
                            input_buffer_empty <= '1';
                        else
                            input_buffer_empty <= '0';
                        end if;

                        if output_buffer_ptr = 31 then
                            output_buffer_full <= '1';
                        else
                            output_buffer_full <= '0';
                        end if;

                        state <= check_flag;
                    end if;
                    
                when coded_first =>
                    if input_buffer_empty = '1' then
                        o_rx_acc_in_ready <= '1';

                        state        <= fetch_data;
                        return_state <= coded_first;
                    else
                        -- read the first byte of the match, which is distributed over two bytes:
                        -- |    1st byte    |    2nd byte    |
                        -- |        position        | length |
                        match_pos(WINDOW_BITS - 1 downto 4)   <= unsigned(input_buffer(to_integer(input_buffer_ptr))(WINDOW_BITS - 5 downto 0));
                        match_pos_2(WINDOW_BITS - 1 downto 4) <= unsigned(input_buffer(to_integer(input_buffer_ptr))(WINDOW_BITS - 5 downto 0));
                        
                        input_buffer_ptr   <= input_buffer_ptr + 1;
                        if input_buffer_ptr = input_buffer_last then
                            input_buffer_empty <= '1';
                        else
                            input_buffer_empty <= '0';
                        end if;

                        state <= coded_second;
                    end if;
                
                when coded_second =>
                    if input_buffer_empty = '1' then
                        o_rx_acc_in_ready <= '1';

                        state        <= fetch_data;
                        return_state <= coded_second;
                    else
                        -- read the second byte of the match
                        match_pos(3 downto 0)   <= unsigned(input_buffer(to_integer(input_buffer_ptr))(7 downto 4));
                        match_len               <= ('0' & unsigned(input_buffer(to_integer(input_buffer_ptr))(3 downto 0))) + 3;
                        match_pos_2(3 downto 0) <= unsigned(input_buffer(to_integer(input_buffer_ptr))(7 downto 4));
                        match_len_2             <= ('0' & unsigned(input_buffer(to_integer(input_buffer_ptr))(3 downto 0))) + 3;

                        input_buffer_ptr   <= input_buffer_ptr + 1;
                        if input_buffer_ptr = input_buffer_last then
                            input_buffer_empty <= '1';
                        else
                            input_buffer_empty <= '0';
                        end if;

                        state <= write_coded_to_output;
                    end if;

                when write_coded_to_output =>
                    if output_buffer_full = '1' then
                        state        <= send;
                        return_state <= write_coded_to_output;
                    else
                        -- read from the window and write the data to the output and the decode buffer
                        output_buffer(to_integer(output_buffer_ptr)) <= window(to_integer(match_pos));
                        decode_buffer(to_integer(18 - match_len))    <= window(to_integer(match_pos));

                        output_buffer_ptr  <= output_buffer_ptr + 1;
                        if output_buffer_ptr = 31 then
                            output_buffer_full <= '1';
                        else
                            output_buffer_full <= '0';
                        end if;

                        match_pos <= match_pos + 1;
                        match_len <= match_len - 1;

                        -- done when the last byte was written
                        if match_len = 1 then
                            state <= write_coded_to_window;
                        end if;
                    end if;

                when write_coded_to_window =>
                    -- write the data from the decode buffer to the window
                    window(to_integer(window_ptr)) <= decode_buffer(to_integer(18 - match_len_2));

                    window_ptr <= window_ptr + 1;

                    match_pos_2 <= match_pos_2 + 1;
                    match_len_2 <= match_len_2 - 1;

                    -- done when the last byte was written
                    if match_len_2 = 1 then
                        state <= check_flag;
                    end if;

                when send =>
                    -- wait until the receiver is ready and then send the buffered data
                    if i_rx_acc_out_ready = '1' then
                        -- display the data at the output
                        for i in 0 to 31 loop
                            o_rx_acc_out_data((255 - 8 * i) downto (248 - 8 * i)) <= output_buffer(i);
                        end loop;

                        -- set the output sop and eop signals appropriately
                        o_rx_acc_out_sop   <= sop_received;
                        if input_buffer_empty = '1' and match_len = 0 then
                            o_rx_acc_out_eop <= eop_received;
                        else
                            o_rx_acc_out_eop <= '0';
                        end if;

                        -- set the other output signals
                        o_rx_acc_out_empty <= std_logic_vector(32 - output_buffer_ptr);
                        o_rx_acc_out_valid <= '1';

                        state <= sending;
                    end if;
                
                when sending =>
                    -- reset output signals
                    o_rx_acc_out_sop   <= '0';
                    o_rx_acc_out_eop   <= '0';
                    o_rx_acc_out_valid <= '0';
                    
                    -- return to the return state while the receiver is reading the data
                    output_buffer_full  <= '0';
                    output_buffer_ptr   <= (others => '0');
                    sop_received        <= '0';
                    if input_buffer_empty = '1' and match_len = 0 then
                        eop_received <= '0';
                    end if;

                    state <= return_state;
            end case;
        end if;
    end process;
end architecture state_machine;
