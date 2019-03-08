---------------------------------------------------------------------------------------
-- Simple DRAM controller for the DE1_SoC board. Assumes Clock of 90Mhz for timing
-- or 11.1ns per clock
--
-- Copyright PJ Davies June 2017
---------------------------------------------------------------------------------------


LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;


entity CacheEnabledDramController is
	Port (
		Clock	 			: in std_logic ;									-- used to drive the state machine- stat changes occur on positive edge
		Reset_L    		: in std_logic ;     							-- active low reset 
		Address    		: in std_logic_vector(31 downto 0);  		-- address bus from 68000
		DataIn     		: in std_logic_vector(15 downto 0); 		-- data bus in from 68000
		UDS_L	   		: in std_logic ;									-- active low signal driven by 68000 when 68000 transferring data over data bit 15-8
		LDS_L	   		: in std_logic; 									-- active low signal driven by 68000 when 68000 transferring data over data bit 7-0
		DramSelect_L 	: in std_logic;     								-- active low signal indicating dram is being addressed by 68000
		WE_L 				: in std_logic;  									-- active low write signal, otherwise assumed to be read
		AS_L				: in std_logic;
		
		SDram_CKE_H   	: out std_logic;									-- active high clock enable for dram chip
		SDram_CS_L   	: out std_logic;									-- active low chip select for dram chip
		SDram_RAS_L   	: out std_logic;									-- active low RAS select for dram chip
		SDram_CAS_L   	: out std_logic;									-- active low CAS select for dram chip		
		SDram_WE_L   	: out std_logic;									-- active low Write enable for dram chip
		SDram_Addr   	: out std_logic_vector(12 downto 0);		-- 13 bit address bus dram chip	
		SDram_BA   		: out std_logic_vector(1 downto 0) ;		-- 2 bit bank address
		SDram_DQ   		: inout std_logic_vector(15 downto 0);  	-- 16 bit bi-directional data lines to dram chip
		Dtack_L			: out std_logic ;									-- Dtack back to CPU at end of bus cycle
		ResetOut_L		: out std_logic 									-- reset out to the CPU
	);
end ;

