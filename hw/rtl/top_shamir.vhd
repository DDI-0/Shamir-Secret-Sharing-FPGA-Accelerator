-- Modes: 00=Brute-Force, 01=Share Generation, 10=Reconstruction

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_shamir is
    generic (
        N_PIPES : natural := 100
    );
    port (
        clk       : in  std_logic;
        reset_n   : in  std_logic;
        
        avs_read      : in  std_logic;
        avs_write     : in  std_logic;
        avs_address   : in  std_logic_vector(5 downto 0);
        avs_writedata : in  std_logic_vector(31 downto 0);
        avs_readdata  : out std_logic_vector(31 downto 0);
        irq : out std_logic
    );
end entity top_shamir;

architecture rtl of top_shamir is
    
    -- Signals from registers
    signal cfg_mode    : std_logic_vector(1 downto 0);
    signal ctrl_start  : std_logic;
    signal ctrl_abort  : std_logic;
    signal cfg_field   : std_logic_vector(1 downto 0);
    signal cfg_share_x : std_logic_vector(31 downto 0);
    signal cfg_share_y : std_logic_vector(31 downto 0);
    signal cfg_coeff   : std_logic_vector(31 downto 0);
    signal cfg_coeff1  : std_logic_vector(31 downto 0);
    signal cfg_coeff2  : std_logic_vector(31 downto 0);
    signal cfg_coeff3  : std_logic_vector(31 downto 0);
    signal cfg_eval_x  : std_logic_vector(31 downto 0);
    signal cfg_degree  : std_logic_vector(3 downto 0);
    signal cfg_share_x1 : std_logic_vector(31 downto 0);
    signal cfg_share_y1 : std_logic_vector(31 downto 0);
    signal cfg_share_x2 : std_logic_vector(31 downto 0);
    signal cfg_share_y2 : std_logic_vector(31 downto 0);
    signal cfg_share_x3 : std_logic_vector(31 downto 0);
    signal cfg_share_y3 : std_logic_vector(31 downto 0);
    signal cfg_k       : std_logic_vector(3 downto 0);
    
    -- Brute force signals
    signal bf_start    : std_logic;
    signal bf_busy     : std_logic;
    signal bf_found    : std_logic;
    signal bf_secret   : std_logic_vector(31 downto 0);
    signal bf_cycles   : std_logic_vector(31 downto 0);
    
    -- Poly eval (share generation) signals
    signal pe_start    : std_logic;
    signal pe_done     : std_logic;
    signal pe_result   : std_logic_vector(31 downto 0);
    signal pe_coeffs   : std_logic_vector(32*16-1 downto 0);
    signal pe_busy     : std_logic := '0';
    
    -- Reconstruction signals
    signal sr_start    : std_logic;
    signal sr_done     : std_logic;
    signal sr_secret   : std_logic_vector(31 downto 0);
    signal sr_busy     : std_logic := '0'; 
	 
    -- Muxed status/result
    signal stat_busy   : std_logic;
    signal stat_found  : std_logic;
    signal stat_done   : std_logic;
    signal result_data : std_logic_vector(31 downto 0);
    signal result_cycles : std_logic_vector(31 downto 0);
    
    
    signal reset : std_logic;
    
