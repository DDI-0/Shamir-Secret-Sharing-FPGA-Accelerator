-- gf_pkg.vhd - GF(2^n) Arithmetic Package
-- VHDL-93 compatible version
-- All GF operators defined here, called by entities

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package gf_pkg is

    -- Field size type
    type gf_field_t is (GF_8, GF_16, GF_32);
    
    -- Irreducible polynomials (low bits, excluding x^n term)
    -- Sparse polys chosen for minimal XOR gates in FPGA reduction
    constant GF8_POLY  : unsigned(7 downto 0)  := "00011011";  -- x^8+x^4+x^3+x+1
    constant GF16_POLY : unsigned(15 downto 0) := "0001000000001011"; -- x^16+x^12+x^3+x+1
    constant GF32_POLY : unsigned(31 downto 0) := "00000000000000000000000010001101"; -- x^32+x^7+x^3+x^2+1
    
    -- GF(2^n) addition: XOR
    function gf_add(a, b : unsigned) return unsigned;
    
    -- GF(2^n) subtraction: same as addition
    function gf_sub(a, b : unsigned) return unsigned;
    
    -- GF(2^8) multiplication using carry-less multiply
    function gf8_mult(a, b : unsigned(7 downto 0)) return unsigned;
    
    -- GF(2^16) multiplication
    function gf16_mult(a, b : unsigned(15 downto 0)) return unsigned;
    
    -- GF(2^32) multiplication
    function gf32_mult(a, b : unsigned(31 downto 0)) return unsigned;
    
    -- Carry-less multiply (polynomial multiplication)
    function clmul8(a, b : unsigned(7 downto 0)) return unsigned;
    function clmul16(a, b : unsigned(15 downto 0)) return unsigned;
    function clmul32(a, b : unsigned(31 downto 0)) return unsigned;
    
    -- Reduction by irreducible polynomial
    function gf8_reduce(prod : unsigned(15 downto 0)) return unsigned;
    function gf16_reduce(prod : unsigned(31 downto 0)) return unsigned;
    function gf32_reduce(prod : unsigned(63 downto 0)) return unsigned;
    
end package gf_pkg;

package body gf_pkg is

    -- GF addition: XOR
    function gf_add(a, b : unsigned) return unsigned is
    begin
        return a xor b;
    end function;
    
    -- GF subtraction: same as XOR
    function gf_sub(a, b : unsigned) return unsigned is
    begin
        return a xor b;
    end function;
    
    -- Carry-less multiply 8-bit (returns 16-bit)
    function clmul8(a, b : unsigned(7 downto 0)) return unsigned is
        variable result : unsigned(15 downto 0) := (others => '0');
        variable shifted : unsigned(15 downto 0);
    begin
        shifted := resize(a, 16);
        for i in 0 to 7 loop
            if b(i) = '1' then
                result := result xor shifted;
            end if;
            shifted := shifted(14 downto 0) & '0';
        end loop;
        return result;
    end function;
    
    -- Carry-less multiply 16-bit (returns 32-bit)
    function clmul16(a, b : unsigned(15 downto 0)) return unsigned is
        variable result : unsigned(31 downto 0) := (others => '0');
        variable shifted : unsigned(31 downto 0);
    begin
        shifted := resize(a, 32);
        for i in 0 to 15 loop
            if b(i) = '1' then
                result := result xor shifted;
            end if;
            shifted := shifted(30 downto 0) & '0';
        end loop;
        return result;
    end function;
    
    -- Carry-less multiply 32-bit (returns 64-bit)
    function clmul32(a, b : unsigned(31 downto 0)) return unsigned is
        variable result : unsigned(63 downto 0) := (others => '0');
        variable shifted : unsigned(63 downto 0);
    begin
        shifted := resize(a, 64);
        for i in 0 to 31 loop
            if b(i) = '1' then
                result := result xor shifted;
            end if;
            shifted := shifted(62 downto 0) & '0';
        end loop;
        return result;
    end function;
    
    -- GF(2^8) reduction
    function gf8_reduce(prod : unsigned(15 downto 0)) return unsigned is
        variable tmp : unsigned(15 downto 0) := prod;
        variable poly : unsigned(15 downto 0);
    begin
        poly := resize(GF8_POLY, 16);
        for i in 15 downto 8 loop
            if tmp(i) = '1' then
                tmp := tmp xor shift_left(poly, i - 8);
                tmp(i) := '0';
            end if;
        end loop;
        return tmp(7 downto 0);
    end function;
    
    -- GF(2^16) reduction
    function gf16_reduce(prod : unsigned(31 downto 0)) return unsigned is
        variable tmp : unsigned(31 downto 0) := prod;
        variable poly : unsigned(31 downto 0);
    begin
        poly := resize(GF16_POLY, 32);
        for i in 31 downto 16 loop
            if tmp(i) = '1' then
                tmp := tmp xor shift_left(poly, i - 16);
                tmp(i) := '0';
            end if;
        end loop;
        return tmp(15 downto 0);
    end function;
    
    -- GF(2^32) reduction
    function gf32_reduce(prod : unsigned(63 downto 0)) return unsigned is
        variable tmp : unsigned(63 downto 0) := prod;
        variable poly : unsigned(63 downto 0);
    begin
        poly := resize(GF32_POLY, 64);
        for i in 63 downto 32 loop
            if tmp(i) = '1' then
                tmp := tmp xor shift_left(poly, i - 32);
                tmp(i) := '0';
            end if;
        end loop;
        return tmp(31 downto 0);
    end function;
    
    -- GF(2^8) multiplication
    function gf8_mult(a, b : unsigned(7 downto 0)) return unsigned is
        variable prod : unsigned(15 downto 0);
        constant zero8 : unsigned(7 downto 0) := (others => '0');
    begin
        if a = zero8 or b = zero8 then
            return to_unsigned(0, 8);
        end if;
        prod := clmul8(a, b);
        return gf8_reduce(prod);
    end function;
    
    -- GF(2^16) multiplication
    function gf16_mult(a, b : unsigned(15 downto 0)) return unsigned is
        variable prod : unsigned(31 downto 0);
        constant zero16 : unsigned(15 downto 0) := (others => '0');
    begin
        if a = zero16 or b = zero16 then
            return to_unsigned(0, 16);
        end if;
        prod := clmul16(a, b);
        return gf16_reduce(prod);
    end function;
    
    -- GF(2^32) multiplication
    function gf32_mult(a, b : unsigned(31 downto 0)) return unsigned is
        variable prod : unsigned(63 downto 0);
        constant zero32 : unsigned(31 downto 0) := (others => '0');
    begin
        if a = zero32 or b = zero32 then
            return to_unsigned(0, 32);
        end if;
        prod := clmul32(a, b);
        return gf32_reduce(prod);
    end function;

end package body gf_pkg;
