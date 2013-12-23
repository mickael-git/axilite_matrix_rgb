------------------------------------------------------------------------
--  pkg_axilite_master_model.vhd
--  simple model for axi-lite read and write
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
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

library std;
use std.textio.all;

use work.axi3ml_pkg.all;    -- axi lite records
use work.pkg_tools_tb.all;  -- display

package pkg_axilite_master_model is

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

procedure single_write  ( signal clk      : in  std_logic;
                          signal m_axi_wi : in  axi3ml_write_in_r;
                          signal m_axi_wo : out axi3ml_write_out_r;
                          variable data   : in  std_logic_vector;
                          variable addr   : in  std_logic_vector
                        );
    
procedure write_file    ( signal clk          : in  std_logic;
                          signal m_axi_wi     : in  axi3ml_write_in_r;
                          signal m_axi_wo     : out axi3ml_write_out_r;
                          data_file  : in string;
                          variable addr       : in  std_logic_vector
                        );

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

procedure single_read   ( signal clk      : in  std_logic;
                          signal m_axi_ri : in  axi3ml_read_in_r;
                          signal m_axi_ro : out axi3ml_read_out_r;
                          variable data   : out std_logic_vector;
                          variable addr   : in  std_logic_vector
                        );
                        
procedure cmp_file      ( signal clk          : in  std_logic;
                          signal m_axi_ri     : in  axi3ml_read_in_r;
                          signal m_axi_ro     : out axi3ml_read_out_r;
                          data_file  : in string;
                          variable addr       : in  std_logic_vector
                        );

end pkg_axilite_master_model;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- PACKAGE BODY
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

package body  pkg_axilite_master_model  is

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- ============================== single write
    procedure single_write( signal clk      : in  std_logic;
                            signal m_axi_wi : in  axi3ml_write_in_r;
                            signal m_axi_wo : out axi3ml_write_out_r;
                            variable data   : in  std_logic_vector;
                            variable addr   : in  std_logic_vector
                        ) is
    begin

        m_axi_wo.bready   <= '1';

        -- address
        m_axi_wo.awaddr   <= addr;
        m_axi_wo.awprot   <= (others=>'U');
        m_axi_wo.awvalid  <= '1';
        wait until rising_edge(clk);
        while m_axi_wi.awready = '0' loop
            wait until rising_edge(clk);
        end loop;
        m_axi_wo.awaddr   <= (others=>'0');
        m_axi_wo.awvalid  <= '0';
        -- data
        m_axi_wo.wdata    <= data;
        m_axi_wo.wstrb    <= (others=>'1');
        m_axi_wo.wvalid   <= '1';
        wait until rising_edge(clk);
        while m_axi_wi.wready = '0' loop
            wait until rising_edge(clk);
        end loop;
        m_axi_wo.wvalid   <= '0';

        wait until m_axi_wi.bvalid = '1';
        wait until rising_edge(clk);

        m_axi_wo.bready   <= '0';

    end;

-- ============================== write file with single write
    procedure write_file  ( signal clk          : in  std_logic;
                            signal m_axi_wi     : in  axi3ml_write_in_r;
                            signal m_axi_wo     : out axi3ml_write_out_r;
                            data_file  : in string;
                            variable addr       : in  std_logic_vector
                        ) is
        file line_txt            : text open read_mode is data_file;
        variable file_line       : line;
        variable nb_value        : integer := 0;
        variable data            : std_logic_vector(31 downto 0);
        variable current_adr     : unsigned(31 downto 0);
    begin
    
        readline(line_txt, file_line);  -- comment line
        readline(line_txt, file_line);  -- size line
        read(file_line, nb_value);

        readline(line_txt, file_line);  -- empty line
        
        current_adr := unsigned(addr);
        
        while (not endfile(line_txt)) loop

          readline(line_txt, file_line);
          hread(file_line, data);

          single_write(clk, m_axi_wi, m_axi_wo, data, std_logic_vector(current_adr));
          
          current_adr := current_adr + 4;  -- 32 bits

        end loop;
    
    end;
                        
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


-- ============================== single read
    procedure single_read ( signal clk      : in  std_logic;
                            signal m_axi_ri : in  axi3ml_read_in_r;
                            signal m_axi_ro : out axi3ml_read_out_r;
                            variable data   : out std_logic_vector;
                            variable addr   : in  std_logic_vector
                        ) is
    begin

        m_axi_ro.rready   <= '1';

        -- address
        m_axi_ro.araddr   <= addr;
        m_axi_ro.arprot   <= (others=>'U');
        m_axi_ro.arvalid  <= '1';
        wait until rising_edge(clk);
        while m_axi_ri.arready = '0' loop
            wait until rising_edge(clk);
        end loop;
        m_axi_ro.araddr   <= (others=>'0');
        m_axi_ro.arvalid  <= '0';
        -- data
        wait until m_axi_ri.rvalid = '1';
        data := m_axi_ri.rdata;

        wait until rising_edge(clk);
        m_axi_ro.rready   <= '0';

    end;
    
-- ============================== cmp file with single read
    procedure cmp_file    ( signal clk          : in  std_logic;
                            signal m_axi_ri     : in  axi3ml_read_in_r;
                            signal m_axi_ro     : out axi3ml_read_out_r;
                            data_file  : in string;
                            variable addr       : in  std_logic_vector
                        ) is
        file line_txt            : text open read_mode is data_file;
        variable file_line       : line;
        variable nb_value        : integer := 0;
        variable data            : std_logic_vector(31 downto 0);
        variable data_axi        : std_logic_vector(31 downto 0);
        variable current_adr     : unsigned(31 downto 0);
    begin
    
        readline(line_txt, file_line);  -- comment line
        readline(line_txt, file_line);  -- size line
        read(file_line, nb_value);

        readline(line_txt, file_line);  -- empty line
        
        current_adr := unsigned(addr);
        
        while (not endfile(line_txt)) loop

          readline(line_txt, file_line);
          hread(file_line, data);

          single_read(clk, m_axi_ri, m_axi_ro, data_axi, std_logic_vector(current_adr));
          
          if (data_axi /= data) then
              display("Error during comparison @ " & integer'image(to_integer(current_adr)));
          end if;
          
          current_adr := current_adr + 4;  -- 32 bits

        end loop;
    
    end;

end pkg_axilite_master_model;

