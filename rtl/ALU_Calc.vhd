library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ALU_Calc is
    generic (
        LONG_PRESS_LIMIT : integer := 50000000
    );

    port (
        clk  : in std_logic;
        SW   : in std_logic_vector(9 downto 0);
        KEY  : in std_logic_vector(1 downto 0);

        HEX0 : out std_logic_vector(6 downto 0);
        HEX1 : out std_logic_vector(6 downto 0);
        HEX2 : out std_logic_vector(6 downto 0);
        HEX3 : out std_logic_vector(6 downto 0);
        HEX4 : out std_logic_vector(6 downto 0);
        HEX5 : out std_logic_vector(6 downto 0)
    );

end entity ALU_Calc;

architecture behavioral of ALU_Calc is

    component seg7_display is
        port (
            in_val  : in  std_logic_vector(3 downto 0);
            out_seg : out std_logic_vector(6 downto 0)
        );
    end component;

    signal operandA, operandB : std_logic_vector(7 downto 0);
    signal operation          : std_logic_vector(1 downto 0);
    signal result             : std_logic_vector(15 downto 0);
    signal display_value      : std_logic_vector(15 downto 0);

    -- ===== NEW: signals added for Logic Mode + long-press support =====
    signal mode               : std_logic := '0';  -- '0' = Arithmetic Mode, '1' = Logic Mode
    signal mode_changed       : std_logic := '0';  -- one-shot guard: only toggle once per hold
    signal long_press_counter : unsigned(25 downto 0) := (others => '0');  -- 26 bits: needs to count to 50,000,000
    signal hex4_sel : std_logic_vector(3 downto 0);
    
    -- ====================================================================

begin

    operation <= SW(9 downto 8);

    -- Latch operandA + KEY1 short/long press handling
    process(clk)
    begin
        if rising_edge(clk) then

            -- operandA latch: UNCHANGED from original design
            if KEY(0) = '0' then
                operandA <= SW(7 downto 0);
            end if;

            -- ===== NEW: KEY1 long-press (mode toggle) / short-press (latch B) =====
            if KEY(1) = '0' then
                -- button currently held down
                if long_press_counter < LONG_PRESS_LIMIT - 1 then
                    long_press_counter <= long_press_counter + 1;
                end if;

                if long_press_counter = LONG_PRESS_LIMIT - 1 and mode_changed = '0' then
                    mode         <= not mode;  -- toggle Arithmetic <-> Logic
                    mode_changed <= '1';       -- block further toggles while still held
                end if;
            else
                -- button released
                if long_press_counter > 0 and long_press_counter < LONG_PRESS_LIMIT - 1 then
                    -- released before reaching 1s => this was a normal short press
                    operandB <= SW(7 downto 0);
                end if;
                long_press_counter <= (others => '0');
                mode_changed        <= '0';
            end if;
            -- ========================================================================

        end if;
    end process;

    -- Perform operations (MODIFIED: now branches on mode)
    process(mode, operation, operandA, operandB)
        variable a_ext, b_ext : unsigned(15 downto 0);
        variable mult_res     : unsigned(15 downto 0);
        variable div_res      : unsigned(7 downto 0);
    begin
        a_ext := resize(unsigned(operandA), 16);
        b_ext := resize(unsigned(operandB), 16);

        if mode = '0' then
            -- Arithmetic Mode: UNCHANGED from original design
            case operation is
                when "00" =>
                    result <= std_logic_vector(a_ext + b_ext);              -- A + B
                when "01" =>
                    result <= std_logic_vector(a_ext - b_ext);              -- A - B
                when "10" =>
                    mult_res := unsigned(operandA) * unsigned(operandB);
                    result <= std_logic_vector(mult_res);                   -- A * B
                when others =>
                    if unsigned(operandB) /= 0 then
                        div_res := unsigned(operandA) / unsigned(operandB);
                        result <= std_logic_vector(resize(div_res, 16));    -- A / B
                    else
                        result <= (others => '0');
                    end if;
            end case;
        else
            -- ===== NEW: Logic Mode =====
            case operation is
                when "00" =>
                    result <= x"00" & (operandA and operandB);  -- AND
                when "01" =>
                    result <= x"00" & (operandA or operandB);   -- OR
                when "10" =>
                    result <= x"00" & (operandA xor operandB);  -- XOR
                when others =>
                    result <= x"00" & (not operandA);           -- NOT (unary, operandA only)
            end case;
            -- =============================
        end if;
    end process;

    -- Display the full 16-bit result for all operations (unchanged)
    process(result)
    begin
        display_value <= result;
    end process;

    -- HEX0-HEX3: result nibbles, unchanged
    seg0 : seg7_display port map (in_val => display_value(3 downto 0),   out_seg => HEX0);
    seg1 : seg7_display port map (in_val => display_value(7 downto 4),   out_seg => HEX1);
    seg2 : seg7_display port map (in_val => display_value(11 downto 8),  out_seg => HEX2);
    seg3 : seg7_display port map (in_val => display_value(15 downto 12), out_seg => HEX3);

    -- ===== NEW: HEX4 shows the 2-bit operation code (0-3) instead of operandB nibble =====
    hex4_sel <= "00" & operation;
    seg4 : seg7_display port map (in_val => hex4_sel, out_seg => HEX4);

    -- ===== NEW: HEX5 shows mode directly ('A' or 'L'), bypasses seg7_display since
    --            'L' isn't a valid hex digit in that decoder's table =====
    HEX5 <= "0001000" when mode = '0' else  -- 'A' = Arithmetic Mode
            "1000111";                      -- 'L' = Logic Mode

end architecture behavioral;