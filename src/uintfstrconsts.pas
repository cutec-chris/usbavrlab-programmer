unit uIntfStrConsts;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils; 
  
resourcestring
  strNoHelp                             = 'No Help avalible';
  strNoAccess                           = 'An USB AVR Lab was found but you havend access to it. Maybe you havend enougth rights.';
  strPleaseUseSpecialSoftware           = 'Please use the Special Software for this Programmer Type';
  strRefreshHint                        = 'Refresh list'+#13+'Liste aktualisierten';
  strBringToBootmodeHint                = 'Bring selected programmer to bootmode'+#13+'Markierten Programmer in den Bootmode versetzen';
  strController                         = 'Controller';
  strPageSize                           = 'Page Size';
  strInvalidhexFile                     = 'Invalid hexfile, check if this is in Intel hex Format';
  strFirmwareLoadedOK                   = 'Firmware loaded, %d Bytes';
  strErrorConnectingToDevice            = 'Error connecting to Device';
  strBringToBootMode                    = 'Bring to boot mode';
  strHexFileToBig                       = 'Hex file does not fit in Controller';
  strProgrammingPage                    = 'Programming Page %d';
  strProgrammedOK                       = 'Device programmed OK ...';
  strFirmware                           = 'Firmware';
  strStartApplication                   = 'Start Application';
  strProgramm                           = 'Programm';
  strAVRISPTool                         = 'USB AVR-ISP Tool';
  strInvalidSoftwareVersion             = 'Invalid Software Version';
  strWrite                              = 'Write';
  strSoftwareVersion                    = 'Software Version';
  strOptions                            = 'Options';
  strISPSpeed                           = 'ISP Speed';
  strProtocol                           = 'Protocol';
  strBaudrate                           = 'Baudrate';
  strDatabits                           = 'Databits';
  strStopbits                           = 'Stopbits';
  strParity                             = 'Parity';
  strDebugPort                          = 'Debug Port';
  strDebugPortModeUpdated               = 'Debug Port Mode updated ...';
  strISPSpeedUpdated                    = 'ISP Speed updated ...';
  strOptionsUpdated                     = 'Options updated...';
  strSend                               = 'Send';
  strI2CSendComplete                    = 'I2C data sended ...';
  strI2CSendFailed                      = 'I2C send failed (%d) ...';
  strInfo                               = 'www:  http://www.ullihome.de'+lineending
                                        +'mail: christian@ullihome.de'+lineending
                                        +lineending
                                        +'Lizenz:'+lineending
                                        +'Die Software und ihre Dokumentation wird wie sie ist zur'+lineending
                                        +'Verfuegung gestellt. Da Fehlfunktionen auch bei ausfuehrlich'+lineending
                                        +'getesteter Software durch die Vielzahl an verschiedenen'+lineending
                                        +'Rechnerkonfigurationen niemals ausgeschlossen werden koennen,'+lineending
                                        +'uebernimmt der Autor keinerlei Haftung fuer jedwede Folgeschaeden,'+lineending
                                        +'die sich durch direkten oder indirekten Einsatz der Software'+lineending
                                        +'oder der Dokumentation ergeben. Uneingeschraenkt ausgeschlossen'+lineending
                                        +'ist vor allem die Haftung fuer Schaeden aus entgangenem Gewinn,'+lineending
                                        +'Betriebsunterbrechung, Verlust von Informationen und Daten und'+lineending
                                        +'Schaeden an anderer Software, auch wenn diese dem Autor bekannt'+lineending
                                        +'sein sollten. Ausschliesslich der Benutzer haftet fuer Folgen der'+lineending
                                        +'Benutzung dieser Software.'+lineending
                                        +lineending
                                        +'erstellt mit Freepascal + Lazarus'+lineending
                                        +'http://www.freepascal.org, http://lazarus.freepascal.org'+lineending
                                        +'Iconset von:'+lineending
                                        +'http://www.famfamfam.com/lab/icons/silk/'+lineending;

implementation

end.

