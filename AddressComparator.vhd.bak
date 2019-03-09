LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_arith.all; 
use ieee.std_logic_unsigned.all; 

entity AddressComparator is
	Port (
		AddressBus 			: in Std_logic_vector(22 downto 0) ;
		TagData  			: in Std_logic_vector(22 downto 0) ;
		
		Hit_H				: out Std_logic
	);
end ;


architecture bhvr of AddressComparator is
Begin
	process(AddressBus, TagData)
	begin
		if(AddressBus = TagData) then
			Hit_H <= '1';
		else
			Hit_H <= '0' ;
		end if ;
	end process ;
END ;
