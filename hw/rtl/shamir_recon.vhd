-- Shamir Secret Reconstruction (k shares)
-- Uses Lagrange interpolation at x=0
-- PIPELINED: one GF operation per clock cycle
--   - Lagrange numerator/denominator: 1 cycle per j
--   - GF inverse (Fermat): 1 cycle per exponent bit (32 cycles)
--   - Final multiply + accumulate: 2 cycles
-- Total per share: ~(k + 32 + 2) cycles
-- Total for k shares: ~k * (k + 34)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gf_pkg.all;

entity shamir_recon is
    generic (
        MAX_K : natural := 8  -- Maximum number of shares
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        start   : in  std_logic;
        field   : in  std_logic_vector(1 downto 0);
        k       : in  std_logic_vector(3 downto 0); -- Number of shares to use
        -- Shares as flat buses: MAX_K x 32-bit packed
        share_xs : in std_logic_vector(32*MAX_K-1 downto 0);
        share_ys : in std_logic_vector(32*MAX_K-1 downto 0);
        secret  : out std_logic_vector(31 downto 0);
        done    : out std_logic
    );
end entity shamir_recon;

architecture rtl of shamir_recon is

    -- FSM states (pipelined)
    type state_t is (
        IDLE,
        LAGRANGE_INIT,    -- Initialize num=1, den=1, j=0 for share i
        LAGRANGE_STEP,    -- One j iteration: num *= xj, den *= (xi - xj)
        INV_INIT,         -- Start Fermat inverse: result=1, base=den, bit=0
        INV_STEP,         -- One bit of square-and-multiply
        FINAL_MULT,       -- coeff = num * inv_result
        ACCUM,            -- term = yi * coeff; acc += term
        NEXT_SHARE,       -- Advance i, loop or finish
        FINISH
    );
    signal state : state_t;

    -- Internal array types for convenient indexing
    type share_array_t is array (0 to MAX_K-1) of unsigned(31 downto 0);
    signal xs, ys : share_array_t;

    signal k_int     : integer range 0 to MAX_K;
    signal i         : integer range 0 to MAX_K;
    signal j         : integer range 0 to MAX_K;
    signal acc       : unsigned(31 downto 0);
    signal field_reg : std_logic_vector(1 downto 0);

    -- Lagrange intermediate values
    signal num_reg   : unsigned(31 downto 0);
    signal den_reg   : unsigned(31 downto 0);
    signal xi_reg    : unsigned(31 downto 0);
    signal yi_reg    : unsigned(31 downto 0);

    -- Inverse (Fermat) state
    signal inv_result : unsigned(31 downto 0);
    signal inv_base   : unsigned(31 downto 0);
    signal inv_exp    : unsigned(31 downto 0);
    signal inv_bit    : integer range 0 to 31;

    -- Final multiply intermediate
    signal coeff_reg  : unsigned(31 downto 0);

    -- Single GF multiplier (shared, only 1 multiply per cycle)
    function do_mult(a, b : unsigned(31 downto 0); f : std_logic_vector(1 downto 0))
        return unsigned is
    begin
        case f is
            when "00"   => return resize(gf8_mult(a(7 downto 0), b(7 downto 0)), 32);
            when "01"   => return resize(gf16_mult(a(15 downto 0), b(15 downto 0)), 32);
            when "10"   => return gf32_mult(a, b);
            when others => return (31 downto 0 => '0');
        end case;
    end function;

    -- Extract 32-bit element from a flat bus
    function get_share(vec : std_logic_vector; idx : natural) return unsigned is
    begin
        return unsigned(vec(32*idx+31 downto 32*idx));
    end function;

begin

    -- Unpack flat buses into internal arrays
    GEN_UNPACK: for idx in 0 to MAX_K-1 generate
        xs(idx) <= get_share(share_xs, idx);
        ys(idx) <= get_share(share_ys, idx);
    end generate;

    process(clk, rst)
        variable xj_val : unsigned(31 downto 0);
        variable fermat_exp : unsigned(31 downto 0);
    begin
        if rst = '1' then
            state      <= IDLE;
            acc        <= (others => '0');
            done       <= '0';
            secret     <= (others => '0');
            num_reg    <= (others => '0');
            den_reg    <= (others => '0');
            inv_result <= (others => '0');
            inv_base   <= (others => '0');
            inv_exp    <= (others => '0');
            coeff_reg  <= (others => '0');
            xi_reg     <= (others => '0');
            yi_reg     <= (others => '0');

        elsif rising_edge(clk) then
            done <= '0';

            case state is

                --  Wait for start 
                when IDLE =>
                    if start = '1' then
                        k_int     <= to_integer(unsigned(k));
                        field_reg <= field;
                        acc       <= (others => '0');
                        i         <= 0;
                        state     <= LAGRANGE_INIT;
                    end if;

                --  Begin Lagrange for share i 
                when LAGRANGE_INIT =>
                    xi_reg  <= xs(i);
                    yi_reg  <= ys(i);
                    num_reg <= to_unsigned(1, 32);
                    den_reg <= to_unsigned(1, 32);
                    j       <= 0;
                    state   <= LAGRANGE_STEP;

                --  One j step: num *= xj, den *= (xi - xj) 
                when LAGRANGE_STEP =>
                    if j >= k_int then
                        -- Done with all j: start inverse of den
                        state <= INV_INIT;
                    elsif j = i then
                        -- Skip j == i
                        j <= j + 1;
                    else
                        xj_val := xs(j);
                        num_reg <= do_mult(num_reg, xj_val, field_reg);
                        den_reg <= do_mult(den_reg, gf_sub(xi_reg, xj_val), field_reg);
                        j <= j + 1;
                    end if;

                --  Start Fermat inverse: den^(2^n - 2) 
                when INV_INIT =>
                    inv_result <= to_unsigned(1, 32);
                    inv_base   <= den_reg;
                    inv_bit    <= 0;

                    -- Set exponent based on field
                    case field_reg is
                        when "00"   => inv_exp <= to_unsigned(254, 32);       -- 2^8 - 2
                        when "01"   => inv_exp <= to_unsigned(65534, 32);     -- 2^16 - 2
                        when "10"   => inv_exp <= x"FFFFFFFE";               -- 2^32 - 2
                        when others => inv_exp <= (others => '0');
                    end case;

                    state <= INV_STEP;

                --  One bit of square-and-multiply
                when INV_STEP =>
                    -- Process current bit
                    if inv_exp(inv_bit) = '1' then
                        inv_result <= do_mult(inv_result, inv_base, field_reg);
                    end if;
                    inv_base <= do_mult(inv_base, inv_base, field_reg);

                    -- Check if this was the last bit
                    if inv_bit = 31 then
                        state <= FINAL_MULT;
                    else
                        inv_bit <= inv_bit + 1;
                    end if;

                --  coeff = num * inverse(den) 
                when FINAL_MULT =>
                    coeff_reg <= do_mult(num_reg, inv_result, field_reg);
                    state     <= ACCUM;

                --  term = yi * coeff; acc ^= term 
                when ACCUM =>
                    acc   <= gf_add(acc, do_mult(yi_reg, coeff_reg, field_reg));
                    state <= NEXT_SHARE;

                --  Advance to next share or finish 
                when NEXT_SHARE =>
                    if i + 1 >= k_int then
                        state <= FINISH;
                    else
                        i     <= i + 1;
                        state <= LAGRANGE_INIT;
                    end if;

                --  Output result 
                when FINISH =>
                    secret <= std_logic_vector(acc);
                    done   <= '1';
                    state  <= IDLE;

            end case;
        end if;
    end process;

end architecture rtl;
