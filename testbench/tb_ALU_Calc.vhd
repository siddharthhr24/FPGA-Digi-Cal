--------------------------------------------------------------------------
-- Testbench for ALU_Calc
-- Self-checking: decodes the 7-segment outputs back into hex digits,
-- reassembles the 16-bit result, compares against an expected value,
-- and reports PASS/FAIL for every test case, plus a final summary.
--
-- LONG_PRESS_LIMIT is overridden via generic to 20 cycles (instead of the
-- real 50,000,000) purely to keep simulation time reasonable. Synthesis
-- still uses the real 50,000,000 default from the entity itself.
--------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ALU_Calc is
end entity tb_ALU_Calc;

architecture sim of tb_ALU_Calc is

    component ALU_Calc is
        generic (
            LONG_PRESS_LIMIT : integer := 50_000_000
        );
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

    -- DUT signals
    signal clk  : std_logic := '0';
    signal SW   : std_logic_vector(9 downto 0) := (others => '0');
    signal KEY  : std_logic_vector(1 downto 0) := "11";  -- idle high, active-low buttons
    signal HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : std_logic_vector(6 downto 0);

    constant CLK_PERIOD          : time := 20 ns;  -- 50 MHz
    constant SIM_LONG_PRESS_LIMIT : integer := 20; -- scaled-down threshold for simulation

    signal pass_count : integer := 0;
    signal fail_count : integer := 0;

    -- Reverse-lookup: 7-segment pattern -> 4-bit hex nibble
    -- (mirrors SegDis_7's table exactly; "1111111" / unknowns map to "0000" defensively)
    function seg_to_hex(seg : std_logic_vector(6 downto 0)) return std_logic_vector is
    begin
        case seg is
            when "1000000" => return "0000";  -- 0
            when "1111001" => return "0001";  -- 1
            when "0100100" => return "0010";  -- 2
            when "0110000" => return "0011";  -- 3
            when "0011001" => return "0100";  -- 4
            when "0010010" => return "0101";  -- 5
            when "0000010" => return "0110";  -- 6
            when "1111000" => return "0111";  -- 7
            when "0000000" => return "1000";  -- 8
            when "0010000" => return "1001";  -- 9
            when "0001000" => return "1010";  -- A
            when "0000011" => return "1011";  -- B
            when "1000110" => return "1100";  -- C
            when "0100001" => return "1101";  -- D
            when "0000110" => return "1110";  -- E
            when "0001110" => return "1111";  -- F
            when others    => return "0000";  -- blank/unknown
        end case;
    end function;

    -- Reassembles HEX0-HEX3 back into the 16-bit result value
    function get_result(h0, h1, h2, h3 : std_logic_vector(6 downto 0)) return std_logic_vector is
        variable r : std_logic_vector(15 downto 0);
    begin
        r(3 downto 0)   := seg_to_hex(h0);
        r(7 downto 4)   := seg_to_hex(h1);
        r(11 downto 8)  := seg_to_hex(h2);
        r(15 downto 12) := seg_to_hex(h3);
        return r;
    end function;

begin

    ----------------------------------------------------------------------
    -- DUT instantiation (generic overridden for fast simulation)
    ----------------------------------------------------------------------
    DUT : ALU_Calc
        generic map (
            LONG_PRESS_LIMIT => SIM_LONG_PRESS_LIMIT
        )
        port map (
            clk  => clk,
            SW   => SW,
            KEY  => KEY,
            HEX0 => HEX0,
            HEX1 => HEX1,
            HEX2 => HEX2,
            HEX3 => HEX3,
            HEX4 => HEX4,
            HEX5 => HEX5
        );

    ----------------------------------------------------------------------
    -- Clock generation
    ----------------------------------------------------------------------
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    ----------------------------------------------------------------------
    -- Stimulus + self-checking process
    ----------------------------------------------------------------------
    stim_proc : process

        -- Latches operandA via a short KEY(0) press
        procedure latch_A(val : std_logic_vector(7 downto 0)) is
        begin
            SW(7 downto 0) <= val;
            wait until rising_edge(clk);
            KEY(0) <= '0';
            wait until rising_edge(clk);
            KEY(0) <= '1';
            wait until rising_edge(clk);
        end procedure;

        -- Latches operandB via a short KEY(1) press (well under the long-press threshold)
        procedure latch_B_short(val : std_logic_vector(7 downto 0)) is
        begin
            SW(7 downto 0) <= val;
            wait until rising_edge(clk);
            KEY(1) <= '0';
            wait for CLK_PERIOD * 3;  -- short hold, releases before SIM_LONG_PRESS_LIMIT
            KEY(1) <= '1';
            wait until rising_edge(clk);
        end procedure;

        -- Holds KEY(1) past the long-press threshold to toggle Arithmetic <-> Logic mode
        procedure toggle_mode is
        begin
            KEY(1) <= '0';
            wait for CLK_PERIOD * (SIM_LONG_PRESS_LIMIT + 3);
            KEY(1) <= '1';
            wait until rising_edge(clk);
        end procedure;

        -- Compares the decoded result against expected, logs PASS/FAIL
        procedure check(test_name : string; expected : std_logic_vector(15 downto 0)) is
            variable actual : std_logic_vector(15 downto 0);
        begin
            wait for CLK_PERIOD * 2;  -- allow combinational logic to settle
            actual := get_result(HEX0, HEX1, HEX2, HEX3);
            if actual = expected then
                pass_count <= pass_count + 1;
                report "PASS: " & test_name severity note;
            else
                fail_count <= fail_count + 1;
                report "FAIL: " & test_name &
         " Expected=" &
         integer'image(to_integer(unsigned(expected))) &
         " Actual=" &
         integer'image(to_integer(unsigned(actual)))
         severity error;
            end if;
        end procedure;

    begin
        SW  <= (others => '0');
        KEY <= "11";
        wait for CLK_PERIOD * 5;

        ------------------------------------------------------------------
        -- ARITHMETIC MODE (default mode after reset)
        ------------------------------------------------------------------

        -- ADD: 15 + 10 = 25
        SW(9 downto 8) <= "00";
        latch_A(x"0F");
        latch_B_short(x"0A");
        check("ADD 15 + 10 = 25", x"0019");

        -- SUB (normal): 20 - 5 = 15
        SW(9 downto 8) <= "01";
        latch_A(x"14");
        latch_B_short(x"05");
        check("SUB 20 - 5 = 15", x"000F");

        -- SUB (edge case: underflow) 5 - 20 -> wraps to 65521 (0xFFF1)
        latch_A(x"05");
        latch_B_short(x"14");
        check("SUB underflow 5 - 20 (wraps)", x"FFF1");

        -- MUL: 12 * 11 = 132
        SW(9 downto 8) <= "10";
        latch_A(x"0C");
        latch_B_short(x"0B");
        check("MUL 12 * 11 = 132", x"0084");

        -- MUL (edge case: max values) 255 * 255 = 65025 (0xFE01)
        latch_A(x"FF");
        latch_B_short(x"FF");
        check("MUL edge 255 * 255", x"FE01");

        -- DIV: 20 / 4 = 5
        SW(9 downto 8) <= "11";
        latch_A(x"14");
        latch_B_short(x"04");
        check("DIV 20 / 4 = 5", x"0005");

        -- DIV (edge case: divide by zero) -> forced to 0
        latch_A(x"20");
        latch_B_short(x"00");
        check("DIV edge divide-by-zero", x"0000");

        ------------------------------------------------------------------
        -- TOGGLE TO LOGIC MODE (long press on KEY1)
        ------------------------------------------------------------------
        toggle_mode;

        ------------------------------------------------------------------
        -- LOGIC MODE
        ------------------------------------------------------------------

        -- AND (edge case: disjoint bit patterns) 0xF0 & 0x0F = 0x00
        SW(9 downto 8) <= "00";
        latch_A(x"F0");
        latch_B_short(x"0F");
        check("AND 0xF0 & 0x0F = 0x00", x"0000");

        -- AND: 0xAC & 0x3F = 0x2C
        latch_A(x"AC");
        latch_B_short(x"3F");
        check("AND 0xAC & 0x3F = 0x2C", x"002C");

        -- OR: 0xF0 | 0x0F = 0xFF
        SW(9 downto 8) <= "01";
        latch_A(x"F0");
        latch_B_short(x"0F");
        check("OR 0xF0 | 0x0F = 0xFF", x"00FF");

        -- XOR: 0xAA ^ 0xFF = 0x55
        SW(9 downto 8) <= "10";
        latch_A(x"AA");
        latch_B_short(x"FF");
        check("XOR 0xAA ^ 0xFF = 0x55", x"0055");

        -- NOT: ~0x0F = 0xF0 (unary, operandB irrelevant)
        SW(9 downto 8) <= "11";
        latch_A(x"0F");
        check("NOT ~0x0F = 0xF0", x"00F0");

        -- NOT (edge case: all zeros) ~0x00 = 0xFF
        latch_A(x"00");
        check("NOT edge ~0x00 = 0xFF", x"00FF");

        -- NOT (edge case: all ones) ~0xFF = 0x00
        latch_A(x"FF");
        check("NOT edge ~0xFF = 0x00", x"0000");

        ------------------------------------------------------------------
        -- SUMMARY
        ------------------------------------------------------------------
        report "----------------------------------------------------";
        report "TESTS COMPLETE:  " & integer'image(pass_count) & " PASSED,  " &
               integer'image(fail_count) & " FAILED";
        if fail_count = 0 then
            report "ALL TESTS PASSED" severity note;
        else
            report "SOME TESTS FAILED - see FAIL lines above" severity error;
        end if;
        report "----------------------------------------------------";

        wait;

    end process;

end architecture sim;