architecture bhvr of CacheEnabledDramController is
	-- command constants for the Dram chip (combinations of signals)
	
	-- CKE, CS, Ras, Cas, Write
	
	constant PoweringUp 		    	: std_logic_vector(4 downto 0) := "00000" ;		-- take CKE & CS low during power up phase, address and bank address = dont'care
	constant DeviceDeselect 		: std_logic_vector(4 downto 0) := "11111" ;		-- address and bank address = dont'care
	constant NOP 						: std_logic_vector(4 downto 0) := "10111" ;		-- address and bank address = dont'care
	constant BurstStop				: std_logic_vector(4 downto 0) := "10110" ;		-- address and bank address = dont'care
	constant ReadOnly 				: std_logic_vector(4 downto 0) := "10101" ;		-- A10 should be logic 0, BA0, BA1 should be set to a value, other addreses = value
	constant ReadAutoPrecharge 	: std_logic_vector(4 downto 0) := "10101" ;		-- A10 should be logic 1, BA0, BA1 should be set to a value, other addreses = value
	constant WriteOnly 				: std_logic_vector(4 downto 0) := "10100" ;		-- A10 should be logic 0, BA0, BA1 should be set to a value, other addreses = value
	constant WriteAutoPrecharge 	: std_logic_vector(4 downto 0) := "10100" ;		-- A10 should be logic 1, BA0, BA1 should be set to a value, other addreses = value
	constant AutoRefresh	 			: std_logic_vector(4 downto 0) := "10001" ;

	constant BankActivate			: std_logic_vector(4 downto 0) := "10011" ;		-- BA0, BA1 should be set to a value, address A11-0 should be value
	constant PrechargeSelectBank	: std_logic_vector(4 downto 0) := "10010" ;		-- A10 should be logic 0, BA0, BA1 should be set to a value, other addreses = don't care
	constant PrechargeAllBanks		: std_logic_vector(4 downto 0) := "10010" ;		-- A10 should be logic 1, BA0, BA1 are dont'care, other addreses = don't care
	constant ModeRegisterSet		: std_logic_vector(4 downto 0) := "10000" ; 		-- A10=0, BA1=0, BA0=0, Address = don't care
	constant ExtModeRegisterSet	: std_logic_vector(4 downto 0) := "10000" ; 		-- A10=0, BA1=1, BA0=0, Address = value
	
	Signal  	Command 					: std_logic_vector(4 downto 0) ;						-- 5 bit signal containing Dram_CKE_H, SDram_CS_L, SDram_RAS_L, SDram_CAS_L, SDram_WE_L
	Signal  	CurrentState 			: std_logic_vector(5 downto 0);						-- holds the current state of the dram controller
	Signal  	NextState 				: std_logic_vector(5 downto 0);						-- holds the next state of the dram controller

	Signal	Timer 					: std_logic_vector(15 downto 0) ;					-- 16 bit timer value
	Signal	TimerValue 				: std_logic_vector(15 downto 0) ;					-- 16 bit timer preload value
	Signal	TimerLoad_H 			: std_logic ;												-- logic 1 to load Timer on next clock
	Signal  	TimerDone_H 			: std_logic ;												-- set to logic 1 when timer reaches 0

	Signal	StateTimer 				: std_logic_vector(3 downto 0) ;						-- 3 bit timer value
	Signal	StateTimerValue 		: std_logic_vector(3 downto 0) ;						-- 3 bit timer preload value
	Signal	StateTimerLoad_H 		: std_logic ;												-- logic 1 to load Timer on next clock
	Signal  	StateTimerDone_H 		: std_logic ;												-- set to logic 1 when timer reaches 0

	Signal	RefreshTimer 			: std_logic_vector(15 downto 0) ;					-- 16 bit refresh timer value
	Signal	RefreshTimerValue 	: std_logic_vector(15 downto 0) ;					-- 16 bit refresh timer preload value
	Signal	RefreshTimerLoad_H 	: std_logic ;												-- logic 1 to load refresh timer on next clock
	Signal  	RefreshTimerDone_H 	: std_logic ;												-- set to 1 when refresh timer reaches 0

	Signal  	BankAddress 			: std_logic_vector(1 downto 0) ;
	Signal  	DramAddress 			: std_logic_vector(12 downto 0) ;

	Signal  	SDramWriteData			: std_logic_vector(15 downto 0) ;
	Signal  	FPGAWritingtoSDram_H	: std_logic ;												-- When '1' enables FPGA data out lines leading to SDRAM to allow writing, otherwise they are set to Tri-State "Z"
	Signal  	CPU_Dtack_L  			: std_logic ;												-- Dtack back to CPU
	Signal  	CPUReset_L				: std_logic ;
	
	-- Dram controller states after power on and/or reset
	-- most dram chip data sheets imply only 2 auto refresh commands need be issued due power up, but
	-- Some chips made by companies like Zentel require 8 or more auto refresh commands, so we will use 8
	
