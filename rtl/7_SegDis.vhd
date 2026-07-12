library ieee;
use ieee.std_logic_1164.all;

entity seg7_display is
    port (
        in_val : in  std_logic_vector(3 downto 0);
        out_seg : out std_logic_vector(6 downto 0)
    );
end entity seg7_display;

architecture behavioral of seg7_display is
begin

    process(in_val)
    begin
        case in_val is
            when "0000" => out_seg <= "1000000"; -- 0
            when "0001" => out_seg <= "1111001"; -- 1
            when "0010" => out_seg <= "0100100"; -- 2
            when "0011" => out_seg <= "0110000"; -- 3
            when "0100" => out_seg <= "0011001"; -- 4
            when "0101" => out_seg <= "0010010"; -- 5
            when "0110" => out_seg <= "0000010"; -- 6
            when "0111" => out_seg <= "1111000"; -- 7
            when "1000" => out_seg <= "0000000"; -- 8
            when "1001" => out_seg <= "0010000"; -- 9
            when "1010" => out_seg <= "0001000"; -- A
            when "1011" => out_seg <= "0000011"; -- B
            when "1100" => out_seg <= "1000110"; -- C
            when "1101" => out_seg <= "0100001"; -- D
            when "1110" => out_seg <= "0000110"; -- E
            when "1111" => out_seg <= "0001110"; -- F
            when others => out_seg <= "1111111"; -- Blank
        end case;
    end process;

end architecture behavioral;