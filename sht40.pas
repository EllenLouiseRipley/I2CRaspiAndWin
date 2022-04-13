unit SHT40;

{$mode objfpc}{$H+}
{
Command            response length              Description
 (hex)             incl. CRC (bytes)           [return values]

0xFD               6                           measure T & RH with high precision (high repeatability)
                                               [2 * 8-bit T-data; 8-bit CRC; 2 * 8-bit RH-data; 8-bit CRC]

0xF6               6                           measure T & RH with medium precision (medium repeatability)
                                               [2 * 8-bit T-data; 8-bit CRC; 2 * 8-bit RH-data; 8-bit CRC]

0xE0               6                           measure T & RH with lowest precision (low repeatability)
                                               [2 * 8-bit T-data; 8-bit CRC; 2 * 8-bit RH-data; 8-bit CRC]

0x89               6                           read serial number
                                               [2 * 8-bit data; 8-bit CRC; 2 * 8-bit data; 8-bit CRC]

0x94               -                           soft reset
                                               [ACK]

0x39               6                           activate heater with 200mW for 1s, including a high precision
                                               measurement just before deactivation
                                               [2 * 8-bit T-data; 8-bit CRC; 2 * 8-bit RH-data; 8-bit CRC]

0x32               6                           activate heater with 200mW for 0.1s including a high precision
                                               measurement just before deactivation
                                               [2 * 8-bit T-data; 8-bit CRC; 2 * 8-bit RH-data; 8-bit CRC]

0x2F               6                           activate heater with 110mW for 1s including a high precision
                                               measurement just before deactivation
                                               [2 * 8-bit T-data; 8-bit CRC; 2 * 8-bit RH-data; 8-bit CRC]

0x24               6                           activate heater with 110mW for 0.1s including a high precision
                                               measurement just before deactivation
                                               [2 * 8-bit T-data; 8-bit CRC; 2 * 8-bit RH-data; 8-bit CRC]

0x1E               6                           activate heater with 20mW for 1s including a high precision
                                               measurement just before deactivation
                                               [2 * 8-bit T-data; 8-bit CRC; 2 * 8-bit RH-data; 8-bit CRC]

0x15               6                           activate heater with 20mW for 0.1s including a high precision
                                               measurement just before deactivation
                                               [2 * 8-bit T-data; 8-bit CRC; 2 * 8-bit RH-data; 8-bit CRC]
t_degC = -45 + 175 * t_ticks/65535
rh_pRH = -6 + 125 * rh_ticks/65535
if (rh_pRH > 100): rh_pRH = 100
if (rh_pRH < 0): rh_pRH = 0
}

interface

uses
  Classes, SysUtils, SensirionCRCGen, math, i2cbasic;
const
  I2C_SLAVE = 1795;  // 0x0703 - 1795 dec
  sht40_cmd_get_serial_ID :  byte = $89;
  sht40_cmd_get_t_h_hi    :  byte = $FD;
  sht40_serial_id_num_bytes = 6;
var
  loc_temperature,   loc_humidity,
sht40_temperature, sht40_humidity  : real;
sht40_serial_lo, sht40_serial_hi   : word;

function sht40_get_serial_ID (i2c_deviceaddress : ptruint) : LongInt;
function sht40_get_t_rh_hi   (i2c_deviceaddress : ptruint) : LongInt;

function CH2O (T, rh : real) : real;
function H2Opsat (T : real) : real;
function Dewpoint (T, H2Oppart: real) : real;

implementation

function dewpoint (T, H2Oppart: real) : real;
var
  td : real;
begin
  td:=T;
  while H2Opsat(td) >= H2Oppart do td:=td-0.01;
  result:=td;
end;

function CH2O (T, rh : real) : real;
const
//over water Coefficients
a0 =  6.107799961;
a1 =  4.436518521E-1;
a2 =  1.428945805E-2;
a3 =  2.650648471E-4;
a4 =  3.031240396E-6;
a5 =  2.034080948E-8;
a6 =  6.136820929E-11;
//over ice Coefficients
b0 =  6.109177956;
b1 =  5.034698970E-1;
b2 =  1.886013408E-2;
b3 =  4.176223716E-4;
b4 =  5.824720280E-6;
b5 =  4.838803174E-8;
b6 =  1.838826904E-10;

R  =  8.31446261815324;         //  Universal gas constant
M  =  18.01528;                 //  molar mass of water

var
 sat_vap_press,
 sat_vap_press_w,
 sat_vap_press_i,
 Mass_conc_H2O        : real;

begin
  sat_vap_press_w :=a0 + T*(a1 + T*(a2 + T*(a3 + T*(a4 + T*(a5 + T*a6)))));
  sat_vap_press_i :=b0 + T*(b1 + T*(b2 + T*(b3 + T*(b4 + T*(b5 + T*b6)))));

  sat_vap_press:=min(sat_vap_press_w, sat_vap_press_i);              // in hPa

  Mass_conc_H2O  :=  rh * sat_vap_press * M / (R * (T + 273.15));    //

  result:=  Mass_conc_H2O;
end;

function H2Opsat (T : real) : real;
const
//Temperature range -50°C to +50°C
//over water Coefficients
  a0 =  6.107799961;
  a1 =  4.436518521E-1;
  a2 =  1.428945805E-2;
  a3 =  2.650648471E-4;
  a4 =  3.031240396E-6;
  a5 =  2.034080948E-8;
  a6 =  6.136820929E-11;
