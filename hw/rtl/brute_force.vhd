-- Integrates controller and pipeline array

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity brute_force is
    generic (
        N_PIPES : natural := 16
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        -- Control
        start       : in  std_logic;
        abort       : in  std_logic;
        field       : in  std_logic_vector(1 downto 0);

        -- Share to crack (only need one share for k=2)
        share_x     : in  std_logic_vector(31 downto 0);
        share_y     : in  std_logic_vector(31 downto 0);
        coeff_a1    : in  std_logic_vector(31 downto 0);
        coeff_a2    : in  std_logic_vector(31 downto 0);
        -- Status
        busy        : out std_logic;
        found       : out std_logic;
        secret      : out std_logic_vector(31 downto 0);
        progress    : out std_logic_vector(31 downto 0);
        cycles      : out std_logic_vector(31 downto 0)
    );
end entity brute_force;

architecture rtl of brute_force is
    signal base_cand    : std_logic_vector(31 downto 0);
    signal pipe_enable  : std_logic;
    signal any_match    : std_logic;
    signal match_idx    : std_logic_vector(6 downto 0);
    signal pipe_valid   : std_logic;
    
begin

    -- Controller
    CTRL: entity work.brute_ctrl
        generic map (N_PIPES => N_PIPES)
        port map (
            clk => clk,
            rst => rst,
            start => start,
            abort => abort,
            field => field,
            share_x => share_x,
            share_y => share_y,
            coeff_a1 => coeff_a1,
            coeff_a2 => coeff_a2,
            base_cand => base_cand,
            pipe_enable => pipe_enable,
            any_match => any_match,
            match_idx => match_idx,
            pipe_valid => pipe_valid,
            busy => busy,
            found => found,
            secret => secret,
            progress => progress,
            cycles => cycles
        );
    
    -- Pipeline Array
    PIPES: entity work.brute_array
        generic map (N_PIPES => N_PIPES)
        port map (
            clk => clk,
            rst => rst,
            enable => pipe_enable,
            field => field,
            base_cand => base_cand,
            share_x => share_x,
            share_y => share_y,
            coeff_a1 => coeff_a1,
            coeff_a2 => coeff_a2,
            any_match => any_match,
            match_idx => match_idx,
            valid => pipe_valid
        );

end architecture rtl;
