-- Top-Level Multi-Mode Shamir FPGA Accelerator
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
        
        -- Avalon-MM Slave Interface (6-bit address for extended registers)
        avs_read      : in  std_logic;
        avs_write     : in  std_logic;
        avs_address   : in  std_logic_vector(5 downto 0);
        avs_writedata : in  std_logic_vector(31 downto 0);
        avs_readdata  : out std_logic_vector(31 downto 0);
        
        -- Interrupt
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
    signal cfg_coeff_a1 : std_logic_vector(31 downto 0);
    signal cfg_coeff_a2 : std_logic_vector(31 downto 0);
    signal cfg_coeff1  : std_logic_vector(31 downto 0);
    signal cfg_coeff2  : std_logic_vector(31 downto 0);
    signal cfg_coeff3  : std_logic_vector(31 downto 0);
    signal cfg_coeff4  : std_logic_vector(31 downto 0);
    signal cfg_coeff5  : std_logic_vector(31 downto 0);
    signal cfg_coeff6  : std_logic_vector(31 downto 0);
    signal cfg_coeff7  : std_logic_vector(31 downto 0);
    signal cfg_eval_x  : std_logic_vector(31 downto 0);
    signal cfg_degree  : std_logic_vector(3 downto 0);
    signal cfg_share_x1 : std_logic_vector(31 downto 0);
    signal cfg_share_y1 : std_logic_vector(31 downto 0);
    signal cfg_share_x2 : std_logic_vector(31 downto 0);
    signal cfg_share_y2 : std_logic_vector(31 downto 0);
    signal cfg_share_x3 : std_logic_vector(31 downto 0);
    signal cfg_share_y3 : std_logic_vector(31 downto 0);
    signal cfg_share_x4 : std_logic_vector(31 downto 0);
    signal cfg_share_y4 : std_logic_vector(31 downto 0);
    signal cfg_share_x5 : std_logic_vector(31 downto 0);
    signal cfg_share_y5 : std_logic_vector(31 downto 0);
    signal cfg_share_x6 : std_logic_vector(31 downto 0);
    signal cfg_share_y6 : std_logic_vector(31 downto 0);
    signal cfg_share_x7 : std_logic_vector(31 downto 0);
    signal cfg_share_y7 : std_logic_vector(31 downto 0);
    -- Flat buses for shamir_recon (8 x 32-bit packed)
    signal sr_share_xs : std_logic_vector(32*8-1 downto 0);
    signal sr_share_ys : std_logic_vector(32*8-1 downto 0);
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
    signal pe_coeffs   : std_logic_vector(32*8-1 downto 0);
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
            cfg_coeff_a1 => cfg_coeff_a1,
            cfg_coeff_a2 => cfg_coeff_a2,
            cfg_coeff1   => cfg_coeff1,
            cfg_coeff2   => cfg_coeff2,
            cfg_coeff3   => cfg_coeff3,
            cfg_coeff4   => cfg_coeff4,
            cfg_coeff5   => cfg_coeff5,
            cfg_coeff6   => cfg_coeff6,
            cfg_coeff7   => cfg_coeff7,
            cfg_eval_x   => cfg_eval_x,
            cfg_degree   => cfg_degree,
            cfg_share_x1 => cfg_share_x1,
            cfg_share_y1 => cfg_share_y1,
            cfg_share_x2 => cfg_share_x2,
            cfg_share_y2 => cfg_share_y2,
            cfg_share_x3 => cfg_share_x3,
            cfg_share_y3 => cfg_share_y3,
            cfg_share_x4 => cfg_share_x4,
            cfg_share_y4 => cfg_share_y4,
            cfg_share_x5 => cfg_share_x5,
            cfg_share_y5 => cfg_share_y5,
            cfg_share_x6 => cfg_share_x6,
            cfg_share_y6 => cfg_share_y6,
            cfg_share_x7 => cfg_share_x7,
            cfg_share_y7 => cfg_share_y7,
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
    
    -- Brute Force Engine (existing)
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
            coeff_a1  => cfg_coeff_a1,
            coeff_a2  => cfg_coeff_a2,
            busy      => bf_busy,
            found     => bf_found,
            secret    => bf_secret,
            progress  => open,
            cycles    => bf_cycles
        );
    
    -- Mapping: COEFF0 -> a0, COEFF1 -> a1, COEFF2 -> a2, COEFF3 -> a3, COEFF4 -> a4
    -- Note: cfg_coeff_a1 = coeff0_reg, cfg_coeff_a2 = coeff1_reg = cfg_coeff1 (shared)
    -- For gen mode we use: coeff0=a0, coeff1=a1, coeff2=a2, coeff3=a3
    pe_coeffs(31 downto 0)    <= cfg_coeff_a1;    -- a0 (coeff0_reg / ADDR_COEFF0)
    pe_coeffs(63 downto 32)   <= cfg_coeff1;      -- a1 (coeff1_reg / ADDR_COEFF1)
    pe_coeffs(95 downto 64)   <= cfg_coeff2;      -- a2 (coeff2_reg / ADDR_COEFF2)
    pe_coeffs(127 downto 96)  <= cfg_coeff3;      -- a3 (coeff3_reg / ADDR_COEFF3)
    pe_coeffs(159 downto 128) <= cfg_coeff4;      -- a4 (coeff4_reg / ADDR_COEFF4)
    pe_coeffs(191 downto 160) <= cfg_coeff5;      -- a5 (coeff5_reg / ADDR_COEFF5)
    pe_coeffs(223 downto 192) <= cfg_coeff6;      -- a6 (coeff6_reg / ADDR_COEFF6)
    pe_coeffs(255 downto 224) <= cfg_coeff7;      -- a7 (coeff7_reg / ADDR_COEFF7)
    
    -- Polynomial Evaluation (Share Generation)
    POLYEVAL: entity work.poly_eval
        generic map (MAX_DEGREE => 7)
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
    
    -- Pack individual share signals into flat buses for shamir_recon
    sr_share_xs( 31 downto   0) <= cfg_share_x;   -- share 0
    sr_share_xs( 63 downto  32) <= cfg_share_x1;   -- share 1
    sr_share_xs( 95 downto  64) <= cfg_share_x2;   -- share 2
    sr_share_xs(127 downto  96) <= cfg_share_x3;   -- share 3
    sr_share_xs(159 downto 128) <= cfg_share_x4;   -- share 4
    sr_share_xs(191 downto 160) <= cfg_share_x5;   -- share 5
    sr_share_xs(223 downto 192) <= cfg_share_x6;   -- share 6
    sr_share_xs(255 downto 224) <= cfg_share_x7;   -- share 7

    sr_share_ys( 31 downto   0) <= cfg_share_y;    -- share 0
    sr_share_ys( 63 downto  32) <= cfg_share_y1;   -- share 1
    sr_share_ys( 95 downto  64) <= cfg_share_y2;   -- share 2
    sr_share_ys(127 downto  96) <= cfg_share_y3;   -- share 3
    sr_share_ys(159 downto 128) <= cfg_share_y4;   -- share 4
    sr_share_ys(191 downto 160) <= cfg_share_y5;   -- share 5
    sr_share_ys(223 downto 192) <= cfg_share_y6;   -- share 6
    sr_share_ys(255 downto 224) <= cfg_share_y7;   -- share 7

    -- Shamir Reconstruction
    RECON: entity work.shamir_recon
        generic map (MAX_K => 8)
        port map (
            clk       => clk,
            rst       => reset,
            start     => sr_start,
            field     => cfg_field,
            k         => cfg_k,
            share_xs  => sr_share_xs,
            share_ys  => sr_share_ys,
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
    
    -- Status/Result multiplexing based on mode
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