-------------------------------------------------------------------------------------------------------------------------------------------------
-- Initialisation States
-------------------------------------------------------------------------------------------------------------------------------------------------
	constant InitialisingState					: std_logic_vector(5 downto 0) := "000000" ;			-- power on initialising state
	constant WaitingForPowerUpState			: std_logic_vector(5 downto 0) := "000001" ;			-- waiting for power up state to complete
	constant IssueFirstNOP						: std_logic_vector(5 downto 0) := "000010" ;			-- issuing 1st NOP after power up
	constant PrechargingAllBanks				: std_logic_vector(5 downto 0) := "000011" ;			-- issuing precharge all command after power up
	constant PreChargeNOP1						: std_logic_vector(5 downto 0) := "000100" ;			-- issuing precharge all command after power up
	constant PreChargeNOP2						: std_logic_vector(5 downto 0) := "000101" ;	
	constant PreChargeNOP3						: std_logic_vector(5 downto 0) := "000110" ;	
	constant InitialAutoRefreshSequence		: std_logic_vector(5 downto 0) := "000111" ;			-- issuing first auto refresh command after power up
	constant RefreshWait1						: std_logic_vector(5 downto 0) := "001000" ;			-- 1 clock period delay before second auto refresh
	constant RefreshWait2						: std_logic_vector(5 downto 0) := "001001" ;			-- 1 clock period delay after second auto refresh
	constant LoadModeRegister    				: std_logic_vector(5 downto 0) := "001010" ;			-- loading mode register in DRam chip
	constant LoadModeRegisterWait1NOP		: std_logic_vector(5 downto 0) := "001011" ;	
	constant Idle									: std_logic_vector(5 downto 0) := "001100" ;			-- main waiting state
-------------------------------------------------------------------------------------------------------------------------------------------------
-- Refreshing States
-------------------------------------------------------------------------------------------------------------------------------------------------	
	constant DoAutoRefresh						: std_logic_vector(5 downto 0) := "001101" ;
	constant PrechargeRefreshWait1			: std_logic_vector(5 downto 0) := "001110" ;
	constant PrechargeRefreshWait2			: std_logic_vector(5 downto 0) := "001111" ;
	constant RefreshDram							: std_logic_vector(5 downto 0) := "010000" ;
	constant RefreshDramWait1					: std_logic_vector(5 downto 0) := "010001" ;

-------------------------------------------------------------------------------------------------------------------------------------------------
-- 68000 access States
-------------------------------------------------------------------------------------------------------------------------------------------------		
	constant IssueRAS								: std_logic_vector(5 downto 0) := "010010" ;
	constant IssueCASWait1						: std_logic_vector(5 downto 0) := "010011" ;
	constant IssueCASWait2						: std_logic_vector(5 downto 0) := "010100" ;
	constant IssueCASWait3						: std_logic_vector(5 downto 0) := "010101" ;
	constant WaitForDataStrobes				: std_logic_vector(5 downto 0) := "010110" ;
	
	-- Read States
	
	constant DramRead								: std_logic_vector(5 downto 0) := "010111" ;
	constant DramReadWait						: std_logic_vector(5 downto 0) := "011000" ;
	
	-- Write States
	
	constant DramWrite							: std_logic_vector(5 downto 0) := "011001" ;
	constant DramWriteWait						: std_logic_vector(5 downto 0) := "011010" ;	

	-- End of Read or Write states
	
	constant WaitTimeTrp							: std_logic_vector(5 downto 0) := "011011" ;
	constant Acknowledge							: std_logic_vector(5 downto 0) := "011100" ;
	
Begin
	
----------------------------------------------------------------------------------------------------------------------------------------------------------
-- General Timer for timing and counting things: Loadable and counts down on each clock then produced a TimerDone signal and stops counting
----------------------------------------------------------------------------------------------------------------------------------------------------------

	Process(Clock, TimerLoad_H, Timer)
	BEGIN
		TimerDone_H <= '0' ;							-- default is not done
		if(rising_edge(Clock)) then
			if(TimerLoad_H = '1') then				-- if we get the signal from another process to load the timer
				Timer  <= TimerValue ;				-- Preload timer
			elsif(Timer /= 0) then					-- otherwise, provided timer has not already counted down to 0, on the next rising edge of the clock		
				Timer <= Timer - 1 ;					-- subtract 1 from the timer value
			end if ;
		end if;
			
		if(Timer = 0) then							-- if timer has counted down to 0
			TimerDone_H <= '1' ;						-- output '1' to indicate time has elapsed
		end if ;
	END Process;			

