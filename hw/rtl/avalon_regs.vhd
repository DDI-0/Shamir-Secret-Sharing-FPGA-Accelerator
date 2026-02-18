-- : Brute-Force (mode 0), Share Generation (mode 1), Reconstruction (mode 2)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity avalon_regs is
    port (
        clk       : in  std_logic;
        reset_n   : in  std_logic;
        read      : in  std_logic;
        write     : in  std_logic;
        address   : in  std_logic_vector(5 downto 0);
        writedata : in  std_logic_vector(31 downto 0);
        readdata  : out std_logic_vector(31 downto 0);
        interrupt : out std_logic;
        
        -- Mode selection
        cfg_mode    : out std_logic_vector(1 downto 0);  -- 00=brute, 01=gen, 10=recon
        
        ctrl_start  : out std_logic;
        ctrl_abort  : out std_logic;
        cfg_field   : out std_logic_vector(1 downto 0);
        
        -- Brute force specific (also used as share0 for recon)
        cfg_share_x  : out std_logic_vector(31 downto 0);
        cfg_share_y  : out std_logic_vector(31 downto 0);
        cfg_coeff_a1 : out std_logic_vector(31 downto 0);  -- a1 for brute, a0 for gen
        cfg_coeff_a2 : out std_logic_vector(31 downto 0);  -- a2 for brute, a1 for gen
        
        -- Share generation: coefficients and eval point
        cfg_coeff1  : out std_logic_vector(31 downto 0);
        cfg_coeff2  : out std_logic_vector(31 downto 0);
        cfg_coeff3  : out std_logic_vector(31 downto 0);
        cfg_coeff4  : out std_logic_vector(31 downto 0);
        cfg_coeff5  : out std_logic_vector(31 downto 0);
        cfg_coeff6  : out std_logic_vector(31 downto 0);
        cfg_coeff7  : out std_logic_vector(31 downto 0);
        cfg_eval_x  : out std_logic_vector(31 downto 0);
        cfg_degree  : out std_logic_vector(3 downto 0);
        
        -- Reconstruction: additional shares (up to 8 total)
        cfg_share_x1 : out std_logic_vector(31 downto 0);
        cfg_share_y1 : out std_logic_vector(31 downto 0);
        cfg_share_x2 : out std_logic_vector(31 downto 0);
        cfg_share_y2 : out std_logic_vector(31 downto 0);
        cfg_share_x3 : out std_logic_vector(31 downto 0);
        cfg_share_y3 : out std_logic_vector(31 downto 0);
        cfg_share_x4 : out std_logic_vector(31 downto 0);
        cfg_share_y4 : out std_logic_vector(31 downto 0);
        cfg_share_x5 : out std_logic_vector(31 downto 0);
        cfg_share_y5 : out std_logic_vector(31 downto 0);
        cfg_share_x6 : out std_logic_vector(31 downto 0);
        cfg_share_y6 : out std_logic_vector(31 downto 0);
        cfg_share_x7 : out std_logic_vector(31 downto 0);
        cfg_share_y7 : out std_logic_vector(31 downto 0);
        cfg_k        : out std_logic_vector(3 downto 0);
        
        stat_busy   : in  std_logic;
        stat_found  : in  std_logic;  -- brute force only
        stat_done   : in  std_logic;  -- gen/recon done
        result_data : in  std_logic_vector(31 downto 0);  -- muxed result
        result_cycles : in std_logic_vector(31 downto 0)
    );
end entity avalon_regs;

