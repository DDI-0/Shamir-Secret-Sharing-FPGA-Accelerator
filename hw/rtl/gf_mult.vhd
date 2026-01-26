-- GF(2^n) Multiplier

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gf_pkg.all;

entity gf_mult is
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        start   : in  std_logic;
        field   : in  std_logic_vector(1 downto 0); -- 00=GF8, 01=GF16, 10=GF32
        a       : in  std_logic_vector(31 downto 0);
        b       : in  std_logic_vector(31 downto 0);
        result  : out std_logic_vector(31 downto 0);
        done    : out std_logic
    );
end entity gf_mult;

architecture rtl of gf_mult is
    signal result_reg : std_logic_vector(31 downto 0);
    signal done_reg   : std_logic;
begin

    process(clk, rst)
        variable a_u8  : unsigned(7 downto 0);
        variable b_u8  : unsigned(7 downto 0);
        variable a_u16 : unsigned(15 downto 0);
        variable b_u16 : unsigned(15 downto 0);
        variable a_u32 : unsigned(31 downto 0);
        variable b_u32 : unsigned(31 downto 0);
        variable res8  : unsigned(7 downto 0);
        variable res16 : unsigned(15 downto 0);
        variable res32 : unsigned(31 downto 0);
    begin
        if rst = '1' then
            result_reg <= (others => '0');
            done_reg <= '0';
        elsif rising_edge(clk) then
            done_reg <= '0';
            
            if start = '1' then
                case field is
                    when "00" => -- GF(2^8)
                        a_u8 := unsigned(a(7 downto 0));
                        b_u8 := unsigned(b(7 downto 0));
                        res8 := gf8_mult(a_u8, b_u8);
                        result_reg <= x"000000" & std_logic_vector(res8);
                        
                    when "01" => -- GF(2^16)
                        a_u16 := unsigned(a(15 downto 0));
                        b_u16 := unsigned(b(15 downto 0));
                        res16 := gf16_mult(a_u16, b_u16);
                        result_reg <= x"0000" & std_logic_vector(res16);
                        
                    when others => -- GF(2^32)
                        a_u32 := unsigned(a);
                        b_u32 := unsigned(b);
                        res32 := gf32_mult(a_u32, b_u32);
                        result_reg <= std_logic_vector(res32);
                end case;
                done_reg <= '1';
            end if;
        end if;
    end process;
    
    result <= result_reg;
    done <= done_reg;

end architecture rtl;
