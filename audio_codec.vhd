library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.sine_package.all;

entity  audio_codec is
port (
----------WM8731 pins-----
AUD_BCLK: out std_logic;
AUD_ADCLRCK:  out std_logic;
AUD_XCK: out std_logic;
AUD_ADCDAT: in std_logic; ---not known
AUD_DACLRCK: out std_logic;
AUD_DACDAT: out std_logic;

---------FPGA pins-----

clock_50: in std_logic;
sw: in std_logic_vector(9 downto 0);
FPGA_I2C_SCLK: out std_logic;
FPGA_I2C_SDAT: inout std_logic;

---------KEYBOARD PINS------
ps2_clk_in : in std_logic;
ps2_data_in : in std_logic;
press_flag  : out std_logic;
press_key   : out std_logic_vector(6 downto 0);

-----------UI------------
shl:in std_logic;   -- button 1
shr:in std_logic;   -- button 2
volume_up:in std_logic;   -- button 3
volume_down:in std_logic; -- button 4
volume_up_led: out std_logic; -- volume up led
volume_down_led: out std_logic; -- volume down led
mute_led: out std_logic;
led_out : out std_logic_vector(10 downto 0);
carrier_select_in : in std_logic_vector(1 downto 0); --00 sin, 01 square, 10 sawtooth
out_note_number : out std_logic_vector(6 downto 0);
--------record----------
record_sw : in std_logic;
replay_sw : in std_logic;
replay_led : out std_logic;
record_led : out std_logic   -- toggel 3 times when replay
);

end audio_codec;


architecture main of audio_codec is

signal aud_mono: std_logic_vector(31 downto 0):=(others=>'0');
signal ROM_OUT: std_logic_vector(15 downto 0);
signal clock_12 : std_logic;
signal WM_i2c_busy: std_logic;
signal WM_i2c_done: std_logic;
signal WM_i2c_send_flag: std_logic;
signal WM_i2c_data: std_logic_vector(15 downto 0);
signal DA_CLR: std_logic:='0';
signal clk_divider:unsigned(8 downto 0);
signal tone_clock : std_logic;
signal cshl : std_logic:= '0';
signal cshr : std_logic:= '0';
signal cvolume_up : std_logic:= '0';
signal cvolume_down : std_logic:= '0';
signal cvolume_up_state : std_logic:= '0';
signal cvolume_down_state : std_logic:= '0';
signal cshl_state : std_logic := '0';
signal cshr_state : std_logic := '0';
signal start : std_logic := '1';
signal shift_count : integer range -2 to 2 := 0;
signal key_press_flag : std_logic:= '0';
signal counter_max, counter_max_div2,counter_max_div4, counter_max_div8, counter_max_div16, counter_max_div32,
		counter_max_mul2,counter_max_mul4, counter_max_mul8, counter_max_mul16, counter_max_mul32 :integer;
signal count, count_div2, count_div4, count_div8, count_div16, count_div32,
		count_mul2, count_mul4, count_mul8, count_mul16, count_mul32 : integer range 0 to 5000000:= 0;
signal sig_press_key : std_logic_vector(6 downto 0);
signal tmp_mul32, tmp_mul16, tmp_mul8, tmp_mul4,tmp_mul2,tmp,
		tmp_div2,tmp_div4, tmp_div8, tmp_div16, tmp_div32 : std_logic:= '0';   -- key clock

signal led_series : std_logic_vector(10 downto 0) := (others => '0'); --11 leds
signal counter_max_a : integer range 0 to 500:= 111 / 2;
signal counter_max_b : integer range 0 to 500:= 99 / 2;
signal counter_max_c : integer range 0 to 500:= 187 / 2;
signal counter_max_d : integer range 0 to 500:= 166 / 2;
signal counter_max_e : integer range 0 to 500:= 148 / 2;
signal counter_max_f : integer range 0 to 500:= 140 / 2;
signal counter_max_g : integer range 0 to 500:= 123 / 2;
signal led_series_1  : std_logic_vector(10 downto 0) := "11111111111";
signal lrchanel_volume : std_logic_vector(6 downto 0) := "1111001";
signal volume_increment : std_logic_vector(6 downto 0) := "0000001";
signal control : integer range 0 to 3 := 0;
signal cvolume_up_led: std_logic; -- volume up led
signal cvolume_down_led: std_logic; -- volume down led
signal cmute_led: std_logic;
signal sine_out: std_logic_vector(15 downto 0);
signal square_out: std_logic_vector(15 downto 0);
signal sawtooth_out: std_logic_vector(15 downto 0);
signal carrier_select : std_logic_vector(1 downto 0);
signal note_number : std_logic_vector(6 downto 0);

