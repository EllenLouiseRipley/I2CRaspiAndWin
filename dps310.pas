unit DPS310;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, math, i2cbasic;
Type
  TCS = (ASIC,MEMS,ERR);

const

// Compensation Scale Factors
// Oversampling Rate          | Scale Factor (kP or kT)
// ---------------------------|------------------------
//   1       (single)         |  524288
//   2 times (Low Power)      | 1572864
//   4 times                  | 3670016
//   8 times                  | 7864320
//  16 times (Standard)       |  253952
//  32 times                  |  516096
//  64 times (High Precision) | 1040384  <- Configured
// 128 times                  | 2088960
__kP = 1040384;               // as above
__kT = 1040384;               // as above

var
  reg_Cal_Array  : array  [0..63] of byte;
  C0r, C1r, C00r, C01r, C10r, C11r, C20r, C21r, C30r : uint32;
  C0 , C1 , C00 , C01 , C10 , C11 , C20 , C21 , C30  : int32;
  t1, t2, t3, p1, p2, p3 : byte;
  R0x06          : byte = 0;
  R0x07          : byte = 0;
  R0x08          : byte = 0;
  R0x09          : byte = 0;
  R0x28          : byte = 0;
  Traw2s, Praw2s : uint32;
  Traw, Praw     : int32;
  Traw_sc, Praw_sc   : real;
  Pcomp, Tcomp       : real;
  loc_elevation,
  DPS310_pressure    : real;
  DPS310_temperature : real;
  DPS310_temp_srce   : TCS;
  DPS310_prod_ID     : byte;

function getTwosComplement(raw_val, length :int32): int32;
function sealevelreduction(feuchte, temperatur, elevation : real) : real;

function DPS310_readProductID     ( i2c_deviceaddress : ptruint)  : longint;
function DPS310_reset_flushFifo   ( i2c_deviceaddress : ptruint)  : longint;
function DPS310_correctTemperature( i2c_deviceaddress : ptruint)  : longint;
function DPS310_getTempCompSource ( i2c_deviceaddress : ptruint)  : longint;
function DPS310_readCoefficients  ( i2c_deviceaddress : ptruint)  : longint;
function DPS310_setMeasParams     ( i2c_deviceaddress : ptruint)  : longint;
function DPS310_readTemperature   ( i2c_deviceaddress : ptruint)  : longint;
function DPS310_readPressure      ( i2c_deviceaddress : ptruint)  : longint;

const
  I2C_SLAVE         = 1795;  // 0x0703 - 1795 dec

implementation

function getTwosComplement(raw_val, length : int32) : int32;
{
Args:
    raw_val (int32): Raw value
    length (int32): Max bit length
Results:
    (int32) Two's complement
}
var
  mask : uint32;
  msbset : uint32;

begin
  mask:=1 shl (length-1);
  msbset:= (1  shl length);
  result:=raw_val;
  if (raw_val and mask) = mask then result := raw_val - msbset;
end{ getTwosComplement };

function sealevelreduction(feuchte, temperatur, elevation : real) : real;
(*
 DD = Dampfdruck in hPa
SDD = Sättigungsdampfdruck in hPa
Parameter:
a = 7.5, b = 237.3 für T >= 0
a = 7.6, b = 240.7 für T < 0 über Wasser (Taupunkt)
a = 9.5, b = 265.5 für T < 0 über Eis (Frostpunkt)
Formeln:
SDD(T) = 6.1078 * 10^((a*T)/(b+T))
DD(r,T) = r/100 * SDD(T)
DD(r,T) = r/100 * 6.1078 * 10^((a*T)/(b+T))

*)
const
 a = 7.5;
 b = 237.3;
 g = 9.80665;    // Normfallbeschleunigung standardwert
 R = 287.05;     // Gaskonstante trockener Luft (= R/M)
 alpha = 0.0065; // vertikaler Temperaturgradient
 Ch = 0.12;      // Beiwert zu E
