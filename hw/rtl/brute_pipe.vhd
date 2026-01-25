-- Single Brute Force Search Pipeline
-- Tests one candidate secret value against shares

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gf_pkg.all;

entity brute_pipe is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        enable      : in  std_logic;
        field       : in  std_logic_vector(1 downto 0); -- 00=GF8, 01=GF16, 10=GF32
        candidate   : in  std_logic_vector(31 downto 0); -- Secret candidate
        -- Share to verify against
        share_x     : in  std_logic_vector(31 downto 0);
        share_y     : in  std_logic_vector(31 downto 0);
        -- Polynomial coefficient (a1 for degree 1)
        coeff_a1    : in  std_logic_vector(31 downto 0);
        -- Result
        match       : out std_logic;
        valid       : out std_logic
    );
end entity brute_pipe;

architecture rtl of brute_pipe is
begin

    -- equation this process is doing: f(x) = a0 + a1*x over GF(2^n)
    process(clk, rst)
        variable a0, a1, x_val : unsigned(31 downto 0);
        variable term, computed : unsigned(31 downto 0);
        variable y_target : unsigned(31 downto 0);
        variable is_match : std_logic;
    begin
        if rst = '1' then
            match <= '0';
            valid <= '0';
        elsif rising_edge(clk) then
            -- Default
            valid <= '0';
            match <= '0';
            
            if enable = '1' then
                a0 := unsigned(candidate);
                a1 := unsigned(coeff_a1);
                x_val := unsigned(share_x);
                y_target := unsigned(share_y);
                
                -- Compute a1 * x
                case field is
                    when "00" => -- GF8
                        term := resize(gf8_mult(a1(7 downto 0), x_val(7 downto 0)), 32);
                    when "01" => -- GF16
                        term := resize(gf16_mult(a1(15 downto 0), x_val(15 downto 0)), 32);
                    when others => -- GF32
                        term := gf32_mult(a1, x_val);
                end case;
                
                -- f(x) = a0 + a1*x (XOR in GF)
                computed := gf_add(a0, term);
                
                -- Check match
                if computed = y_target then
                    is_match := '1';
                else
                    is_match := '0';
                end if;
                
                match <= is_match;
                valid <= '1';
            end if;
        end if;
    end process;

end architecture rtl;