architecture rtl of avalon_regs is

    -- Register addresses 
    constant ADDR_CONTROL   : std_logic_vector(5 downto 0) := "000000"; -- 0x00
    constant ADDR_STATUS    : std_logic_vector(5 downto 0) := "000001"; -- 0x04
    constant ADDR_FIELD     : std_logic_vector(5 downto 0) := "000010"; -- 0x08
    constant ADDR_SHARE_X0  : std_logic_vector(5 downto 0) := "000011"; -- 0x0C
    constant ADDR_SHARE_Y0  : std_logic_vector(5 downto 0) := "000100"; -- 0x10
    constant ADDR_COEFF0    : std_logic_vector(5 downto 0) := "000101"; -- 0x14 (a1 brute / a0 gen)
    constant ADDR_RESULT    : std_logic_vector(5 downto 0) := "000110"; -- 0x18
    constant ADDR_CYCLES    : std_logic_vector(5 downto 0) := "000111"; -- 0x1C
    -- Extended registers
    constant ADDR_SHARE_X1  : std_logic_vector(5 downto 0) := "001000"; -- 0x20
    constant ADDR_SHARE_Y1  : std_logic_vector(5 downto 0) := "001001"; -- 0x24
    constant ADDR_SHARE_X2  : std_logic_vector(5 downto 0) := "001010"; -- 0x28
    constant ADDR_SHARE_Y2  : std_logic_vector(5 downto 0) := "001011"; -- 0x2C
    constant ADDR_SHARE_X3  : std_logic_vector(5 downto 0) := "001100"; -- 0x30
    constant ADDR_SHARE_Y3  : std_logic_vector(5 downto 0) := "001101"; -- 0x34
    constant ADDR_COEFF1    : std_logic_vector(5 downto 0) := "001110"; -- 0x38
    constant ADDR_COEFF2    : std_logic_vector(5 downto 0) := "001111"; -- 0x3C
    constant ADDR_COEFF3    : std_logic_vector(5 downto 0) := "010000"; -- 0x40
    constant ADDR_K_DEGREE  : std_logic_vector(5 downto 0) := "010001"; -- 0x44 (k for recon, degree for gen)
    constant ADDR_EVAL_X    : std_logic_vector(5 downto 0) := "010010"; -- 0x48
    -- Shares 4-7 for full 8-share reconstruction
    constant ADDR_SHARE_X4  : std_logic_vector(5 downto 0) := "010011"; -- 0x4C
    constant ADDR_SHARE_Y4  : std_logic_vector(5 downto 0) := "010100"; -- 0x50
    constant ADDR_SHARE_X5  : std_logic_vector(5 downto 0) := "010101"; -- 0x54
    constant ADDR_SHARE_Y5  : std_logic_vector(5 downto 0) := "010110"; -- 0x58
    constant ADDR_SHARE_X6  : std_logic_vector(5 downto 0) := "010111"; -- 0x5C
    constant ADDR_SHARE_Y6  : std_logic_vector(5 downto 0) := "011000"; -- 0x60
    constant ADDR_SHARE_X7  : std_logic_vector(5 downto 0) := "011001"; -- 0x64
    constant ADDR_SHARE_Y7  : std_logic_vector(5 downto 0) := "011010"; -- 0x68
    -- Additional coefficients for poly_eval (up to 8 total)
    constant ADDR_COEFF4    : std_logic_vector(5 downto 0) := "011011"; -- 0x6C
    constant ADDR_COEFF5    : std_logic_vector(5 downto 0) := "011100"; -- 0x70
    constant ADDR_COEFF6    : std_logic_vector(5 downto 0) := "011101"; -- 0x74
    constant ADDR_COEFF7    : std_logic_vector(5 downto 0) := "011110"; -- 0x78

    -- Control register bits
    constant CTRL_START_BIT    : natural := 0;
    constant CTRL_ABORT_BIT    : natural := 1;
    constant CTRL_INT_CLR_BIT  : natural := 2;
    constant CTRL_INT_EN_BIT   : natural := 3;
    -- Mode bits [5:4]
    constant CTRL_MODE_LO_BIT  : natural := 4;
    constant CTRL_MODE_HI_BIT  : natural := 5;

    -- Status register bits
    constant STAT_BUSY_BIT  : natural := 0;
    constant STAT_FOUND_BIT : natural := 1;
    constant STAT_DONE_BIT  : natural := 2;
    constant STAT_INT_PEND  : natural := 3;

    -- Configuration registers
    signal mode_reg     : std_logic_vector(1 downto 0) := "00";
    signal field_reg    : std_logic_vector(1 downto 0) := "00";
    signal share_x0_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal share_y0_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal coeff0_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal share_x1_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal share_y1_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal share_x2_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal share_y2_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal share_x3_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal share_y3_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal share_x4_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal share_y4_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal share_x5_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal share_y5_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal share_x6_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal share_y6_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal share_x7_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal share_y7_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal coeff1_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal coeff2_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal coeff3_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal coeff4_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal coeff5_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal coeff6_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal coeff7_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal k_degree_reg : std_logic_vector(3 downto 0) := "0010";  -- default k=2
    signal eval_x_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal int_enable   : std_logic := '0';

    -- Control/status
    signal busy_d : std_logic := '0';
    signal done_pulse : std_logic;
    signal interrupt_pending : std_logic := '0';
    signal start_pulse : std_logic := '0';
    signal abort_reg   : std_logic := '0';

