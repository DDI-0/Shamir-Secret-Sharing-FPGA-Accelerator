-- Brute Force Search Pipeline
-- Tests one candidate secret value against a share
--   S1: register inputs, compute term1 = a1 * x
--   S2: compute xx = x * x
--   S3: compute term2 = a2 * xx
--   S4: f(x) = a0 + term1 + term2, compare with y

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

        -- Coefficients
        coeff_a1    : in  std_logic_vector(31 downto 0);
        coeff_a2    : in  std_logic_vector(31 downto 0);

        -- Result
        match       : out std_logic;
        valid       : out std_logic
    );
end entity brute_pipe;

architecture rtl of brute_pipe is

    type state_t is (IDLE, S1, S2, S3, S4);
    signal state : state_t;

    -- Registered intermediates
    signal r_a0       : unsigned(31 downto 0);
    signal r_a2       : unsigned(31 downto 0);
    signal r_x        : unsigned(31 downto 0);
    signal r_y        : unsigned(31 downto 0);
    signal r_field    : std_logic_vector(1 downto 0);
    signal r_term1    : unsigned(31 downto 0);  -- a1 * x
    signal r_xx       : unsigned(31 downto 0);  -- x * x
    signal r_term2    : unsigned(31 downto 0);  -- a2 * xx

    -- Single GF multiply helper
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

begin

    -- f(x) = a0 + a1*x + a2*x^2 over GF(2^n)
    fsm: process(clk, rst)
        variable computed : unsigned(31 downto 0);
    begin
        if rst = '1' then
            state   <= IDLE;
            match   <= '0';
            valid   <= '0';
            r_a0    <= (others => '0');
            r_a2    <= (others => '0');
            r_x     <= (others => '0');
            r_y     <= (others => '0');
            r_field <= (others => '0');
            r_term1 <= (others => '0');
            r_xx    <= (others => '0');
            r_term2 <= (others => '0');

        elsif rising_edge(clk) then
            valid <= '0';
            match <= '0';

            case state is

                when IDLE =>
                    if enable = '1' then
                        -- Register all inputs
                        r_a0    <= unsigned(candidate);
                        r_a2    <= unsigned(coeff_a2);
                        r_x     <= unsigned(share_x);
                        r_y     <= unsigned(share_y);
                        r_field <= field;
                        -- S1: compute term1 = a1 * x)
                        r_term1 <= do_mult(unsigned(coeff_a1), unsigned(share_x), field);
                        state   <= S2;
                    end if;

                when S2 =>
                    -- Compute xx = x * x
                    r_xx  <= do_mult(r_x, r_x, r_field);
                    state <= S3;

                when S3 =>
                    -- Compute term2 = a2 * xx
                    r_term2 <= do_mult(r_a2, r_xx, r_field);
                    state   <= S4;

                when S4 =>
                    -- Sum and compare: f(x) = a0 + term1 + term2
                    computed := gf_add(gf_add(r_a0, r_term1), r_term2);

                    if computed = r_y then
                        match <= '1';
                    end if;
                    valid <= '1';
                    state <= IDLE;

                when others =>
                    state <= IDLE;

            end case;
        end if;
    end process fsm;


end architecture rtl;
