LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_arith.all; 
use ieee.std_logic_unsigned.all; 

entity AddressDecoder is
	Port (
		Address 						: in Std_logic_vector(31 downto 0) ;
		
		OnChipRomSelect_H 		: out Std_Logic ;
		OnChipRamSelect_H 		: out Std_Logic ;
		DramSelect_H 				: out Std_logic ;
		IOSelect_H 					: out Std_logic ;
		DMASelect_L 				: out Std_logic ;
		GraphicsCS_L 				: out Std_logic ;
		OffBoardMemory_H		   : out Std_logic ;
		CanBusSelect_H				: out Std_logic 
		
	);
end ;


architecture bhvr of AddressDecoder is
Begin
	process(Address)
	begin
		OnChipRomSelect_H <= '0' ;
		OnChipRamSelect_H <= '0' ;
		DramSelect_H <= '0' ;
		IOSelect_H <= '0' ;
		DMASelect_L <= '1' ;
		GraphicsCS_L <= '1' ;
		OffBoardMemory_H <= '0';
		CanBusSelect_H <= '0';
	
		if(Address( 31 downto 15) = B"0000_0000_0000_0000_0") then 		-- ON CHIP ROM address hex 0000 0000 - 0000 7FFF 32k full decoding
			OnChipRomSelect_H <= '1' ;												-- DO NOT CHANGE - debugger expects rom at this address
		end if ;	
		
		if(Address( 31 downto 18) = B"1111_1000_0000_00") then 			-- address hex F000 0000 - F003 FFFF Partial decoding - 256kbytes
			OnChipRamSelect_H <= '1' ;												-- DO NOT CHANGE - debugger expects memory at this address
		end if ;	

		if(Address(31 downto 16) = B"0000_0000_0100_0000") then 			-- address hex 0040 0000 - 0040 FFFF Partial decoding
			IOSelect_H <= '1' ;														-- DO NOT CHANGE - debugger expects IO at this address
		end if ;
		
		if(Address(31 downto 26) = B"0000_10") then 							-- address hex 0800 0000 - 0BFF FFFF Partial decoding - 64M Partial Decoding
			DramSelect_H <= '1' ;													-- DO NOT CHANGE - debugger expects IO at this address
		end if ;
		
		---------------------------------------------------------------------------------
		-- add other decoder signals here as we work through assignments and labs
		---------------------------------------------------------------------------------

		
	end process ;
END ;