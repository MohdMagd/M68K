LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_arith.all; 
use ieee.std_logic_unsigned.all; 

entity SPI_BUS_Decoder is
	Port (
		Address 			: in Std_logic_vector(31 downto 0) ;
		SPI_Select_H 		: in Std_logic ;
		AS_L				: in Std_Logic ;
		
		SPI_Enable_H 		: out std_logic 
	);
end ;

Architecture bhvr of SPI_BUS_Decoder is
Begin
	process(Address, SPI_Select_H, AS_L)
	Begin
		
		SPI_Enable_H  	<= '0' ;	-- default is no enable
		
		if(AS_L = '0')	then 	
			-- decoder for the IIC chip - 7 registers at locations 0x0040800x 
			-- where 'x' = 0/2/4/6/8/a/c so that they occupy same half of data bus on 
			-- D15-D8


			-- [00408020 to 0040802F]. Use SPI_Select_H input to simplify decoder
			-- IMPORTANT decoder MUST USE AS_L to make sure only 1 clock edge seen by SPI controller per read/write
			if(Address(31 downto 4) = B"0000_0000_0100_0000_1000_0000_0010" and SPI_Select_H = '1') then 
				SPI_Enable_H <= '1' ;	
			end if ;
		end if ;	
	end process;
END ;
