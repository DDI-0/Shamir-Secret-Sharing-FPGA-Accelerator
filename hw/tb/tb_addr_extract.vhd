-- Testbench for Address Bit Extraction

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_addr_extract is
end entity tb_addr_extract;

architecture sim of tb_addr_extract is
    signal addr : std_logic_vector(31 downto 0);
    signal x_out, y_out : std_logic_vector(15 downto 0);
    
begin
    
    DUT: entity work.addr_extract
        port map (addr => addr, x_out => x_out, y_out => y_out);
    
    process
    begin
        -- Test 1: All odd bits set
        addr <= x"AAAAAAAA";  -- 1010...
        wait for 10 ns;
        assert x_out = x"FFFF" report "Test 1 x FAIL" severity error;
        assert y_out = x"0000" report "Test 1 y FAIL" severity error;
        report "Test 1 (0xAAAAAAAA): x=" & integer'image(to_integer(unsigned(x_out))) &
               " y=" & integer'image(to_integer(unsigned(y_out))) severity note;
        
        -- Test 2: All even bits set
        addr <= x"55555555";  -- 0101...
        wait for 10 ns;
        assert x_out = x"0000" report "Test 2 x FAIL" severity error;
        assert y_out = x"FFFF" report "Test 2 y FAIL" severity error;
        report "Test 2 (0x55555555): x=" & integer'image(to_integer(unsigned(x_out))) &
               " y=" & integer'image(to_integer(unsigned(y_out))) severity note;
        
        -- Test 3: Real address
        addr <= x"00401000";
        wait for 10 ns;
        report "Test 3 (0x00401000): x=0x" & 
               integer'image(to_integer(unsigned(x_out))) &
               " y=0x" & integer'image(to_integer(unsigned(y_out))) severity note;
        
        report "=== Address tests complete ===" severity note;
        wait;
    end process;

end architecture sim;