----------------------------------------------------------------------------------------------------------------------------------------------------------
-- Refresh Timer: Loadable and counts down on each clock then produces a RefreshTimerDone signal and stops counting
----------------------------------------------------------------------------------------------------------------------------------------------------------

	Process(Clock, RefreshTimerLoad_H, RefreshTimer)
	BEGIN
		RefreshTimerDone_H <= '0' ;							-- default is not done
		if(rising_edge(Clock)) then
			if(RefreshTimerLoad_H = '1') then				-- if we get the signal from another process to load the timer
				RefreshTimer  <= RefreshTimerValue ;		-- Preload timer
			elsif(RefreshTimer /= 0) then						-- otherwise, provided timer has not already counted down to 0, on the next rising edge of the clock		
				RefreshTimer <= RefreshTimer - 1 ;			-- subtract 1 from the timer value
			end if ;
		end if;
			
		if(RefreshTimer = 0) then								-- if timer has counted down to 0
			RefreshTimerDone_H <= '1' ;						-- output '1' to indicate time has elapsed
		end if ;
	END Process;			
	
	
----------------------------------------------------------------------------------------------------------------------------------------------------------
-- State Timer for timing clock cycles to build up delays etc
----------------------------------------------------------------------------------------------------------------------------------------------------------

	Process(Clock, StateTimerLoad_H, StateTimer)
	BEGIN
		StateTimerDone_H <= '0' ;							-- default is not done
		if(rising_edge(Clock)) then
			if(StateTimerLoad_H = '1') then				-- if we get the signal from another process to load the timer
				StateTimer  <= StateTimerValue ;			-- Preload timer
			elsif(StateTimer /= 0) then					-- otherwise, provided timer has not already counted down to 0, on the next rising edge of the clock		
				StateTimer <= StateTimer - 1 ;			-- subtract 1 from the timer value
			end if ;
		end if;
			
		if(StateTimer = 0) then								-- if timer has counted down to 0
			StateTimerDone_H <= '1' ;						-- output '1' to indicate time has elapsed
		end if ;
	END Process;		
	
---------------------------------------------------------------------------------------------------------------------
-- concurrent process state registers
-- this process RECORDS the current state of the system.
----------------------------------------------------------------------------------------------------------------------

   process(Reset_L, Clock, NextState, FPGAWritingtoSDram_H)
	begin
		if(Reset_L = '0') then
			CurrentState 		<= InitialisingState ;
			
		elsif (rising_edge(Clock)) then						-- state can change only on low-to-high transition of clock
			CurrentState 		<= NextState;		
			SDram_CKE_H 		<= Command(4);
			SDram_CS_L  		<= Command(3);
			SDram_RAS_L 		<= Command(2);
			SDram_CAS_L 		<= Command(1);
			SDram_WE_L 		 	<= Command(0);
			SDram_Addr  		<= DramAddress;
			SDram_BA   			<= BankAddress;
	
			Dtack_L 				<= CPU_Dtack_L ;
			ResetOut_L 			<= CPUReset_L ;
			
			if(FPGAWritingtoSDram_H = '1') then				-- if CPU is doing a write, we need to turn on the FPGA data out lines to the SDRam and present Dram with CPU data 
				SDram_DQ			<= SDramWriteData ;
			else
				SDram_DQ			<= "ZZZZZZZZZZZZZZZZ" ;		-- otherwise tri-state the FPGA data output lines to the SDRAM for anything other than writing to it
			end if ;
		end if;
	end process;	
	
