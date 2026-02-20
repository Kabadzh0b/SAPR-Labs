library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_ALUR is
end tb_ALUR;

architecture Behavioral of tb_ALUR is

    signal clk  : STD_LOGIC := '0';
    signal rst  : STD_LOGIC := '1';
    signal A    : STD_LOGIC_VECTOR(15 downto 0);
    signal B    : STD_LOGIC_VECTOR(15 downto 0);
    signal OP   : STD_LOGIC_VECTOR(2 downto 0);
    signal CIN  : STD_LOGIC;
    signal R    : STD_LOGIC_VECTOR(15 downto 0);
    signal COUT : STD_LOGIC;

begin

    uut: entity work.ALUR
        port map(
            clk => clk,
            rst => rst,
            A => A,
            B => B,
            OP => OP,
            CIN => CIN,
            R => R,
            COUT => COUT
        );

    -- Clock generation (10 ns period)
    clk_process : process
    begin
        while now < 200 ns loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
        wait;
    end process;

    -- Stimulus process
    process
    begin
        wait for 20 ns;
        rst <= '0';

        A <= x"000A";
        B <= x"0005";
        CIN <= '1';

        OP <= "010"; -- ADD
        wait for 20 ns;
        report "ALUR ADD result = " &
               integer'image(to_integer(unsigned(R)));

        OP <= "011"; -- ADDC
        wait for 20 ns;
        report "ALUR ADDC result = " &
               integer'image(to_integer(unsigned(R)));

        OP <= "100"; -- SUB
        wait for 20 ns;
        report "ALUR SUB result = " &
               integer'image(to_integer(unsigned(R)));

        report "Simulation finished";
        wait;
    end process;

end Behavioral;