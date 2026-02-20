library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity detector is
    Port (
        clk        : in  STD_LOGIC;
        rst        : in  STD_LOGIC;

        -- Input stream
        start      : in  STD_LOGIC;                          -- Start detector
        ed         : in  STD_LOGIC;                          -- Input byte valid strobe
        di         : in  STD_LOGIC_VECTOR(7 downto 0);       -- ASCII byte input

        -- Outputs: detection flags (1-cycle pulses)
        flag_set   : out STD_LOGIC;
        flag_reset : out STD_LOGIC;
        flag_data  : out STD_LOGIC;

        -- Output data for 0Hcccc
        data_out   : out STD_LOGIC_VECTOR(15 downto 0);

        -- Optional debug/status
        ok         : out STD_LOGIC;
        err        : out STD_LOGIC
    );
end detector;

architecture rtl of detector is

    -- =========================
    -- FIFO interface signals
    -- =========================
    signal fifo_wr    : STD_LOGIC;
    signal fifo_rd    : STD_LOGIC;
    signal fifo_din   : STD_LOGIC_VECTOR(7 downto 0);
    signal fifo_dout  : STD_LOGIC_VECTOR(7 downto 0);
    signal fifo_full  : STD_LOGIC;
    signal fifo_empty : STD_LOGIC;

    -- Current symbol from FIFO (show-ahead)
    signal symb : STD_LOGIC_VECTOR(7 downto 0);

    -- =========================
    -- FSM states
    -- =========================
    type state_t is (
        IDLE,
        WAIT_FULL,
        ST_S,

        -- SET branch
        SET_S, SET_SE, SET_OK,

        -- RESET branch
        R_R, R_RE, R_RES, R_RESE, R_RESET_OK,

        -- 0Hcccc branch
        D_0, D_0H, D_H1, D_H2, D_H3, D_H4_OK,

        ERR_STATE
    );

    signal state, next_state : state_t;

    -- Hex accumulator for 0Hcccc (nibbles packed into 16-bit)
    signal hex_acc : STD_LOGIC_VECTOR(15 downto 0);

    -- 1-cycle pulses (registered)
    signal flag_set_r, flag_reset_r, flag_data_r : STD_LOGIC;

    -- Internal status
    signal err_r : STD_LOGIC;

    -- =========================
    -- Helpers: ASCII constants
    -- =========================
    constant C_NULL : STD_LOGIC_VECTOR(7 downto 0) := x"00";

    constant C_S : STD_LOGIC_VECTOR(7 downto 0) := x"53"; -- 'S'
    constant C_E : STD_LOGIC_VECTOR(7 downto 0) := x"45"; -- 'E'
    constant C_T : STD_LOGIC_VECTOR(7 downto 0) := x"54"; -- 'T'
    constant C_R : STD_LOGIC_VECTOR(7 downto 0) := x"52"; -- 'R'
    constant C_0 : STD_LOGIC_VECTOR(7 downto 0) := x"30"; -- '0'
    constant C_H : STD_LOGIC_VECTOR(7 downto 0) := x"48"; -- 'H'

    -- Return TRUE if symb is HEX [0-9A-F]
    function is_hex(sym : STD_LOGIC_VECTOR(7 downto 0)) return boolean is
        variable code : integer;
    begin
        code := to_integer(unsigned(sym));

        -- '0'..'9' => 16#30#..16#39#
        if (code >= 16#30#) and (code <= 16#39#) then
            return true;
        end if;

        -- 'A'..'F' => 16#41#..16#46#
        if (code >= 16#41#) and (code <= 16#46#) then
            return true;
        end if;

        return false;
    end function;

    -- Convert HEX ASCII [0-9A-F] to nibble (4-bit)
    function hex_to_nibble(sym : STD_LOGIC_VECTOR(7 downto 0)) return STD_LOGIC_VECTOR is
        variable code : integer;
        variable n    : unsigned(3 downto 0);
    begin
        code := to_integer(unsigned(sym));

        if (code >= 16#30#) and (code <= 16#39#) then
            -- '0'..'9'
            n := to_unsigned(code - 16#30#, 4);
        else
            -- 'A'..'F' -> 10..15
            n := to_unsigned(code - 16#41# + 10, 4);
        end if;

        return std_logic_vector(n);
    end function;

begin

    -- Outputs
    flag_set   <= flag_set_r;
    flag_reset <= flag_reset_r;
    flag_data  <= flag_data_r;

    ok  <= '1' when state /= IDLE else '0';
    err <= err_r;

    -- FIFO wiring
    fifo_din <= di;
    fifo_wr  <= ed;
    symb     <= fifo_dout;

    fifo16_inst: entity work.fifo16
        port map(
            clk   => clk,
            rst   => rst,
            wr_en => fifo_wr,
            rd_en => fifo_rd,
            din   => fifo_din,
            dout  => fifo_dout,
            full  => fifo_full,
            empty => fifo_empty
        );

    -- =========================
    -- FSM state register + outputs/registers updates
    -- =========================
    process(clk, rst)
        variable nib : STD_LOGIC_VECTOR(3 downto 0);
    begin
        if rst = '1' then
            state <= IDLE;

            flag_set_r   <= '0';
            flag_reset_r <= '0';
            flag_data_r  <= '0';

            data_out <= (others => '0');
            hex_acc  <= (others => '0');

            err_r <= '0';

        elsif rising_edge(clk) then
            state <= next_state;

            -- Flags are 1-cycle pulses
            flag_set_r   <= '0';
            flag_reset_r <= '0';
            flag_data_r  <= '0';

            -- Clear error by default (will be set when entering ERR_STATE)
            err_r <= '0';

            -- Clear accumulator at "0H" start
            if (state = D_0) and (next_state = D_0H) and (fifo_rd = '1') then
                hex_acc <= (others => '0');
            end if;

            -- Update hex accumulator when reading hex digits
            if fifo_rd = '1' and (state = D_0H or state = D_H1 or state = D_H2 or state = D_H3) then
                if is_hex(symb) then
                    nib := hex_to_nibble(symb);
                    case state is
                        when D_0H =>
                            hex_acc(15 downto 12) <= nib; -- 1st nibble
                        when D_H1 =>
                            hex_acc(11 downto 8)  <= nib; -- 2nd nibble
                        when D_H2 =>
                            hex_acc(7 downto 4)   <= nib; -- 3rd nibble
                        when D_H3 =>
                            hex_acc(3 downto 0)   <= nib; -- 4th nibble
                        when others =>
                            null;
                    end case;
                end if;
            end if;

            -- Latch outputs on successful terminator (NULL)
            if state = SET_OK and fifo_rd = '1' and symb = C_NULL then
                flag_set_r <= '1';
            end if;

            if state = R_RESET_OK and fifo_rd = '1' and symb = C_NULL then
                flag_reset_r <= '1';
            end if;

            if state = D_H4_OK and fifo_rd = '1' and symb = C_NULL then
                data_out <= hex_acc;
                flag_data_r <= '1';
            end if;

            -- Error flag when we enter ERR_STATE
            if next_state = ERR_STATE then
                err_r <= '1';
            end if;

        end if;
    end process;

    -- =========================
    -- FSM next-state logic + fifo_rd control
    -- =========================
    process(state, start, fifo_full, fifo_empty, symb)
        variable want_read : STD_LOGIC;
    begin
        next_state <= state;
        want_read  := '0';

        case state is

            when IDLE =>
                if start = '1' then
                    next_state <= WAIT_FULL;
                end if;

            when WAIT_FULL =>
                if fifo_full = '1' then
                    next_state <= ST_S;
                end if;

            when ST_S =>
                if fifo_empty = '0' then
                    want_read := '1';

                    if symb = C_NULL then
                        next_state <= ST_S;
                    elsif symb = C_S then
                        next_state <= SET_S;
                    elsif symb = C_R then
                        next_state <= R_R;
                    elsif symb = C_0 then
                        next_state <= D_0;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

            -- ===== SET =====
            when SET_S =>
                if fifo_empty = '0' then
                    want_read := '1';
                    if symb = C_E then
                        next_state <= SET_SE;
                    elsif symb = C_NULL then
                        next_state <= ST_S;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

            when SET_SE =>
                if fifo_empty = '0' then
                    want_read := '1';
                    if symb = C_T then
                        next_state <= SET_OK;
                    elsif symb = C_NULL then
                        next_state <= ST_S;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

            when SET_OK =>
                if fifo_empty = '0' then
                    want_read := '1';
                    if symb = C_NULL then
                        next_state <= ST_S;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

            -- ===== RESET =====
            when R_R =>
                if fifo_empty = '0' then
                    want_read := '1';
                    if symb = C_E then
                        next_state <= R_RE;
                    elsif symb = C_NULL then
                        next_state <= ST_S;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

            when R_RE =>
                if fifo_empty = '0' then
                    want_read := '1';
                    if symb = C_S then
                        next_state <= R_RES;
                    elsif symb = C_NULL then
                        next_state <= ST_S;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

            when R_RES =>
                if fifo_empty = '0' then
                    want_read := '1';
                    if symb = C_E then
                        next_state <= R_RESE;
                    elsif symb = C_NULL then
                        next_state <= ST_S;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

            when R_RESE =>
                if fifo_empty = '0' then
                    want_read := '1';
                    if symb = C_T then
                        next_state <= R_RESET_OK;
                    elsif symb = C_NULL then
                        next_state <= ST_S;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

            when R_RESET_OK =>
                if fifo_empty = '0' then
                    want_read := '1';
                    if symb = C_NULL then
                        next_state <= ST_S;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

            -- ===== 0Hcccc =====
            when D_0 =>
                if fifo_empty = '0' then
                    want_read := '1';
                    if symb = C_H then
                        next_state <= D_0H;
                    elsif symb = C_NULL then
                        next_state <= ST_S;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

            when D_0H =>
                if fifo_empty = '0' then
                    want_read := '1';
                    if is_hex(symb) then
                        next_state <= D_H1;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

            when D_H1 =>
                if fifo_empty = '0' then
                    want_read := '1';
                    if is_hex(symb) then
                        next_state <= D_H2;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

            when D_H2 =>
                if fifo_empty = '0' then
                    want_read := '1';
                    if is_hex(symb) then
                        next_state <= D_H3;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

            when D_H3 =>
                if fifo_empty = '0' then
                    want_read := '1';
                    if is_hex(symb) then
                        next_state <= D_H4_OK;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

            when D_H4_OK =>
                if fifo_empty = '0' then
                    want_read := '1';
                    if symb = C_NULL then
                        next_state <= ST_S;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

            -- ===== ERROR =====
            when ERR_STATE =>
                if fifo_empty = '0' then
                    want_read := '1';
                    if symb = C_NULL then
                        next_state <= ST_S;
                    else
                        next_state <= ERR_STATE;
                    end if;
                end if;

        end case;

        fifo_rd <= want_read;
    end process;

end rtl;