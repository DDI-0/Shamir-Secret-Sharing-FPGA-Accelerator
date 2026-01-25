-- C³ Address Bit Extraction
-- Extracts odd/even bits from 32-bit address to form (x,y) coordinate

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity addr_extract is
    port (
        addr    : in  std_logic_vector(31 downto 0);
        x_out   : out std_logic_vector(15 downto 0); -- Odd bits
        y_out   : out std_logic_vector(15 downto 0)  -- Even bits
    );
end entity addr_extract;

architecture rtl of addr_extract is
begin

    process(addr)
    begin
        for i in 0 to 15 loop
            x_out(i) <= addr(2*i + 1);
            y_out(i) <= addr(2*i);
        end loop;
    end process;
end architecture rtl;
