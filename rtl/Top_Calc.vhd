library ieee;
use ieee.std_logic_1164.all;

entity Top_Calc is
    port (
        MAX10_CLK1_50 : in  std_logic;
        SW            : in  std_logic_vector(9 downto 0);
        KEY           : in  std_logic_vector(1 downto 0);  -- Push buttons
        HEX0          : out std_logic_vector(6 downto 0);
        HEX1          : out std_logic_vector(6 downto 0);
        HEX2          : out std_logic_vector(6 downto 0);
        HEX3          : out std_logic_vector(6 downto 0);
        HEX4          : out std_logic_vector(6 downto 0);
        HEX5          : out std_logic_vector(6 downto 0)
    );
end entity Top_Calc;

architecture structural of Top_Calc is

    component ALU_Calc is
        port (
            clk  : in  std_logic;
            SW   : in  std_logic_vector(9 downto 0);
            KEY  : in  std_logic_vector(1 downto 0);
            HEX0 : out std_logic_vector(6 downto 0);
            HEX1 : out std_logic_vector(6 downto 0);
            HEX2 : out std_logic_vector(6 downto 0);
            HEX3 : out std_logic_vector(6 downto 0);
            HEX4 : out std_logic_vector(6 downto 0);
            HEX5 : out std_logic_vector(6 downto 0)
        );
    end component;

begin

    calc_inst : ALU_Calc
        port map (
            clk  => MAX10_CLK1_50,
            SW   => SW,
            KEY  => KEY,
            HEX0 => HEX0,
            HEX1 => HEX1,
            HEX2 => HEX2,
            HEX3 => HEX3,
            HEX4 => HEX4,
            HEX5 => HEX5
        );

end architecture structural;