---------------------------------------------------------------------------------------------------------------------
-- Next state and output logic
----------------------------------------------------------------------------------------------------------------------	
	
	process(Clock, Reset_L, Address, DataIn, AS_L, UDS_L, LDS_L, DramSelect_L, WE_L, CurrentState, TimerDone_H, RefreshTimerDone_H, Timer, StateTimerDone_H)
	begin
	-- start with default values for everything and override as necessary, so we do not infer storage for signals inside this process
	
		Command 						<= NOP ;							-- tell Dram chip to do nothing
		NextState 					<= IDLE ;

		TimerValue 					<= "0000000000000000";		-- no timer value 
		StateTimerValue			<= "0000";						-- no timer value 
		RefreshTimerValue 		<= "0000000000000000" ;		-- no timer value

		TimerLoad_H 				<= '0';							-- no load
		StateTimerLoad_H 			<= '0';							-- no load		
		RefreshTimerLoad_H 		<= '0' ;							-- no Load

		DramAddress 				<= "0000000000000" ;
		BankAddress 				<= "00" ;

		CPU_Dtack_L 				<= '1' ;							-- acknowledged
		SDramWriteData 			<= "0000000000000000" ;
		CPUReset_L 					<= '0' ;							-- default is reset to CPU
		FPGAWritingtoSDram_H 	<= '0' ;							-- default is to tri-state the FPGA data lines leading to bi-directional SDRam data lines, i.e. assume a read operation

		if(CurrentState = InitialisingState ) then
			TimerValue 				<= "0000000000001000";					-- decimal 5000 = 1 0011 1000 1000 equivalent to a value of 100us at 50Mhz clock
			TimerLoad_H 			<= '1' ;										-- on next edge of clock timer will be loaded and start to time out
			Command 					<= PoweringUp ;							-- clock enable must be low (disabled)
			NextState 				<= WaitingForPowerUpState ;			-- on next edge move to this state
		
		elsif(CurrentState = WaitingForPowerUpState) then
			Command 					<= PoweringUp ;							-- no clock enable or CS while witing for timer
			
			if(TimerDone_H = '1') then
				NextState 			<= IssueFirstNOP ;						-- waited for power delay of at least 100us, now take CKE and CS to active and issue a NOP command
			else
				NextState 			<= WaitingForPowerUpState ;			-- stay here until power up time delay finished
			end if ;
			
-- Powering up phase complete, now issue NOP command			
		
		elsif(CurrentState = IssueFirstNOP) then	 						-- issue a valid NOP
			Command 					<= NOP ;										-- send a valid NOP command to to the dram chip
			NextState 				<= PrechargingAllBanks;

-- now issue a Pre charge all banks command			
			
		elsif(CurrentState = PrechargingAllBanks) then	  				-- issue a precharge to all banks
			Command 					<= PrechargeAllBanks ;
			DRamAddress 			<= "0010000000000" ;						-- A10 has to be logic 1 to precharge all banks
			NextState 				<= PreChargeNOP1 ;						-- make sure 1 NOP after prechargeallbanks before first refresh	
			
-- have to wait at least 18ns after precharge before issuing an autorefresh command. At 11.1ns per clock this means at least 2 clocks, but let's make it 3
	
		elsif(CurrentState = PreChargeNOP1) then	  						-- issue 3 NOPs after precharge before 1st autorefresh
			Command 					<= NOP ;
			NextState 				<= PreChargeNOP2 ;						
			
		elsif(CurrentState = PreChargeNOP2) then
			Command 					<= NOP ;
			NextState 				<= PreChargeNOP3 ;

		elsif(CurrentState = PreChargeNOP3) then	  						
			Command 					<= NOP ;
			TimerValue 				<= X"0044";									-- Load timer with deimal 68 which means initial autorefresh sequence will issue 8 auto refreshes of 8 states
			TimerLoad_H 			<= '1' ;										-- on next edge of clock timer will be loaded and start to time out
			NextState 				<= InitialAutoRefreshSequence ;		-- Now issue 1st refresh
						
