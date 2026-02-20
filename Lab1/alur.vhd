library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ALUR is
    Port (
        clk  : in  STD_LOGIC;                         -- Clock signal
        rst  : in  STD_LOGIC;                         -- Asynchronous reset
        A    : in  STD_LOGIC_VECTOR(15 downto 0);     -- Operand A
        B    : in  STD_LOGIC_VECTOR(15 downto 0);     -- Operand B
        OP   : in  STD_LOGIC_VECTOR(2 downto 0);      -- Operation code
        CIN  : in  STD_LOGIC;                         -- Carry input
        R    : out STD_LOGIC_VECTOR(15 downto 0);     -- Result output
        COUT : out STD_LOGIC                          -- Carry output
    );
end ALUR;

architecture Behavioral of ALUR is

    -- Registered inputs
    signal A_reg, B_reg : STD_LOGIC_VECTOR(15 downto 0);
    signal OP_reg       : STD_LOGIC_VECTOR(2 downto 0);
    signal CIN_reg      : STD_LOGIC;

    -- Combinational outputs from ALU
    signal R_comb  : STD_LOGIC_VECTOR(15 downto 0);
    signal C_comb  : STD_LOGIC;

begin

    -- Input registers
    process(clk, rst)
    begin
        if rst = '1' then
            A_reg <= (others => '0');
            B_reg <= (others => '0');
            OP_reg <= (others => '0');
            CIN_reg <= '0';
        elsif rising_edge(clk) then
            A_reg <= A;
            B_reg <= B;
            OP_reg <= OP;
            CIN_reg <= CIN;
        end if;
    end process;

    -- ALU instance (combinational block)
    ALU_inst: entity work.ALU
        port map(
            A => A_reg,
            B => B_reg,
            OP => OP_reg,
            CIN => CIN_reg,
            R => R_comb,
            COUT => C_comb
        );

    -- Output registers
    process(clk, rst)
    begin
        if rst = '1' then
            R <= (others => '0');
            COUT <= '0';
        elsif rising_edge(clk) then
            R <= R_comb;
            COUT <= C_comb;
        end if;
    end process;

end Behavioral;