begin

    reset <= not reset_n;

    -- Avalon Register Interface
    REGS: entity work.avalon_regs
        port map (
            clk          => clk,
            reset_n      => reset_n,
            read         => avs_read,
            write        => avs_write,
            address      => avs_address,
            writedata    => avs_writedata,
            readdata     => avs_readdata,
            interrupt    => irq,
            cfg_mode     => cfg_mode,
            ctrl_start   => ctrl_start,
            ctrl_abort   => ctrl_abort,
            cfg_field    => cfg_field,
            cfg_share_x  => cfg_share_x,
            cfg_share_y  => cfg_share_y,
            cfg_coeff    => cfg_coeff,
            cfg_coeff1   => cfg_coeff1,
            cfg_coeff2   => cfg_coeff2,
            cfg_coeff3   => cfg_coeff3,
            cfg_eval_x   => cfg_eval_x,
            cfg_degree   => cfg_degree,
            cfg_share_x1 => cfg_share_x1,
            cfg_share_y1 => cfg_share_y1,
            cfg_share_x2 => cfg_share_x2,
            cfg_share_y2 => cfg_share_y2,
            cfg_share_x3 => cfg_share_x3,
            cfg_share_y3 => cfg_share_y3,
            cfg_k        => cfg_k,
            stat_busy    => stat_busy,
            stat_found   => stat_found,
            stat_done    => stat_done,
            result_data  => result_data,
            result_cycles => result_cycles
        );
    
    -- Mode-based start routing
    bf_start <= ctrl_start when cfg_mode = "00" else '0';
    pe_start <= ctrl_start when cfg_mode = "01" else '0';
    sr_start <= ctrl_start when cfg_mode = "10" else '0';
    
    -- Brute Force Engine
    BRUTE: entity work.brute_force
        generic map (N_PIPES => N_PIPES)
        port map (
            clk       => clk,
            rst       => reset,
            start     => bf_start,
            abort     => ctrl_abort,
            field     => cfg_field,
            share_x   => cfg_share_x,
            share_y   => cfg_share_y,
            coeff_a1  => cfg_coeff,
            busy      => bf_busy,
            found     => bf_found,
            secret    => bf_secret,
            progress  => open,
            cycles    => bf_cycles
        );
    
    -- Pack coefficients for poly_eval (a0=secret, a1, a2, a3, rest zeros)
    pe_coeffs(31 downto 0)    <= cfg_coeff;   -- a0 (secret)
    pe_coeffs(63 downto 32)   <= cfg_coeff1;  -- a1
    pe_coeffs(95 downto 64)   <= cfg_coeff2;  -- a2
    pe_coeffs(127 downto 96)  <= cfg_coeff3;  -- a3
    pe_coeffs(511 downto 128) <= (others => '0');
    
    -- Polynomial Evaluation (Share Generation)
    POLYEVAL: entity work.poly_eval
        generic map (MAX_DEGREE => 15)
        port map (
            clk     => clk,
            rst     => reset,
            start   => pe_start,
            field   => cfg_field,
            x       => cfg_eval_x,
            degree  => cfg_degree,
            coeffs  => pe_coeffs,
            result  => pe_result,
            done    => pe_done
        );
    
    -- Shamir Reconstruction
    RECON: entity work.shamir_recon
        generic map (MAX_K => 8)
        port map (
            clk       => clk,
            rst       => reset,
            start     => sr_start,
            field     => cfg_field,
            k         => cfg_k,
            share_x0  => cfg_share_x,
            share_y0  => cfg_share_y,
            share_x1  => cfg_share_x1,
            share_y1  => cfg_share_y1,
            share_x2  => cfg_share_x2,
            share_y2  => cfg_share_y2,
            share_x3  => cfg_share_x3,
            share_y3  => cfg_share_y3,
            share_x4  => (others => '0'),
            share_y4  => (others => '0'),
            share_x5  => (others => '0'),
            share_y5  => (others => '0'),
            share_x6  => (others => '0'),
            share_y6  => (others => '0'),
            share_x7  => (others => '0'),
            share_y7  => (others => '0'),
            secret    => sr_secret,
            done      => sr_done
        );
    
    -- tracking for poly_eval and reconstruction
    busy_track: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pe_busy <= '0';
                sr_busy <= '0';
            else
                -- Poly eval busy: set on start, clear on done
                if pe_start = '1' then
                    pe_busy <= '1';
                elsif pe_done = '1' then
                    pe_busy <= '0';
                end if;
                
                -- Reconstruction busy: set on start, clear on done
                if sr_start = '1' then
                    sr_busy <= '1';
                elsif sr_done = '1' then
                    sr_busy <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- Status/Result multiplexing 
    process(cfg_mode, bf_busy, bf_found, bf_secret, bf_cycles,
            pe_done, pe_result, pe_busy, sr_done, sr_secret, sr_busy)
    begin
        case cfg_mode is
            when "00" =>  -- Brute force
                stat_busy     <= bf_busy;
                stat_found    <= bf_found;
                stat_done     <= '0';
                result_data   <= bf_secret;
                result_cycles <= bf_cycles;
                
            when "01" =>  -- Share generation
                stat_busy     <= pe_busy;
                stat_found    <= '0';
                stat_done     <= pe_done;
                result_data   <= pe_result;
                result_cycles <= (others => '0');
                
            when "10" =>  -- Reconstruction
                stat_busy     <= sr_busy;
                stat_found    <= '0';
                stat_done     <= sr_done;
                result_data   <= sr_secret;
                result_cycles <= (others => '0');
                
            when others =>
                stat_busy     <= '0';
                stat_found    <= '0';
                stat_done     <= '0';
                result_data   <= (others => '0');
                result_cycles <= (others => '0');
        end case;
    end process;

end architecture rtl;
