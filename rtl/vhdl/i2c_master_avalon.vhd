
library ieee;
use ieee.std_logic_1164.all;

entity i2c_master_avalon is
    port   (
            -- wishbone signals
            clk   	  : in  std_logic;                    -- master clock input
            reset_n	  : in  std_logic;		    -- asynchronous reset
            address	  : in  std_logic_vector(2 downto 0); -- lower address bits
            wrdata        : in  std_logic_vector(7 downto 0); -- Databus input
            rddata        : out std_logic_vector(7 downto 0); -- Databus output
            chipselect    : in  std_logic;                    -- Write enable input
            write         : in  std_logic;                    -- Strobe signals / core select signal
            waitrequest_n : out  std_logic;                    -- Valid bus cycle input
             -- i2c lines
            scl_pad_i     : in  std_logic;                    -- i2c clock line input
            scl_pad_o     : out std_logic;                    -- i2c clock line output
            scl_padoen_o  : out std_logic;                    -- i2c clock line output enable, active low
            sda_pad_i     : in  std_logic;                    -- i2c data line input
            sda_pad_o     : out std_logic;                    -- i2c data line output
            sda_padoen_o  : out std_logic                     -- i2c data line output enable, active low
    );
end entity i2c_master_avalon;

architecture structural of i2c_master_avalon is

    component i2c_master_top is
    generic(
            ARST_LVL : std_logic := '0'                   -- asynchronous reset level
    );
    port   (
            -- wishbone signals
            wb_clk_i      : in  std_logic;                    -- master clock input
            wb_rst_i      : in  std_logic := '0';             -- synchronous active high reset
            arst_i        : in  std_logic := not ARST_LVL;    -- asynchronous reset
            wb_adr_i      : in  std_logic_vector(2 downto 0); -- lower address bits
            wb_dat_i      : in  std_logic_vector(7 downto 0); -- Databus input
            wb_dat_o      : out std_logic_vector(7 downto 0); -- Databus output
            wb_we_i       : in  std_logic;                    -- Write enable input
            wb_stb_i      : in  std_logic;                    -- Strobe signals / core select signal
            wb_cyc_i      : in  std_logic;                    -- Valid bus cycle input
            wb_ack_o      : out std_logic;                    -- Bus cycle acknowledge output
            wb_inta_o     : out std_logic;                    -- interrupt request output signal

            -- i2c lines
            scl_pad_i     : in  std_logic;                    -- i2c clock line input
            scl_pad_o     : out std_logic;                    -- i2c clock line output
            scl_padoen_o  : out std_logic;                    -- i2c clock line output enable, active low
            sda_pad_i     : in  std_logic;                    -- i2c data line input
            sda_pad_o     : out std_logic;                    -- i2c data line output
            sda_padoen_o  : out std_logic                     -- i2c data line output enable, active low
    );
    end component i2c_master_top;

    signal wb_we_i		: std_logic;
 
begin

	wb_we_i <= chipselect and write;

	c_i2c : i2c_master_top
	generic map (
        	ARST_LVL  => '0'
	)
	port map (
        	wb_clk_i		=> clk,
		wb_rst_i		=> '0',
		arst_i			=> reset_n,
		wb_adr_i		=> address,
		wb_dat_i		=> wrdata,
		wb_dat_o		=> rddata,
		wb_we_i			=> wb_we_i,
		wb_stb_i		=> chipselect,
		wb_cyc_i		=> chipselect,
		wb_ack_o		=> waitrequest_n,
		wb_inta_o		=> open,
		
		scl_pad_i		=> scl_pad_i,
		scl_pad_o		=> scl_pad_o,
		scl_padoen_o		=> scl_padoen_o,
		sda_pad_i		=> sda_pad_i,
		sda_pad_o		=> sda_pad_o,
		sda_padoen_o		=> sda_padoen_o
	);

end architecture structural;
