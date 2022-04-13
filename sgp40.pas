unit SGP40;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SensirionCRCGen, math, i2cbasic;


const
  sgp40_cmd_measure_raw  : array[0..7] of byte = ($26,$0F,$80,$00,$A2,$66,$66,$93);
  sgp40_cmd_measure_test : array[0..1] of byte = ($28,$0E);
  sgp40_cmd_heater_off   : array[0..1] of byte = ($36,$15);
  sgp40_cmd_get_serial_ID: array[0..1] of byte = ($36,$82);
  sgp40_serial_id_num_bytes = 6;

var
  loc_tics               : dword;

function sgp40_probe(i2c_deviceaddress : ptruint) : longint;
function sgp40_get_serial_ID ( i2c_deviceaddress : ptruint) : longint;
function sgp40_get_raw_ticks ( i2c_deviceaddress : ptruint) : longint;

implementation

function sgp40_probe(i2c_deviceaddress : ptruint) : longint;
var
  rslt : integer;
begin
  result:=i2cfpIOCtl(i2c_deviceaddress);
end;

function sgp40_get_raw_ticks ( i2c_deviceaddress : ptruint) : longint;
var
  rslt : integer;
  crc  : uint8;
  locbuf : array [0..1] of byte;
begin
  result:=i2cfpIOCtl(i2c_deviceaddress);
  if result<0 then exit;
  data[0]:=sgp40_cmd_measure_raw [0];
  data[1]:=sgp40_cmd_measure_raw [1];
  data[2]:=sgp40_cmd_measure_raw [2];
  data[3]:=sgp40_cmd_measure_raw [3];
  data[4]:=sgp40_cmd_measure_raw [4];
  data[5]:=sgp40_cmd_measure_raw [5];
  data[6]:=sgp40_cmd_measure_raw [6];
  data[7]:=sgp40_cmd_measure_raw [7];
  count:=8;
  rslt:=i2cwrite(data,count);
  if (rslt<>count) then
  begin
    result:=rslt;
    exit;
  end;
  sleep(500);     //nicht kleiner!
  count :=3;
  rslt:=i2cread(data,count);
  if (rslt<>count) then
  begin
    result:=rslt;
    exit;
  end;
  locbuf[0] := data[0];
  locbuf[1] := data[1];
  crc:=sensirion_i2c_generate_crc(locbuf);
  crc8_v_err := (crc<>data[2]);
  if crc8_v_err then
  begin
    loc_tics:=$10000;
    result:=-1;
    exit;
  end;
  result:=0;
  loc_tics:=data[0]*256 + data[1];
end;

function sgp40_get_serial_ID ( i2c_deviceaddress : ptruint) : longint;
begin
  result:=i2cfpIOCtl(i2c_deviceaddress);
  if result<0 then exit;
  data[0]:=sgp40_cmd_get_serial_ID[0];
  data[1]:=sgp40_cmd_get_serial_ID[1];
  count:=2;
  result:=i2cwrite(data,count);
  if result<>count then exit;
  sleep(10);
  count:=sgp40_serial_id_num_bytes;
  result:=i2cread(data,count);
  if result<>count then exit;
end;


end.

