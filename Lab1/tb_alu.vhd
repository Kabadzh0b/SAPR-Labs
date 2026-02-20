library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_ALU is
end tb_ALU;

architecture Behavioral of tb_ALU is

    signal A    : STD_LOGIC_VECTOR(15 downto 0);
    signal B    : STD_LOGIC_VECTOR(15 downto 0);
    signal OP   : STD_LOGIC_VECTOR(2 downto 0);
    signal CIN  : STD_LOGIC;
    signal R    : STD_LOGIC_VECTOR(15 downto 0);
    signal COUT : STD_LOGIC;

begin

    uut: entity work.ALU
        port map (
            A => A,
            B => B,
            OP => OP,
            CIN => CIN,
            R => R,
            COUT => COUT
        );

    process
    begin

        A <= x"000A"; -- 10
        B <= x"0005"; -- 5
        CIN <= '1';

        -- AND
        OP <= "000"; wait for 10 ns;
        report "AND result = " & integer'image(to_integer(unsigned(R)));

        -- XOR
        OP <= "001"; wait for 10 ns;
        report "XOR result = " & integer'image(to_integer(unsigned(R)));

        -- ADD
        OP <= "010"; wait for 10 ns;
        report "ADD result = " & integer'image(to_integer(unsigned(R))) &
               " Carry = " & std_logic'image(COUT);

        -- ADDC
        OP <= "011"; wait for 10 ns;
        report "ADDC result = " & integer'image(to_integer(unsigned(R))) &
               " Carry = " & std_logic'image(COUT);

        -- SUB
        OP <= "100"; wait for 10 ns;
        report "SUB result = " & integer'image(to_integer(unsigned(R)));

        -- SRL
        OP <= "101"; wait for 10 ns;
        report "SRL result = " & integer'image(to_integer(unsigned(R))) &
               " Carry = " & std_logic'image(COUT);

        -- SWAP
        OP <= "110"; wait for 10 ns;
        report "SWAP result = " & integer'image(to_integer(unsigned(R)));

        wait;

    end process;

end Behavioral;
