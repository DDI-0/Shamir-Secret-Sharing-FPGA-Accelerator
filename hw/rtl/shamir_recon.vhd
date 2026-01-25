-- Shamir Secret Reconstruction (k shares)
-- Uses Lagrange interpolation at x=0

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gf_pkg.all;

entity shamir_recon is
    generic (
        MAX_K : natural := 8  -- Maximum threshold
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        start   : in  std_logic;
        field   : in  std_logic_vector(1 downto 0);
        k       : in  std_logic_vector(3 downto 0); -- Number of shares
        -- Shares as arrays (each share is 32-bit)
        share_x0, share_y0 : in std_logic_vector(31 downto 0);
        share_x1, share_y1 : in std_logic_vector(31 downto 0);
        share_x2, share_y2 : in std_logic_vector(31 downto 0);
        share_x3, share_y3 : in std_logic_vector(31 downto 0);
        share_x4, share_y4 : in std_logic_vector(31 downto 0);
        share_x5, share_y5 : in std_logic_vector(31 downto 0);
        share_x6, share_y6 : in std_logic_vector(31 downto 0);
        share_x7, share_y7 : in std_logic_vector(31 downto 0);
        secret  : out std_logic_vector(31 downto 0);
        done    : out std_logic
    );
end entity shamir_recon;

architecture rtl of shamir_recon is
    type state_t is (IDLE, CALC_TERM, ACCUM, FINISH);
    signal state : state_t;
    
    -- Store shares in arrays
    type share_array_t is array (0 to MAX_K-1) of unsigned(31 downto 0);
    signal xs, ys : share_array_t;
    
    signal k_int : integer range 0 to MAX_K;
    signal i     : integer range 0 to MAX_K;
    signal acc   : unsigned(31 downto 0);
    signal field_reg : std_logic_vector(1 downto 0);
    
    -- GF multiply helper
    function do_mult(a, b : unsigned(31 downto 0); f : std_logic_vector(1 downto 0)) 
        return unsigned is
    begin
        case f is
            when "00" => return resize(gf8_mult(a(7 downto 0), b(7 downto 0)), 32);
            when "01" => return resize(gf16_mult(a(15 downto 0), b(15 downto 0)), 32);
            when others => return gf32_mult(a, b);
        end case;
    end function;
    
    -- GF inverse using Fermat's little theorem
    function do_inv(a : unsigned(31 downto 0); f : std_logic_vector(1 downto 0))
        return unsigned is
        variable result : unsigned(31 downto 0);
        variable base : unsigned(31 downto 0);
        variable exp : unsigned(31 downto 0);
    begin
        case f is
            when "00" => exp := to_unsigned(254, 32);
            when "01" => exp := to_unsigned(65534, 32);
            when others => exp := x"FFFFFFFE";
        end case;
        
        result := to_unsigned(1, 32);
        base := a;
        
        for ii in 0 to 31 loop
            if exp(ii) = '1' then
                result := do_mult(result, base, f);
            end if;
            base := do_mult(base, base, f);
        end loop;
        
        return result;
    end function;
    
begin

    -- Register inputs into arrays
    xs(0) <= unsigned(share_x0); ys(0) <= unsigned(share_y0);
    xs(1) <= unsigned(share_x1); ys(1) <= unsigned(share_y1);
    xs(2) <= unsigned(share_x2); ys(2) <= unsigned(share_y2);
    xs(3) <= unsigned(share_x3); ys(3) <= unsigned(share_y3);
    xs(4) <= unsigned(share_x4); ys(4) <= unsigned(share_y4);
    xs(5) <= unsigned(share_x5); ys(5) <= unsigned(share_y5);
    xs(6) <= unsigned(share_x6); ys(6) <= unsigned(share_y6);
    xs(7) <= unsigned(share_x7); ys(7) <= unsigned(share_y7);

    process(clk, rst)
        variable num, den, coeff, term : unsigned(31 downto 0);
        variable xi, yi, xj : unsigned(31 downto 0);
    begin
        if rst = '1' then
            state <= IDLE;
            acc <= (others => '0');
            done <= '0';
            secret <= (others => '0');
        elsif rising_edge(clk) then
            done <= '0';
            
            case state is
                when IDLE =>
                    if start = '1' then
                        k_int <= to_integer(unsigned(k));
                        field_reg <= field;
                        acc <= (others => '0');
                        i <= 0;
                        state <= CALC_TERM;
                    end if;
                    
                when CALC_TERM =>
                    -- Get share i
                    xi := xs(i);
                    yi := ys(i);
                    
                    num := to_unsigned(1, 32);
                    den := to_unsigned(1, 32);
                    
                    -- Compute Lagrange coefficient
                    for jj in 0 to MAX_K-1 loop
                        if jj < k_int and jj /= i then
                            xj := xs(jj);
                            num := do_mult(num, xj, field_reg);
                            den := do_mult(den, gf_sub(xi, xj), field_reg);
                        end if;
                    end loop;
                    
                    coeff := do_mult(num, do_inv(den, field_reg), field_reg);
                    term := do_mult(yi, coeff, field_reg);
                    acc <= gf_add(acc, term);
                    
                    state <= ACCUM;
                    
                when ACCUM =>
                    if i + 1 >= k_int then
                        state <= FINISH;
                    else
                        i <= i + 1;
                        state <= CALC_TERM;
                    end if;
                    
                when FINISH =>
                    secret <= std_logic_vector(acc);
                    done <= '1';
                    state <= IDLE;
            end case;
        end if;
    end process;

end architecture rtl;
