unit SHT35;
// currently only read of t & H, and status  done


{$mode objfpc}{$H+}
{
unit to read a Sensirion SHT35/SHT85 Sensor providing
a typical accuracy of +/- 1.5 %RH and +/- 0.1 °C.
i2c adresses are 0x44 or 0x45 (Pin selectable).
Measurement is performed using the single shot mode with high repeatability.
Commands available :

sht35_SoftReset : 0x30A2

I2CGeneralReset : 0x06 to adress 0x00

sht35_HeaterOn  : 0x306D
sht35_HeaterOff : 0x3066

sht35_StatusRead: 0xF32D
Response          Description             Default
Bit 15          : Alert 1=true                  1
Bit 14          : spare
Bit 13          : Heater 1=true                 0
Bit 12          : spare
Bit 11          : RH Tracking alert 1=true      0
Bit 10          : T TRacking alert 1=true       0
Bit  9          : spare                         0
Bit  8          : spare                         0
Bit  7          : spare                         0
Bit  6          : spare                         0
Bit  5          : spare                         0
Bit  4          : System reset detected         1
Bit  3          : spare
Bit  2          : spare
Bit  1          : Command status 1= sucessfull  0
Bit  0          : Write CRC status 1=failed     0

sht35_StatusClear : 0x3041
                                              Measurement time
sht35_SingleShot  : 0x2416                      4.5 ms
                    0x240B                      6.5 ms
                    0x2400                     15.5 ms
}

interface

uses
  Classes, SysUtils,  math,
  //my units
  SensirionCRCGen, i2cbasic;

const

  sht35_StatusRead        : word = $F32D;     //done
  sht35_StatusClear       : word = $3041;
  sht35_SoftReset         : word = $30A2;
  sht35_SingleShot_Hi     : word = $2400;     //done
  sht35_SingleShot_Me     : word = $240B;
  sht35_SingleShot_Lo     : word = $2416;
  sht35_HeaterOn          : word = $306D;
  sht35_HeaterOff         : word = $3066;


var
    loc_temperature,   loc_humidity,
  sht35_temperature, sht35_humidity  : real;
  loc_status,
  sht35_status                       : word;

function sht35_do_StatusRead ( i2c_deviceaddress : ptruint) : longint;
function sht35_get_t_rh_hi   ( i2c_deviceaddress : ptruint) : longint;

function CH2O (T, rh : real) : real;
function H2Opsat (T : real) : real;
function H2Oppart (T,rh : real) : real;
function Dewpoint (T, H2Oppart: real) : real;

implementation

function dewpoint (T, H2Oppart: real) : real;           // dew point calculation
var
  td : real;
begin
  td:=T;
  while H2Opsat(td) >= H2Oppart do td:=td-0.01;
  result:=td;
end;

function H2Oppart (T,rh : real) : real;                // partial vapor pressure
begin
  result:=rh/100*H2Opsat(T);
end;

function CH2O (T, rh : real) : real;                   // water mass concentration
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
  if (t>50) or (t<-100) then
  begin
    result:=-1;
    exit;
  end;
  if t>-50 then begin
    sat_vap_press_w :=a0 + T*(a1 + T*(a2 + T*(a3 + T*(a4 + T*(a5 + T*a6)))));
    sat_vap_press_i :=b0 + T*(b1 + T*(b2 + T*(b3 + T*(b4 + T*(b5 + T*b6)))));
  end else
  begin
    sat_vap_press_w :=c0 + T*(c1 + T*(c2 + T*(c3 + T*(c4 + T*(c5 + T*c6)))));
    sat_vap_press_i :=d0 + T*(d1 + T*(d2 + T*(d3 + T*(d4 + T*(d5 + T*d6)))));
  end;
  sat_vap_press:=min(sat_vap_press_w, sat_vap_press_i);              // in hPa
  Mass_conc_H2O  :=  rh * sat_vap_press * M / (R * (T + 273.15));    //
  result:=  Mass_conc_H2O;
end;

function H2Opsat (T : real) : real;            //saturation water vapor pressure
//
// The Computation of Saturation Vapor Pressure
// Paul R. Lowe, et al
// Environmental Prediction Research Facility (Navy)
// Monterey, California
// March 1974
//
// https://apps.dtic.mil/sti/citations/AD0778316
//
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
  if (t>50) or (t<-100) then
  begin
    result:=-1;
    exit;
  end;
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

function sht35_do_StatusRead ( i2c_deviceaddress : ptruint) : longint;
var
  rslt : integer;
  crc : uint8;
  locbuf : array[0..1] of byte;
begin
  result:=i2cfpIOCtl(i2c_deviceaddress);
  if result<0 then exit;
  data[0]:=hi(sht35_StatusRead);
  data[1]:=lo(sht35_StatusRead);
  count :=2;
  result:=-1;
  loc_status := $5555;
  rslt:=i2cwrite(data,count);
  if (rslt<>count) then
  begin
    result:=rslt;
    exit;
  end;
  count :=3;
  rslt:=i2cread(data,count);
  if rslt<>count then
  begin
    result:=rslt;
    exit;
  end;
  begin
    locbuf[0]:=data[0];
    locbuf[1]:=data[1];
    crc:=sensirion_i2c_generate_crc(locbuf);
    if crc<>data[2] then
    begin
      crc8_s_err:=true;
      exit;
    end;
  end;
  if not crc8_s_err then
  begin
    loc_status:=data[0]*256 + data[1];
    result:=0;
  end
  else loc_status := $5555;
end { sht35_do_StatusRead };

function sht35_get_t_rh_hi  ( i2c_deviceaddress : ptruint) : longint;
var
  rslt, i : integer;
  crc : uint8;
  locbuf : array[0..1] of byte;
begin
  result:=-1;
  result:=i2cfpIOCtl(i2c_deviceaddress);
  if result<0 then exit;
  data[0]:=hi(sht35_SingleShot_Hi);
  data[1]:=lo(sht35_SingleShot_Hi);
  count :=2;
  rslt:=i2cwrite(data,count);
//  rslt:=i2cwrite(data[0],count);
  if rslt<>count then
  begin
    result:=rslt;
    exit;
  end;
  sleep(50); //not less, needed for processing of command - I know shall be avoided but for now...
  count :=6;
  rslt:=i2cread(data,count);
  if rslt<>count then
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
  crc8_h_err:= crc<>data[5];
  if crc8_h_err then loc_humidity := 65.11;
  if not (crc8_t_err or crc8_h_err)
{
t_degC = -45 + 175 * t_ticks/65535
rh_pRH =  100 * rh_ticks/65535
}
  then begin
    i:= data[0] * 256 + data[1];
    loc_temperature := (175 * i/ 65535.0) - 45;
    i:= data[3] * 256 + data[4];
    loc_humidity := 100 * i / 65535.0;
    result:=0;
    exit;
  end
  else begin
    loc_temperature := 22.47;
    sht35_temperature:= 22.47;
    loc_humidity := 65.11;
    sht35_humidity:= 65.11;
    exit;
  end;
  result:=0;
end { sht35_get_t_rh_hi } ;

end { unit SHT35 }.

