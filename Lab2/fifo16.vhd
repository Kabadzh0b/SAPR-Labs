library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fifo16 is
    Port (
        clk   : in  STD_LOGIC;
        rst   : in  STD_LOGIC;

        wr_en : in  STD_LOGIC;                         -- Write enable
        rd_en : in  STD_LOGIC;                         -- Read enable

        din   : in  STD_LOGIC_VECTOR(7 downto 0);      -- Data input
        dout  : out STD_LOGIC_VECTOR(7 downto 0);      -- Data output (show-ahead)

        full  : out STD_LOGIC;                         -- FIFO full flag
        empty : out STD_LOGIC                          -- FIFO empty flag
    );
end fifo16;

architecture rtl of fifo16 is

    type mem_t is array (0 to 15) of STD_LOGIC_VECTOR(7 downto 0);
    signal mem : mem_t;

    signal wr_ptr : unsigned(3 downto 0);
    signal rd_ptr : unsigned(3 downto 0);

    -- Count of stored elements: 0..16 (needs 5 bits)
    signal count : unsigned(4 downto 0);

begin

    -- Show-ahead output: always show current head element
    dout <= mem(to_integer(rd_ptr)) when count > 0 else (others => '0');

    -- Full/Empty flags
    full  <= '1' when count = 16 else '0';
    empty <= '1' when count = 0  else '0';

    process(clk, rst)
        variable do_write : boolean;
        variable do_read  : boolean;
    begin
        if rst = '1' then
            wr_ptr <= (others => '0');
            rd_ptr <= (others => '0');
            count  <= (others => '0');

        elsif rising_edge(clk) then
            do_write := (wr_en = '1') and (count < 16);
            do_read  := (rd_en = '1') and (count > 0);

            if do_write then
                mem(to_integer(wr_ptr)) <= din;
                wr_ptr <= wr_ptr + 1;
            end if;

            if do_read then
                rd_ptr <= rd_ptr + 1;
            end if;

            if do_write and (not do_read) then
                count <= count + 1;
            elsif do_read and (not do_write) then
                count <= count - 1;
            end if;
        end if;
    end process;

end rtl;