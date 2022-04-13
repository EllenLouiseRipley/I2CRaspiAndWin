unit i2cbasic;

{$mode objfpc}{$H+}

interface

uses
{$IFDEF UNIX}
   baseUnix,             //i²c io handled by operating system
{$ENDIF}
{$IFDEF MSWINDOWS}
   MCP2221_DLL,          //i²c io handled by dedicated driver
{$ENDIF}

   Classes, SysUtils;
type
  Regarray  = array [0..63] of byte;
  pRegarray = ^Regarray;

function i2cfpIoctl(i2c_deviceaddress: byte): LongInt;
function i2cfpgeterrno() : longint;
{$IFDEF MSWINDOWS}
function i2cdeviceexists(i2c_device :  mcpHandle_): boolean;
{$ENDIF}
{$IFDEF UNIX}
function i2cdeviceexists(i2c_device : LongInt) : boolean;
{$ENDIF}
function i2cOpen()  : LongInt;
function i2cClose() : LongInt;
{$IFDEF UNIX}
function i2cwrite(var  buf ; nbytes : LongWord) : LongInt;
function i2cread( var  buf ; nbytes : LongWord) : LongInt;
{$ENDIF}
{$IFDEF MSWINDOWS}
function i2cwrite(var  buf : regarray ; nbytes : word) : LongInt;
function i2cread( var  buf : regarray ; nbytes : word) : LongInt;
{$ENDIF}

var
{$IFDEF UNIX}
  i2c_device           : LongInt    =  -1;    //file handle preset
{$ENDIF}
{$IFDEF MSWINDOWS}
  i2c_device           : mcpHandle_ =nil;     //file handle preset
{$ENDIF}
  i2c_address_sht35    : byte       = $44;    //address of SHT75 sensor as found per i2cdetect -y 1
  i2c_address_sht35a   : byte       = $45;    //alternative address of SHT75 sensor as found per i2cdetect -y 1
  i2c_address_sht85    : byte       = $44;    //address of SHT85 sensor as found per i2cdetect -y 1
  i2c_address_sht40    : byte       = $44;
  i2c_address_sgp30    : byte       = $58;    //address of SGP30 SVM30 board as found per i2cdetect -y 1
  i2c_address_sgp40    : byte       = $59;    //address of SGP40 sensor from data sheet, i2cdetect -y 1 does not show it!
  i2c_address_dps310a  : byte       = $76;    //address of DPS310 sensor as found per i2cdetect -y 1
  i2c_address_dps310   : byte       = $77;    //address of DPS310 sensor as found per i2cdetect -y 1

  i2c_address_svm40    : byte       = $6A;    //address of SVM40 board as found per i2cdetect -y 1
  i2c_address_mpc23017 : byte       = $27;    //address of MPC23017 board as found per i2cdetect -y 1
  i2c_address_pca9685  : byte       = $70;    //address of PCA9685 board as found per i2cdetect -y 1
  i2c_address_shtc1    : byte       = $70;    //address of SHTC1 on SVM30 board as found per i2cdetect -y 1
  i2c_address_all      : byte       = $00;    //Broadcast
  i2c_address_ioctl    : byte       = $80;    //address for operations
  i2c_address_default  : byte       = $80;
  data                 : Regarray;
  count                : uint16;
  pdata                : pRegarray;

(*
pi@RasPiHW:~ $ i2cdetect -y 1
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:          -- 04 -- -- -- -- -- -- -- -- -- -- --
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
20: -- -- -- -- -- -- -- 27 -- -- -- -- -- -- -- --
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
40: -- -- -- -- 44 45 -- -- -- -- -- -- -- -- -- --
50: -- -- -- -- -- -- -- -- 58 59 -- -- -- -- -- --
60: -- -- -- -- -- -- -- -- -- -- 6A -- -- -- -- --
70: 70 -- -- -- -- -- 76 77
pi@RasPiHW:~ $
*)