Var
  ph : real;  // Luftdruck in Barometerhöhe (in hPa, auf 0,1 hPa genau)
  P0 : real;  // Luftdruck auf Meeresniveau reduziert (in hPa)
  h  : real;  // Barometerhöhe (in m, auf dm genau)
  ThK : real; // Hüttentemperatur (in K, wobei T(h) = t(h) + 273,15)
  ThC : real; // Hüttentemperatur (in °C)
  Hum : real; // rel. Feuchte (in %)
  E   : real; // Dampfdruck des Wasserdampfanteils (in hPa)
  x   : real; // exponent für Formel
begin
  h   := Elevation;              // adapt to local value
  ThC := Temperatur;
  Hum := Feuchte;

  ph  := DPS310_pressure/100;                          // aus Unit DPS310
  E   := Hum/100 * 6.1078 * 10**(a*ThC/(b+ThC));       // Partialdruck des Wasserdampfs
  ThK := ThC + 273.15;                                 // Temperatur in K
  x   := g/(R*(ThK + Ch*E+alpha*h/2))*h;
  P0  := ph * exp(x);
  result:=P0;
end{ sealevelreduction };

function DPS310_correctTemperature( i2c_deviceaddress : ptruint)  : integer;
{ Correct temperature.
       DPS sometimes indicates a temperature over 60 degree Celsius
       although room temperature is around 20-30 degree Celsius.
       Call this function to fix.  }
begin
  result:=i2cfpIOCtl(i2c_deviceaddress);
  if result < 0 then exit;
  data[0]:=$0E;   // 0x0E, 0xA5
  data[1]:=$A5;
  count :=2;
  result:=i2cwrite(data,count);
  if result <> count then exit;
  data[0]:=$0F;   // 0x0F, 0x96
  data[1]:=$96;
  count :=2;
  result:=i2cwrite(data,count);
  if result <> count then exit;
  data[0]:=$62;   // 0x62, 0x02
  data[1]:=$02;
  count :=2;
  result:=i2cwrite(data,count);
  if result <> count then exit;
  data[0]:=$0E;   // 0x0E, 0x00
  data[1]:=$00;
  count :=2;
  result:=i2cwrite(data,count);
  if result <> count then exit;
  data[0]:=$0F;   // 0x0F, 0x00
  data[1]:=$00;
  count :=2;
  result:=i2cwrite(data,count);
  if result <> count then exit;
  result:=0;
end{ correctTemperature };

function DPS310_reset_flushFifo   ( i2c_deviceaddress : ptruint)  : longint;
begin
  result:=i2cfpIOCtl(i2c_deviceaddress);
  if result<0 then exit;
  data[0]:=$0C;       // 0x0C
  data[1]:=%10001001; //  FIFO FLUSH & SOFT RESET
  count :=2;
  result:=i2cwrite(data,count);
  if result<>count then exit;
  result:=0;
end{ reset_flushFifo };

function DPS310_readProductID( i2c_deviceaddress : ptruint) : longint;
begin
  result:=i2cfpIOCtl(i2c_deviceaddress);
  if result<0 then exit;
  data[0]:=$0D;   // 0x0D
  count :=1;
  result:=i2cwrite(data,count);
  if result<>count then exit;
  sleep(100);
  result:=255;
  count :=1;
  result:=i2cread(data,count);
  if result=count
  then begin
    DPS310_prod_ID:=data[0];
    result:=0;
    exit;
  end;
end{ readProductID };

function DPS310_readCoefficients( i2c_deviceaddress : ptruint)  : longint;
var
  CoefPoint : byte;
begin
  result:=i2cfpIOCtl(i2c_deviceaddress);
  if result<0 then exit;
  for CoefPoint := $10  to $21 do begin
    data[0]:=CoefPoint;                                                         // 0x10 - 0x21 Coefficient Source Registers
    count :=1;                                                                  // One byte per read
    result:=i2cwrite(data,count);
    if result<> count then exit;
    sleep(1);
    result:=i2cread(data,count);
    if result<> count then exit;
    reg_Cal_Array[CoefPoint] := data[0];
  end;
  Result:=0;
