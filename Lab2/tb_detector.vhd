library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_detector is
end tb_detector;

architecture sim of tb_detector is

    -- DUT signals
    signal clk        : STD_LOGIC := '0';
    signal rst        : STD_LOGIC := '1';

    signal start      : STD_LOGIC := '0';
    signal ed         : STD_LOGIC := '0';
    signal di         : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

    signal flag_set   : STD_LOGIC;
    signal flag_reset : STD_LOGIC;
    signal flag_data  : STD_LOGIC;
    signal data_out   : STD_LOGIC_VECTOR(15 downto 0);
    signal ok         : STD_LOGIC;
    signal err        : STD_LOGIC;

    -- ASCII constants
    constant C_NULL : STD_LOGIC_VECTOR(7 downto 0) := x"00";
    constant C_S    : STD_LOGIC_VECTOR(7 downto 0) := x"53"; -- 'S'
    constant C_E    : STD_LOGIC_VECTOR(7 downto 0) := x"45"; -- 'E'
    constant C_T    : STD_LOGIC_VECTOR(7 downto 0) := x"54"; -- 'T'
    constant C_R    : STD_LOGIC_VECTOR(7 downto 0) := x"52"; -- 'R'
    constant C_0    : STD_LOGIC_VECTOR(7 downto 0) := x"30"; -- '0'
    constant C_H    : STD_LOGIC_VECTOR(7 downto 0) := x"48"; -- 'H'
    constant C_A    : STD_LOGIC_VECTOR(7 downto 0) := x"41"; -- 'A'
    constant C_1    : STD_LOGIC_VECTOR(7 downto 0) := x"31"; -- '1'
    constant C_2    : STD_LOGIC_VECTOR(7 downto 0) := x"32"; -- '2'
    constant C_F    : STD_LOGIC_VECTOR(7 downto 0) := x"46"; -- 'F'

    -- Convert 4-bit nibble to ASCII hex char
    function nibble_to_char(n : STD_LOGIC_VECTOR(3 downto 0)) return character is
        variable v : integer;
    begin
        v := to_integer(unsigned(n));
        if v < 10 then
            return character'val(character'pos('0') + v);
        else
            return character'val(character'pos('A') + (v - 10));
        end if;
    end function;

    -- Convert 16-bit vector to 4-char hex string
    function to_hex4(x : STD_LOGIC_VECTOR(15 downto 0)) return string is
        variable s : string(1 to 4);
    begin
        s(1) := nibble_to_char(x(15 downto 12));
        s(2) := nibble_to_char(x(11 downto 8));
        s(3) := nibble_to_char(x(7 downto 4));
        s(4) := nibble_to_char(x(3 downto 0));
        return s;
    end function;

    -- Push a byte into DUT input stream (ED strobe for 1 clock)
    procedure push_byte(
        signal di_s  : out STD_LOGIC_VECTOR(7 downto 0);
        signal ed_s  : out STD_LOGIC;
        signal clk_s : in  STD_LOGIC;
        b            : in  STD_LOGIC_VECTOR(7 downto 0)
    ) is
    begin
        di_s <= b;
        ed_s <= '1';
        wait until rising_edge(clk_s);
        ed_s <= '0';
        wait until rising_edge(clk_s);
    end procedure;

begin

    -- Instantiate DUT
    uut: entity work.detector
        port map(
            clk        => clk,
            rst        => rst,
            start      => start,
            ed         => ed,
            di         => di,
            flag_set   => flag_set,
            flag_reset => flag_reset,
            flag_data  => flag_data,
            data_out   => data_out,
            ok         => ok,
            err        => err
        );

    -- Clock generation: 10 ns period
    clk_gen : process
    begin
        while now < 2000 ns loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
        wait;
    end process;

    -- Monitor: print detections
    monitor : process(clk)
        variable data_int : integer;
    begin
        if rising_edge(clk) then
            if flag_data = '1' then
                data_int := to_integer(unsigned(data_out));
                report "DETECTED: DATA 0x" & to_hex4(data_out) &
                       " (" & integer'image(data_int) & ")" severity note;
            end if;

            if flag_set = '1' then
                report "DETECTED: SET" severity note;
            end if;

            if flag_reset = '1' then
                report "DETECTED: RESET" severity note;
            end if;

            if err = '1' then
                report "ERROR STATE ACTIVE" severity note;
            end if;
        end if;
    end process;

    -- Stimulus
    stim : process
    begin
        -- Reset
        wait for 20 ns;
        rst <= '0';
        wait until rising_edge(clk);

        -- Start detector
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        -- ==========================================================
        -- IMPORTANT:
        -- Detector starts processing only when FIFO becomes FULL (16).
        -- We MUST ensure that the DATA word (0Hcccc + NULL) is already
        -- inside FIFO before it becomes FULL.
        --
        -- First 16 bytes we push:
        --  0H1A2F\0  -> 7 bytes
        --  SET\0     -> 4 bytes (total 11)
        --  NULL x5   -> 5 bytes (total 16) => FIFO becomes FULL here
        -- ==========================================================

        -- 0H1A2F\0  (7 bytes)
        push_byte(di, ed, clk, C_0);
        push_byte(di, ed, clk, C_H);
        push_byte(di, ed, clk, C_1);
        push_byte(di, ed, clk, C_A);
        push_byte(di, ed, clk, C_2);
        push_byte(di, ed, clk, C_F);
        push_byte(di, ed, clk, C_NULL);

        -- SET\0 (4 bytes) -> total 11
        push_byte(di, ed, clk, C_S);
        push_byte(di, ed, clk, C_E);
        push_byte(di, ed, clk, C_T);
        push_byte(di, ed, clk, C_NULL);

        -- Pad with NULLs to reach exactly 16 bytes -> add 5 NULLs
        push_byte(di, ed, clk, C_NULL);
        push_byte(di, ed, clk, C_NULL);
        push_byte(di, ed, clk, C_NULL);
        push_byte(di, ed, clk, C_NULL);
        push_byte(di, ed, clk, C_NULL);

        -- After processing starts, push RESET\0 as additional stream
        wait for 80 ns;
        push_byte(di, ed, clk, C_R);
        push_byte(di, ed, clk, C_E);
        push_byte(di, ed, clk, C_S);
        push_byte(di, ed, clk, C_E);
        push_byte(di, ed, clk, C_T);
        push_byte(di, ed, clk, C_NULL);

        -- Add noise: XY\0 (should go ERR until NULL)
        wait for 50 ns;
        push_byte(di, ed, clk, x"58"); -- 'X'
        push_byte(di, ed, clk, x"59"); -- 'Y'
        push_byte(di, ed, clk, C_NULL);

        -- Finish
        wait for 200 ns;
        report "TB finished" severity note;
        wait;
    end process;

end sim;