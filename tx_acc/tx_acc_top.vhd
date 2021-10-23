library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lzss.all;

entity tx_acc_top is
    port (
        -- clock & reset
        clk   : in std_logic;
        reset : in std_logic;

        -- TX ACC input
        i_tx_acc_in_data  : in std_logic_vector(255 downto 0);
        i_tx_acc_in_sop   : in std_logic;
        i_tx_acc_in_eop   : in std_logic;
        i_tx_acc_in_valid : in std_logic;
        i_tx_acc_in_empty : in std_logic_vector(4 downto 0);
        o_tx_acc_in_ready : out std_logic;

        -- TX ACC output
        o_tx_acc_out_data  : out std_logic_vector(255 downto 0);
        o_tx_acc_out_sop   : out std_logic;
        o_tx_acc_out_eop   : out std_logic;
        o_tx_acc_out_valid : out std_logic;
        o_tx_acc_out_empty : out std_logic_vector(4 downto 0);
        i_tx_acc_out_ready : in std_logic
    );
end entity tx_acc_top;

architecture state_machine of tx_acc_top is
    type state_t is (fetch_data, fill_lookahead, wait_for_match_finder, uncoded, coded, update_window, output_flags, output_symbols, send, sending);

    component match_finder
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
    end component match_finder;

    -- state is the current state of the state machine
    -- resturn state is used define to which state shall be "returned" in the 'fetch_data' and 'sending' state
    signal state        : state_t;
    signal return_state : state_t;

    -- sliding window
    signal window        : ram(0 to WINDOW_SIZE - 1);
    signal window_ptr    : unsigned(WINDOW_BITS - 1 downto 0);

    -- several buffers and pointers
    signal input_buffer       : ram(0 to 31);
    signal input_buffer_ptr   : unsigned(4 downto 0);
    signal input_buffer_empty : std_logic;
    signal input_buffer_last  : unsigned(4 downto 0);

    signal lookahead_buffer     : ram(0 to 17);
    signal lookahead_buffer_ptr : unsigned(4 downto 0);

    signal output_buffer      : ram(0 to 31);
    signal output_buffer_ptr  : unsigned(4 downto 0);
    signal output_buffer_full : std_logic;

    signal flags_buffer      : std_logic_vector(0 to 7);
    signal flags_buffer_ptr  : unsigned(2 downto 0);
    signal flags_buffer_full : std_logic;

    signal symbols_buffer       : ram(0 to 15);
    signal symbols_buffer_ptr   : unsigned(3 downto 0);
    signal symbols_buffer_empty : std_logic;
    signal symbols_buffer_last  : unsigned(3 downto 0);

    -- signals for storing the eop and sop inputs
    signal sop_received : std_logic;
    signal eop_received : std_logic;

    -- singals for match finding
    signal match_length : unsigned(4 downto 0);

    signal reset_match_finder : std_logic;

    signal o_match_finder_out_position : std_logic_vector(WINDOW_BITS - 1 downto 0);
    signal o_match_finder_out_length   : unsigned(4 downto 0);
    signal o_match_finder_out_valid    : std_logic;