// c00r = (src13 << 12) | (src14 << 4) | (src15 >> 4)        c00r datatype is unsigned
// c00  = getTwosComplement(c00r, 20)                        c00  datatype is signed
  C00r:=   reg_Cal_Array[$13] shl 12 or  reg_Cal_Array[$14] shl 4 or reg_Cal_Array[$15] shr 4;
  C00:= getTwosComplement(C00r,20 );
// c10r = ((src15 & 0x0F) << 16) | (src16 << 8) | src17
// c10  = getTwosComplement(c10r, 20)
  C10r:=   (reg_Cal_Array[$15] and $0F) shl 16 or  reg_Cal_Array[$16] shl 8 or reg_Cal_Array[$17];
  C10:= getTwosComplement(C10r,20 );
// c20r = (src1C << 8) | src1D
// c20  = getTwosComplement(c20r, 16) *)
  C20r:= reg_Cal_Array[$1C] shl 8 or reg_Cal_Array[$1D];
  C20:= getTwosComplement(C20r,16 );
// c30r = (src20 << 8) | src21
// c30  = getTwosComplement(c30r, 16) *)
  C30r:= reg_Cal_Array[$20] shl 8 or reg_Cal_Array[$21];
  C30:= getTwosComplement(C30r,16 );
// c01r = (src18 << 8) | src19
// c01  = getTwosComplement(c01r, 16) *)
  C01r:= reg_Cal_Array[$18] shl 8 or reg_Cal_Array[$19];
  C01:= getTwosComplement(C01r,16 );
// c11r = (src1A << 8) | src1B
// c11  = getTwosComplement(c11r, 16) *)
  C11r:= reg_Cal_Array[$1A] shl 8 or reg_Cal_Array[$1B];
  C11:= getTwosComplement(C11r,16 );
// c21r = (src1E < 8) | src1F
// c21  = getTwosComplement(c21r, 16) *)
  C21r:= reg_Cal_Array[$1E] shl 8 or reg_Cal_Array[$1F];
  C21:= getTwosComplement(C21r,16 );
// c0r = (src10 << 4) | (src11 >> 4)
// c0  = getTwosComplement(c0r, 12) *)
  C0r:= reg_Cal_Array[$10] shl 4 or reg_Cal_Array[$1F] shr 4;
  C0:= getTwosComplement(C0r,12 );
// c1r = ((src11 & 0x0F) << 8) | src12
// c1  = getTwosComplement(c1r, 12) *)
  C1r:= (reg_Cal_Array[$11] and $0F) shl 8 or reg_Cal_Array[$12];
  C1:= getTwosComplement(C1r,12 );
end{ readCoefficients };

function DPS310_setMeasParams( i2c_deviceaddress : ptruint)  : longint;
(*
Pressure measurement rate    :  4 Hz
Pressure oversampling rate   : 64 times
Oversampling Rate Setting (64time)
addr, 0x06, 0x26             0b0010 4 measurements/sec 0b0110 64 oversamplings - Pressure Config
addr, 0x07, 0xA6             0b1010 4 measurements/sec 0b0110 64 oversamplings - Temperature Config, Ext Sensor (in MEMS Element)
addr, 0x08, 0x07             0b0000 read only          0b0111 Continuous pressure and temperature measurement
Oversampling Rate Configuration
addr, 0x09, 0x0C             0b0000 no settings        0b1110 Temp result bit shift, Pressure result bit shift, Enable FIFO, SPI Mode default
*)
var
  rslt      : integer;
begin
  rslt:=i2cfpIOCtl(i2c_deviceaddress);
  Result:=rslt;
  if rslt=-1 then exit;
  (*ioctl*)
  Result:=-1;
