LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;

entity CacheDataMux is
	Port (
			ValidHit0_H, ValidHit1_H,ValidHit2_H, ValidHit3_H : in std_logic;
			Block0_In		: in std_logic_vector(15 downto 0);  		
			Block1_In		: in std_logic_vector(15 downto 0);  		
			Block2_In		: in std_logic_vector(15 downto 0);  		
			Block3_In		: in std_logic_vector(15 downto 0);  		

			DataOut		: out std_logic_vector(15 downto 0)
	);
end ;

architecture bhvr of CacheDataMux is
begin
	process(ValidHit0_H, ValidHit1_H, ValidHit2_H, ValidHit3_H, Block0_In, Block1_In, Block2_In, Block3_In)
	begin
		if(ValidHit0_H = '1') then
			DataOut <= Block0_In;
		elsif(ValidHit1_H = '1') then
			DataOut <= Block1_In;
		elsif(ValidHit2_H = '1') then
			DataOut <= Block2_In;
		else
			DataOut <= Block3_In;
		end if;
	end process;
end ;
