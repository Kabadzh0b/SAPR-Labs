library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ALU is
    Port (
        A    : in  STD_LOGIC_VECTOR(15 downto 0);
        B    : in  STD_LOGIC_VECTOR(15 downto 0);
        OP   : in  STD_LOGIC_VECTOR(2 downto 0);
        CIN  : in  STD_LOGIC;
        R    : out STD_LOGIC_VECTOR(15 downto 0);
        COUT : out STD_LOGIC
    );
end ALU;

architecture Behavioral of ALU is
begin

    process(A, B, OP, CIN)
        variable tmp : unsigned(16 downto 0);
    begin

        R <= (others => '0');
        COUT <= '0';

        case OP is

            when "000" => -- AND
                R <= A and B;

            when "001" => -- XOR
                R <= A xor B;

            when "010" => -- ADD
                tmp := ('0' & unsigned(A)) + ('0' & unsigned(B));
                R <= std_logic_vector(tmp(15 downto 0));
                COUT <= tmp(16);

            when "011" => -- ADDC
                tmp := ('0' & unsigned(A)) +
                       ('0' & unsigned(B)) +
                       unsigned'(0 => CIN);
                R <= std_logic_vector(tmp(15 downto 0));
                COUT <= tmp(16);

            when "100" => -- SUB
                tmp := ('0' & unsigned(A)) - ('0' & unsigned(B));
                R <= std_logic_vector(tmp(15 downto 0));
                COUT <= tmp(16);

            when "101" => -- SRL
                R <= std_logic_vector(shift_right(unsigned(A), 1));
                COUT <= A(0);

            when "110" => -- SWAP
                R <= A(7 downto 0) & A(15 downto 8);

            when others =>
                R <= (others => '0');

        end case;

    end process;

end Behavioral;
