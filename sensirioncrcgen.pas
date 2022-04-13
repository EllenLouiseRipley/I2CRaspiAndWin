Unit SensirionCRCGen;

Interface

uses   SysUtils;

function TwoHexToUint16(s: string) : uint16;
//
function sensirion_common_bytes_to_uint16_t(buf : array of byte): uint16;
//    return (uint16_t)bytes[0] << 8 | (uint16_t)bytes[1];

function sensirion_i2c_generate_crc(buf : array of byte) : uint8;
//    calculate Sensirion crc value

// Sensirion constants
const
  CRC8_POLYNOMIAL = $31;
  CRC8_INIT       = $FF;
  CRC8_LEN        = 1;
var
  crc8_t_err,                              //crc error temperature data
  crc8_p_err,                              //          pressure data
  crc8_h_err,                              //          humidity data
  crc8_s_err,                              //          status data
  crc8_n_err,                              //          serial number data
  crc8_v_err,                              //          voc/raw tic data
  crc8_d_err      : boolean;               //          general data

implementation

function TwoHexToUint16(s: string) : uint16;
var
  Hex_Buffer : string;
begin
  Hex_Buffer:='0x' + s;
  Result :=  StrToInt(Hex_Buffer);
end;

function sensirion_common_bytes_to_uint16_t(buf : array of byte): uint16;
begin
  Result:= uint16(buf[0] shl 8) or uint16(buf[1]);
end;

function sensirion_i2c_generate_crc(buf : array of byte) : uint8;
var
 I,J : uint16;
 crc : uint8;
begin
  crc:= CRC8_INIT;
  for I := 0 to 1 do
  begin
    crc:= crc xor buf[I];
    for J := 8 downto 1 do
    begin
      if (crc and $80) = $80
      then crc := (crc shl 1) xor CRC8_POLYNOMIAL
      else crc := (crc shl 1);
    end;
  end;
  result := crc;
end;

end.
