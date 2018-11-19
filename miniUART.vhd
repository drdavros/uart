--===========================================================================--
--
--  S Y N T H E Z I A B L E    miniUART   C O R E
--
--  www.OpenCores.Org - January 2000
--  This core adheres to the GNU public license  
--
-- Design units   : miniUART core for the OCRP-1
--
-- File name      : miniuart.vhd
--
-- Purpose        : Implements an miniUART device for communication purposes 
--                  between the OR1K processor and the Host computer through
--                  an RS-232 communication protocol.
--                  
-- Library        : uart_lib.vhd
--
-- Dependencies   : IEEE.Std_Logic_1164
--
-- Simulator      : ModelSim PE/PLUS version 4.7b on a Windows95 PC
--===========================================================================--
-------------------------------------------------------------------------------
-- Revision list
-- Version   Author                 Date            Changes
--
-- 0.1      Ovidiu Lupas     15 January 2000        New model
-- 1.0      Ovidiu Lupas     January  2000          Synthesis optimizations
-- 2.0      Ovidiu Lupas     April    2000          Bugs removed - RSBusCtrl
--          olupas@opencores.org
--          the RSBusCtrl did not process all possible situations
-- 2.1		ML				June 2003			    Cleanup, made reset positive
-- 3.0      ML              Mar 2017                Added generic to handle baud rate
--
-------------------------------------------------------------------------------
-- Description    : The memory consists of a dual-port memory addressed by
--                  two counters (RdCnt & WrCnt). The third counter (StatCnt)
--                  sets the status signals and keeps a track of the data flow.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--library work;
--   use work.UART_Def.all;

entity miniUART is
    generic (
        osc_freq : integer
        );
    port (
        sysclk   : in  Std_Logic; -- System Clock (25MHz in , 9600 Baud)
        reset    : in  Std_Logic; -- Reset input (positive)
        -- device control
        cs_n     : in  Std_Logic; -- Chip Select
        rd_n     : in  Std_Logic; -- Read
        wr_n     : in  Std_Logic; -- Write
        -- address and data
        Addr     : in  Std_Logic; -- addr(0) = read serial data, addr(1) = read status bits 
        datain   : in  Std_Logic_Vector(7 downto 0); -- data input interface with host
        dataout  : out Std_Logic_Vector(7 downto 0); -- data output interface with host
        --
        rxd      : in  Std_Logic; -- serial receive data
        txd      : out Std_Logic; -- serial Xmit data
        -- status control lines
        intrx_n  : out Std_Logic; -- Receive flag
        inttx_n  : out Std_Logic); -- Transmit flag
end entity;

architecture uart of miniUART is
    signal RxData : Std_Logic_Vector(7 downto 0); -- data input from rxUnit
    signal TxData : Std_Logic_Vector(7 downto 0); -- data output to txUnit
    signal CSReg  : Std_Logic_Vector(7 downto 0); -- Ctrl & status register
    signal EnabRx : Std_Logic;  -- Enable RX unit
    signal EnabTx : Std_Logic;  -- Enable TX unit
    signal DRdy   : Std_Logic;  -- Receive Data ready
    signal TRegE  : Std_Logic;  -- Transmit register empty
    signal TBufE  : Std_Logic;  -- Transmit buffer empty
    signal Read   : Std_Logic;  -- Read receive buffer
    signal Load   : Std_Logic;  -- Load transmit buffer
    signal FErr   : Std_Logic;  -- Frame error
    signal OErr   : Std_Logic;  -- Output error
    -----------------------------------------------------------------------------
    -- Baud rate Generator
    -----------------------------------------------------------------------------
    component ClkUnit is
        generic (
            osc_freq : integer
            );
        port (
            SysClk   : in  Std_Logic;  -- System Clock
            EnableRX : out Std_Logic;  -- Control signal
            EnableTX : out Std_Logic;  -- Control signal
            Reset    : in  Std_Logic); -- Reset input
    end component;
    -----------------------------------------------------------------------------
    -- Receive Unit
    -----------------------------------------------------------------------------
    component RxUnit is
        port (
            Clk    : in  Std_Logic;  -- Clock signal
            Reset  : in  Std_Logic;  -- Reset input
            Enable : in  Std_Logic;  -- Enable input (clock gate)
            RxD    : in  Std_Logic;  -- RS-232 data input
            RD     : in  Std_Logic;  -- Read data signal
            FErr   : out Std_Logic;  -- Status signal
            OErr   : out Std_Logic;  -- Status signal
            DRdy   : out Std_Logic;  -- Status signal
            DataIn : out Std_Logic_Vector(7 downto 0));
    end component;
    -----------------------------------------------------------------------------
    -- Transmitter Unit
    -----------------------------------------------------------------------------
    component TxUnit is
        port (
            Clk    : in  Std_Logic;  -- Clock signal
            Reset  : in  Std_Logic;  -- Reset input
            Enable : in  Std_Logic;  -- Enable input (clock gate)
            Load   : in  Std_Logic;  -- Load transmit data
            TxD    : out Std_Logic;  -- RS-232 data output
            TRegE  : out Std_Logic;  -- Tx register empty
            TBufE  : out Std_Logic;  -- Tx buffer empty
            DataO  : in  Std_Logic_Vector(7 downto 0));
    end component;