const
  I2C_DEVICE_PATH   : string ='/dev/i2c-1';         //i²c bus on header pins 3 & 5
// The following defines were taken from i2c-dev.h.
  I2C_SLAVE         = 1795;  // 0x0703 - 1795 dec
  I2C_WRITE_FAILED  = -1;
  I2C_READ_FAILED   = -1;

implementation

function i2cfpIoctl(i2c_deviceaddress: byte): LongInt;
begin
  {$IFDEF UNIX}
//  i2c_device as file handle, Ndx (=I2C_SLAVE) is the IOCTL function request type, data is the target i2c device address.
    Result := BaseUnix.FpIOCtl(i2c_device, I2C_SLAVE, pointer(i2c_deviceaddress));
  {$ENDIF}
  {$IFDEF MSWINDOWS}
    i2c_address_ioctl :=  i2c_deviceaddress;
    if i2c_address_ioctl<$7F then Result := 0 else result:=-1;
  {$ENDIF}
end { i2cfpIoctl } ;

function i2cfpgeterrno() : longint ;
begin
{$IFDEF UNIX}
  result:=fpgeterrno;
{$ENDIF}
{$IFDEF MSWINDOWS}
 // result:=Mcp2221_GetLastError();
  result:=-mcpResult;
{$ENDIF}
end { i2cfpgeterrno } ;
{$IFDEF MSWINDOWS}
function i2cdeviceexists(i2c_device:mcpHandle_) : boolean;
begin
  result:=(i2c_device <> nil)
end;
{$ENDIF}
{$IFDEF UNIX}
function i2cdeviceexists(i2c_device:longint) : boolean;
begin
  result:=(i2c_device>=0);
end;
{$ENDIF}

function i2cOpen() : longint;
begin
  if not i2cdeviceexists(i2c_device) then
  begin
    {$IFDEF UNIX}
    i2c_device := fpopen(I2C_DEVICE_PATH, O_RdWr);
    Result:=i2c_device;
    {$ENDIF}
    {$IFDEF MSWINDOWS}
    i2c_device:= Mcp2221_OpenByIndex(DEFAULT_VID, DEFAULT_PID, mcpIndex);
    if i2c_device<>nil
    then result:=ptrUint(i2c_device)
    else result:=-1;
    exit;
    {$ENDIF}
  end else result:=-1;
end { i2cOpen } ;


function i2cClose() : LongInt;
begin
  if i2cdeviceexists(i2c_device)
  then begin
    {$IFDEF UNIX}
    result:=fpclose(i2c_device);
    if result=0 then i2c_device:=-1;
    {$ENDIF}
    {$IFDEF MSWINDOWS}
    mcpResult := Mcp2221_Close(i2c_device);
    if mcpResult = E_NO_ERR then i2c_device:=nil;
    result:=0
    {$ENDIF}
  end
  else result:=-1;
end { i2cClose } ;

{$IFDEF UNIX}
function i2cwrite(var buf ; nbytes : LongWord) : LongInt;
begin
  result:= fpwrite(i2c_device, buf, nbytes);
end{ i2cwrite};

function i2cread(var buf; nbytes : longWord) : LongInt;
begin
  result:= fpread(i2c_device, buf, nbytes);
end{ i2cread};
{$ENDIF}
{$IFDEF MSWINDOWS}
function i2cwrite(var buf : regarray ; nbytes : word) : LongInt;
begin
  mcpResult:=Mcp2221_I2cWrite(i2c_device, nbytes, i2c_address_ioctl, use7bitAddress, buf[0]);
  if mcpResult=0 then result:=nbytes else result:=mcpResult;
end{ i2cwrite};

function i2cread(var buf: regarray ; nbytes : word) : LongInt;
begin
  mcpResult:=Mcp2221_I2cRead(i2c_device, nbytes, i2c_address_ioctl, use7bitAddress, buf[0]);
  if mcpResult=0 then result:=nbytes else result:=mcpResult;
end{ i2cread};
{$ENDIF}

end { i2cbasic}.
