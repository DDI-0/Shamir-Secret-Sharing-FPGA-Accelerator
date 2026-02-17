-- poly_eval.vhd - Polynomial Evaluation using Horner's Method
-- Uses gf_pkg operators

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gf_pkg.all;

entity poly_eval is
    generic (
        MAX_DEGREE : natural := 7  -- Maximum polynomial degree (8 coefficients)
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        start   : in  std_logic;
        field   : in  std_logic_vector(1 downto 0); -- 00=GF8, 01=GF16, 10=GF32
        x       : in  std_logic_vector(31 downto 0);
        degree  : in  std_logic_vector(3 downto 0); -- 0 to 15
        -- Coefficients: coeffs[0] is constant term
        coeffs  : in  std_logic_vector(32*8-1 downto 0); -- 8 x 32-bit (a0..a7)
        result  : out std_logic_vector(31 downto 0);
        done    : out std_logic
    );
end entity poly_eval;

architecture rtl of poly_eval is
    type state_t is (IDLE, COMPUTE, FINISH);
    signal state : state_t;
    
    signal acc      : unsigned(31 downto 0);
    signal idx      : integer range 0 to MAX_DEGREE;
    signal x_reg    : unsigned(31 downto 0);
    signal field_reg: std_logic_vector(1 downto 0);
    
    -- Extract coefficient from packed array
    function get_coeff(coeffs : std_logic_vector; idx : integer) return unsigned is
        variable start_bit : integer;
    begin
        start_bit := idx * 32;
        return unsigned(coeffs(start_bit + 31 downto start_bit));
    end function;
    
begin

    process(clk, rst)
        variable tmp : unsigned(31 downto 0);
        variable mult_res : unsigned(31 downto 0);
    begin
        if rst = '1' then
            state <= IDLE;
            acc <= (others => '0');
            idx <= 0;
            done <= '0';
            result <= (others => '0');
        elsif rising_edge(clk) then
            done <= '0';
            
            case state is
                when IDLE =>
                    if start = '1' then
                        x_reg <= unsigned(x);
                        field_reg <= field;
                        -- Start with highest coefficient
                        acc <= get_coeff(coeffs, to_integer(unsigned(degree)));
                        idx <= to_integer(unsigned(degree)) - 1;
                        if unsigned(degree) = 0 then
                            state <= FINISH;
                        else
                            state <= COMPUTE;
                        end if;
                    end if;
                    
                when COMPUTE =>
                    -- Horner: acc = acc * x + coeff[idx]
                    case field_reg is
                        when "00" => -- GF8
                            mult_res := resize(gf8_mult(acc(7 downto 0), x_reg(7 downto 0)), 32);
                        when "01" => -- GF16
                            mult_res := resize(gf16_mult(acc(15 downto 0), x_reg(15 downto 0)), 32);
                        when others => -- GF32
                            mult_res := gf32_mult(acc, x_reg);
                    end case;
                    
                    tmp := get_coeff(coeffs, idx);
                    acc <= gf_add(mult_res, tmp);
                    
                    if idx = 0 then
                        state <= FINISH;
                    else
                        idx <= idx - 1;
                    end if;
                    
                when FINISH =>
                    result <= std_logic_vector(acc);
                    done <= '1';
                    state <= IDLE;
            end case;
        end if;
    end process;

end architecture rtl;