//over ice Coefficients
  b0 =  6.109177956;
  b1 =  5.034698970E-1;
  b2 =  1.886013408E-2;
  b3 =  4.176223716E-4;
  b4 =  5.824720280E-6;
  b5 =  4.838803174E-8;
  b6 =  1.838826904E-10;
//Temperature range -100°C to -50°C
//over water Coefficients
  c0 =  4.866786841;
  c1 =  3.152625546E-1;
  c2 =  8.640188586E-3;
  c3 =  1.279669658E-4;
  c4 =  1.077955914E-6;
  c5 =  4.886796102E-9;
  c6 =  9.296508850E-12;
//over ice Coefficients
  d0 =  3.927659727;
  d1 =  2.643578680E-1;
  d2 =  7.505070860E-3;
  d3 =  1.147668232E-4;
  d4 =  9.948650743E-7;
  d5 =  4.626362556E-9;
  d6 =  9.001382935E-12;

  R  =  8.31446261815324;         //  Universal gas constant
  M  =  18.01528;                 //  molar mass of water

var
 sat_vap_press,
 sat_vap_press_w,
 sat_vap_press_i,
 Mass_conc_H2O        : real;

begin
  if t>-50 then begin
    sat_vap_press_w :=a0 + T*(a1 + T*(a2 + T*(a3 + T*(a4 + T*(a5 + T*a6)))));
    sat_vap_press_i :=b0 + T*(b1 + T*(b2 + T*(b3 + T*(b4 + T*(b5 + T*b6)))));
  end else
  begin
    sat_vap_press_w :=c0 + T*(c1 + T*(c2 + T*(c3 + T*(c4 + T*(c5 + T*c6)))));
    sat_vap_press_i :=d0 + T*(d1 + T*(d2 + T*(d3 + T*(d4 + T*(d5 + T*d6)))));
  end;
  sat_vap_press:=min(sat_vap_press_w, sat_vap_press_i);              // in hPa
  result:=  sat_vap_press;
end;

function sht40_get_serial_ID (i2c_deviceaddress : ptruint) : LongInt;
var
  rslt : integer;
  crc : uint8;
  locbuf : array[0..1] of byte;
begin
  result:=i2cfpIOCtl(i2c_deviceaddress);
  if result<0 then exit;
  data[0]:= sht40_cmd_get_serial_ID;
  count:=1;
  result:=i2cwrite(data,count);
  if result<0 then exit;
  sleep(10);
  rslt:=i2cread(data,sht40_serial_id_num_bytes);
  if (rslt <> sht40_serial_id_num_bytes) then
  begin
    result:=rslt;
    exit;
  end;
  result:=-1;
  locbuf[0]:=data[0];
  locbuf[1]:=data[1];
  crc:=sensirion_i2c_generate_crc(locbuf);
  crc8_n_err:= crc<>data[2];
  if crc8_n_err then exit;
  locbuf[0]:=data[3];
  locbuf[1]:=data[4];
  crc:=sensirion_i2c_generate_crc(locbuf);
  crc8_n_err:=crc<>data[5];
  if crc8_n_err then exit;
  sht40_serial_lo:= data[0] * 256 +  data[1];
  sht40_serial_hi:= data[3] * 256 +  data[4];
  result:=0;
end;

function sht40_get_t_rh_hi (i2c_deviceaddress : ptruint)  : LongInt;
var
  rslt, i : integer;
  crc : uint8;
  locbuf : array[0..1] of byte;
begin
  result:=-1;
  result := i2cfpIOCtl(i2c_deviceaddress);
  if result<0 then exit;
  data[0]:=sht40_cmd_get_t_h_hi;
  count :=1;
  rslt:=i2cwrite(data,count);
  if (rslt<>count) then
  begin
    result:=rslt;
    exit;
  end;
  sleep(100); //nicht kleiner!
  count :=6;
  rslt:=i2cread(data,count);
  if (rslt<>count) then
  begin
    result:=rslt;
    exit;
  end;
  locbuf[0]:=data[0];
  locbuf[1]:=data[1];
  crc:=sensirion_i2c_generate_crc(locbuf);
  crc8_t_err:= crc<>data[2];
  if crc8_t_err then loc_temperature := 22.47;
  locbuf[0]:=data[3];
  locbuf[1]:=data[4];
  crc:=sensirion_i2c_generate_crc(locbuf);
  crc8_h_err:=crc<>data[5];
  if crc8_h_err then loc_humidity := 65.11;
  if not (crc8_t_err or crc8_h_err)
  {
  t_degC = -45 + 175 * t_ticks/65535
  rh_pRH =  -6 + 125 * rh_ticks/65535
  if (rh_pRH > 100): rh_pRH = 100
  if (rh_pRH < 0): rh_pRH = 0
  }
  then begin
    i:= data[0] * 256 + data[1];
    loc_temperature := (175 * i/ 65535.0) - 45;
    sht40_temperature:= loc_temperature;
    i:= data[3] * 256 + data[4];
    loc_humidity := (125 * i / 65535.0) - 6;
    if loc_humidity >100 then  loc_humidity:=100;
    if loc_humidity <0 then  loc_humidity:=0;
    sht40_humidity:=loc_humidity;
    result:=0;
    exit;
  end
  else begin
    loc_temperature := 22.47;
    loc_humidity := 65.11;
    exit;
  end;
  result:=0;
end;

end.