begin
    -----------------------------------------------------------------------------
    -- Instantiation of internal components
    -----------------------------------------------------------------------------
    ClkDiv  : ClkUnit     generic map (
        osc_freq => osc_freq
        )
    port map (SysClk,EnabRX,EnabTX,Reset);
    
    TxDev   : TxUnit port map (SysClk,Reset,EnabTX,Load,TxD,TRegE,TBufE,TxData);
    RxDev   : RxUnit port map (SysClk,Reset,EnabRX,RxD,Read,FErr,OErr,DRdy,RxData);
    -----------------------------------------------------------------------------
    -- Implements the controller for Rx&Tx units
    -----------------------------------------------------------------------------
    process(SysClk,Reset)
        -----------------------------------
        -- CSReg detailed
        -- csreg(0) xmit overrun error
        -- csreg(1) rec. frame error
        -- csreg(2) rec. overrun error
        -- csreg(3) xmit underrun error
        -- csreg(4) rec. data ready _n
        -- csreg(5) xmit data ready _n
        -- csreg(6)	spare
        -- csreg(7)	spare
        -----------------------------------
        
    begin
        if reset = '1' then
            IntTx_N <= '1'; -- not ready to accept xmit data
            IntRx_N <= '1'; -- not ready to receive data
            CSReg <= "11110000";
        elsif Rising_Edge(SysClk) then
            
            -- data read (receiving)
            if DRdy = '1' then
                IntRx_N <= '0'; -- receive data ready
                csreg(4) <= '0';
            end if;
            
            if Read = '1' then
                IntRx_N <= '1';
                csreg(4) <= '1';
            end if;
            
            -- data writes (sending)
            if TBufE = '1' then
                IntTx_N <= '0'; -- transmit data buffer space ready
                csreg(5) <= '0';
            end if;
            
            -- Transmit underrun when we run out of things to send
            CSReg(3) <= TBufE and TRegE;
            
            if Load = '1' then
                IntTx_N <= '1'; -- data loading into xmit buffer, tell world we are full
                csreg(5) <= '1';
                if TBufE = '1' then
                    -- loading xmit and buffer is empty
                    CSReg(0) <= '0'; -- no xmit overrun here
                else
                    -- xmit buffer was not empty
                    CSReg(0) <= '1'; -- transmit buffer overrun error
                end if;
            end if;
            
            -- Other
            CSReg(1) <= FErr; -- receive data frame error
            CSReg(2) <= OErr; -- receive data overrun
            
        end if;
        
    end process;
    -----------------------------------------------------------------------------
    -- Combinational section
    -----------------------------------------------------------------------------
    
    -- Read data for sending
    TX_PROC : process(SysClk,reset)
    begin
        if reset = '1' then
            txdata <= "00000000";
        elsif rising_edge(sysclk) then
            txdata <= DataIn;
        end if;
    end process;
    
    -- Generate a flag on writing serial data
    WRITE_FLAG : process(SysClk,reset)
    begin
        if reset = '1' then
            Load <= '0';
        elsif rising_edge(sysclk) then
            -- chip select and write = classic write (load)
            if (CS_N = '0' and WR_N = '0')  then
                Load <= '1';
            else 
                Load <= '0';
            end if;
        end if;
    end process;
    
    -- Generate a flag on reading serial data
    READ_FLAG : process(SysClk,reset)
    begin
        if reset = '1' then
            Read <= '0';
        elsif rising_edge(sysclk) then
            --			 chip select and read = classic read
            if (CS_N = '0' and RD_N = '0' and Addr = '0') then
                Read <= '1'; -- flag passed to rxunit, lets rxunit know data was read
            elsif (CS_N = '0' and RD_N = '0' and Addr = '1') then
                Read <= '0'; -- control register reads are not serial data reads
            else
                Read <= '0'; -- we are not doing any read at all
            end if;
        end if;
    end process;
    
    --
    -- I wanted the reading of the data to occur in one sysclk
    -- this requires the output to be valid on the next edge of sysclk
    -- after the read signal (or addr) is active.
    --
    DataOut <= RxData when Addr = '0' else
    CSReg;
    
    
    -- Select data for output
    --	RX_PROC : process(SysClk)
    --	begin
    --		if rising_edge(sysclk) then
    --			--			 chip select and read = classic read
    --			if (CS_N = '0' and RD_N = '0') then
    --				if Addr = '0' then
    --					DataOut <= RxData;
    --				else
    --					DataOut <= CSReg;
    --				end if;
    --			end if;
    --		end if;
    --	end process;
    
    --
    -- Don't need tristate in some cases
    --
    
    -- Tristate Control of data output lines
    -- (works better for synthesis to have tristate separated from other logic)
    --	RX_IO : process(CS_N, RD_N, ouch)
    --	begin
    --		--			 chip select and read = classic read
    --		if (CS_N = '0' and RD_N = '0') then
    --			DataOut <= ouch;
    --		else
    --			DataOut <= "ZZZZZZZZ";					
    --		end if;
    --	end process;
    
    
end uart;