begin

    -- Done edge detectoR
    done_pulse <= (busy_d and not stat_busy) or stat_done;

    avalon_proc: process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '0' then
                mode_reg <= "00";
                field_reg <= "00";
                share_x0_reg <= (others => '0');
                share_y0_reg <= (others => '0');
                coeff0_reg <= (others => '0');
                share_x1_reg <= (others => '0');
                share_y1_reg <= (others => '0');
                share_x2_reg <= (others => '0');
                share_y2_reg <= (others => '0');
                share_x3_reg <= (others => '0');
                share_y3_reg <= (others => '0');
                share_x4_reg <= (others => '0');
                share_y4_reg <= (others => '0');
                share_x5_reg <= (others => '0');
                share_y5_reg <= (others => '0');
                share_x6_reg <= (others => '0');
                share_y6_reg <= (others => '0');
                share_x7_reg <= (others => '0');
                share_y7_reg <= (others => '0');
                coeff1_reg <= (others => '0');
                coeff2_reg <= (others => '0');
                coeff3_reg <= (others => '0');
                coeff4_reg <= (others => '0');
                coeff5_reg <= (others => '0');
                coeff6_reg <= (others => '0');
                coeff7_reg <= (others => '0');
                k_degree_reg <= "0010";
                eval_x_reg <= (others => '0');
                int_enable <= '0';
                interrupt_pending <= '0';
                start_pulse <= '0';
                abort_reg <= '0';
                busy_d <= '0';
                readdata <= (others => '0');
            else
                start_pulse <= '0';
                busy_d <= stat_busy;
                
                if done_pulse = '1' then
                    interrupt_pending <= '1';
                end if;

                -- Write handling
                if write = '1' then
                    case address is
                        when ADDR_CONTROL =>
                            if writedata(CTRL_START_BIT) = '1' then
                                start_pulse <= '1';
                            end if;
                            abort_reg <= writedata(CTRL_ABORT_BIT);
                            if writedata(CTRL_INT_CLR_BIT) = '1' then
                                interrupt_pending <= '0';
                            end if;
                            int_enable <= writedata(CTRL_INT_EN_BIT);
                            mode_reg <= writedata(CTRL_MODE_HI_BIT downto CTRL_MODE_LO_BIT);
                            
                        when ADDR_FIELD =>
                            field_reg <= writedata(1 downto 0);
                            
                        when ADDR_SHARE_X0 =>
                            share_x0_reg <= writedata;
                        when ADDR_SHARE_Y0 =>
                            share_y0_reg <= writedata;
                        when ADDR_COEFF0 =>
                            coeff0_reg <= writedata;
                            
                        when ADDR_SHARE_X1 =>
                            share_x1_reg <= writedata;
                        when ADDR_SHARE_Y1 =>
                            share_y1_reg <= writedata;
                        when ADDR_SHARE_X2 =>
                            share_x2_reg <= writedata;
                        when ADDR_SHARE_Y2 =>
                            share_y2_reg <= writedata;
                        when ADDR_SHARE_X3 =>
                            share_x3_reg <= writedata;
                        when ADDR_SHARE_Y3 =>
                            share_y3_reg <= writedata;
                            
                        when ADDR_COEFF1 =>
                            coeff1_reg <= writedata;
                        when ADDR_COEFF2 =>
                            coeff2_reg <= writedata;
                        when ADDR_COEFF3 =>
                            coeff3_reg <= writedata;
                            
                        when ADDR_K_DEGREE =>
                            k_degree_reg <= writedata(3 downto 0);
                        when ADDR_EVAL_X =>
                            eval_x_reg <= writedata;
                        
                        when ADDR_SHARE_X4 =>
                            share_x4_reg <= writedata;
                        when ADDR_SHARE_Y4 =>
                            share_y4_reg <= writedata;
                        when ADDR_SHARE_X5 =>
                            share_x5_reg <= writedata;
                        when ADDR_SHARE_Y5 =>
                            share_y5_reg <= writedata;
                        when ADDR_SHARE_X6 =>
                            share_x6_reg <= writedata;
                        when ADDR_SHARE_Y6 =>
                            share_y6_reg <= writedata;
                        when ADDR_SHARE_X7 =>
                            share_x7_reg <= writedata;
                        when ADDR_SHARE_Y7 =>
                            share_y7_reg <= writedata;
                        
                        when ADDR_COEFF4 =>
                            coeff4_reg <= writedata;
                        when ADDR_COEFF5 =>
                            coeff5_reg <= writedata;
                        when ADDR_COEFF6 =>
                            coeff6_reg <= writedata;
                        when ADDR_COEFF7 =>
                            coeff7_reg <= writedata;
                            
                        when others =>
                            null;
                    end case;
                end if;

                -- Read handling
                readdata <= (others => '0');
                if read = '1' then
                    case address is
                        when ADDR_CONTROL =>
                            readdata(31 downto 24) <= x"02";  -- Version 2
                            readdata(CTRL_MODE_HI_BIT downto CTRL_MODE_LO_BIT) <= mode_reg;
                            readdata(CTRL_INT_EN_BIT) <= int_enable;
                            
                        when ADDR_STATUS =>
                            readdata(STAT_BUSY_BIT) <= stat_busy;
                            readdata(STAT_FOUND_BIT) <= stat_found;
                            readdata(STAT_DONE_BIT) <= stat_done;
                            readdata(STAT_INT_PEND) <= interrupt_pending;
                            
                        when ADDR_FIELD =>
                            readdata(1 downto 0) <= field_reg;
                            
                        when ADDR_SHARE_X0 =>
                            readdata <= share_x0_reg;
                        when ADDR_SHARE_Y0 =>
                            readdata <= share_y0_reg;
                        when ADDR_COEFF0 =>
                            readdata <= coeff0_reg;
                            
                        when ADDR_RESULT =>
                            readdata <= result_data;
                        when ADDR_CYCLES =>
                            readdata <= result_cycles;
                            
                        when ADDR_SHARE_X1 =>
                            readdata <= share_x1_reg;
                        when ADDR_SHARE_Y1 =>
                            readdata <= share_y1_reg;
                        when ADDR_SHARE_X2 =>
                            readdata <= share_x2_reg;
                        when ADDR_SHARE_Y2 =>
                            readdata <= share_y2_reg;
                        when ADDR_SHARE_X3 =>
                            readdata <= share_x3_reg;
                        when ADDR_SHARE_Y3 =>
                            readdata <= share_y3_reg;
                            
                        when ADDR_COEFF1 =>
                            readdata <= coeff1_reg;
                        when ADDR_COEFF2 =>
                            readdata <= coeff2_reg;
                        when ADDR_COEFF3 =>
                            readdata <= coeff3_reg;
                            
                        when ADDR_K_DEGREE =>
                            readdata(3 downto 0) <= k_degree_reg;
                        when ADDR_EVAL_X =>
                            readdata <= eval_x_reg;
                        
                        when ADDR_SHARE_X4 =>
                            readdata <= share_x4_reg;
                        when ADDR_SHARE_Y4 =>
                            readdata <= share_y4_reg;
                        when ADDR_SHARE_X5 =>
                            readdata <= share_x5_reg;
                        when ADDR_SHARE_Y5 =>
                            readdata <= share_y5_reg;
                        when ADDR_SHARE_X6 =>
                            readdata <= share_x6_reg;
                        when ADDR_SHARE_Y6 =>
                            readdata <= share_y6_reg;
                        when ADDR_SHARE_X7 =>
                            readdata <= share_x7_reg;
                        when ADDR_SHARE_Y7 =>
                            readdata <= share_y7_reg;
                        
                        when ADDR_COEFF4 =>
                            readdata <= coeff4_reg;
                        when ADDR_COEFF5 =>
                            readdata <= coeff5_reg;
                        when ADDR_COEFF6 =>
                            readdata <= coeff6_reg;
                        when ADDR_COEFF7 =>
                            readdata <= coeff7_reg;
                            
                        when others =>
                            readdata <= x"DEADBEEF";
                    end case;
                end if;
            end if;
        end if;
    end process;

    ctrl_start   <= start_pulse;
    ctrl_abort   <= abort_reg;
    cfg_mode     <= mode_reg;
    cfg_field    <= field_reg;
    cfg_share_x  <= share_x0_reg;
    cfg_share_y  <= share_y0_reg;
    cfg_coeff_a1 <= coeff0_reg;
    cfg_coeff_a2 <= coeff1_reg;
    cfg_share_x1 <= share_x1_reg;
    cfg_share_y1 <= share_y1_reg;
    cfg_share_x2 <= share_x2_reg;
    cfg_share_y2 <= share_y2_reg;
    cfg_share_x3 <= share_x3_reg;
    cfg_share_y3 <= share_y3_reg;
    cfg_share_x4 <= share_x4_reg;
    cfg_share_y4 <= share_y4_reg;
    cfg_share_x5 <= share_x5_reg;
    cfg_share_y5 <= share_y5_reg;
    cfg_share_x6 <= share_x6_reg;
    cfg_share_y6 <= share_y6_reg;
    cfg_share_x7 <= share_x7_reg;
    cfg_share_y7 <= share_y7_reg;
    cfg_coeff1   <= coeff1_reg;
    cfg_coeff2   <= coeff2_reg;
    cfg_coeff3   <= coeff3_reg;
    cfg_coeff4   <= coeff4_reg;
    cfg_coeff5   <= coeff5_reg;
    cfg_coeff6   <= coeff6_reg;
    cfg_coeff7   <= coeff7_reg;
    cfg_k        <= k_degree_reg;
    cfg_degree   <= k_degree_reg;
    cfg_eval_x   <= eval_x_reg;
    interrupt    <= interrupt_pending and int_enable;

end architecture rtl;
