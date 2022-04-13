unit Conversions;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Math;

function CH2O     (t, rh : real) : real;               // Temperature °C, relative Humidity in %,
                                                       // -> water mass concentration g/m³
function H2Opsat  (t     : real) : real;               // Temperature °C
                                                       // - > saturation water vapor pressure hPa
function H2Oppart (t, rh : real) : real;               // Temperature °C, relative Humidity in %,
                                                       // -> partial water vapor Pressure hPa
function Dewpoint (t, ppartw : real) : real;           // Temperature °C, partial water vapor Pressure hPa,
                                                       // -> dew point temperature in °C
function SeaLevelReduction(t, rh, e, p : real) : real; // Temperature °C, relative Humidity %, Elevation m, air Pressure absolute hPa
                                                       // -> air pressure sea level hPa

implementation

function SeaLevelReduction(t, rh, e, p : real) : real;
{
QFF
"Atmospheric pressure at a place, reduced to MSL using
the actual temperature at the time of observation as
the mean temperature."

calculation per

DWD, Vorschriften und Betriebsunterlagen 3, BEOBACHTERHANDBUCH, Page 6-11
VuB 3 BHB - Dezember 2015

}
const
 g = 9.80665;    // gravitation constant standard value
 R = 287.05;     // gas constant dry air (= R/M)
 alpha = 0.0065; // vertical temperature gradient
 Ch = 0.12;      // factor for E
Var
  ph : real;  // absolute air pressure at barometer elevation (in hPa, 0.1 hPa accuracy)
  P0 : real;  // sea level reduced air pressure (in hPa)
  h  : real;  // barometer elevation (in m, 0.1 m accuracy)
  ThK : real; // barometer ambient temperature (in K, where as T(h) = t(h) + 273,15)
  ThC : real; // barometer ambient temperature (in °C)
  Hum : real; // rel. humidity (in %)
  Pp  : real; // partial water vapor pressure (in hPa)
  x   : real; // exponent for expression

begin
  h   := e;                                           // adapt to local value
  ThC := t;
  Hum := rh;
  ph  := p;                                           // in hPa
  Pp  := H2Oppart(ThC, Hum);                          // artial water vapor pressure
  ThK := ThC + 273.15;                                // Temperature in K
  x   := g/(R*(ThK + Ch*Pp+alpha*h/2))*h;
  P0  := ph * exp(x);
  result:=P0;
end{ sealevelreduction };

function dewpoint (T, ppartw : real) : real;           // dew point calculation
var
  td : real;
begin
  td:=T;
  while H2Opsat(td) >= ppartw do td:=td-0.01;
  result:=td;
end;

function H2Oppart (t, rh : real) : real;            // partial vapor pressure
begin
  result:=rh/100*H2Opsat(T);
end;

function CH2O     (t, rh : real) : real;            // water mass concentration
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

function H2Opsat  (t     : real) : real;            //saturation water vapor pressure
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

var
 sat_vap_press,
 sat_vap_press_w,
 sat_vap_press_i      : real;

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

end.