// addr 0x06, data 0x26  0b0010 4 measurements/sec 0b0110 64 oversamplings - Pressure Config
  data[0]:= $06;        // 0x06 Pressure Configuration
  data[1]:= %00100110;  // 0x26
  count :=2;
  rslt:=i2cwrite(data,count);  //write register 0x06
  if rslt<>count then exit;
  sleep(1);
  data[0]:= $06;       // 0x06 Pressure Configuration
  count :=1;
  rslt:=i2cwrite(data,count);
  if rslt<>count then exit;
  sleep(1);
  rslt:=i2cread(data,count);
  if rslt<>count then exit;
  r0x06:= data[0];
  sleep(1);
// addr 0x07, data 0xA6  0b1010 4 measurements/sec 0b0110 64 oversamplings - Temperature Config, Ext Sensor (in MEMS Element)
  data[0]:= $07;        // 0x07 Temperature Configuration
  data[1]:= %10100110;  // 0xA6
//data[1]:= %00100110;  // 0x26 same but Int Sensor
  count :=2;
  rslt:=i2cwrite(data,count);  //write register 0x07
  if rslt<>count then exit;
  sleep(1);
  data[0]:= $07;       // 0x07 Temperature Configuration
  count :=1;
  rslt:=i2cwrite(data,count);
  if rslt<>count then exit;
  sleep(1);
  rslt:=i2cread(data,count);
  if rslt<>count then exit;
  r0x07:= data[0];
  sleep(1);
// addr 0x08, data 0x07  0b0000 read only          0b0111 Continuous pressure and temperature measurement
  data[0]:= $08;        // 0x08 Sensor Operating Mode and Status
  data[1]:= %00000111;  // 0x07
  count :=2;
  rslt:=i2cwrite(data,count);  //write register 0x08
  if rslt<>count then exit;
  sleep(1);
  data[0]:= $08;       // 0x08 Sensor Operating Mode and Status
  count :=1;
  rslt:=i2cwrite(data,count);
  if rslt<>count then exit;
  sleep(1);
  rslt:=i2cread(data,count);
  if rslt<>count then exit;
  r0x08:= data[0];
  sleep(1);
//addr 0x09 data 0x0C  0b0000 no settings        0b1110 Temp result bit shift, Pressure result bit shift, Enable FIFO, SPI Mode default
  data[0]:= $09;        // 0x09 Interrupt and FIFO configuration
  data[1]:= %00001100;  // 0x0E
  count :=2;
  rslt:=i2cwrite(data,count);  //write register 0x09
  if rslt<>count then exit;
  sleep(1);
  data[0]:= $09;       // 0x09 Interrupt and FIFO configuration
  count :=1;
  rslt:=i2cwrite(data,count);
  if rslt<>count then exit;
  sleep(1);
  rslt:=i2cread(data,count);
  if rslt<>count then exit;
  r0x09:= data[0];
  result:=0;
end{ setMeasParams };

function DPS310_readTemperature( i2c_deviceaddress : ptruint)  : longint;
(*
t1, t2, t3, p1, p2, p3 : byte;
Traw2s, Praw2s : uint32;
Traw, Praw     : int32;
Traw_sc, Praw_sc : real;
Pcomp, Tcomp     : real;
t1 = addr, 0x03)
t2 = addr, 0x04)
t3 = addr, 0x05)
t  = (t1 << 16) | (t2 << 8) | t3
t  = getTwosComplement(t, 24)
p1 = addr, 0x00)
p2 = addr, 0x01)
p3 = addr, 0x02)
p  = (p1 << 16) | (p2 << 8) | p3
p  = getTwosComplement(p, 24)
*)
begin
  DPS310_temperature:=111.22;
  result:=i2cfpIOCtl(i2c_deviceaddress);
  if result <>  0 then exit;
  (*ioctl*)
  data[0]:= $03;       // 0x03 t1 value
  count :=1;
  result:=i2cwrite(data,count);
  if result<>count then exit;
  sleep(1);
  result:=i2cread(data,count);
  t1:=data[0];
  if result<>count then exit;
  sleep(1);
  data[0]:= $04;       // 0x04 t2 value
  count :=1;
  result:=i2cwrite(data,count);
  if result<>count then exit;
  sleep(1);
  result:=i2cread(data,count);
  t2:=data[0];
  if result<>count then exit;
  sleep(1);
  data[0]:= $05;       // 0x05 t3 value
  count :=1;
  result:=i2cwrite(data,count);
  if result<>count then exit;
  sleep(1);
  result:=i2cread(data,count);
  t3:=data[0];
  if result<>count then exit;
  Traw2s:= (t1 shl 16) or (t2 shl 8) or t3;
  Traw:=getTwosComplement(Traw2s, 24);
  Traw_sc := Traw/__kT;
  DPS310_temperature := c0*0.5 + c1*Traw_sc;
  result:=0;