---------------record parameters--------------------
type int_array is array(0 to 100000) of integer;
signal memory_key : int_array;
signal memory_time : int_array;
signal crecord_sw : std_logic := '0';
signal creplay_sw : std_logic;
signal crecord_led : std_logic := '0';   -- toggel 3 times when replay
signal creplay_led : std_logic;
signal rtime_counter : std_logic_vector(30 downto 0);
signal ptime_counter : std_logic_vector(30 downto 0);
signal last_crecord_sw : std_logic := '0';
signal cpress_flag : std_logic := '0';
signal last_cpress_flag : std_logic := '0';
signal index : integer range 0 to 99 := 0;
signal key_index : integer range 0 to 30 := 0;
signal key_nobreak : std_logic_vector(6 downto 0) := "0000000";
signal replay_counter : std_logic_vector(30 downto 0);
signal play_flag : std_logic := '0';
signal replay_press_key : std_logic_vector(6 downto 0);
signal replay_index : integer range 0 to 30 := 0;
signal replay_key_index : integer range 0 to 30 := 0;
signal max_index : integer range 0 to 30 := 0;

 component aud_gen is
 port (
	aud_clock_12: in std_logic;
	aud_bk: out std_logic;
	aud_dalr: out std_logic;
	aud_dadat: out std_logic;
	aud_data_in: in std_logic_vector(31 downto 0)
 ); 
 end component aud_gen;

 component i2c is
 port(
	i2c_busy: out std_logic;
	i2c_scl: out std_logic;
	i2c_send_flag: in std_logic;
	i2c_sda: inout std_logic;
	i2c_addr: in std_logic_vector(7 downto 0);
	i2c_done: out std_logic;
	i2c_data: in std_logic_vector(15 downto 0);
	i2c_clock_50: in std_logic
 );
 end component i2c;
  
 component ps2_key is
 port(
	clk        : IN  STD_LOGIC;
   ps2_clk    : IN  STD_LOGIC;
   ps2_data   : IN  STD_LOGIC;
   ascii_new  : OUT STD_LOGIC;
   ascii_code : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
 );
 end component ps2_key;
 
 component sine_wave is
 port( 
	clock, reset, enable: in std_logic;
   wave_out: out sine_vector_type
 );
 end component sine_wave;
 
 component square_wave is
 port( 
	clock, reset, enable: in std_logic;
   wave_out: out sine_vector_type
 );
 end component square_wave;
 
  component sawtooth_wave is
 port( 
	clock, reset, enable: in std_logic;
   wave_out: out sine_vector_type
 );
 end component sawtooth_wave;
 
 
begin
sound: component aud_gen
		port map(
		aud_clock_12=>clock_12,
		aud_bk=>AUD_BCLK,   ---out
		aud_dalr=>DA_CLR,
		aud_dadat=>AUD_DACDAT,	---out
		aud_data_in=>aud_mono
		);
		
key_press : component ps2_key
		port map(
		clk=>clock_50,
      ps2_clk=>ps2_clk_in,
      ps2_data=>ps2_data_in,
      ascii_new=>key_press_flag,
      ascii_code=>sig_press_key
		);

WM8731: component i2c 
		port map(
			i2c_busy=>WM_i2c_busy,
			i2c_scl=>FPGA_I2C_SCLK,
			i2c_send_flag=>WM_i2c_send_flag,
			i2c_sda=>FPGA_I2C_SDAT,
			i2c_addr=>"00110100",
			i2c_done=>WM_i2c_done,
			i2c_data=>WM_i2c_data,
			i2c_clock_50=>clock_50	
		);
-----------generate different tone sine wave-----
sine_tone :process(start, clock_50, clk_divider, shift_count, key_press_flag, tmp_mul32, tmp_mul16, 
			tmp_mul8, tmp_mul4, tmp_mul2, tmp, tmp_div2, tmp_div4, tmp_div8, tmp_div16, tmp_div32)