-- start of a loop using the timer where we generate 8 autorefresh commands to the SDRAM during power on/reset with 8 NOP time delays between each one
-- The chip on the DE1 states that it requries at least 2 autorefreshes (but some chips need 8), so that's at least > 68 clocks at 8 by 8 clocks per autorefresh
			
		elsif(CurrentState = InitialAutoRefreshSequence) then	  		-- issue an autorefresh command
			Command 					<= AutoRefresh ;
			NextState 				<= RefreshWait1 ;
			StateTimerLoad_H		<= '1';
			StateTimerValue		<= b"0110" ;								-- 6 for a total of 8 NOPs between refreshes
		
		elsif(CurrentState = RefreshWait1) then	  						-- State Timer loaded here and decrements on each risging edge of clock
			Command 					<= NOP ;
			NextState 				<= RefreshWait1 ;							-- stay here until state timer times out
			
			if(StateTimerDone_H = '1') then									-- until timer times out
				NextState <= RefreshWait2 ;
			end if ;
			
		elsif(CurrentState = RefreshWait2) then
			Command 					<= NOP ;										-- 8th NOP command
			
			if(TimerDone_H = '1') then
				NextState 			<= LoadModeRegister ;					-- DONE power on REFRESHING - go and load mode register
			else
				NextState 			<= InitialAutoRefreshSequence ;		-- OTHERWISE keep auto refreshing
			end if ;
		
----------------------------------------------------------------------------------------
-- now issue the load mode register command
----------------------------------------------------------------------------------------	
		elsif(CurrentState = LoadModeRegister) then	  						-- load sdram mode register
			Command 					<= ModeRegisterSet ;
			
			DramAddress 			<= b"000_1_00_010_0_011"	;				-- 13 bits of address A12 - A0: Write burst=1, read burst=8, sequential access, cas latency=2
			BankAddress 			<= "00"	;
			NextState 				<= LoadModeRegisterWait1NOP ;

		elsif(CurrentState = LoadModeRegisterWait1NOP) then	  				
			Command 					<= NOP ;
--			RefreshTimerValue 	<= b"0000_0001_0101_0010";					-- 7.5us delay for refreshing = 338 clocks at 20.0ns per clock (50 Mhz)
			RefreshTimerValue 	<= b"0000_0010_1010_0011";					-- 7.5us delay for refreshing = 675 clocks at 11.1ns per clock (90 Mhz)
			RefreshTimerLoad_H 	<= '1' ;											-- preload and start refresh timer
			NextState 				<= IDLE ;			
						
--------------------------------------------------------------------------------------------------------------------------------------------
-- States associated with refreshing	
-- Issue Pre-charge All Banks Command Prior to Refresh
----------------------------------------------------------------------------------------------------------------------------------
		elsif(CurrentState = DoAutoRefresh) then	  							-- issue three NOPs between auto refresh commands (just to be safe)
			Command 					<= PrechargeAllBanks ;
			CPUReset_L 				<= '1' ;
			DRamAddress 			<= "0010000000000" ;							-- A10 has to be logic 1 to precharge all banks
--			RefreshTimerValue 	<= b"0000_0001_0101_0010";					-- 7.5us delay for refreshing = 338 clocks at 20.0ns per clock (50 Mhz)
			RefreshTimerValue 	<= b"0000_0010_1010_0011";					-- 7.5us delay for refreshing = 675 clocks at 11.1ns per clock (90 Mhz)
			RefreshTimerLoad_H 	<= '1' ;											-- preload and start refresh timer
			NextState 				<= PrechargeRefreshWait1	 ;				-- wait 1 clock after prechage before issuing refresh command

------------------------------------------------------------------------------------------------------------------------------------
-- Wait 3 clocks after after pre-charge command before issuing Refresh command. minimum is 18ns with 3 clock @ 90 Mhz this gives 33ns
------------------------------------------------------------------------------------------------------------------------------------
			
		elsif(CurrentState = PrechargeRefreshWait1) then	  				
			Command 					<= NOP ;
			CPUReset_L 				<= '1' ;	
			NextState 				<= PrechargeRefreshWait2 ;	
			
		elsif(CurrentState = PrechargeRefreshWait2) then	  				
			Command 					<= NOP ;
			CPUReset_L 				<= '1' ;	
			NextState 				<= RefreshDram ;

		elsif(CurrentState = RefreshDram) then	  								-- issue auto-refresh command to dram 3 clock after precharge all bbanks command
			Command 					<= AutoRefresh ;
			CPUReset_L 				<= '1' ;	
			NextState 				<= RefreshDramWait1 ;

			StateTimerLoad_H		<= '1';
			StateTimerValue		<= b"0101";										-- 5 for delay of 7 NOPs