begin
    -- instantiate the match finder
    -- the concrete implementation is specified by the 'ITERATIONS' constant in the lzss package
    finder : match_finder port map (
        clk                           => clk,
        reset                         => reset_match_finder,
        i_match_finder_in_haystack    => window,
        i_match_finder_in_needle      => lookahead_buffer,
        i_match_finder_in_needle_used => lookahead_buffer_ptr,
        o_match_finder_out_position   => o_match_finder_out_position,
        o_match_finder_out_length     => o_match_finder_out_length,
        o_match_finder_out_valid      => o_match_finder_out_valid
    );

    process (clk, reset)
    begin
        if reset = '1' then
            -- asynchronous reset
            state                <= fetch_data;
            return_state         <= fill_lookahead;
            window               <= (others => x"20");
            window_ptr           <= (others => '0');
            input_buffer         <= (others => (others => '0'));
            input_buffer_ptr     <= (others => '0');
            input_buffer_empty   <= '1';
            input_buffer_last    <= "11111";
            lookahead_buffer     <= (others => (others => '0'));
            lookahead_buffer_ptr <= (others => '0');
            output_buffer        <= (others => (others => '0'));
            output_buffer_ptr    <= (others => '0');
            output_buffer_full   <= '0';
            flags_buffer         <= (others => '0');
            flags_buffer_ptr     <= (others => '0');
            flags_buffer_full    <= '0';
            symbols_buffer       <= (others => (others => '0'));
            symbols_buffer_ptr   <= (others => '0');
            symbols_buffer_empty <= '0';
            symbols_buffer_last  <= (others => '0');
            sop_received         <= '0';
            eop_received         <= '0';
            match_length         <= (others => '0');
            reset_match_finder   <= '0';

            o_tx_acc_in_ready  <= '1';
            o_tx_acc_out_data  <= (others => '0');
            o_tx_acc_out_sop   <= '0';
            o_tx_acc_out_eop   <= '0';
            o_tx_acc_out_valid <= '0';
            o_tx_acc_out_empty <= (others => '0');
        elsif rising_edge(clk) then
            case state is
                when fetch_data =>
                    if eop_received = '1' then
                        -- package is done
                        state        <= output_flags;
                        return_state <= fetch_data;
                    elsif i_tx_acc_in_valid = '1' then
                        -- fetch data from the input
                        for i in 0 to 31 loop
                            input_buffer(i) <= i_tx_acc_in_data((255 - 8 * i) downto (248 - 8 * i));
                        end loop;

                        -- inititalize the input buffer pointers
                        input_buffer_ptr   <= (others => '0');
                        input_buffer_empty <= '0';
                        if i_tx_acc_in_eop = '1' then
                            input_buffer_last <= (31 - unsigned(i_tx_acc_in_empty));
                        else
                            input_buffer_last <= "11111";
                        end if;
                        
                        -- store the sop and eop signals
                        sop_received       <= i_tx_acc_in_sop;
                        eop_received       <= i_tx_acc_in_eop;

                        -- advance to the next state
                        o_tx_acc_in_ready <= '0';
                        state             <= return_state;
                    end if;

                when fill_lookahead =>
                    if flags_buffer_full = '1' then
                        -- write data to the output buffer if 8 symbols have been processed
                        state        <= output_flags;
                        return_state <= fill_lookahead;
                    elsif lookahead_buffer_ptr = 18 or (input_buffer_empty = '1' and eop_received = '1' and lookahead_buffer_ptr /= 0) then
                        -- lookahead buffer is full and the end of the input is not reached, so a match is searched
                        reset_match_finder <= '1';

                        state <= wait_for_match_finder;
                    elsif input_buffer_empty = '1' then
                        -- fetch data if the input is empty
                        o_tx_acc_in_ready <= '1';

                        state        <= fetch_data;
                        return_state <= fill_lookahead;
                    else
                        -- fill the lookahead buffer
                        lookahead_buffer(to_integer(lookahead_buffer_ptr)) <= input_buffer(to_integer(input_buffer_ptr));

                        lookahead_buffer_ptr <= lookahead_buffer_ptr + 1;
                        input_buffer_ptr     <= input_buffer_ptr + 1;
                        if input_buffer_ptr = input_buffer_last then
                            input_buffer_empty <= '1';
                        else
                            input_buffer_empty <= '0';
                        end if;
                    end if;

                when wait_for_match_finder =>
                    -- wait for the match finder to validate its output
                    reset_match_finder <= '0';
                    
                    if o_match_finder_out_valid = '1' then
                        if o_match_finder_out_length >= 3 then
                            -- a valid match was found
                            state <= coded;
                        else
                            -- no match was found
                            state <= uncoded;
                        end if;
                    end if;

                when uncoded =>
                    -- no match was found, so the first byte in the lookahead buffer will be transferred uncoded
                    symbols_buffer(to_integer(symbols_buffer_last)) <= lookahead_buffer(0);
                    window(to_integer(window_ptr))                  <= lookahead_buffer(0); 
                    flags_buffer(to_integer(flags_buffer_ptr))      <= '0';

                    symbols_buffer_last  <= symbols_buffer_last + 1;
                    symbols_buffer_empty <= '0';
                    window_ptr           <= window_ptr + 1;
                    flags_buffer_ptr     <= flags_buffer_ptr + 1;
                    if flags_buffer_ptr = 7 then
                        flags_buffer_full <= '1';
                    else
                        flags_buffer_full <= '0';
                    end if;

                    -- shift the lookahead buffer
                    lookahead_buffer(0 to 16) <= lookahead_buffer(1 to 17);
                    lookahead_buffer_ptr      <= lookahead_buffer_ptr - 1;

                    state <= fill_lookahead;

                when coded =>
                    -- a match was found, so the match position and length is written to the symbols buffer
                    symbols_buffer(to_integer(symbols_buffer_last))     <= std_logic_vector(resize(unsigned(o_match_finder_out_position(WINDOW_BITS - 1 downto 4)), 8));
                    symbols_buffer(to_integer(symbols_buffer_last + 1)) <= o_match_finder_out_position(3 downto 0) & std_logic_vector(resize(o_match_finder_out_length - 3, 4));
                    flags_buffer(to_integer(flags_buffer_ptr))          <= '1';

                    symbols_buffer_last  <= symbols_buffer_last + 2;
                    symbols_buffer_empty <= '0';
                    flags_buffer_ptr     <= flags_buffer_ptr + 1;
                    if flags_buffer_ptr = 7 then
                        flags_buffer_full <= '1';
                    else
                        flags_buffer_full <= '0';
                    end if;
                    lookahead_buffer_ptr <= lookahead_buffer_ptr - o_match_finder_out_length;

                    match_length <= o_match_finder_out_length;

                    state <= update_window;

                when update_window =>
                    -- update the window and shift the lookahead buffer
                    window(to_integer(window_ptr)) <= lookahead_buffer(0);
                    lookahead_buffer(0 to 16)      <= lookahead_buffer(1 to 17);

                    match_length <= match_length - 1;
                    window_ptr   <= window_ptr + 1;
                    
                    -- done when the whole match was written to the window
                    if match_length = 1 then
                        state <= fill_lookahead;
                    end if;

                when output_flags =>
                    if output_buffer_full = '1' then
                        state        <= send;
                        return_state <= output_flags;
                    else
                        -- write the buffered flags to the output buffer
                        output_buffer(to_integer(output_buffer_ptr)) <= flags_buffer;

                        flags_buffer       <= (others => '0');
                        flags_buffer_ptr   <= (others => '0');
                        flags_buffer_full  <= '0';
                        output_buffer_ptr  <= output_buffer_ptr + 1;
                        if output_buffer_ptr = 31 then
                            output_buffer_full <= '1';
                        else
                            output_buffer_full <= '0';
                        end if;

                        -- next, write the buffered sybols to the output buffer
                        state <= output_symbols;
                    end if;

                when output_symbols =>
                    if output_buffer_full = '1' then
                        state        <= send;
                        return_state <= output_symbols;
                    else
                        -- write the buffered sybols to the output buffer
                        output_buffer(to_integer(output_buffer_ptr)) <= symbols_buffer(to_integer(symbols_buffer_ptr));

                        symbols_buffer_ptr   <= symbols_buffer_ptr + 1;
                        if symbols_buffer_ptr + 1 = symbols_buffer_last then
                            symbols_buffer_empty <= '1';
                        else
                            symbols_buffer_empty <= '0';
                        end if;
                        output_buffer_ptr    <= output_buffer_ptr + 1;
                        if output_buffer_ptr = 31 then
                            output_buffer_full <= '1';
                        else
                            output_buffer_full <= '0';
                        end if;

                        -- done when the last symbol was written to the output buffer
                        if symbols_buffer_ptr + 1 = symbols_buffer_last and input_buffer_empty = '1' and eop_received = '1' and lookahead_buffer_ptr = 0 then
                            -- if the whole input was processed, the data is sent directly
                            state <= send;
                        elsif symbols_buffer_ptr + 1 = symbols_buffer_last then
                            -- otherwise, the lookahead buffer is filled
                            state <= fill_lookahead;
                        end if;
                    end if;

                when send =>
                    -- wait until the receiver is ready and then send the buffered data
                    if i_tx_acc_out_ready = '1' then
                        -- display the data at the output
                        for i in 0 to 31 loop
                            o_tx_acc_out_data((255 - 8 * i) downto (248 - 8 * i)) <= output_buffer(i);
                        end loop;

                        -- set the output sop and eop signals appropriately
                        o_tx_acc_out_sop   <= sop_received;
                        if symbols_buffer_empty = '1' and input_buffer_empty = '1' and eop_received = '1' and lookahead_buffer_ptr = 0 then
                            o_tx_acc_out_eop <= '1';
                        else
                            o_tx_acc_out_eop <= '0';
                        end if;

                        -- set the other output signals
                        o_tx_acc_out_empty <= std_logic_vector(32 - output_buffer_ptr);
                        o_tx_acc_out_valid <= '1';

                        state <= sending;
                    end if;
                
                when sending =>
                    -- reset output signals
                    o_tx_acc_out_sop   <= '0';
                    o_tx_acc_out_eop   <= '0';
                    o_tx_acc_out_valid <= '0';
                    
                    -- return to the return state while the receiver is reading the data
                    output_buffer_full  <= '0';
                    output_buffer_ptr   <= (others => '0');
                    sop_received        <= '0';
                    if symbols_buffer_empty = '1' and input_buffer_empty = '1' and eop_received = '1' and lookahead_buffer_ptr = 0 then
                        eop_received <= '0';
                    end if;

                    state <= return_state;
            end case;
        end if;
    end process;
end architecture state_machine;