begin
	if start = '1' then
			tone_clock <= clk_divider(1);  ---at start, clock at 12.5MHz, 50MHz / 4
			start <= '0';
		end if;
		press_flag <= key_press_flag;
		if (rising_edge(clock_50)) then
--------------------output led, button value-----------------------
		volume_up_led <= cvolume_up_led; -- volume up led
      volume_down_led <= cvolume_down_led; -- volume down led
		mute_led <= cmute_led;          ------mute led
		out_note_number <= note_number;
--------------------key map control button 1 2---------------------
		if shl = '0' then
			cshl <= '1';
		else
			cshl <= '0';
			cshl_state <= '1';
		end if;
		if shr = '0' then
			cshr <= '1';
		else
			cshr <= '0';
			cshr_state <= '1';
		end if;
		if cshl = '1' AND cshl_state = '1' then      ---shift key map left
			if shift_count > -4 then
				shift_count <= shift_count - 1;
			end if;
			cshl_state <= '0';
		end if;
		if cshr = '1' AND cshr_state = '1' then      ---shift key map right
			if shift_count < 3 then
				shift_count <= shift_count + 1;
			end if;
			cshr_state <= '0';
		end if;
------------------ volume control button 3 4--------------------
		if volume_down = '0' then
			cvolume_down <= '1';
		else
			cvolume_down <= '0';
			cvolume_down_state <= '1';
			cvolume_down_led <= '0';
		end if;
		if volume_up = '0' then
			cvolume_up <= '1';
		else
			cvolume_up <= '0';
			cvolume_up_state <= '1';
			cvolume_up_led <= '0';
		end if;
		if cvolume_down = '1' AND cvolume_down_state = '1' then      ---turn volume down by 1 
			if lrchanel_volume > "0000000" then
				lrchanel_volume <= lrchanel_volume - volume_increment;
				cvolume_down_led <= '1';
			end if;
			cvolume_down_state <= '0';
		end if;
		if cvolume_up = '1' AND cvolume_up_state = '1' then      ---turn volume up by 1
			if lrchanel_volume < "1111111" then
				lrchanel_volume <= lrchanel_volume + volume_increment;
				cvolume_up_led <= '1';
			end if;
			cvolume_up_state <= '0';
		end if;
	end if;
--------------------end volume control-------------------------


----since shift C4 to C3 resulted into change of frequency from
----261.63 to 130.81, thus reduce tone generator clock will do the job
	tone_clock <= tmp;          ----key_clock.
	if shift_count = -5 then
		tone_clock <= tmp_mul32;    -- /32
		note_number <= "1000000";  -- 0
	elsif shift_count = -4 then
		tone_clock <= tmp_mul16;    -- /16
		note_number <= "1111001";  -- 1
	elsif shift_count = -3 then
		tone_clock <= tmp_mul8;    -- /8
		note_number <= "0100100";  -- 2
	elsif shift_count = -2 then
		tone_clock <= tmp_mul4;    -- /4
		note_number <= "0110000";  -- 3
	elsif shift_count = -1 then
		tone_clock <= tmp_mul2;    -- /2
		note_number <= "0011001";  -- 4
	end if;
	if shift_count = 0 then
		tone_clock <= tmp;    -- 0
		note_number <= "0010010";  -- 5
	elsif shift_count = 1 then
		tone_clock <= tmp_div2; -- *2
		note_number <= "0000010";  -- 6
	elsif shift_count = 2 then
		tone_clock <= tmp_div4;    -- *4
		note_number <= "1111000";  -- 7
	elsif shift_count = 3 then
		tone_clock <= tmp_div8;    -- *8
		note_number <= "0000000";  -- 8
	elsif shift_count = 4 then
		tone_clock <= tmp_div16;    -- *16
		note_number <= "0001000";  -- 9
	elsif shift_count = 5 then
		tone_clock <= tmp_div32;    -- *32
		note_number <= "0001000";  -- 9
	end if;
