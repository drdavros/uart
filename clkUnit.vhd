--===========================================================================--
--
--  S Y N T H E Z I A B L E    miniUART   C O R E
--
--  www.OpenCores.Org - January 2000
--  This core adheres to the GNU public license  

-- Design units   : miniUART core for the OCRP-1
--
-- File name      : clkUnit.vhd
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
-- Version   Author              Date                Changes
--
-- 1.0     Ovidiu Lupas      15 January 2000         New model
-- 1.1     Ovidiu Lupas      28 May 2000     EnableRx/EnableTx ratio corrected
--      olupas@opencores.org 
-- 2.0      ML                  June 2003           Made reset signal positive
-- 2.1      ML                  Dec 2016            Made reset asynchronous
-- 3.0      ML                  Mar 2017            Added generic to handle baud rate
--                                                  changes caused by different oscillators
-------------------------------------------------------------------------------
-- Description    : Generates the Baud clock and enable signals for RX & TX
--                  units. 
-------------------------------------------------------------------------------
-- Entity for Baud rate generator Unit - 9600 baudrate                       --
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--library work;
--use work.UART_Def.all;
-------------------------------------------------------------------------------
-- Baud rate generator
-------------------------------------------------------------------------------
entity ClkUnit is
    generic (
        osc_freq : integer
        );
    port (
        SysClk   : in  Std_Logic;  -- System Clock
        EnableRx : out Std_Logic;  -- Control signal
        EnableTx : out Std_Logic;  -- Control signal
        reset    : in  Std_Logic); -- Reset input
end entity;
-------------------------------------------------------------------------------
-- Architecture for Baud rate generator Unit
-------------------------------------------------------------------------------
architecture Behaviour of ClkUnit is
    -- 153600 = 9600 Baud
    -- 307200 = 19.2K Baud
    -- number = 16 times baud rate desired
    constant    DIVIDER     : integer := integer(osc_freq/153600);
    signal      tmpEnRX     : Std_Logic;
    signal      tmpEnTX     : Std_Logic;
begin
    -----------------------------------------------------------------------------
    -- Divides the system clock
    --
    -- you need something 16x higher so
    -- for 9600 baud we need 153,600 Hz
    -- for 19.2K baud we need 307,200 Hz
    --
    -- 33.5 Mhz by 218 = 153669
    -- 25 MHz by 163 = 153374
    --
    -- 24 MHz by 156 = 153846
    --
    -- 12 MHz by 78 = 153846
    --
    -- 66 MHz / 33 MHz / 16.5 MHz
    -- 16.5 MHz by 107 = 154205
    --
    -----------------------------------------------------------------------------
    DivClk26 : process(SysClk,reset)
        variable Cnt26  : integer range 0 to 255;
    begin
        if reset = '1' then
            Cnt26 := 0;
            tmpEnRx <= '0';
        elsif Rising_Edge(SysClk) then
            Cnt26 := Cnt26 + 1;
            if Cnt26 < DIVIDER then
                tmpEnRx <= '0';
            else
                Cnt26 := 0;
                tmpEnRx <= '1';
            end if;
            
            -- HDL compiler does not like this, wants locally static
            --            case Cnt26 is
            --                --when 218 => -- unit for 9600 @ 33.5 MHz
            --                --when 163 => -- unit for 9600 @ 25 MHz (Xilinx)
            --                --when 156 => -- unit for 9600 @ 24 MHz
            --                --when 78 => -- unit for 9600 @ 12 MHz (ProASIC)
            --                --when 107 => -- unit for 9600 @ 16.5 MHz (V2 1000)
            --                --when 10 => -- for debug test purposes, speeds up simulations
            --                when DIVIDER =>
            --                    Cnt26 := 0;
            --                tmpEnRx <= '1';
            --                when others =>
            --                tmpEnRx <= '0';
            --            end case;
            
        end if;
    end process;
    
    EnableRX <= tmpEnRX;
    
    -----------------------------------------------------------------------------
    -- Provides the EnableRX signal, at ~ 155 KHz
    -- divide by 10
    -- divide the already reduced system clock by 10
    -----------------------------------------------------------------------------
    --	DivClk10 : process(SysClk,Reset,Clkdiv26)
    --		constant CntOne : unsigned(3 downto 0) := "0001";
    --		variable Cnt10  : unsigned(3 downto 0);
    --	begin
    --		if Rising_Edge(SysClk) then
    --			if Reset = '0' then
    --				Cnt10 := "0000";
    --				tmpEnRX <= '0';
    --			elsif ClkDiv26 = '1' then
    --				Cnt10 := Cnt10 + CntOne;
    --			end if;
    --			case Cnt10 is
    --				when "1010" =>
    --				tmpEnRX <= '1';
    --				Cnt10 := "0000";
    --				when others =>
    --				tmpEnRX <= '0';
    --			end case;
    --		end if;
    --	end process;
    
    
    
    -----------------------------------------------------------------------------
    -- Provides the EnableTX signal, at 9.6 KHz
    -- divide by 16
    -- divide the receive clock by 16
    -----------------------------------------------------------------------------
    DivClk16 : process(SysClk,reset,tmpEnRX)
        constant CntOne : unsigned(4 downto 0) := "00001";
        variable Cnt16  : unsigned(4 downto 0);
    begin
        if reset = '1' then
            Cnt16 := "00000";
            tmpEnTX <= '0';
        elsif Rising_Edge(SysClk) then
            if tmpEnRX = '1' then
                Cnt16 := Cnt16 + CntOne;
            end if;
            case Cnt16 is
                when "01111" =>
                    tmpEnTX <= '1';
                Cnt16 := Cnt16 + CntOne;
                when "10001" =>
                    Cnt16 := "00000";
                tmpEnTX <= '0';
                when others =>
                tmpEnTX <= '0';
            end case;
        end if;
    end process;
    
    EnableTX <= tmpEnTX;
    
end Behaviour;