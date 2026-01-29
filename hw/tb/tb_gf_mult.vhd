library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_gf_mult is
end entity tb_gf_mult;

architecture sim of tb_gf_mult is
    signal clk, rst, start, done : std_logic := '0';
    signal field : std_logic_vector(1 downto 0) := "00";
    signal a, b, result : std_logic_vector(31 downto 0);
    
    constant CLK_PERIOD : time := 10 ns;
    
begin
    
    DUT: entity work.gf_mult
        port map (
            clk => clk, rst => rst, start => start, field => field,
            a => a, b => b, result => result, done => done
        );
    
    -- Clock
    clk <= not clk after CLK_PERIOD/2;
    
    process
        procedure test_mult(
            test_a, test_b : std_logic_vector(31 downto 0);
            test_field : std_logic_vector(1 downto 0);
            expected : std_logic_vector(31 downto 0);
            msg : string
        ) is
        begin
            a <= test_a;
            b <= test_b;
            field <= test_field;
            start <= '1';
            wait for CLK_PERIOD;
            start <= '0';
            wait for CLK_PERIOD;
            
            if result = expected then
                report msg & " PASS" severity note;
            else
                report msg & " FAIL: got " & 
                       integer'image(to_integer(unsigned(result))) severity error;
            end if;
        end procedure;
        
    begin
        rst <= '1';
        wait for CLK_PERIOD * 2;
        rst <= '0';
        wait for CLK_PERIOD;
        
        -- GF8 tests
        report "=== GF(2^8) Tests ===" severity note;
        test_mult(x"00000053", x"000000CA", "00", x"00000001", "GF8: 0x53*0xCA=1");
        test_mult(x"00000002", x"00000087", "00", x"00000015", "GF8: 0x02*0x87=0x15");
        test_mult(x"00000001", x"000000AB", "00", x"000000AB", "GF8: 1*a=a");
        test_mult(x"00000000", x"000000FF", "00", x"00000000", "GF8: 0*a=0");
        
        -- GF16 tests
        report "=== GF(2^16) Tests ===" severity note;
        test_mult(x"00001234", x"00000001", "01", x"00001234", "GF16: a*1=a");
        test_mult(x"00000000", x"0000BEEF", "01", x"00000000", "GF16: 0*a=0");
        
        -- GF32 tests  
        report "=== GF(2^32) Tests ===" severity note;
        test_mult(x"DEADBEEF", x"00000001", "10", x"DEADBEEF", "GF32: a*1=a");
        test_mult(x"00000000", x"CAFEBABE", "10", x"00000000", "GF32: 0*a=0");
        
        report "=== All tests complete ===" severity note;
        wait;
    end process;

end architecture sim;
