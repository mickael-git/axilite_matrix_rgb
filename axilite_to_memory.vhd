------------------------------------------------------------------------
--  axilite_to_memory.vhd
--  support only aligned access and don't mask bytes
--
--  Copyright (C) 2013 M.FORET
--
--  This program is free software: you can redistribute it and/or
--  modify it under the terms of the GNU General Public License
--  as published by the Free Software Foundation, either version
--  2 of the License, or (at your option) any later version.
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.ALL;

use work.axi3ml_pkg.all;  -- axi-lite records

entity axilite_to_memory is
    generic (
        ADDR_WIDTH    : integer := 15  -- address width (32 bits word)
    );
    port (
        -- ========= AXI
        s_axi_aclk     : in  std_logic;
        --
        s_axi_areset_n : in  std_logic;
        
        -- write interface
        s_axi_wi : in  axi3ml_write_out_r;
        s_axi_wo : out axi3ml_write_in_r;
        
        -- read interface
        s_axi_ri : in  axi3ml_read_out_r;
        s_axi_ro : out axi3ml_read_in_r;
        
        -- ========= block ram interface
        mem_addr      : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        mem_we        : out std_logic_vector( 3 downto 0);
        mem_din       : out std_logic_vector(31 downto 0);
        mem_dout      : in  std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of axilite_to_memory is

type type_state_fsm is (IDLE, READ_REQ, SEND_DATA, WRITING, END_WRITING);
signal state_fsm : type_state_fsm := IDLE;

signal awready_i : std_logic;
signal wready_i  : std_logic;
signal bvalid_i  : std_logic;
signal rvalid_i  : std_logic;
signal arready   : std_logic;
signal rdata     : std_logic_vector(s_axi_ro.rdata'length-1 downto 0);

begin

s_axi_wo.awready <= awready_i;
s_axi_wo.wready  <= wready_i;
s_axi_wo.bvalid  <= bvalid_i;
s_axi_wo.bresp   <= "00";  -- status ok

s_axi_ro.rvalid  <= rvalid_i;
s_axi_ro.rresp   <= "00";  -- status ok
s_axi_ro.arready <= arready;
s_axi_ro.rdata   <= rdata;

fsm_axi : process(s_axi_aclk)
begin

    if rising_edge(s_axi_aclk) then

        if (s_axi_areset_n = '0') then
        
            state_fsm           <= IDLE;
            arready             <= '0';
            rdata               <= (others=>'0');
            rvalid_i            <= '0';
            awready_i           <= '0';
            wready_i            <= '0';
            bvalid_i            <= '0';
            mem_we              <= (others=>'0');
            mem_din             <= (others=>'0');
        
        else
        
          case state_fsm is
        
            when IDLE =>
                rdata          <= (others=>'0');
                rvalid_i       <= '0';
                awready_i      <= '1';
                arready        <= '1';
                mem_we         <= (others=>'0');
                wready_i       <= '0';
                bvalid_i       <= '0';
                mem_din        <= (others=>'0');
                
                if (s_axi_wi.awvalid = '1' and awready_i = '1') then
                    state_fsm          <= WRITING;
                    --address_to_write   <= unsigned(s_axi_wi.awaddr(ADDR_WIDTH+1 downto 2));  -- byte address => 32 bits word address
                    mem_addr           <= s_axi_wi.awaddr(ADDR_WIDTH+1 downto 2);  -- byte address => 32 bits word address
                    awready_i          <= '0';
                    wready_i           <= '1';
                elsif (s_axi_ri.arvalid = '1' and arready = '1') then
                    state_fsm          <= READ_REQ;
                    --address_to_read    <= unsigned(s_axi_ri.araddr(ADDR_WIDTH+1 downto 2));  -- byte address => 32 bits word address
                    mem_addr           <= s_axi_ri.araddr(ADDR_WIDTH+1 downto 2);  -- byte address => 32 bits word address
                    arready            <= '0';
                else
                    state_fsm   <= IDLE;
                    mem_addr    <= (others=>'0');
                end if;
        
            -- ============= reading management
            when READ_REQ =>
                state_fsm <= SEND_DATA;
        
            when SEND_DATA =>
                if (s_axi_ri.rready = '1' and rvalid_i = '1') then  -- it is sent
                    rvalid_i    <= '0';
                    arready     <= '1';
                    state_fsm   <= IDLE;
                    rdata       <= (others=>'0');
                else                   -- we send it
                   rvalid_i    <= '1';
                   rdata       <= mem_dout;
                   state_fsm   <= SEND_DATA;
                end if;
        
            -- ============= writing management
            when WRITING =>
                wready_i <= '1';
                if (s_axi_wi.wvalid = '1' and wready_i = '1') then
                    mem_din   <= s_axi_wi.wdata;
                    mem_we    <= (others=>'1');
                    wready_i  <= '0';
                    bvalid_i  <= '1';
                    state_fsm <= END_WRITING;
                else
                    state_fsm <= WRITING;
                    mem_we    <= (others=>'0');
                    mem_din   <= (others=>'0');
                end if;
        
            when END_WRITING =>
                mem_din  <= (others => '0');
                mem_we   <= (others=>'0');
                if (s_axi_wi.bready = '1' and bvalid_i = '1') then
                    bvalid_i  <= '0';
                    awready_i <= '1';
                    state_fsm <= IDLE;
                else
                    bvalid_i  <= '1';
                    state_fsm <= END_WRITING;
                end if;
        
        
            when others =>
                state_fsm <= IDLE;
        
          end case;
        
        end if;  -- if m_axi_aresetn

    end if;  -- if m_axi_aclk

end process fsm_axi;

end rtl;
