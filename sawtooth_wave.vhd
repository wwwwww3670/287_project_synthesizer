-- Synthesisable design for a sine wave generator
-- Copyright Doulos Ltd
-- SD, 07 Aug 2003

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.sawtooth_package.all;

entity sawtooth_wave is
  port( 
  clock : in std_logic;
  reset : in std_logic;
  enable : in std_logic;
  wave_out: out sine_vector_type);
end;

architecture arch1 of sawtooth_wave is
  signal table_index: table_index_type:= 0;
  signal positive_cycle: boolean;
begin

  process( clock, reset )
  begin
    if rising_edge( clock ) then
		if enable = '1' then
			table_index <= table_index + 1;
			if table_index = 255 then
				positive_cycle <= not positive_cycle;
				table_index <= 0;
			end if;
		end if;
	 end if;
  end process;
      

  process( table_index, positive_cycle )
    variable table_value: table_value_type;
  begin
	 if positive_cycle then
		table_value := get_table_value( table_index );
      wave_out <= std_logic_vector(to_signed(table_value,sine_vector_type'length));
    else
		table_value := get_table_value( 255 - table_index );
      wave_out <= std_logic_vector(to_signed(-table_value,sine_vector_type'length));
    end if;
  end process;

end;