----------------------------------------------------------------------------------------------------------------------------------
-- Wait at least 60ns after Auto-refresh command before returning to idle state, i.e. 7 NOP's at 90Mhz = 11.1 ns per clock
----------------------------------------------------------------------------------------------------------------------------------

		elsif(CurrentState = RefreshDramWait1) then				-- state timer loaded with value here and decrements with each rising egde of clock
			Command 					<= NOP ;
			CPUReset_L 				<= '1' ;
			
			NextState 				<= RefreshDramWait1 ;				
			if(StateTimerDone_H = '1') then
				NextState <= IDLE;
			end if ;
			
					
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Main IDLE state: Enter here after initialisation and return to here after every action, e.g. refreshing, reading, writing states	
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
		elsif(CurrentState = IDLE) then	  								-- if nothing happening				
			Command 					<= NOP ;									-- issue No operations to the Dram
			CPUReset_L 				<= '1' ;									-- no cpu reset
			
			if(RefreshTimerDone_H = '1') then							-- if it's time to do an auto refresh
				NextState 			<= DoAutoRefresh ;					-- go start a refresh operation
			
			elsif (DramSelect_L = '0' and AS_L = '0') then			-- if 68000 trying to access the dram not sure if it is read or write at the moment
				Command 				<= BankActivate;						-- Activate the required bank with a RAS
				DramAddress			<= Address(23 downto 11);			-- supply a 13 bit ROW address to Dram
				BankAddress			<= Address(25 downto 24) ;			-- supply a 2 bit BANK address to dram
				
				if(WE_L = '1')	then											-- if it is a read then issue CAS (but wait for 1 clock to meet 18ns min time between activate and read/write command)
					NextState 		<= IssueCASWait1 ;
				else
					NextState 		<= WaitForDataStrobes;				-- otherwise assume write and wait for data strobes before issueing CAS/WE to dram
				end if ;
			else
				NextState 			<= IDLE ;
			end if ;		
				
--------------------------------------------------------------------------------------------------------------------------------------------
-- States associated with Memory Reads
--------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
-- Wait at least 18ns after ACTIVATE command before issuing READ command, i.e. at least 3 clocks at 90Mhz to allow a margin of skew timing
----------------------------------------------------------------------------------------------------------------------------------
		elsif(CurrentState = IssueCASWait1) then										-- enter here when it is a read cycle, or if it is a (data strobes have already been asserted)
			Command 					<= NOP ;
			CPUReset_L 				<= '1' ;
			
			NextState 				<= IssueCASWait2 ;	
			
		elsif(CurrentState = IssueCASWait2) then										-- enter here when it is a read cycle, or if it is a (data strobes have already been asserted)
			Command 					<= NOP ;
			CPUReset_L 				<= '1' ;
			
			NextState 				<= IssueCASWait3 ;				
			
		elsif(CurrentState = IssueCASWait3) then									-- enter here when it is a read cycle, or if it is a (data strobes have already been asserted)
			Command 					<= ReadAutoPrecharge ;						-- MUST be a read cycle so issue read with pre-charge command
			CPUReset_L 				<= '1' ;											-- no CPU reset

			--	No Dtack Yet
			DramAddress 			<= "001" & Address(10 downto 1) ;		-- issue a 10 bit COLUMN address and set A10 on sdram = 1 to be a precharge command
			BankAddress				<= Address(25 downto 24) ;					-- supply a 2 bit BANK address
			
			TimerLoad_H 			<= '1' ;											-- start the timer for 2 clock cycle CAS LATENCY
			TimerValue 				<= "0000000000000010" ;					
			
			NextState 				<= DramReadWait ;		

