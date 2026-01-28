-- Testbench for Brute Force Engine

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_brute_force is
end entity tb_brute_force;

architecture sim of tb_brute_force is
    constant CLK_PERIOD : time := 10 ns;
    constant N_PIPES : natural := 10;  
    
    signal clk, rst : std_logic := '0';
    signal start, abort : std_logic := '0';
    signal field : std_logic_vector(1 downto 0) := "00";
    signal share_x, share_y : std_logic_vector(31 downto 0);
    signal coeff_a1 : std_logic_vector(31 downto 0);
    signal busy, found : std_logic;
    signal secret_out, progress, cycles : std_logic_vector(31 downto 0);
    
begin

    DUT: entity work.brute_force
        generic map (N_PIPES => N_PIPES)
        port map (
            clk => clk, rst => rst,
            start => start, abort => abort, field => field,
            share_x => share_x, share_y => share_y,
            coeff_a1 => coeff_a1,
            busy => busy, found => found,
            secret => secret_out, progress => progress, cycles => cycles
        );
    
    clk <= not clk after CLK_PERIOD/2;
    
    process
    begin
        -- Reset
        rst <= '1';
        wait for CLK_PERIOD * 3;
        rst <= '0';
        wait for CLK_PERIOD;
        
        report "=== Test 1: GF(2^8) Brute Force ===" severity note;
        
        -- Secret is 0x42 (known for test)
        -- Share at x=1: y = a0 + a1*1 = 0x42 + 0x05 = 0x47
        -- Using a1 = 0x05
        field <= "00";  -- GF8
        share_x <= x"00000001";
        share_y <= x"00000047";  -- 0x42 XOR 0x05
        coeff_a1 <= x"00000005";
        
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';
        
        -- Wait for completion
        wait until busy = '0';
        wait for CLK_PERIOD;
        
        if found = '1' then
            report "FOUND secret: 0x" & integer'image(to_integer(unsigned(secret_out))) severity note;
            if unsigned(secret_out) = x"00000042" then
                report "Test 1 PASS: Correct secret 0x42" severity note;
            else
                report "Test 1 FAIL: Expected 0x42" severity error;
            end if;
        else
            report "Test 1 FAIL: Secret not found" severity error;
        end if;
        
        report "Cycles: " & integer'image(to_integer(unsigned(cycles))) severity note;
        
        wait for CLK_PERIOD * 5;
        
        report "=== Test 2: GF(2^8) with secret 0xAB ===" severity note;
        
        -- Secret is 0xAB, a1 = 0x10
        -- y = 0xAB XOR 0x10 = 0xBB (at x=1)
        share_y <= x"000000BB";
        coeff_a1 <= x"00000010";
        
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';
        
        wait until busy = '0';
        wait for CLK_PERIOD;
        
        if found = '1' and unsigned(secret_out) = x"000000AB" then
            report "Test 2 PASS: Correct secret 0xAB" severity note;
        else
            report "Test 2 FAIL: Got 0x" & integer'image(to_integer(unsigned(secret_out))) severity error;
        end if;
        
        report "Cycles: " & integer'image(to_integer(unsigned(cycles))) severity note;
        
        report "=== All brute force tests complete ===" severity note;
        wait;
    end process;

end architecture sim;
