-- Manages search and progress tracking

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity brute_ctrl is
    generic (
        N_PIPES : natural := 16
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        start       : in  std_logic;
        abort       : in  std_logic;
        field       : in  std_logic_vector(1 downto 0);
        share_x     : in  std_logic_vector(31 downto 0);
        share_y     : in  std_logic_vector(31 downto 0);
        coeff_a1    : in  std_logic_vector(31 downto 0);
        coeff_a2    : in  std_logic_vector(31 downto 0);
        base_cand   : out std_logic_vector(31 downto 0);
        pipe_enable : out std_logic;
        any_match   : in  std_logic;
        match_idx   : in  std_logic_vector(6 downto 0);
        pipe_valid  : in  std_logic;
        busy        : out std_logic;
        found       : out std_logic;
        secret      : out std_logic_vector(31 downto 0);
        progress    : out std_logic_vector(31 downto 0); -- Current position
        cycles      : out std_logic_vector(31 downto 0)  -- Cycle count
    );
end entity brute_ctrl;

architecture rtl of brute_ctrl is
    type state_t is (IDLE, RUNNING, WAIT_VALID, DONE);
    signal state : state_t;
    
    signal counter     : unsigned(31 downto 0);
    signal cycle_cnt   : unsigned(31 downto 0);
    signal max_value   : unsigned(31 downto 0);
    signal found_reg   : std_logic;
    signal secret_reg  : std_logic_vector(31 downto 0);
    
begin

    process(clk, rst)
    begin
        if rst = '1' then
            state <= IDLE;
            counter <= (others => '0');
            cycle_cnt <= (others => '0');
            max_value <= (others => '0');
            found_reg <= '0';
            secret_reg <= (others => '0');
            base_cand <= (others => '0');
            pipe_enable <= '0';
            busy <= '0';
        elsif rising_edge(clk) then
            pipe_enable <= '0';
            
            case state is
                when IDLE =>
                    if start = '1' then
                        counter <= (others => '0');
                        cycle_cnt <= (others => '0');
                        found_reg <= '0';
                        
                        -- Set max value based on field
                        case field is
                            when "00" => max_value <= x"000000FF"; -- 256
                            when "01" => max_value <= x"0000FFFF"; -- 65536
                            when others => max_value <= x"FFFFFFFF"; -- 4B
                        end case;
                        
                        state <= RUNNING;
                        busy <= '1';
                    end if;
                    
                when RUNNING =>
                    cycle_cnt <= cycle_cnt + 1;
                    
                    if abort = '1' then
                        state <= DONE;
                    elsif counter > max_value then
                        state <= DONE;
                    else
                        -- Start batch
                        base_cand <= std_logic_vector(counter);
                        pipe_enable <= '1';
                        state <= WAIT_VALID;
                    end if;
                    
                when WAIT_VALID =>
                    cycle_cnt <= cycle_cnt + 1;
                    
                    -- Check for result when valid arrives
                    if pipe_valid = '1' then
                        if any_match = '1' then
                            found_reg <= '1';
                            secret_reg <= std_logic_vector(counter + 
                                          resize(unsigned(match_idx), 32));
                            state <= DONE;
                        else
                            -- increment counter 
                            if counter + N_PIPES > max_value then
                                state <= DONE;
                            else
                                counter <= counter + N_PIPES;
                                state <= RUNNING;
                            end if;
                        end if;
                    end if;
                    
                when DONE =>
                    busy <= '0';
                    if start = '0' then
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;
    
    found <= found_reg;
    secret <= secret_reg;
    progress <= std_logic_vector(counter);
    cycles <= std_logic_vector(cycle_cnt);

end architecture rtl;