end{ readTemperature };

function DPS310_readPressure( i2c_deviceaddress : ptruint)  : longint;
(*
t1, t2, t3, p1, p2, p3 : byte;
Traw2s, Praw2s : uint32;
Traw, Praw     : int32;
Traw_sc, Praw_sc : real;
Pcomp, Tcomp     : real;
t1 = addr, 0x03)
t2 = addr, 0x04)
t3 = addr, 0x05)
t  = (t1 << 16) | (t2 << 8) | t3
t  = getTwosComplement(t, 24)
p1 = addr, 0x00)
p2 = addr, 0x01)
p3 = addr, 0x02)
p  = (p1 << 16) | (p2 << 8) | p3
p  = getTwosComplement(p, 24)
*)
var
  rslt : integer;
begin
  Pcomp:=1200.99;
  result:=i2cfpIOCtl(i2c_deviceaddress);
  if result<0 then exit;
  data[0]:= $00;       // 0x00 p1 value
  count :=1;
  rslt:=i2cwrite(data,count);
  if rslt<>count then exit;
  sleep(1);
  rslt:=i2cread(data,count);
  if rslt<>count then exit;
  p1:=data[0];
  sleep(1);
  data[0]:= $01;       // 0x01 p2 value
  count :=1;
  rslt:=i2cwrite(data,count);
  if rslt<>count then exit;
  sleep(1);
  rslt:=i2cread(data,count);
  p2:=data[0];
  if rslt<>count then exit;
  sleep(1);
  data[0]:= $02;       // 0x02 p3 value
  count :=1;
  rslt:=i2cwrite(data,count);
  if rslt<>count then exit;
  sleep(1);
  rslt:=i2cread(data,count);
  p3:=data[0];
  if rslt<>count then exit;
  sleep(1);
  Praw2s:= (p1 shl 16) or (p2 shl 8) or p3;
  Praw:=getTwosComplement(Praw2s, 24);
  if rslt<>count then exit;
  Praw_sc := Praw/__kT;
  Pcomp := C00 + Praw_sc * (C10 + Praw_sc * (c20 + Praw_sc * c30)) + Traw_sc * C01 + Traw_sc * Praw_sc * (c11 + Praw_sc * 21);
  DPS310_pressure:= Pcomp;
  result:=0;
end{ readPressure };

function DPS310_getTempCompSource( i2c_deviceaddress : ptruint)  : longint;
// Temperature Coefficients Source
// 1xxx xxxx = External temperature sensor (of pressure sensor MEMS element)
// 0xxx xxxx = Internal temperature sensor (of ASIC)
begin
  result:= i2cfpIOCtl(i2c_deviceaddress);
  if result=-1 then exit;
  data[0]:=$28;   // 0x28 Coefficient Source
  count :=1;
  result:=i2cwrite(data,count);
  if result <> count then exit;
  sleep(1);
  result:=i2cread(data,count);
  if result  <> count then exit;
  if data[0] and $80 = $80
  then DPS310_temp_srce:= MEMS
  else DPS310_temp_srce:= ASIC;
end{ getTempCompSource };

end.

