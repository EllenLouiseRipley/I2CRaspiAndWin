unit MCP2221_DLL;

{///©[2015] Microchip Technology Inc.and its subsidiaries.You may use this software and any derivatives exclusively with Microchip products. }
{/// }
{///THIS SOFTWARE IS SUPPLIED BY MICROCHIP "AS IS".NO WARRANTIES, WHETHER EXPRESS, IMPLIED OR STATUTORY, APPLY TO THIS SOFTWARE, INCLUDING ANY IMPLIED }
{///WARRANTIES OF NON - INFRINGEMENT, MERCHANTABILITY, AND FITNESS FOR A PARTICULAR PURPOSE, OR ITS INTERACTION WITH MICROCHIP PRODUCTS, COMBINATION WITH ANY }
{///OTHER PRODUCTS, OR USE IN ANY APPLICATION. }
{/// }
{///IN NO EVENT WILL MICROCHIP BE LIABLE FOR ANY INDIRECT, SPECIAL, PUNITIVE, INCIDENTAL OR CONSEQUENTIAL LOSS, DAMAGE, COST OR EXPENSE OF ANY KIND WHATSOEVER }
{///RELATED TO THE SOFTWARE, HOWEVER CAUSED, EVEN IF MICROCHIP HAS BEEN ADVISED OF THE POSSIBILITY OR THE DAMAGES ARE FORESEEABLE.TO THE FULLEST EXTENT ALLOWED }
{///BY LAW, MICROCHIP'S TOTAL LIABILITY ON ALL CLAIMS IN ANY WAY RELATED TO THIS SOFTWARE WILL NOT EXCEED THE AMOUNT OF FEES, IF ANY, THAT YOU HAVE PAID }
{///DIRECTLY TO MICROCHIP FOR THIS SOFTWARE. }
{/// }
{///MICROCHIP PROVIDES THIS SOFTWARE CONDITIONALLY UPON YOUR ACCEPTANCE OF THESE TERMS. }

{/// The following ifdef block is the standard way of creating macros which make exporting }
{/// from a DLL simpler. All files within this DLL are compiled with the MCP2221_DLL_UM_EXPORTS }
{/// symbol defined on the command line. This symbol should not be defined on any project }
{/// that uses this DLL. This way any other project whose source files include this file see }
{/// MCP2221_DLL_UM_API functions as being imported from a DLL, whereas this DLL sees symbols }
{/// defined with this macro as being exported. }

{///for projects importing the .lib, use the MCP2221_LIB preprocessor definition }
//
//
// download necessary software under : https://www.microchip.com/en-us/product/mcp2221a
//
//

interface

const
  {$IFDEF WIN64}
  MCP_DLL = 'mcp2221_dll_um_x64.dll';
  {$ENDIF}
  {$IFDEF WIN32}
  MCP_DLL = 'mcp2221_dll_um_x86.dll';
  {$ENDIF}
  DEFAULT_VID =                $04D8;
  DEFAULT_PID =                $00DD;
  mcpIndex    : Uint16 =           0;             //only one device!

type
  mcpHandle_	= pointer;
  mcpRslt	= LongInt;
  wchar_t 	= array [0..63] of widechar;

var
  libVersion  : wchar_t;
  HW_Revision,
  FW_Revision : wchar_t;
  mcpHandle   : mcpHandle_;
  mcpResult   : mcpRslt;
  mcpChars    : wchar_t;
  use7bitAddress  : byte            = 1;


function Mcp2221_OpenByIndex(VID: Word; PID: Word; index: Word)		: mcpHandle_; external MCP_DLL;

function Mcp2221_Close(handle: Pointer)			                : mcpRslt; external MCP_DLL;

function Mcp2221_Reset(handle: Pointer)			                : mcpRslt; external MCP_DLL;

function Mcp2221_GetLibraryVersion(var version: WCHAR_T)                : mcpRslt; external MCP_DLL;

function Mcp2221_GetHwFwRevisions(handle: Pointer;
                                    var HW_Revision;
                                    var FW_Revision)                    : mcpRslt; external MCP_DLL;

function Mcp2221_GetLastError()                                         : mcpRslt; external MCP_DLL;

function Mcp2221_GetConnectedDevices(vid: Word;
                                     pid: Word;
                                  var noOfDevs: Word)                   : mcpRslt; external MCP_DLL;

// i2c functions }

function Mcp2221_I2cCancelCurrentTransfer(handle: Pointer)              : mcpRslt; external MCP_DLL;

function Mcp2221_I2cRead(handle: Pointer; 
                         bytesToRead: Word; 
                         slaveAddress: Byte; 
                         use7bitAddress: Byte;
                         var i2cRxData: Byte)                           : mcpRslt; external MCP_DLL;

function Mcp2221_I2cWrite(handle: Pointer; 
                          bytesToWrite: Word; 
                          slaveAddress: Byte; 
                          use7bitAddress: Byte;
                          var i2cTxData: Byte)                          : mcpRslt; external MCP_DLL;

function Mcp2221_SetAdvancedCommParams(handle: Pointer; 
                                       timeout: Byte; 
                                       maxRetries: Byte)                : mcpRslt; external MCP_DLL;

function Mcp2221_SetSpeed(handle: Pointer; 
                          speed: dWord)                                  : mcpRslt; external MCP_DLL;


function Mcp2221_I2cWriteNoStop(handle: Pointer; 
                                bytesToWrite: Word; 
                                slaveAddress: Byte; 
                                use7bitAddress: Byte; 
                                var i2cTxData: Byte)                    : mcpRslt; external MCP_DLL;

function Mcp2221_I2cReadRestart(handle: Pointer; 
                                bytesToRead: Word; 
                                slaveAddress: Byte; 
                                use7bitAddress: Byte; 
                                var i2cRxData: Byte)                    : mcpRslt; external MCP_DLL;


function Mcp2221_I2cWriteRestart(handle: Pointer; 
                                 bytesToWrite: Word; 
                                 slaveAddress: Byte; 
                                 use7bitAddress: Byte; 
                                 var i2cTxData: Byte)                   : mcpRslt; external MCP_DLL;

{+//******************************* }
{-Error codes }
{=******************************** }
const
  E_NO_ERR 					=  0;   // no error
  E_ERR_UNKOWN_ERROR 				= -1;   //
  E_ERR_CMD_FAILED 				= -2;
  E_ERR_INVALID_HANDLE 				= -3;
  E_ERR_INVALID_PARAMETER 			= -4;
  E_ERR_INVALID_PASS 				= -5;
  E_ERR_PASSWORD_LIMIT_REACHED		        = -6;
  E_ERR_FLASH_WRITE_PROTECTED		        = -7;
  E_ERR_NULL 					= -10;	// null pointer received
  E_ERR_DESTINATION_TOO_SMALL		        = -11;	// destination string too small
  E_ERR_INPUT_TOO_LARGE				= -12;
  E_ERR_FLASH_WRITE_FAILED                      = -13;
  E_ERR_MALLOC					= -14;
  E_ERR_NO_SUCH_INDEX                           = -101;	// we tried to connect to a device with a non existent index
  E_ERR_DEVICE_NOT_FOUND                        = -103;	// no device matching the provided criteria was found
  E_ERR_INTERNAL_BUFFER_TOO_SMALL               = -104;	// one of the internal buffers of the function was too small
  E_ERR_OPEN_DEVICE_ERROR                       = -105;	// an error occurred when trying to get the device handle
  E_ERR_CONNECTION_ALREADY_OPENED               = -106;	// connection already opened
  E_ERR_CLOSE_FAILED                            = -107; // close failed
  
  //****** I2C errors*******

  E_ERR_INVALID_SPEED                           = -401;
  E_ERR_SPEED_NOT_SET                           = -402;
  E_ERR_INVALID_BYTE_NUMBER                     = -403;
  E_ERR_INVALID_ADDRESS                         = -404;
  E_ERR_I2C_BUSY                                = -405;
  E_ERR_I2C_READ_ERROR                          = -406;	// mcp2221 signaled an error during the i2c read operation
  E_ERR_ADDRESS_NACK                            = -407;
  E_ERR_TIMEOUT                                 = -408;
  E_ERR_TOO_MANY_RX_BYTES                       = -409;
  E_ERR_COPY_RX_DATA_FAILED                     = -410;	//could not copy the data received from the slave into the provided buffer;
  E_ERR_COPY_TX_DATA_FAILED                     = -412;	// failed to copy the data into the HID buffer
  E_ERR_NO_EFFECT                               = -411;	// The i2c engine (inside mcp2221) was already idle. The cancellation command had no effect.
  E_ERR_INVALID_PEC                             = -413;
  E_ERR_BLOCK_SIZE_MISMATCH                     = -414;	// The slave sent a different value for the block size(byte count) than we expected
  E_ERR_RAW_TX_TOO_LARGE                        = -301;
  E_ERR_RAW_TX_COPYFAILED                       = -302;
  E_ERR_RAW_RX_COPYFAILED                       = -303;

//********************************** }
const
//*********************************** }

  FLASH_SETTINGS = 0;
  RUNTIME_SETTINGS = 1;
  NO_CHANGE = $F;

{///GPIO settings }

  MCP2221_GPFUNC_IO                   = 0;
  MCP2221_GP_SSPND                    = 1;
  MCP2221_GP_CLOCK_OUT                = 1;
  MCP2221_GP_USBCFG                   = 1;
  MCP2221_GP_LED_I2C                  = 1;
  MCP2221_GP_LED_UART_RX              = 2;
  MCP2221_GP_ADC                      = 2;
  MCP2221_GP_LED_UART_TX              = 3;
  MCP2221_GP_DAC                      = 3;
  MCP2221_GP_IOC                      = 4;
  MCP2221_GPDIR_INPUT                 = 1;
  MCP2221_GPDIR_OUTPUT                = 0;
  MCP2221_GPVAL_HIGH                  = 1;
  MCP2221_GPVAL_LOW                   = 0;
  INTERRUPT_NONE                      = 0;
  INTERRUPT_POSITIVE_EDGE             = 1;
  INTERRUPT_NEGATIVE_EDGE             = 2;
  INTERRUPT_BOTH_EDGES                = 3;
  VREF_VDD                            = 0;
  VREF_1024V                          = 1;
  VREF_2048V                          = 2;
  VREF_4096V                          = 3;
  MCP2221_USB_BUS                     = $80;
  MCP2221_USB_SELF                    = $40;
  MCP2221_USB_REMOTE                  = $20;
  MCP2221_PASS_ENABLE                 = 1;
  MCP2221_PASS_DISABLE                = 0;
  MCP2221_PASS_CHANGE                 = $ff;


implementation

end.
