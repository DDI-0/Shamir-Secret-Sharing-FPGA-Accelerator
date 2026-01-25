-- Instantiates N_PIPES parallel search units(brute_pipe)
-- For i = 0 to N_PIPES-1 (0 -> N_PIPES-1):
--   f_i(x) = (base_cand + i) gf_add (coeff_a1 gf_multi share_x)
--   match_i = '1' if f_i(x) = share_y

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity brute_array is
    generic (
        N_PIPES : natural := 100  -- Number of parallel pipelines
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        enable      : in  std_logic;
        field       : in  std_logic_vector(1 downto 0);
        -- Base candidate (pipeline i tests base + i)
        base_cand   : in  std_logic_vector(31 downto 0);
        -- Share to verify
        share_x     : in  std_logic_vector(31 downto 0);
        share_y     : in  std_logic_vector(31 downto 0);
        coeff_a1    : in  std_logic_vector(31 downto 0);
        -- Results
        any_match   : out std_logic;
        match_idx   : out std_logic_vector(6 downto 0); -- 0-99
        valid       : out std_logic
    );
end entity brute_array;

architecture rtl of brute_array is
    -- Pipeline results
    signal pipe_match : std_logic_vector(N_PIPES-1 downto 0);
    signal pipe_valid : std_logic_vector(N_PIPES-1 downto 0);
    
    -- Candidate for each pipeline
    type cand_array_t is array (0 to N_PIPES-1) of std_logic_vector(31 downto 0);
    signal candidates : cand_array_t;
    
begin

    GEN_PIPES: for i in 0 to N_PIPES-1 generate
        -- Each pipeline tests base_cand + i
        candidates(i) <= std_logic_vector(unsigned(base_cand) + to_unsigned(i, 32));
        
        PIPE_I: entity work.brute_pipe
            port map (
                clk => clk,
                rst => rst,
                enable => enable,
                field => field,
                candidate => candidates(i),
                share_x => share_x,
                share_y => share_y,
                coeff_a1 => coeff_a1,
                match => pipe_match(i),
                valid => pipe_valid(i)
            );
    end generate GEN_PIPES;
    
    -- Combine results
    process(clk, rst)
        variable found_match : std_logic;
        variable found_idx : integer range 0 to N_PIPES-1;
    begin
        if rst = '1' then
            any_match <= '0';
            match_idx <= (others => '0');
            valid <= '0';
        elsif rising_edge(clk) then
            valid <= pipe_valid(0);
            
            found_match := '0';
            found_idx := 0;
            
            -- find first match
            for i in 0 to N_PIPES-1 loop
                if pipe_match(i) = '1' and found_match = '0' then
                    found_match := '1';
                    found_idx := i;
                end if;
            end loop;
            
            any_match <= found_match;
            match_idx <= std_logic_vector(to_unsigned(found_idx, 7));
        end if;
    end process;

end architecture rtl;