-------------display the current key page---------
	if shift_count > 0 then  --- shift right, increase tone
		led_series(10 downto 0) <= (others => '0');
		led_series(5 downto (5 - shift_count)) <= led_series_1(5 downto (5 - shift_count));    -- if shift_count = 2, 00000111000
	else
		led_series(10 downto 0) <= (others => '0');
		led_series((5 - shift_count) downto 5) <= led_series_1((5 - shift_count) downto 5);      -- if shift_count = -2, (7 downto 5) = 1, "00001100000"
	end if;
	
	led_out <= led_series;
------------------------------------------------------------
end process sine_tone;

record_process : process(clock_50)
begin
	if (rising_edge(clock_50)) then
		------------detect record pressed, and record time------------
		---1. when record button is pressed, reset the counter at the first time frame.
		---2. increment the rtime_counter, and restore the counter value when a key is pressed in the first time frame.
		---   reset the ptime_counter
		---3. increment the ptime_counter for the rest of time frame when a key is pressed. reset rtime_counter every time.
		---4. if key is let go, in the first time frame, record the pressed time.
		--------------------------------------------------------------
		record_led <= crecord_led;
		crecord_sw <= record_sw;
		cpress_flag <= key_press_flag;
		
		if (crecord_sw = '1') then
			crecord_led <= '1';
			if (last_crecord_sw = '0') then
				rtime_counter <= (others => '0');   --reset counter when sw is pressed at the first time frame.
			else	
				rtime_counter <= rtime_counter + 1;
				if (cpress_flag = '1') then
					if (last_cpress_flag = '0') then  --record rest time 
						memory_time(index) <= to_integer(unsigned(rtime_counter));
						index <= index + 1;
						ptime_counter <= (others => '0');
					else -----record key pressed time
						ptime_counter <= ptime_counter + 1;
						rtime_counter <= (others => '0');
					end if;
				end if;
				if (last_cpress_flag = '1') then
					-----------detect which key is pressed-----------
					if (cpress_flag = '0') then 
						key_index <= key_index + 1;
						memory_time(index) <= to_integer(unsigned(ptime_counter));
						rtime_counter <= (others => '0');
						index <= index + 1;
					else
						if key_nobreak = "0001000" then   --a
							memory_key(key_index) <= 1;
						elsif key_nobreak = "0000011" then  --b
							memory_key(key_index) <= 2;
						elsif key_nobreak = "1000110" then  --c
							memory_key(key_index) <= 3;
						elsif key_nobreak = "0100001" then  --d
							memory_key(key_index) <= 4;
						elsif key_nobreak = "0000110" then  --e
							memory_key(key_index) <= 5;
						elsif key_nobreak = "0001110" then  --f
							memory_key(key_index) <= 6;
						elsif key_nobreak = "0010000" then  --g
							memory_key(key_index) <= 7;
						end if;
					end if;
				end if;
			end if;
		else
			crecord_led <= '0';
			key_index <= 0;     ----when record sw is released, reset index.
			if (NOT(index = 0)) then
				memory_time(index) <= to_integer(unsigned(rtime_counter));
				max_index <= index;
			end if;
			index <= 0;
		end if;
		last_crecord_sw <= crecord_sw;
		last_cpress_flag <= cpress_flag;
	end if;
end process record_process;

replay_process : process(clock_50, replay_press_key) 
begin
	if (rising_edge(clock_50)) then 
		replay_led <= creplay_led;
		creplay_sw <= replay_sw;
	------------when the replay is pressed, reading array values------------------
		if(creplay_sw = '1') then
			creplay_led <= '1';
			replay_counter <= replay_counter + 1;
			if (replay_counter = memory_time(replay_index)) then
			if (replay_index < max_index) then
				replay_index <= replay_index + 1;
			end if;        ---- 0 1 0 1 0 1 0   odd.
				if(NOT(replay_index rem 2 = 1)) then   ---press duration is stored in odd index.
					play_flag <= '1';  --- output sound
					
					-------copy the key interger to the press key--------------
					if (memory_key(replay_key_index)) = 1 then
						replay_press_key <= "0001000";
					elsif memory_key(replay_key_index) = 2 then
						replay_press_key <= "0000011";
					elsif memory_key(replay_key_index) = 3 then
						replay_press_key <= "1000110";
					elsif memory_key(replay_key_index) = 4 then
						replay_press_key <= "0100001";
					elsif memory_key(replay_key_index) = 5 then
						replay_press_key <= "0000110";
					elsif memory_key(replay_key_index) = 6 then
						replay_press_key <= "0001110";
					elsif memory_key(replay_key_index) = 7 then
						replay_press_key <= "0010000";
					end if;
					replay_key_index <= replay_key_index + 1;
				else
					play_flag <= '0';
				end if;
				replay_counter <= (others => '0');  -- reset the counter when reach time in memory
			end if;
			if (replay_index = max_index) then
				play_flag <= '0';
			end if;
		else
			replay_index <= 0;
			replay_key_index <= 0;
			replay_counter <= (others => '0');
			creplay_led <= '0';
			play_flag <= '0'; --stop the sound.
		end if;
	end if;