-- wait 2 clocks for 1st item of data
			
		elsif(CurrentState = DramReadWait) then				-- waiting for CAS latency to expire (2 clock cycles)
			Command 					<= NOP ;							-- issue NOP while waiting
			CPUReset_L 				<= '1' ;							-- no CPU reset
			
  			CPU_Dtack_L 			<= '0';							-- give 68000 notification that it will get data and can terminate the read operation
			
    		if(TimerDone_H = '1') then								-- when CAS latency expires
    			NextState 			<= Acknowledge ;				-- got data, must  wait time Trp (20ns) so 2 states at 11.1 ns per state (@90Mhz), but 68000 will slow this even further
    		else
    			NextState 			<= DramReadWait ;				-- stay here until CAS latency up
    		end if ;
    	
--------------------------------------------------------------------------------------------------------------------------------------------
-- State associated with issuing CAS during Memory Write: Has to be at least 18ns between ACTIVATE and WRITE commands i.e. 3clocks at 90Mhz
--------------------------------------------------------------------------------------------------------------------------------------------
		elsif(CurrentState = WaitForDataStrobes) then	 					-- ONLY end up here if 68k is writing to dram
			CPUReset_L  			<= '1' ;											-- no CPU reset
			Command 					<= NOP ;											-- issue NOP's to the Dram
			
			-- wait for 68k to decide/indicate the width of the data write upper or lower byte or 16 bit word (i.e both bytes)
			
			if( UDS_L = '0' or LDS_L = '0') then								-- we have to wait for either data strobes (or both) to go low before issuing CAS/WE
				Command 				<= WriteAutoPrecharge ;						-- issue the write
				CPU_Dtack_L 		<= '0' ;											-- issue a dtack immediately for a write with no wait states
				FPGAWritingtoSDram_H <= '1'	;									-- assume a write to sdram so turn on FPGA output buffers to drive data into SDRam
				SDRamWriteData 	<= DataIn ;										-- present 68000 data out to dram data pins
				DramAddress 		<= "001" & Address(10 downto 1) ;		-- issue a 10 bit COLUMN address and set A10 on sdram = 1 to be a precharge command
				BankAddress			<= Address(25 downto 24) ;					-- supply a 2 bit BANK address
				NextState 			<= DramWriteWait ;							-- wait for the dram 30ns after write command before next activate command
			else
				NextState 			<= WaitForDataStrobes ;						-- otherwise stay here until 68000 data strobes activate, cannot issue write to dram until then
			end if ;		
			
		elsif(CurrentState = DramWriteWait) then
			Command 						<= NOP ;										-- issue NOP
			CPUReset_L 					<= '1' ;										-- no CPU reset
			
			CPU_Dtack_L 				<= '0';										-- give 68000 advance warning that it can begin to terminate the bus cycle
			FPGAWritingtoSDram_H 	<= '1'	;									-- assume a write to sdram so turn on FPGA output buffers to drive data into SDRam
			SDRamWriteData 			<= DataIn ;
   		NextState 					<= Acknowledge ;							-- got data wait time Trp (20ns) so 1 state at 20ns per state (@50Mhz)
    		
--------------------------------------------------------------------------------------------------------------------------------------------
-- States associated with Memory Access Termination
--------------------------------------------------------------------------------------------------------------------------------------------
    		
  		elsif(CurrentState = Acknowledge) then	  								-- now wait for 68000 to terminate its access to memory
			Command 					<= NOP ;											-- issue NOP
			CPUReset_L 				<= '1' ;											-- no reset to CPU
			
			if (UDS_L = '0' or LDS_L = '0') then								-- if 68000 still trying to access the dram
				CPU_Dtack_L 		<= '0';											-- keep issuing DTACK
				NextState 			<= Acknowledge;								-- stay in this state until 68000 terminates memory access
			else
				NextState 			<= IDLE ;										-- return to the idle state
			end if ;
		end if ;
	end process;
end ;