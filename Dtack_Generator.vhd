LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_arith.all; 
use ieee.std_logic_unsigned.all; 

entity Dtack_Generator is
	Port (
		AS_L						: in std_logic ;  	-- address strobe
		DramSelect_H 			: in std_logic ;		-- from address decoder
	   DramDtack_L 			: in std_logic ;		-- from Dram controller
	   DtackOut_L 				: out std_logic ; 	-- to CPU
		
		CanBusSelect_H			: in std_logic ;		-- from address decoder
		CanBusDtack_L			: in std_logic 		-- from Canbus controllers

	);
end ;


architecture bhvr of Dtack_Generator is
Begin
	process(AS_L, DramSelect_H, DramDtack_L, CanBusSelect_H, CanBusDtack_L)
	begin
		
		DtackOut_L <= '1' ;					-- default is no Dtack IN BETWEEN bus cycles (when AS_L = '1')
		
		-- however in VHDL we can override the above "default output" with other outputs
		-- e.g. if the address decoder is telling us that the CPU is accessing say some slow IO device (e.g. CanBusSelect_H above is logic 1), then we could delay
		-- producing a Dtack back to the CPU until sometime later (i.e. introduce wait states)
		--
		-- This would be done by getting the canbus controller to produce its own dtack (e.g. CanBusDtack_L above) when it it is ready
		-- when this occurs we could take that CanBusDtack signals and use that to provide the dtack back the 68k
		-- it could provide the DramDtack_L input that could be used to provide rthe 68k Dtack
				
		if(AS_L = '0')	then 					-- When AS active 68k is accessing something so we get to produce a Dtack here if we chose
			DtackOut_L <= '0' ;				-- assume for the moment everything is fast enough, nothing needs wait states so we set DtackOut_L to low as soon as we see AS go low
													-- this will be the default that covers things like on chip RAM/ROM and IO devices like LEDs, switches, graphics, DMA etc
													-- this default may or may not work for off chip devices like Flash, Dram etc
			
			--
			-- if however the memory or IO is known to be slow and thus wait states ARE needed, i.e. we cannot just produce the dtack immediately as above
			-- then we can override the above DtackOut_L <= '0' statement with another based on an IF test
			-- e.g. if CanBus is being selected then take the dtack signal produced from the CanBus controller and give that to the 68k
			-- However you only need to override the above default DtackOut_L <= '0' when you KNOW you need to introduce wait states
			-- For devices that are fast enough NOT to need wait states, the above default will work
			-- IMPORTANT - if you modify this file, realise that this circuit produces Dtack for ALL devices/chips in the system so make sure it still works for those chips after you modify this circuit
			-- If your system hangs after modifications, run the simulator and check whether Dtack is being produced with each access. If not - you've screwed up
			--
			
			-- here's an example that shows how we override the default DtackOut_L <= '0' above so that DtackOut_L is produced when we want (i.e. not be default)
			-- in this example the dtack generator looks at the address decoder output and if the 68k is accessing the CanBus device (i.e. CanBusSelect_H equals '1')
			-- we generate DtackOut_L as a copy of the signal produced by the CanBus controller (i.e. the signal CanBusDtack_L) which comes from the CanBus controller
			-- we can add extra 'if' tests to cover all the other kinds of things that may need a dtack other than the default above e.g. dram controller etc
			
			if(CanBusSelect_H = '1')	then		-- if canbus is being selected and for example it needed wait states
				DtackOut_L <= CanBusDtack_L;		-- copy the dtack signal from the can controller and give this as the dtack to the 68k
			end if ;
			
			if(DramSelect_H = '1')	then		-- if dram is being selected
				DtackOut_L <= DramSelect_H;		-- copy the dtack signal from the address decoder and give this as the dtack to the 68k
			end if ;
			
		end if ;	
	end process ;
END ;

