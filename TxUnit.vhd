--===========================================================================--
--
--  S Y N T H E Z I A B L E    miniUART   C O R E
--
--  www.OpenCores.Org - January 2000
--  This core adheres to the GNU public license  
--
-- Design units   : miniUART core for the OCRP-1
--
-- File name      : TxUnit.vhd
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
-- 0.1      Ovidiu Lupas       15 January 2000                 New model
-- 2.0      Ovidiu Lupas       17 April   2000    unnecessary variable removed
--  olupas@opencores.org
-- 2.1      ML                 June 2003                       Made reset positive
-------------------------------------------------------------------------------
-- Description    : 
-------------------------------------------------------------------------------
-- Entity for the Tx Unit                                                    --
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--library work;
--use work.Uart_Def.all;
-------------------------------------------------------------------------------
-- Transmitter unit
-------------------------------------------------------------------------------
entity TxUnit is
	port (
		Clk    : in  Std_Logic;  -- Clock signal
		reset  : in  Std_Logic;  -- Reset input
		Enable : in  Std_Logic;  -- Enable input
		Load   : in  Std_Logic;  -- Load transmit data
		TxD    : out Std_Logic;  -- RS-232 data output
		TRegE  : out Std_Logic;  -- Tx register empty
		TBufE  : out Std_Logic;  -- Tx buffer empty
		DataO  : in  Std_Logic_Vector(7 downto 0));
end entity; --================== End of entity ==============================--
-------------------------------------------------------------------------------
-- Architecture for TxUnit
-------------------------------------------------------------------------------
architecture Behaviour of TxUnit is
	-----------------------------------------------------------------------------
	-- Signals
	-----------------------------------------------------------------------------
	signal TBuff    : Std_Logic_Vector(7 downto 0); -- transmit buffer
	signal TReg     : Std_Logic_Vector(7 downto 0); -- transmit register
	signal BitCnt   : Unsigned(3 downto 0);         -- bit counter
	signal tmpTRegE : Std_Logic;                    -- 
	signal tmpTBufE : Std_Logic;                    --
begin
	-----------------------------------------------------------------------------
	-- Implements the Tx unit
	-----------------------------------------------------------------------------
	process(Clk,Reset,Enable,Load,DataO,TBuff,TReg,tmpTRegE,tmpTBufE)
		constant CntOne    : Unsigned(3 downto 0):="0001";
	begin
		if reset = '1' then
			tmpTRegE <= '1'; -- set transmit register to empty
			tmpTBufE <= '1'; -- set transmit buffer to empty
			TxD <= '1'; -- set serial transmit data line high
			BitCnt <= "0000"; -- clear bit counter
			TBuff <= "00000000"; -- clear
			TReg <= "00000000"; -- clear
		elsif Rising_Edge(Clk) then
			if Load = '1' then -- are we loading data to transmit?
				TBuff <= DataO; -- yes, transfer data to be sent into transmit buffer
				tmpTBufE <= '0'; -- make transmit buffer show full
			elsif Enable = '1' then	-- wait for serial transmission rate clock enable
				if ( tmpTBufE = '0') and (tmpTRegE = '1') then -- check if data waiting in transmit buffer
					TReg <= TBuff; -- yes, data in buffer and register was empty, copy data to transmit register
					tmpTRegE <= '0'; -- transmit register is now full
					tmpTBufE <= '1'; -- transmit buffer is now empty
				end if;
				
				if tmpTRegE = '0' then -- check if transmit register empty
					case BitCnt is
						when "0000" =>
						TxD <= '0'; -- send start bit
						BitCnt <= BitCnt + CntOne;                         
						when "0001" | "0010" | "0011" |
						"0100" | "0101" | "0110" |
						"0111" | "1000" =>
						TxD <= TReg(0); -- send bit from transmit register
						TReg <= '1' & TReg(7 downto 1); -- shift bits
						BitCnt <= BitCnt + CntOne;
						when "1001" =>
						TxD <= '1'; -- send stop bit
						TReg <= '1' & TReg(7 downto 1);
						BitCnt <= "0000";	-- reset bit count
						tmpTRegE <= '1'; -- transmit register is now empty
						when others => null;
					end case;
				end if;
			end if;
		end if;
	end process;
	
	TRegE <= tmpTRegE;
	TBufE <= tmpTBufE;
end Behaviour; --=================== End of architecture ====================--