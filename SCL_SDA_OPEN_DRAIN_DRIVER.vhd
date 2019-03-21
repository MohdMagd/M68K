library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity SCL_SDA_OPEN_DRAIN_DRIVER is
	port (
		-- i2c lines
		scl_pad_i     : out  std_logic;        -- i2c clock line input
		scl_pad_o     : in  std_logic;  	     -- i2c clock line output
		scl_padoen_o  : in  std_logic;      -- i2c clock line output enable, active low
		sda_pad_i     : out  std_logic;       -- i2c data line input
		sda_pad_o     : in std_logic;         -- i2c data line output
		sda_padoen_o  : in std_logic;      -- i2c data line output enable, active low
		
		SCL : inout std_logic ;
		SDA : inout std_logic
	);
end entity SCL_SDA_OPEN_DRAIN_DRIVER;

architecture structural of SCL_SDA_OPEN_DRAIN_DRIVER is
begin
	SCL <= scl_pad_o when (scl_padoen_o = '0') else 'Z';
	SDA <= sda_pad_o when (sda_padoen_o = '0') else 'Z';
	
	scl_pad_i <= SCL;
	sda_pad_i <= SDA;
end architecture;
