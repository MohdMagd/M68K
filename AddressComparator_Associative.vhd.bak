LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_arith.all; 
use ieee.std_logic_unsigned.all; 

entity AddressComparator_Associative is
	port (
		AddressBus 	: in std_logic_vector(24 downto 0) ;
		TagData  		: in std_logic_vector(24 downto 0) ;
		
		Hit_H			: out std_logic
	);
end ;


architecture bhvr of AddressComparator_Associative is
begin
	process(AddressBus, TagData)
	begin
		if(AddressBus = TagData) then
			Hit_H <= '1';
		else
			Hit_H <= '0' ;
		end if ;
	end process ;
end;
