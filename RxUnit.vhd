--===========================================================================--
--
--  S Y N T H E Z I A B L E    miniUART   C O R E
--
--  www.OpenCores.Org - January 2000
--  This core adheres to the GNU public license  
--
-- Design units   : miniUART core for the OCRP-1
--
-- File name      : RxUnit.vhd
--
-- Purpose        : Implements an miniUART device for communication purposes 
--                  between the OR1K processor and the Host computer through
--                  an RS-232 communication protocol.
--                  
-- Library        : uart_lib.vhd
--
-- Dependencies   : IEEE.Std_Logic_1164
--
--===========================================================================--
-------------------------------------------------------------------------------
-- Revision list
-- Version   Author                 Date                        Changes
--
-- 0.1      Ovidiu Lupas     15 January 2000                   New model
-- 2.0      Ovidiu Lupas     17 April   2000  samples counter cleared for bit 0
--        olupas@opencores.org
-- 2.1      ML               June 2003                         Made reset positive
-------------------------------------------------------------------------------
-- Description    : Implements the receive unit of the miniUART core. Samples
--                  16 times the RxD line and retain the value in the middle of
--                  the time interval. 
-------------------------------------------------------------------------------
-- Entity for Receive Unit - 9600 baudrate                                  --
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--library work;
--use work.UART_Def.all;
-------------------------------------------------------------------------------
-- Receive unit
-------------------------------------------------------------------------------
entity RxUnit is
	port (
		Clk    : in  Std_Logic;  -- system clock signal
		Reset  : in  Std_Logic;  -- Reset input
		Enable : in  Std_Logic;  -- Enable input
		RxD    : in  Std_Logic;  -- RS-232 data input
		RD     : in  Std_Logic;  -- Read data signal
		FErr   : out Std_Logic;  -- Status signal, framing error
		OErr   : out Std_Logic;  -- Status signal, overrun error
		DRdy   : out Std_Logic;  -- Status signal, data received and ready to be read
		DataIn : out Std_Logic_Vector(7 downto 0)); -- data input
end entity; --================== End of entity ==============================--
-------------------------------------------------------------------------------
-- Architecture for receive Unit
-------------------------------------------------------------------------------
architecture Behaviour of RxUnit is
	-----------------------------------------------------------------------------
	-- Signals
	-----------------------------------------------------------------------------
	signal Start     : Std_Logic;             -- Syncro signal
	signal tmpRxD    : Std_Logic;             -- RxD buffer
	signal tmpDRdy   : Std_Logic;             -- Data ready buffer
	signal outErr    : Std_Logic;             -- flag error output overrun
	signal frameErr  : Std_Logic;             -- flag frame error
	--	signal BitCnt    : Unsigned(3 downto 0);  -- count incoming serial bits
	--	signal SampleCnt : Unsigned(3 downto 0);  -- samples on one bit counter
	signal ShtReg    : Std_Logic_Vector(7 downto 0);  -- store incoming serial bits
	signal DOut      : Std_Logic_Vector(7 downto 0);  --
begin
	---------------------------------------------------------------------
	-- Receiver process
	---------------------------------------------------------------------
	RcvProc : process(Clk,Reset,Enable,RxD)
		--		variable tmpBitCnt    : Integer range 0 to 15;
		variable BitCnt    : Integer range 0 to 15;
		variable SampleCnt : Integer range 0 to 15;
	begin
		if Reset = '1' then
			BitCnt := 0;
			SampleCnt := 0;
			Start <= '0';
			tmpDRdy <= '0';
			frameErr <= '0';
			outErr <= '0';
			ShtReg <= "00000000";  --
			DOut   <= "00000000";  --
			tmpRxD <= '1';
		elsif Rising_Edge(Clk) then
			-- look for "RD", then clear input data buffer flag.
			if RD = '1' then
				tmpDRdy <= '0';      -- Data was read
			end if;
			
			-- look for "Enable" which is clock gating signal (typically CLK / 16)
			if Enable = '1' then
				if Start = '0' then -- flag for looking for first bit in serial stream
					if RxD = '0' then -- do we have the Start bit, 
						SampleCnt := SampleCnt + 1;
						Start <= '1';
					end if;
				else
					-- start = 1 else
					-- we have already received the leading edge of the start bit
					-- delay "8" to place use in middle of bit time
					if SampleCnt = 8 then  -- reads the RxD line
						tmpRxD <= RxD; -- sample data in the middle of the bit period window
						SampleCnt := SampleCnt + 1;                
					elsif SampleCnt = 15 then -- wait until end of bit to look at what we sampled
						SampleCnt := 0;
						case BitCnt is  
							when 0 =>
							if tmpRxD = '1' then -- check again for Start Bit
								Start <= '0'; -- Don't see start anymore, must have been a glitch
							else
								BitCnt := BitCnt + 1; -- good start bit count it
							end if;
							when 1|2|3|4|5|6|7|8 => -- data bits 1 through 8
							BitCnt := BitCnt + 1; -- count incoming bits
							ShtReg <= tmpRxD & ShtReg(7 downto 1); -- store incoming bits
							when 9 =>
							
							if tmpRxD = '0' then  -- stop bit expected
								frameErr <= '1';
							else
								frameErr <= '0';
							end if;
							
							if tmpDRdy = '1' then -- input buffer overrun 
								outErr <= '1';
							else
								outErr <= '0';
							end if;
							
							tmpDRdy <= '1'; -- let world know we have data byte received
							DOut <= ShtReg; -- copy received data into output register
							BitCnt := 0;
							Start <= '0';
							when others =>
							null;
						end case;
					else
						SampleCnt := SampleCnt + 1; -- counts every time we get clk                
					end if;
				end if;
			end if;
		end if;
	end process;
	
	DRdy <= tmpDRdy;
	DataIn <= DOut;
	FErr <= frameErr;
	OErr <= outErr;
	
end Behaviour; --==================== End of architecture ====================--