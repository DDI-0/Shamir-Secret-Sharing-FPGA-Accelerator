library ieee;
use ieee.std_logic_1164.all;

entity DE10_Standard is
port
(
    -- CLOCK
    CLOCK_50           : in    std_logic;

    -- DDR3
    HPS_DDR3_ADDR      : out   std_logic_vector(14 downto 0);
    HPS_DDR3_BA        : out   std_logic_vector(2 downto 0);
    HPS_DDR3_CK_P      : out   std_logic;
    HPS_DDR3_CK_N      : out   std_logic;
    HPS_DDR3_CKE       : out   std_logic;
    HPS_DDR3_CS_N      : out   std_logic;
    HPS_DDR3_RAS_N     : out   std_logic;
    HPS_DDR3_CAS_N     : out   std_logic;
    HPS_DDR3_WE_N      : out   std_logic;
    HPS_DDR3_RESET_N   : out   std_logic;
    HPS_DDR3_DQ        : inout std_logic_vector(31 downto 0);
    HPS_DDR3_DQS_P     : inout std_logic_vector(3 downto 0);
    HPS_DDR3_DQS_N     : inout std_logic_vector(3 downto 0);
    HPS_DDR3_ODT       : out   std_logic;
    HPS_DDR3_DM        : out   std_logic_vector(3 downto 0);
    HPS_DDR3_RZQ       : in    std_logic;

    -- SD Card (SDIO)
    HPS_SD_CMD         : inout std_logic;
    HPS_SD_DATA        : inout std_logic_vector(3 downto 0);
    HPS_SD_CLK         : out   std_logic;

    -- GPIO
    HPS_GPIO0          : inout std_logic
);
end entity DE10_Standard;

---------------------------------------------------------
--  Architecture
---------------------------------------------------------
architecture rtl of DE10_Standard is

    component SoC_Shamir is
        port (
            clk_clk                          : in    std_logic                     := 'X';
            hps_io_0_hps_io_sdio_inst_CMD    : inout std_logic                     := 'X';
            hps_io_0_hps_io_sdio_inst_D0     : inout std_logic                     := 'X';
            hps_io_0_hps_io_sdio_inst_D1     : inout std_logic                     := 'X';
            hps_io_0_hps_io_sdio_inst_CLK    : out   std_logic;
            hps_io_0_hps_io_sdio_inst_D2     : inout std_logic                     := 'X';
            hps_io_0_hps_io_sdio_inst_D3     : inout std_logic                     := 'X';
            hps_io_0_hps_io_gpio_inst_GPIO00 : inout std_logic                     := 'X';
            memory_0_mem_a                   : out   std_logic_vector(14 downto 0);
            memory_0_mem_ba                  : out   std_logic_vector(2 downto 0);
            memory_0_mem_ck                  : out   std_logic;
            memory_0_mem_ck_n                : out   std_logic;
            memory_0_mem_cke                 : out   std_logic;
            memory_0_mem_cs_n                : out   std_logic;
            memory_0_mem_ras_n               : out   std_logic;
            memory_0_mem_cas_n               : out   std_logic;
            memory_0_mem_we_n                : out   std_logic;
            memory_0_mem_reset_n             : out   std_logic;
            memory_0_mem_dq                  : inout std_logic_vector(31 downto 0) := (others => 'X');
            memory_0_mem_dqs                 : inout std_logic_vector(3 downto 0)  := (others => 'X');
            memory_0_mem_dqs_n               : inout std_logic_vector(3 downto 0)  := (others => 'X');
            memory_0_mem_odt                 : out   std_logic;
            memory_0_mem_dm                  : out   std_logic_vector(3 downto 0);
            memory_0_oct_rzqin               : in    std_logic                     := 'X';
            reset_reset_n                    : in    std_logic                     := 'X'
        );
    end component SoC_Shamir;

begin

    u0 : component SoC_Shamir
        port map (
            clk_clk                          => CLOCK_50,
            reset_reset_n                    => '1',
            -- DDR3
            memory_0_mem_a                   => HPS_DDR3_ADDR,
            memory_0_mem_ba                  => HPS_DDR3_BA,
            memory_0_mem_ck                  => HPS_DDR3_CK_P,
            memory_0_mem_ck_n                => HPS_DDR3_CK_N,
            memory_0_mem_cke                 => HPS_DDR3_CKE,
            memory_0_mem_cs_n                => HPS_DDR3_CS_N,
            memory_0_mem_ras_n               => HPS_DDR3_RAS_N,
            memory_0_mem_cas_n               => HPS_DDR3_CAS_N,
            memory_0_mem_we_n                => HPS_DDR3_WE_N,
            memory_0_mem_reset_n             => HPS_DDR3_RESET_N,
            memory_0_mem_dq                  => HPS_DDR3_DQ,
            memory_0_mem_dqs                 => HPS_DDR3_DQS_P,
            memory_0_mem_dqs_n               => HPS_DDR3_DQS_N,
            memory_0_mem_odt                 => HPS_DDR3_ODT,
            memory_0_mem_dm                  => HPS_DDR3_DM,
            memory_0_oct_rzqin               => HPS_DDR3_RZQ,
            -- SD Card
            hps_io_0_hps_io_sdio_inst_CMD    => HPS_SD_CMD,
            hps_io_0_hps_io_sdio_inst_D0     => HPS_SD_DATA(0),
            hps_io_0_hps_io_sdio_inst_D1     => HPS_SD_DATA(1),
            hps_io_0_hps_io_sdio_inst_D2     => HPS_SD_DATA(2),
            hps_io_0_hps_io_sdio_inst_D3     => HPS_SD_DATA(3),
            hps_io_0_hps_io_sdio_inst_CLK    => HPS_SD_CLK,
            -- GPIO
            hps_io_0_hps_io_gpio_inst_GPIO00 => HPS_GPIO0
        );

end architecture rtl;