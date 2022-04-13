unit MainUnitRaspiWin;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  RTTICtrls, i2cbasic, errorioctl, SHT35, SHT40, DPS310, SGP40, SensirionCRCGen;

type

  { TFEasyI2C }

  TFEasyI2C = class(TForm)
    BtnDS310ASICMEMS: TButton;
    BtnDS310GetCoefficients: TButton;
    BtnDS310GetTemperature: TButton;
    BtnDS310GetPressure: TButton;
    BtnDS310SetParameters: TButton;
    BtnDS310Reset: TButton;
    BtnDS310CorrTemp: TButton;
    BtnGetFileHandle: TButton;
    BtnCloseFileHandle: TButton;
    BtnSHT35Status: TButton;
    BtnSGP40gettics: TButton;
    BtnSHT35TempHum: TButton;
    BtnDS310Id: TButton;
    BtnSHT40TempHum: TButton;
    BtnSHT40SerNo: TButton;
    DPS310ButtonsBox: TGroupBox;
    LblEdtDPS310Elevation: TLabeledEdit;
    RGDPS310addr: TRadioGroup;
    RGSHT35addr: TRadioGroup;
    SGP40Buttons: TGroupBox;
    SHT35ButtonsBox: TGroupBox;
    I2CFileHandleBox: TGroupBox;
    MMEssages: TMemo;
    SHT40ButtonsBox: TGroupBox;
    procedure BtnCloseFileHandleClick(Sender: TObject);
    procedure BtnDS310GetCoefficientsClick(Sender: TObject);
    procedure BtnDS310GetPressureClick(Sender: TObject);
    procedure BtnDS310GetTemperatureClick(Sender: TObject);
    procedure BtnDS310SetParametersClick(Sender: TObject);
    procedure BtnGetFileHandleClick(Sender: TObject);
    procedure BtnSGP40getticsClick(Sender: TObject);
    procedure BtnSHT35StatusClick(Sender: TObject);
    procedure BtnSHT35TempHumClick(Sender: TObject);
    procedure BtnSHT40SerNoClick(Sender: TObject);
    procedure BtnSHT40TempHumClick(Sender: TObject);
    procedure FormClose(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure LblEdtDPS310ElevationKeyPress(Sender: TObject; var Key: char);
    procedure MMEssagesDblClick(Sender: TObject);
    procedure RGDPS310addrSelectionChanged(Sender: TObject);
    procedure RGSHT35addrSelectionChanged(Sender: TObject);
  private
    procedure Addmessages(mess2show: string);

  public

  end;

var
  FEasyI2C: TFEasyI2C;
  cvtcode : integer;
  MainTemperature,
  MainHumidity,
  MainElevation,
  ppart,
  H2OMassconc : real;
  DPS310_i2c_address,
  SHT35_i2c_address   : byte;


implementation

{$R *.lfm}

{ TFEasyI2C }
procedure TFEasyI2C.Addmessages(mess2show: string);
begin
  MMEssages.Lines.BeginUpdate;
  MMEssages.Lines.Add(mess2show);
  MMEssages.Lines.EndUpdate;
  MMEssages.SelStart := Length(MMEssages.Lines.Text)-1;
  MMEssages.SelLength:=0;
end;

procedure TFEasyI2C.FormClose(Sender: TObject);
var
  rslt        : integer;
begin
   if i2cdeviceexists(i2c_device) then rslt:=i2cClose();
end;

procedure TFEasyI2C.FormCreate(Sender: TObject);
begin
  MainElevation:=StrToIntDef(LblEdtDPS310Elevation.text,175);
  DPS310.loc_elevation:= MainElevation;
  RGDPS310addrSelectionChanged(self);
  RGSHT35addrSelectionChanged(self);
end;


procedure TFEasyI2C.MMEssagesDblClick(Sender: TObject);
begin
  MMEssages.clear;
end;

procedure TFEasyI2C.BtnGetFileHandleClick(Sender: TObject);
var
  rslt : integer;
  ioctlerr : longint;
begin
  if not i2cdeviceexists(i2c_device) then
  begin
    rslt := i2cOpen;
    if rslt = -1
    then begin
      ioctlerr:=i2cfpgeterrno;
      Addmessages('device open ioctl errno: '+inttostr(ioctlerr));
      Addmessages(ioctlerrortext(ioctlerr));
    end
    else addmessages('device handle: '+inttostr(rslt));
  end else addmessages('device handle exists');
end;

procedure TFEasyI2C.BtnCloseFileHandleClick(Sender: TObject);
var
  rslt : integer;
  ioctlerr : longint;
begin
  if i2cdeviceexists(i2c_device) then
  begin
    rslt:=i2cClose();
    if rslt =0 then addmessages('device closed')
  else begin
    ioctlerr:=i2cfpgeterrno;
    Addmessages('device open ioctl errno: '+inttostr(ioctlerr));
    Addmessages(ioctlerrortext(ioctlerr));
  end;
  end else addmessages('no device handle');
end;

procedure TFEasyI2C.BtnSGP40getticsClick(Sender: TObject);
var
  rslt       : longint;
  ioctlerr   : longint;
begin
  if i2cdeviceexists(i2c_device) then
  begin
    rslt:=sgp40_get_raw_ticks (i2c_address_sgp40);
    if rslt<0 then
    begin
      ioctlerr:=i2cfpgeterrno;
      Addmessages('ioctl errno: '+inttostr(ioctlerr));
      Addmessages(ioctlerrortext(ioctlerr));
      exit;
    end else begin
      Addmessages('VOC tics : '+InttoStr(loc_tics));
    end;
  end else Addmessages('no device handle');
end;

procedure TFEasyI2C.LblEdtDPS310ElevationKeyPress(Sender: TObject; var Key: char);
Var
  Text4Label : string;
begin
  if key=#13 then begin
    DPS310.loc_elevation:=StrToIntDef(LblEdtDPS310Elevation.text,175);
    str(DPS310.loc_elevation:4:1,Text4Label);
    LblEdtDPS310Elevation.text:= Text4Label;
    MainElevation:=DPS310.loc_elevation;
  end;
end;

procedure TFEasyI2C.RGDPS310addrSelectionChanged(Sender: TObject);
begin
  case RGDPS310addr.ItemIndex of
  0 : DPS310_i2c_address:= i2c_address_dps310a;
  1 : DPS310_i2c_address:= i2c_address_dps310;
  end;
end;

procedure TFEasyI2C.RGSHT35addrSelectionChanged(Sender: TObject);
begin
  case RGSHT35addr.ItemIndex of
  0 : SHT35_i2c_address:= i2c_address_sht35a;
  1 : SHT35_i2c_address:= i2c_address_sht35;
  end;
end;

procedure TFEasyI2C.BtnDS310GetCoefficientsClick(Sender: TObject);
var
  rslt : integer;
  ioctlerr : longint;
begin
  if i2cdeviceexists(i2c_device) then
  begin
    rslt:=DPS310_readCoefficients(DPS310_i2c_address);
    if rslt<0 then
    begin
      ioctlerr:=i2cfpgeterrno;
      Addmessages('ioctl errno: '+inttostr(ioctlerr));
      Addmessages(ioctlerrortext(ioctlerr));
      exit;
    end else Addmessages('Coefficients read')
  end else Addmessages('no device handle');
end;

procedure TFEasyI2C.BtnDS310GetPressureClick(Sender: TObject);
var
  rslt       : integer;
  ioctlerr   : longint;
  Text4Label : string;
  Pabs, P0   : real;
begin
  if i2cdeviceexists(i2c_device) then
  begin
    rslt:=DPS310_readPressure(DPS310_i2c_address);
    if rslt<0 then begin
      ioctlerr:=i2cfpgeterrno;
      Addmessages('ioctl errno: '+inttostr(ioctlerr));
      Addmessages(ioctlerrortext(ioctlerr));
      exit;
    end;
    Pabs:=DPS310_pressure/100;
    str(Pabs:4:2,Text4Label);
    Addmessages('Pabs : '+Text4Label+' hPa');
//    P0:= sealevelreduction(sht35.loc_humidity, sht35.loc_temperature, DPS310.loc_elevation);

    P0:= sealevelreduction(MainHumidity,  MainTemperature, Mainelevation);
    str(P0:4:2,Text4Label);
    Addmessages('P0   : '+Text4Label+' hPa');
    str( MainTemperature:4:2,Text4Label);
    Addmessages('T    : '+Text4Label+' °C');
    str(MainHumidity:4:2,Text4Label);
    Addmessages('r. H.: '+Text4Label+' %');
    str(Mainelevation:4:2,Text4Label);
    Addmessages('Elev.: '+Text4Label+' m');
  end else Addmessages('no device handle');
end;

procedure TFEasyI2C.BtnDS310GetTemperatureClick(Sender: TObject);
var
  rslt       : integer;
  ioctlerr   : longint;
  Text4Label : string;
begin
  if i2cdeviceexists(i2c_device) then
  begin
    rslt:=DPS310_readTemperature(DPS310_i2c_address);
    if rslt<0 then begin
      ioctlerr:=i2cfpgeterrno;
      Addmessages('ioctl errno: '+inttostr(ioctlerr));
      Addmessages(ioctlerrortext(ioctlerr));
      exit;
    end;
    str(DPS310_Temperature:6:2,Text4Label);
    Addmessages('Tcomp: '+Text4Label);
  end else Addmessages('no device handle');
end;

procedure TFEasyI2C.BtnDS310SetParametersClick(Sender: TObject);
var
  rslt      : integer;
  ioctlerr  : longint;
begin
  if i2cdeviceexists(i2c_device) then
  begin
    rslt:=DPS310_setMeasParams(DPS310_i2c_address);
    if rslt<0 then begin
      ioctlerr:=i2cfpgeterrno;
      Addmessages('ioctl errno: '+inttostr(ioctlerr));
      Addmessages(ioctlerrortext(ioctlerr));
      exit;
    end else Addmessages('Parameters sent');
  end else Addmessages('no device handle');
end;

procedure TFEasyI2C.BtnSHT35StatusClick(Sender: TObject);
var
  rslt       : integer;
  Text4label : string;
  ioctlerr   : longint;
begin
  if i2cdeviceexists(i2c_device) then
  begin
    rslt:=sht35_do_StatusRead (SHT35_i2c_address );
    if rslt=-1
    then begin
      if not crc8_s_err
      then begin
        ioctlerr:=i2cfpgeterrno;
        Addmessages('ioctl errno: '+inttostr(ioctlerr));
        Addmessages(ioctlerrortext(ioctlerr));
      end //not CRC Err
      else Addmessages('crc status error');
      exit;
    end
    else
    begin
      text4Label:=BinStr(loc_status,16);
      addmessages('Status :'+ Text4label);
    end;
  end else Addmessages('no device handle');
end;

procedure TFEasyI2C.BtnSHT35TempHumClick(Sender: TObject);
var
  rslt        : integer;
  ioctlerr    : longint;
  Text4label : string;
begin
  if i2cdeviceexists(i2c_device) then
  begin
    rslt:= sht35_get_t_rh_hi  ( SHT35_i2c_address );
    if rslt<0
    then begin
      if not crc8_t_err or crc8_h_err
      then begin
        ioctlerr:=i2cfpgeterrno;
        Addmessages('ioctl errno: '+inttostr(ioctlerr));
        Addmessages(ioctlerrortext(ioctlerr));
      end //not CRC Err
      else Addmessages('crc t or h error');
      exit;
    end
    else
    begin
      MainTemperature:=sht35.loc_temperature;
      MainHumidity   :=sht35.loc_humidity;
      str(sht35.loc_temperature:6:2,Text4label);
      Addmessages('Temperature :'+Text4label+' °C');
      str(sht35.loc_humidity:6:2,Text4label);
      Addmessages('Humidity :'+Text4label+' % rel.');
      ppart:=H2Oppart (Maintemperature, Mainhumidity);
      str(ppart:6:2,Text4label);
      Addmessages('H2O Partial Pressure :'+Text4label+' hPa');
      H2OMassconc:=CH2O (Maintemperature, Mainhumidity);
      str(H2OMassconc:6:2,Text4label);
      Addmessages('H2O Mass concentration :'+Text4label+' g/m³');
    end;
  end else Addmessages('no device handle');
end;

procedure TFEasyI2C.BtnSHT40SerNoClick(Sender: TObject);
var
  rslt        : integer;
  ioctlerr    : longint;
  Text4label : string;
begin
  if i2cdeviceexists(i2c_device) then
  begin
    rslt:= sht40_get_serial_ID  ( i2c_address_sht40 );
    if rslt <0 then
    begin
      if not crc8_n_err
      then begin
        ioctlerr:=i2cfpgeterrno;
        Addmessages('ioctl errno: '+inttostr(ioctlerr));
        Addmessages(ioctlerrortext(ioctlerr));
      end else  Addmessages('crc n error');
      exit;
    end
    else begin
      text4Label:=HexStr(SHT40.sht40_serial_lo,4);
      Addmessages('Serial Number Lo : 0x' + text4Label);
      text4Label:=HexStr(SHT40.sht40_serial_hi,4);
      Addmessages('Serial Number Hi : 0x' + text4Label);
    end;
  end else Addmessages('no device handle');
end;


procedure TFEasyI2C.BtnSHT40TempHumClick(Sender: TObject);
var
  rslt        : integer;
  ioctlerr    : longint;
  Text4label : string;
begin
  if i2cdeviceexists(i2c_device) then
  begin
    rslt:= sht40_get_t_rh_hi  ( i2c_address_sht40 );
    if rslt=0 then begin
      str(sht40.loc_temperature:6:2,Text4label);
      Addmessages('Temperature :'+Text4label+' °C');
      str(sht40.loc_humidity:6:2,Text4label);
      Addmessages('Humidity :'+Text4label+' % rel.');
      MainTemperature := sht40.loc_temperature;
      MainHumidity    := sht40.loc_humidity;
    end;
    if rslt<0 then begin
      if not crc8_t_err or crc8_h_err
      then begin
        ioctlerr:=i2cfpgeterrno;
        Addmessages('ioctl errno: '+inttostr(ioctlerr));
        Addmessages(ioctlerrortext(ioctlerr));
      end //not CRC Err
      else Addmessages('crc t or h error');
      exit;
    end;
  end else Addmessages('no device handle');
end;

end { unit MainUnitRaspiWin }.