end process replay_process;


sixteen_bit_sine: component sine_wave
		port map( 
			clock=> tone_clock,
			reset=>'0',
			enable=>'1',
			wave_out=>sine_out
		);
		
sixteen_bit_square: component square_wave
		port map( 
			clock=> tone_clock,
			reset=>'0',
			enable=>'1',
			wave_out=>square_out
		);
		
sixteen_bit_sawtooth: component sawtooth_wave
		port map( 
			clock=> tone_clock,
			reset=>'0',
			enable=>'1',
			wave_out=>sawtooth_out
		);
		
AUD_XCK<=clock_12;   ---out
AUD_DACLRCK<=DA_CLR;   ---out

process(clock_50)
begin
if rising_edge(clock_50) then
	carrier_select <= carrier_select_in;
	if carrier_select = "00" then
		ROM_OUT <= sine_out;
	elsif carrier_select = "01" then
		ROM_OUT <= square_out;
	elsif carrier_select = "10" then
		ROM_OUT <= sawtooth_out;
	end if;
end if;
end process;

p_clk_divider: process(clock_50)
begin 
	if rising_edge(clock_50) then
		clk_divider <= clk_divider + 1;
	end if;
	clock_12 <= clk_divider(1);
	
end process p_clk_divider;

process(clock_50)
begin 
	press_key <= sig_press_key;
	key_nobreak <= sig_press_key;   ---the key signal with no break.
	if sig_press_key = "0001000" then   --a
		counter_max <= counter_max_a;
	elsif sig_press_key = "0000011" then  --b
		counter_max <= counter_max_b;
	elsif sig_press_key = "1000110" then  --c
		counter_max <= counter_max_c;
	elsif sig_press_key = "0100001" then  --d
		counter_max <= counter_max_d;
	elsif sig_press_key = "0000110" then  --e
		counter_max <= counter_max_e;
	elsif sig_press_key = "0001110" then  --f
		counter_max <= counter_max_f;
	elsif sig_press_key = "0010000" then  --g
		counter_max <= counter_max_g;
	end if;
	
	if (creplay_sw = '1') then
		if replay_press_key = "0001000" then   --a
			counter_max <= counter_max_a;
		elsif replay_press_key = "0000011" then  --b
			counter_max <= counter_max_b;
		elsif replay_press_key = "1000110" then  --c
			counter_max <= counter_max_c;
		elsif replay_press_key = "0100001" then  --d
			counter_max <= counter_max_d;
		elsif replay_press_key = "0000110" then  --e
			counter_max <= counter_max_e;
		elsif replay_press_key = "0001110" then  --f
			counter_max <= counter_max_f;
		elsif replay_press_key = "0010000" then  --g
			counter_max <= counter_max_g;
		end if;
	end if;

	counter_max_div2 <= counter_max / 2;
	counter_max_div4 <= counter_max / 4;
	counter_max_div8 <= counter_max / 8;
	counter_max_div16 <= counter_max / 16;
	counter_max_div32 <= counter_max / 32;
	counter_max_mul2 <= counter_max * 2;
	counter_max_mul4 <= counter_max * 4;
	counter_max_mul8 <= counter_max * 8;
	counter_max_mul16 <= counter_max * 16;
	counter_max_mul32 <= counter_max * 32;
	
	if (clock_50'event and clock_50 = '1') then
		count <= count + 1;
		count_div2 <= count_div2 + 1;
		count_div4 <= count_div4 + 1;
		count_div8 <= count_div8 + 1;
		count_div16 <= count_div16 + 1;
		count_div32 <= count_div32 + 1;
		count_mul2 <= count_mul2 + 1;
		count_mul4 <= count_mul4 + 1;
		count_mul8 <= count_mul8 + 1;
		count_mul16 <= count_mul16 + 1;
		count_mul32 <= count_mul32 + 1;
		if (count = counter_max) then   -- 
			tmp <= not tmp;
			count <= 0;
		end if;
		if (count_div2 = counter_max_div2) then
			tmp_div2 <= not tmp_div2;
			count_div2 <= 0;
		end if;
		if (count_div4 = counter_max_div4) then
			tmp_div4 <= not tmp_div4;
			count_div4 <= 0;
		end if;
		if (count_div8 = counter_max_div8) then
			tmp_div8 <= not tmp_div8;
			count_div8 <= 0;
		end if;
		if (count_div16 = counter_max_div16) then
			tmp_div16 <= not tmp_div16;
			count_div16 <= 0;
		end if;
		if (count_div32 = counter_max_div32) then
			tmp_div32 <= not tmp_div32;
			count_div32 <= 0;
		end if;
		if (count_mul2 = counter_max_mul2) then
			tmp_mul2 <= not tmp_mul2;
			count_mul2 <= 0;
		end if;
		if (count_mul4 = counter_max_mul4) then
			tmp_mul4 <= not tmp_mul4;
			count_mul4 <= 0;
		end if;
		if (count_mul8 = counter_max_mul8) then
			tmp_mul8 <= not tmp_mul8;
			count_mul8 <= 0;
		end if;
		if (count_mul16 = counter_max_mul16) then
			tmp_mul16 <= not tmp_mul16;
			count_mul16 <= 0;
		end if;
		if (count_mul32 = counter_max_mul32) then
			tmp_mul32 <= not tmp_mul32;
			count_mul32 <= 0;
		end if;
	end if;
end process;

process (clock_12)
begin
if rising_edge(clock_12)then
		if key_press_flag = '0' then
			aud_mono(31 downto 0) <= (others => '0');
		else
			aud_mono(15 downto 0)<=ROM_OUT;----mono sound
			aud_mono(31 downto 16)<=ROM_OUT;
		end if;
		if creplay_sw = '1' then   -- if the replay sw is pressed
			if play_flag = '1' then  -- if the index is at odd position
				aud_mono(15 downto 0)<=ROM_OUT;----mono sound
				aud_mono(31 downto 16)<=ROM_OUT;
			else  -- if the index is at the even position, mute the sound.
				aud_mono(31 downto 0) <= (others => '0');
			end if;
		end if;
end if;
end process;

process (clock_50)
begin
	if rising_edge (clock_50)then
		if(sw(6) = '1')then
		WM_i2c_send_flag<='0';
		end if;
	end if;
 if rising_edge(clock_50) and WM_i2c_busy='0' then
		if sw(0) = '0' then
			WM_i2c_data(15 downto 9)<="0001001";---activ interface
			WM_i2c_data(8 downto 0)<="111111111";
			WM_i2c_send_flag<='1';
		elsif sw(1) = '0' then
			WM_i2c_data(15 downto 9)<="0000111";----Digital Interface: DSP, 16 bit, slave mode
			WM_i2c_data(8 downto 0)<="000010011";	
			WM_i2c_send_flag<='1';
		elsif sw(2) = '0' then---ADC of, DAC on, Linout ON, Power ON
			WM_i2c_data(15 downto 9)<="0000110";
			WM_i2c_data(8 downto 0)<="000000111";
			WM_i2c_send_flag<='1';
		elsif sw(3) = '0' then---Enable DAC to LINOUT
			WM_i2c_data(15 downto 9)<="0000100";
			WM_i2c_data(8 downto 0)<="000010010";
			WM_i2c_send_flag<='1';
		--------volume control both chanel-------
		elsif sw(4) = '0' then
			WM_i2c_data(15 downto 9)<="0000010";
			WM_i2c_data(8 downto 7)<="10";
			WM_i2c_data(6 downto 0)<=lrchanel_volume(6 downto 0);
			if sw(5) = '1' then         ---------mute both chanel
				WM_i2c_data(6 downto 0) <= "0000000";
				cmute_led <= '1';
			else
				cmute_led <= '0';
			end if;
			WM_i2c_send_flag<='1';
		end if;
end if;
end process;
end main;