unit uProgrammer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  ComCtrls, StdCtrls, EditBtn, XMLRead, DOM, XMLPropStorage,
  Utils, Grids, LCLIntf, LCLType, Buttons, libusb, Menus, ActnList,LCLProc,
  ExtCtrls, Process,uEncrypt;

type
  Bytearray = array of byte;

  { TRegisterItem }

  TRegisterItem = class(TList)
  private
    FLength: byte;
    FValue: word;
    function GetRealValue: word;
    procedure SetRealValue(const AValue: word);
  public
    procedure ChangeValue(Sender : TObject);
    property Value : word read FValue write FValue;
    property RealValue : word read GetRealValue write SetRealValue;
    property RegisterLength : byte read FLength;
    constructor Create;
  end;

  { TFuseItem }

  TFuseItem = class
  private
    FDescription: string;
    FParent : TRegisterItem;
  public
    property Description : string read FDescription;
    constructor Create(Desc : string;aParent : TRegisterItem);
  end;

  { TBitFieldItem }

  TBitFieldItem = class(TFuseItem)
  private
    FMask: Integer;
    function GetValue: Boolean;
  public
    property Mask : Integer read FMask;
    property Value : Boolean read GetValue;
    constructor Create(Desc : string;aMask : string;aParent : TRegisterItem);
    procedure ChangeValue(Sender : TObject);
  end;

  { TEnumeratorItem }

  TEnumeratorItem = class(TFuseItem)
  private
    FNamesList : TStringList;
    ValuesList : TList;
    FMask: Integer;
    FShiftCount : Integer;
    property Mask : Integer read FMask;
    function GetValue: Integer;
    function GetValueName: string;
  public
    property Value : Integer read GetValue;
    property ValueName : string read GetValueName;
    property namesList : TStringList read FNamesList write FNamesList;
    constructor Create(Desc : string;enum_node: TDOMNode;aMask : string;aParent : TRegisterItem);
    procedure ChangeValue(Sender : TObject);
  end;

  { TfProgrammer }

  TfProgrammer = class(TForm)
    acProgramm: TAction;
    acLoadPackage: TAction;
    acSavePackage: TAction;
    ActionList1: TActionList;
    bProgramm: TButton;
    cbProgramEEPROM: TCheckBox;
    cbProgramFlash: TCheckBox;
    cbProgramFuses: TCheckBox;
    cbProgramLockBits: TCheckBox;
    cbType: TComboBox;
    feEEPROMFile: TFileNameEdit;
    feFlashFile: TFileNameEdit;
    IdleTimer: TIdleTimer;
    iFailed: TImage;
    iHourglass: TImage;
    Image1: TImage;
    Image2: TImage;
    Image3: TImage;
    Image4: TImage;
    Image5: TImage;
    iOK: TImage;
    Label1: TLabel;
    lbStatus: TListBox;
    lLockBits: TLabel;
    lFuseBits: TLabel;
    lProgramFile: TLabel;
    lStatus: TLabel;
    lStep1: TLabel;
    lStep2: TLabel;
    lStep3: TLabel;
    lStep4: TLabel;
    lStep5: TLabel;
    lType: TLabel;
    MainMenu1: TMainMenu;
    miInfo: TMenuItem;
    miLanguage: TMenuItem;
    miOptions: TMenuItem;
    miSavePackage: TMenuItem;
    miLoadPackage: TMenuItem;
    miFile: TMenuItem;
    pProgramm: TPanel;
    pProgress: TPanel;
    ProgressBar1: TProgressBar;
    ProgressBar2: TProgressBar;
    sbFuses: TSpeedButton;
    sbLockBits: TSpeedButton;
    xpsProperties: TXMLPropStorage;
    procedure acProgrammExecute(Sender: TObject);
    procedure cbProgramEEPROMChange(Sender: TObject);
    procedure cbProgramFlashChange(Sender: TObject);
    procedure cbProgramFusesChange(Sender: TObject);
    procedure cbProgramLockBitsChange(Sender: TObject);
    procedure cbTypeSelect(Sender: TObject);
    procedure feEEPROMFileAcceptFileName(Sender: TObject; var Value: String);
    procedure feFlashFileAcceptFileName(Sender: TObject; var Value: String);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure IdleTimerTimer(Sender: TObject);
    procedure miInfoClick(Sender: TObject);
    procedure NewMItemClick(Sender: TObject);
    procedure sbFusesClick(Sender: TObject);
    procedure sbLockBitsClick(Sender: TObject);
  private
    { private declarations }
    Language : string;
    Programmer : PUSBDevice;
    DeviceAttatched : Boolean;
    Deviceid : array[0..2] of byte;
    WinAVRDir : string;

    PageSize : word;
    StartAddress : Integer;
    ProgramBuffer : Bytearray;
    Controller : Byte;
    Version : byte;
    ProgrammerType : Integer;
    Controller_str : string;
    Controller_long_str : string;

    procedure LoadCodedHexFile(Filename: string);
    procedure Enumerate;
    procedure Status(NewStatus : string;AddToList : Boolean = True);
    procedure SelectDevice;
    function InitTarget(Device : PUSBDevice) : Boolean;
    procedure ProgramDevice(Device : PUSBDevice);
  public
    { public declarations }
    procedure SetLanguage(Lang : string);
  end;

var
  fProgrammer: TfProgrammer;

implementation

uses uChangeBits,uInfo
  {$IFDEF WINDOWS}
  ,windows
  {$ENDIF}
  ;

{$IFDEF MSWINDOWS}
var
  PrevWndProc: WNDPROC;
{$ENDIF}


resourcestring
  strProgrammernotaccessable            = 'Sie besitzen keine Zugriffsrechte um auf das USB AVR Lab zuzugreifen';
  strProgrammermustbeupdated            = 'Das angeschlossene USB AVR Lab muss zuerst mit der Programmierfirmware ausgestattet werden, solldies jetzt getan werden ?';
  strHexFileToBig                       = 'Hex file does not fit in Controller';
  strInvalidhexFile                     = 'Invalid hexfile, check if this is in Intel hex Format';
  strDeviceID                           = 'Device ID: 0x%.2x,0x%.2x,0x%.2x';
  strOK                                 = 'OK';
  strFailed                             = 'fehlgeschlagen';
  strTryingISPSpeed                     = 'versuche ISP Geschwindigkeit %s';
  strDeviceWrongAttatched               = 'Target falsch angeschlossen';
  strDeviceAttatched                    = 'Target angeschlossen (%f V)';
  strNoDeviceAttatched                  = 'kein Target angeschlossen';
  strNoprogrammerConnected              = 'kein Programmiergerät angeschlossen';
  strNewProgrammerFound                 = 'neues Programmiergerät gefunden';
  strFuses                              = 'Fuses';
  strLockBits                           = 'Lock Bits';
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

const
  FUNC_TYPE                 = $FE;
  FUNC_START_BOOTLOADER     = 30;
  FUNC_GET_CONTROLLER       = 5;
  FUNC_GET_PAGESIZE         = 3;
  FUNC_WRITE_PAGE           = 2;
  FUNC_LEAVE_BOOT           = 1;

  FUNC_GET_VOLTAGE          = 36;
  FUNC_SET_ISP_SPEED        = 34;
  FUNC_GET_ISP_SPEED        = 35;

  USBASP_FUNC_CONNECT       =	1;
  USBASP_FUNC_DISCONNECT    =	2;
  USBASP_FUNC_TRANSMIT      =	3;
  USBASP_FUNC_READFLASH     =	4;
  USBASP_FUNC_ENABLEPROG    =	5;
  USBASP_FUNC_WRITEFLASH    =	6;
  USBASP_FUNC_READEEPROM    =   7;
  USBASP_FUNC_WRITEEEPROM   =	8;
  USBASP_FUNC_SETLONGADDRESS= 	9;

  CONTROLLER_ATMEGA8          = 1;
  CONTROLLER_ATMEGA88         = 2;
  CONTROLLER_ATMEGA168        = 3;

  ISPSpeeds : array[1..7] of String = ('~1 khz','93.75 khz','187.5 khz','375 khz','750 khz','1.5 Mhz','3 Mhz');

{$IFDEF MSWINDOWS}
function WndCallback(Ahwnd: HWND; uMsg: UINT; wParam: WParam; lParam: LParam):LRESULT; stdcall;
begin
  if uMsg=WM_DEVICECHANGE then
    begin
      fProgrammer.Enumerate;
    end;
  result:=CallWindowProc(PrevWndProc,Ahwnd, uMsg, WParam, LParam);
end;
{$ENDIF}

{ TfProgrammer }

procedure TfProgrammer.cbProgramFlashChange(Sender: TObject);
begin
  feFlashFile.Enabled:=cbprogramFlash.Checked;
  if cbProgramFlash.Checked then
    xpsProperties.StoredValue['DOWRITEFLASH'] := 'TRUE'
  else
    xpsProperties.StoredValue['DOWRITEFLASH'] := 'FALSE';
end;

procedure TfProgrammer.cbProgramFusesChange(Sender: TObject);
begin
  if cbProgramFuses.Checked then
    xpsProperties.StoredValue['DOWRITEFUSES'] := 'TRUE'
  else
    xpsProperties.StoredValue['DOWRITEFUSES'] := 'FALSE';
end;

procedure TfProgrammer.cbProgramLockBitsChange(Sender: TObject);
begin
  if cbProgramLockBits.Checked then
    xpsProperties.StoredValue['DOWRITELOCKBITS'] := 'TRUE'
  else
    xpsProperties.StoredValue['DOWRITELOCKBITS'] := 'FALSE';
end;

procedure TfProgrammer.cbTypeSelect(Sender: TObject);
var
  Doc: TXMLDocument;
  aNode: TDOMNode;
  i: Integer;
  RegisterNode: TDOMNode;
  a: Integer;
  RegisterTreeNode: TTreeNode;
  b: Integer;
  NewNode: TTreeNode;
begin
  if cbType.ItemIndex = -1 then exit;
  xpsProperties.StoredValue['TYPE'] := cbType.Items[cbType.ItemIndex];
  ReadXMLFile(Doc,AppendPathDelim(ExtractFileDir(Application.Exename))+'progdata'+DirectorySeparator+cbType.Items[cbType.ItemIndex]+'.xml');
  aNode := nil;
  with Doc.DocumentElement.FindNode('templates').ChildNodes do
    for i := 0 to (Count - 1) do
      if (Item[i].Attributes.GetNamedItem('class') <> nil) and (Item[i].Attributes.GetNamedItem('class').NodeValue = 'FUSE') then
        aNode := Item[i];
  sbFuses.Enabled:=Assigned(aNode);
  with Doc.DocumentElement.FindNode('templates').ChildNodes do
    for i := 0 to (Count - 1) do
      if (Item[i].Attributes.GetNamedItem('class') <> nil) and (Item[i].Attributes.GetNamedItem('class').NodeValue = 'LOCKBIT') then
        aNode := Item[i];
  sbLockBits.Enabled:=Assigned(aNode);
  Doc.free;
end;

procedure TfProgrammer.feEEPROMFileAcceptFileName(Sender: TObject;
  var Value: String);
begin
  xpsProperties.StoredValue['EEPFILE'] := Value;
end;

procedure TfProgrammer.feFlashFileAcceptFileName(Sender: TObject;
  var Value: String);
begin
  xpsProperties.StoredValue['HEXFILE'] := Value;
end;

procedure TfProgrammer.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  IdleTimer.Enabled:=False;
  CanClose := True;
  xpsProperties.StoredValue['LEFT'] := IntToStr(Left);
  xpsProperties.StoredValue['TOP'] := IntToStr(Top);
  xpsProperties.StoredValue['WIDTH'] := IntToStr(Width);
  xpsProperties.StoredValue['HEIGHT'] := IntToStr(Height);
  xpsProperties.Save;
end;

procedure TfProgrammer.FormCreate(Sender: TObject);
var
  Info: TSearchRec;
  sl: TStringList;
  i: Integer;
  NewMItem: TMenuItem;
begin
  Programmer := nil;
  DeviceAttatched := False;
  ForceDirectories(AppendPathDelim(Utils.GetConfigDir('embeddedbuilder'+DirectorySeparator+'programmer')));
  xpsProperties.FileName := AppendPathDelim(Utils.GetConfigDir('embeddedbuilder'+DirectorySeparator+'programmer'))+'config.xml';
  xpsProperties.Active:=True;
  xpsProperties.Restore;
  Left :=StrToIntDef(xpsProperties.StoredValue['LEFT'],Left);
  Top :=StrToIntDef(xpsProperties.StoredValue['TOP'],Top);
  Width :=StrToIntDef(xpsProperties.StoredValue['WIDTH'],Width);
  Height :=StrToIntDef(xpsProperties.StoredValue['HEIGHT'],Height);
  feFlashFile.FileName:= xpsProperties.StoredValue['HEXFILE'];
  feEEPROMFile.FileName:= xpsProperties.StoredValue['EEPFILE'];
  lFuseBits.Caption:= xpsProperties.StoredValue['FUSES'];
  cbProgramFuses.Enabled := lFuseBits.Caption <> '';
  lLockBits.Caption:= xpsProperties.StoredValue['LOCKBITS'];
  cbProgramLockBits.Enabled := lLockBits.Caption <> '';
  cbProgramFlash.Checked := xpsProperties.StoredValue['DOWRITEFLASH'] <> 'FALSE';
  cbProgramEEPRom.Checked := xpsProperties.StoredValue['DOWRITEEEPROM'] = 'TRUE';
  cbProgramFuses.Checked := xpsProperties.StoredValue['DOWRITEFUSES'] <> 'FALSE';
  cbProgramLockBits.Checked := xpsProperties.StoredValue['DOWRITELOCKBITS'] = 'TRUE';
  If FindFirst (AppendPathDelim(ExtractFileDir(Application.Exename))+'progdata'+DirectorySeparator+'*.xml',faAnyFile,Info)=0 then
    repeat
      cbType.Items.Add(copy(Info.Name,0,length(Info.Name)-4));
    until FindNext(info)<>0;
  SysUtils.FindClose(Info);
  cbType.Text := xpsProperties.StoredValue['TYPE'];
  cbTypeSelect(nil);
  sl := TStringList.Create;
  if FileExistsUTF8(AppendPathDelim(AppendPathDelim(ProgramDirectory) + 'languages')+'languages.txt') then
    sl.LoadFromFile(UTF8ToSys(AppendPathDelim(AppendPathDelim(ProgramDirectory) + 'languages')+'languages.txt'));
  for i := 0 to sl.Count-1 do
    begin
      NewMItem := TMenuItem.Create(nil);
      NewMItem.Caption := sl[i];
      NewMItem.AutoCheck := True;
      NewMItem.OnClick :=@NewMItemClick;
      NewMItem.GroupIndex := 11;
      miLanguage.Add(NewMItem);
      if UTF8UpperCase(NewMItem.Caption) = UTF8UpperCase(xpsProperties.StoredValue['LANGUAGE']) then
        begin
          NewMItem.Checked := True;
          Language := xpsProperties.StoredValue['LANGUAGE'];
        end;
    end;
  sl.Free;
  SetLanguage(Language);
  fInfo := TfInfo.Create(Self);
  with fInfo do
    begin
      Version := {$I version.inc};
      Version := Version+{$I revision.inc} / 100;
      ProgramName := 'USB AVR Lab Programmer';
      Copyright := '2007-2009 C.Ulrich';
      InfoText := strInfo;
    end;
  fInfo.SetLanguage;


{$IFDEF MSWINDOWS}
  PrevWndProc:=Windows.WNDPROC(SetWindowLong(Self.Handle,GWL_WNDPROC,PtrInt(@WndCallback)));
{$ENDIF}
  Enumerate;
end;

function ISP_transmit(DeviceHandle: PUSBDevHandle;b0,b1,b2,b3 : byte) : integer;
var
  aresult : array[0..3] of byte = (0,0,0,0);
  res: LongInt;
begin
  res := usb_control_msg(DeviceHandle,USB_TYPE_VENDOR or USB_ENDPOINT_IN,USBASP_FUNC_TRANSMIT, (b1 shl 8) or b0,
                                                                                               (b3 shl 8) or b2,@aresult, 4, 5000);
  if res = 4 then
    Result := aresult[3]
  else
    result := -1;
end;

procedure TfProgrammer.IdleTimerTimer(Sender: TObject);
var
  DeviceHandle: PUSBDevHandle;
  res: LongInt;
  voltage,
  enres : byte;
  i: Integer;
  a: Integer;

begin
  {$IFDEF LINUX}
  Enumerate;
  {$ENDIF}
  if Assigned(Programmer) then
    begin
      DeviceHandle := usb_open(Programmer);
      try
      res := usb_control_msg(DeviceHandle,USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_GET_VOLTAGE, 0, 0,@voltage, 1, 500);
      if res = 1 then
        if voltage > 27 then
          begin
            if copy(lbStatus.Items[lbStatus.Count-1],0,10) = copy(strDeviceAttatched,0,10) then
              Status(Format(strDeviceAttatched,[voltage/10]),False)
            else
              Status(Format(strDeviceAttatched,[voltage/10]));
            if not DeviceAttatched then
              begin
                Application.ProcessMessages;
                for i := high(ISPSpeeds) downto low(ISPSpeeds) do
                  begin
                    usb_control_msg(DeviceHandle,USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_SET_ISP_SPEED, byte(i), 0,nil, 1, 500);
                    Status(Format(strTryingISPSpeed,[ISPSpeeds[i]]));
                    Application.ProcessMessages;
                    usb_control_msg(DeviceHandle,USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,USBASP_FUNC_CONNECT, 0, 0,nil, 1, 500);
                    usb_control_msg(DeviceHandle,USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,USBASP_FUNC_ENABLEPROG, 0, 0,@enres, 1, 500);
                    if enres = 0 then
                      begin
                        lbStatus.Items[lbStatus.Count-1] := lbStatus.Items[lbStatus.Count-1]+'..'+strOK;
                        for a:=0 to 3 do
                          DeviceID[a] := ISP_transmit(DeviceHandle,$30,$00,a,$00);
                        Status(Format(strDeviceId,[DeviceID[0],DeviceID[1],DeviceID[2]]));
                        usb_control_msg(DeviceHandle,USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,USBASP_FUNC_DISCONNECT, 0, 0,nil, 1, 500);
                        if  (DeviceID[0] <> DeviceID[1])
                        and (DeviceID[1] <> DeviceID[2]) then
                          begin
                            SelectDevice;
                            break;
                          end;
                      end;
                    lbStatus.Items[lbStatus.Count-1] := lbStatus.Items[lbStatus.Count-1]+'..'+strFailed;
                    usb_control_msg(DeviceHandle,USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,USBASP_FUNC_DISCONNECT, 0, 0,nil, 1, 500);
                  end;
                DeviceAttatched := True;
              end;
          end
        else
          begin
            if (voltage > 20) and (voltage < 27) then
              Status(strDeviceWrongAttatched)
            else
              Status(strNoDeviceAttatched);
            DeviceAttatched := False;
            cbType.Enabled:=True;
          end;
      usb_close(DeviceHandle);
      except
      end;
    end;
end;

procedure TfProgrammer.miInfoClick(Sender: TObject);
begin
  fInfo.Showmodal;
end;

procedure TfProgrammer.NewMItemClick(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to miLanguage.Count-1 do
    if miLanguage[i].Caption = Language then
      miLanguage[i].Checked := false;
  TmenuItem(Sender).Checked := True;
  Language := TmenuItem(Sender).Caption;
  SetLanguage(Language);
  xpsProperties.StoredValue['LANGUAGE'] := Language;
end;

procedure TfProgrammer.sbFusesClick(Sender: TObject);
var
  Doc: TXMLDocument;
  aNode: TDOMNode;
  i: Integer;
  RegisterNode: TDOMNode;
  a: Integer;
  RegisterTreeNode: TTreeNode;
  b: Integer;
  NewNode: TTreeNode;
begin
  if cbType.ItemIndex = -1 then exit;
  xpsProperties.StoredValue['TYPE'] := cbType.Items[cbType.ItemIndex];
  ReadXMLFile(Doc,AppendPathDelim(ExtractFileDir(Application.Exename))+'progdata'+DirectorySeparator+cbType.Items[cbType.ItemIndex]+'.xml');
  aNode := nil;
  with Doc.DocumentElement.FindNode('templates').ChildNodes do
    for i := 0 to (Count - 1) do
      if (Item[i].Attributes.GetNamedItem('class') <> nil) and (Item[i].Attributes.GetNamedItem('class').NodeValue = 'FUSE') then
        aNode := Item[i];
  if Assigned(aNode) then
    with fChangeBits do
      begin
        tvFuses.Items.Clear;
        RegisterNode := aNode.FindNode('registers');
        with RegisterNode.ChildNodes do
          for i := 0 to (Count - 1) do
            begin
              RegisterTreeNode := tvFuses.Items.AddChildObject(nil,Item[i].Attributes.GetNamedItem('name').NodeValue,TRegisterItem.Create);
              with Item[i].ChildNodes do
                for a := 0 to (Count - 1) do
                  begin
                    if (Item[a].NodeName = 'bitfield') and (Item[a].Attributes.GetNamedItem('enum') = nil) then
                      TRegisterItem(RegisterTreeNode.Data).Add(tvFuses.Items.AddChildObject(RegisterTreeNode,Item[a].Attributes.GetNamedItem('name').NodeValue,TBitfieldItem.Create(Item[a].Attributes.GetNamedItem('text').NodeValue,Item[a].Attributes.GetNamedItem('mask').NodeValue,TRegisterItem(RegisterTreeNode.Data))).Data)
                    else if (Item[a].NodeName = 'bitfield') then
                      begin
                        for b := 0 to aNode.ChildNodes.Count-1 do
                          if (aNode.ChildNodes[b].NodeName = 'enumerator') and  (aNode.ChildNodes[b].Attributes.GetNamedItem('name').NodeValue = Item[a].Attributes.GetNamedItem('enum').NodeValue) then
                            begin
                              NewNode := tvFuses.Items.AddChildObject(RegisterTreeNode,Item[a].Attributes.GetNamedItem('name').NodeValue,
                              TEnumeratorItem.Create(Item[a].Attributes.GetNamedItem('text').NodeValue,aNode.ChildNodes[b],Item[a].Attributes.GetNamedItem('mask').NodeValue,TRegisterItem(RegisterTreeNode.Data)));
                              TRegisterItem(RegisterTreeNode.Data).Add(newNode.Data);
                              NewNode.Height:=24;
                            end;
                      end;
                  end;
              RegisterTreeNode.Expanded:=True;
            end;
      end;
  Doc.free;
  fChangeBits.Caption:= strFuses;
  if fChangeBits.ShowModal = mrOK then
    begin
      RegisterTreeNode := fChangeBits.tvFuses.Items[0];
      lFuseBits.Caption:='';
      while RegisterTreeNode <> nil do
        begin
          lFuseBits.Caption:=lFuseBits.Caption+'  '+RegisterTreeNode.Text+': 0x'+IntToHex(TRegisterItem(RegisterTreeNode.Data).RealValue,TRegisterItem(RegisterTreeNode.Data).RegisterLength*2)+#13;
          RegisterTreeNode := RegisterTreeNode.GetNextSibling;
        end;
      cbProgramFuses.Enabled:=True;
      xpsProperties.StoredValue['FUSES'] := lFuseBits.Caption;
    end;
end;

procedure TfProgrammer.sbLockBitsClick(Sender: TObject);
var
  Doc: TXMLDocument;
  aNode: TDOMNode;
  i: Integer;
  RegisterNode: TDOMNode;
  a: Integer;
  RegisterTreeNode: TTreeNode;
  b: Integer;
  NewNode: TTreeNode;
begin
  if cbType.ItemIndex = -1 then exit;
  xpsProperties.StoredValue['TYPE'] := cbType.Items[cbType.ItemIndex];
  ReadXMLFile(Doc,AppendPathDelim(ExtractFileDir(Application.Exename))+'progdata'+DirectorySeparator+cbType.Items[cbType.ItemIndex]+'.xml');
  aNode := nil;
  with Doc.DocumentElement.FindNode('templates').ChildNodes do
    for i := 0 to (Count - 1) do
      if (Item[i].Attributes.GetNamedItem('class') <> nil) and (Item[i].Attributes.GetNamedItem('class').NodeValue = 'LOCKBIT') then
        aNode := Item[i];
  if Assigned(aNode) then
    with fChangeBits do
      begin
        tvFuses.Items.Clear;
        RegisterNode := aNode.FindNode('registers');
        with RegisterNode.ChildNodes do
          for i := 0 to (Count - 1) do
            begin
              RegisterTreeNode := tvFuses.Items.AddChildObject(nil,Item[i].Attributes.GetNamedItem('name').NodeValue,TRegisterItem.Create);
              with Item[i].ChildNodes do
                for a := 0 to (Count - 1) do
                  begin
                    if (Item[a].NodeName = 'bitfield') and (Item[a].Attributes.GetNamedItem('enum') = nil) then
                      TRegisterItem(RegisterTreeNode.Data).Add(tvFuses.Items.AddChildObject(RegisterTreeNode,Item[a].Attributes.GetNamedItem('name').NodeValue,TBitfieldItem.Create(Item[a].Attributes.GetNamedItem('text').NodeValue,Item[a].Attributes.GetNamedItem('mask').NodeValue,TRegisterItem(RegisterTreeNode.Data))).Data)
                    else if (Item[a].NodeName = 'bitfield') then
                      begin
                        for b := 0 to aNode.ChildNodes.Count-1 do
                          if (aNode.ChildNodes[b].NodeName = 'enumerator') and  (aNode.ChildNodes[b].Attributes.GetNamedItem('name').NodeValue = Item[a].Attributes.GetNamedItem('enum').NodeValue) then
                            begin
                              NewNode := tvFuses.Items.AddChildObject(RegisterTreeNode,Item[a].Attributes.GetNamedItem('name').NodeValue,
                              TEnumeratorItem.Create(Item[a].Attributes.GetNamedItem('text').NodeValue,aNode.ChildNodes[b],Item[a].Attributes.GetNamedItem('mask').NodeValue,TRegisterItem(RegisterTreeNode.Data)));
                              TRegisterItem(RegisterTreeNode.Data).Add(newNode.Data);
                              NewNode.Height:=24;
                            end;
                      end;
                  end;
              RegisterTreeNode.Expanded:=True;
            end;
      end;
  Doc.free;
  fChangeBits.Caption:= strLockBits;
  if fChangeBits.ShowModal = mrOK then
    begin
      RegisterTreeNode := fChangeBits.tvFuses.Items[0];
      lLockBits.Caption:='';
      while RegisterTreeNode <> nil do
        begin
          lLockBits.Caption:=lLockBits.Caption+'  '+RegisterTreeNode.Text+': 0x'+IntToHex(TRegisterItem(RegisterTreeNode.Data).RealValue,TRegisterItem(RegisterTreeNode.Data).RegisterLength*2)+#13;
          RegisterTreeNode := RegisterTreeNode.GetNextSibling;
        end;
      cbProgramLockBits.Enabled:=True;
      xpsProperties.StoredValue['LOCKBITS'] := lLockBits.Caption;
    end;
end;

function GetIHexAddress(Hexline : string) : Integer;
var
  t: String;
begin
  Result := -1;
  if Hexline[1]=':' then
    begin
      t:='$'+copy(HexLine,4,4); // get address
      Result:=strtoint(t);
    end;
end;

function ReadIHexLine(HexLine:string;var Buf : bytearray):integer;
var
  ADDR,
  count:integer;
  CHKSUM,SUMLINE,RECLEN,RECTYPE,DATA:byte;
  t:shortstring;
  tmpline : string;
begin
  result := 0;
  tmpline := hexline;
  if tmpline[1]=':' then
    begin
      t:='$'+copy(HexLine,2,2);   // get length
      RECLEN:=strtoint(t);
      CHKSUM:=0;
      CHKSUM:=CHKSUM+RECLEN;
      t:='$'+copy(HexLine,4,4); // get address
      ADDR:=strtoint(t);
      CHKSUM:=CHKSUM+lo(ADDR)+hi(ADDR);
      t:='$'+copy(HexLine,8,2);
      RECTYPE:=strtoint(t);
      CHKSUM:=CHKSUM+RECTYPE;
      tmpline := copy(tmpline,10,length(tmpline));
      case RECTYPE of
      0:// datablock
        begin
          count:=0;
          while (count < RECLEN) do
            begin
              t:='$'+copy(tmpline,0,2);
              if length(tmpline) > 2 then
                tmpline := copy(tmpline,3,length(tmpline));
              DATA:=strtoint(t);
              CHKSUM:=CHKSUM+DATA;
              if length(Buf) < ADDR+count+1 then
                SetLength(Buf,ADDR+count+1);
              Buf[ADDR+count]:=DATA;
              inc(count);
            end;
          t:='$'+tmpline;
          SUMLINE:=strtoint(t);
        end;
      1: // end of file
        begin
          t:='$'+copy(HexLine,10,2);
          SUMLINE:=strtoint(t);
          result:=1;
        end;
      else
        begin
          result := -2;  // invalid record type
          exit;
        end;
      end; //case
      // test checksum
      DATA:=SUMLINE+CHKSUM;
//      if (DATA<>0) then result:=-3; // checksum error
    end
  else result:=-1; // no record
end;

procedure TfProgrammer.LoadCodedHexFile(Filename: string);
var
  f : Textfile;
  Res: LongInt;
  tmp,tmp1 : string;
  MaxSize: Integer;
const
  my_key = 928371;
begin
  Setlength(ProgramBuffer,0);
  StartAddress := 99999999;
  AssignFile(f,Filename);
  Reset(f);
  while not EOF(f) do
    begin
      readln(f,tmp);
      tmp1 := Decrypt(tmp, my_key);
      try
      if (GetIHexAddress(tmp) < StartAddress) and (GetIHexAddress(tmp) > -1) then
        StartAddress := GetIHexAddress(tmp);
      Res := ReadIHexLine(tmp1,ProgramBuffer);
      except
        Showmessage(tmp);
      end;
      if Res < 0 then
        begin
          Showmessage(strInvalidHexFile+' '+IntToStr(res)+' '+tmp1);
          exit;
        end;
    end;
  if Res <> 1 then
    Showmessage(strInvalidHexFile+' '+IntToStr(res));
  MaxSize := 6140;
  if Controller > CONTROLLER_ATMEGA88 then
    MaxSize := 14335;
  if length(ProgramBuffer) > MaxSize then
    begin
      Showmessage(strHexFileToBig);
      Setlength(ProgramBuffer,0);
      CloseFile(f);
      exit;
    end;
  CloseFile(f);
end;

procedure TfProgrammer.Enumerate;
var
  busses : PUSBBus;
  usb_bus: PUSBBus;
  c, i, a : Integer;
  dev :    PUSBDevice;
  DeviceHandle: PUSBDevHandle;
  typ,res : byte;
  Found : Boolean = False;
  Devicecount : Integer = 0;
  NewProgrammer : PUSBDevice = nil;
  LastDevice: PUSBDevice;
  Info: TSearchRec;
begin
  usb_init();
  usb_find_busses();
  usb_find_devices();

  busses := usb_get_busses();
  usb_bus := busses;
  while Assigned(usb_bus) do
    begin
      dev := usb_bus^.devices;
      while Assigned(dev) do
        begin
          if  (dev^.descriptor.idVendor = $16C0)
          and (dev^.descriptor.idProduct = $05dc) then
            begin
              DeviceHandle := usb_open(dev);
              res := usb_control_msg(DeviceHandle,USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_TYPE, 0, 0,@typ, 1, 5000);
              if res = 1 then
                begin
                  if Programmer = dev then Found := True;
                  inc(DeviceCount);
                  if typ = 2 then NewProgrammer := dev;
                  LastDevice := dev;
                end
              else if res > 1 then
                begin
                  Status(strProgrammernotaccessable);
                  exit;
                end;
            end;
          dev := dev^.next;
        end;
      usb_bus := usb_bus^.next
    end;
  if (not Found) and Assigned(NewProgrammer) then
    begin
      Status(strNewProgrammerFound);
      Programmer := NewProgrammer;
    end
  else if (not Found) then
    begin
      Status(strNoProgrammerConnected);
      Programmer := nil;
      if DeviceCount = 1 then
        begin
          if MessageDlg('USB AVR Lab Programmer',strProgrammermustbeupdated,mtConfirmation,[mbYes,mbNo],0) = mrYes then
            begin
              DeviceHandle := usb_open(LastDevice);
              res := usb_control_msg(DeviceHandle,USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_START_BOOTLOADER, 0, 0,nil, 0, 5000);
              usb_close(DeviceHandle);
              sleep(3000);
              busses := usb_get_busses();
              usb_bus := busses;
              LastDevice := usb_bus^.devices;
              if InitTarget(LastDevice) then
                If FindFirst (AppendPathDelim(ExtractFileDir(Application.Exename))+'data'+DirectorySeparator+Controller_str+'USBasp*.hex',faAnyFile,Info)=0 then
                  begin
                    LoadCodedhexFile(AppendPathDelim(ExtractFileDir(Application.Exename))+'data'+DirectorySeparator+Info.Name);
                    SysUtils.FindClose(Info);
                    ProgramDevice(LastDevice);
                    DeviceHandle := usb_open(LastDevice);
                    res := usb_control_msg(DeviceHandle,USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_LEAVE_BOOT, 0, 0,nil, 0, 5000);
                    usb_close(DeviceHandle);
                  end;
            end;
        end;
    end;
end;

procedure TfProgrammer.Status(NewStatus: string;AddToList : Boolean = True);
begin
  if not AddToList then
    begin
      lbStatus.Items[lbStatus.Count-1] := NewStatus;
      exit;
    end;
  if (lbStatus.Count > 0) and (NewStatus <> lbStatus.Items[lbStatus.Count-1]) then
    lbStatus.Items.Add(NewStatus)
  else if lbStatus.Count = 0 then
    lbStatus.Items.Add(NewStatus);
  lbStatus.ItemIndex:=lbStatus.Count-1;
end;

procedure TfProgrammer.SelectDevice;
var
  Info: TSearchRec;
  Doc: TXMLDocument;
  aNode: TDOMNode;
  Found: Boolean;
  i: Integer;
begin
  If FindFirst (AppendPathDelim(ExtractFileDir(Application.Exename))+'progdata'+DirectorySeparator+'*.xml',faAnyFile,Info)=0 then
    repeat
      ReadXMLFile(Doc,AppendPathDelim(ExtractFileDir(Application.Exename))+'progdata'+DirectorySeparator+Info.Name);
      aNode := nil;
      Found := True;
      with Doc.DocumentElement.FindNode('Signature').ChildNodes do
        for i := 0 to (Count - 1) do
          if StrToInt(StringReplace(Item[i].FirstChild.NodeValue,'0x','$',[])) <> DeviceID[i] then
            Found := False;
      Doc.Free;
      if Found then break;
    until FindNext(info)<>0;
  if Found then
    begin
      cbType.Text:=copy(Info.Name,0,length(Info.Name)-4);
      cbTypeSelect(nil);
      cbType.Enabled:=False;
      acProgramm.Enabled:=True;
    end;
  SysUtils.FindClose(Info);
end;

function TfProgrammer.InitTarget(Device : PUSBDevice): Boolean;
var
  DeviceHandle : PUSBDevHandle;
  res: LongInt;
begin
  Result := False;
  if Device = nil then exit;
  DeviceHandle := usb_open(Device);
  res := usb_control_msg(DeviceHandle,USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_TYPE, 0, 0,@ProgrammerType, 1, 5000);
  if res <> 1 then
    begin
      exit;
    end;
  if ProgrammerType = 1 then
    begin
      res := usb_control_msg(DeviceHandle,USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_GET_CONTROLLER, 0, 0,@Controller, 1, 5000);
      if res <> 1 then
        begin
          exit;
        end;
      Version := 0;
      if Controller > 10 then
        begin
          Version := Controller div 10;
          Controller := Controller mod 10;
        end;
      case Controller of
      CONTROLLER_ATMEGA8:
        begin
          Controller_str := 'm8_';
          Controller_long_str := 'ATMega8(L)';
        end;
      CONTROLLER_ATMEGA88:
        begin
          Controller_str := 'm88_';
          Controller_long_str := 'ATMega88(V)';
        end;
      CONTROLLER_ATMEGA168:
        begin
          Controller_str := 'm168_';
          Controller_long_str := 'ATMega168(V)';
        end;
      end;
      if Version > 0 then
        begin
          Controller_str := 'v'+IntToStr(Version)+Controller_str;
          Controller_long_str := Controller_long_str+' (V'+IntToStr(Version)+')';
        end;
      res := usb_control_msg(DeviceHandle,USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_GET_PAGESIZE, 0, 0,@PageSize, 2, 5000);
      if res <> 2 then
        begin
          exit;
        end;
      PageSize := (PageSize shr 8)+(PageSize shl 8);
    end;
  usb_close(DeviceHandle);
  Result := true;
end;

procedure TfProgrammer.ProgramDevice(Device: PUSBDevice);
var
  Page: Integer;
  res: LongInt;
  DeviceHandle: PUSBDevHandle;
begin
  DeviceHandle := usb_open(Device);
  for Page := 0 to length(ProgramBuffer) div PageSize do
    begin
      res := usb_control_msg(DeviceHandle,USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_OUT,FUNC_WRITE_PAGE,Page*PageSize,0,@ProgramBuffer[Page*PageSize], PageSize, 5000);
      if res <> PageSize then
        begin
          exit;
        end;
    end;
  usb_close(DeviceHandle);
end;

procedure TfProgrammer.SetLanguage(Lang: string);
begin
//  LoadLanguage(Lang);
end;

procedure TfProgrammer.cbProgramEEPROMChange(Sender: TObject);
begin
  feEEPROMFile.Enabled:=cbProgramEEPROM.Checked;
  if cbProgramEEPROM.Checked then
    xpsProperties.StoredValue['DOWRITEEEPROM'] := 'TRUE'
  else
    xpsProperties.StoredValue['DOWRITEEEPROM'] := 'FALSE';
end;

procedure TfProgrammer.acProgrammExecute(Sender: TObject);
var
  Process : TProcess;
  Buffer: string;
  Line : string;
  BytesAvailable: DWord;
  BytesRead:LongInt;
  NoMoreOutput: Boolean;
  Progress : Boolean;
  InfoProgress : TProgressBar = nil;
  InfoImage: TImage = nil;
  InfoLabel: TLabel = nil;
  OldBuffer: String;
  tmp: String;
  label Error;
function CorrectFileName(Filename : string) : string;
begin
  result := Filename;
end;

function ProcessStuff(Line : string) : Boolean;
  function LineStart(aCmp : string) : Boolean;
  begin
    Result := copy(Line,0,length(aCmp)) = aCmp;
  end;
begin
  Result := True;
  if not (copy(Line,0,12) = 'avrdude.exe:') then exit;
//  OutputMemo.Lines.Add(Line);
  Line := trim(copy(Line,13,length(line)));
  if line = 'erasing chip' then
    begin
      InfoImage := Image1;
      InfoLabel := lStep1;
      InfoProgress := nil;
      InfoImage.Picture.Assign(iOK.Picture);
      InfoLabel.Caption:=InfoLabel.Caption+strOK;
      Update;
    end
  else if LineStart('reading input file') and ((InfoLabel = lStep2) or (not cbProgramFlash.Checked)) then
    begin
      InfoImage := Image3;
      InfoLabel := lStep3;
      InfoProgress := ProgressBar2;
      InfoImage.Picture.Assign(iHourglass.Picture);
      Update;
    end
  else if pos('bytes of flash written',Line) > 0 then
    begin
      InfoImage.Picture.Assign(iOK.Picture);
      InfoLabel.Caption:=InfoLabel.Caption+strOK;
    end
  else if LineStart('reading input file') then
    begin
      InfoImage := Image2;
      InfoLabel := lStep2;
      InfoProgress := ProgressBar1;
      InfoImage.Picture.Assign(iHourglass.Picture);
      Update;
    end
  else if LineStart('writing hfuse') or LineStart('writing lfuse') or LineStart('writing efuse') then
    begin
      InfoImage := Image4;
      InfoLabel := lStep4;
      InfoProgress := nil;
      InfoImage.Picture.Assign(iHourglass.Picture);
      Update;
    end
  else if LineStart('writing lock') then
    begin
      InfoImage := Image5;
      InfoLabel := lStep5;
      InfoProgress := nil;
      InfoImage.Picture.Assign(iHourglass.Picture);
      Update;
    end
  else if (pos('bytes of hfuse written',Line) > 0) or (pos('bytes of lfuse written',Line) > 0) or (pos('bytes of efuse written',Line) > 0) or (pos('bytes of lock written',Line) > 0) then
    begin
      InfoImage.Picture.Assign(iOK.Picture);
      InfoLabel.Caption:=InfoLabel.Caption+strOK;
    end

  else if LineStart('ERROR:') or LineStart('error') then
    begin
      if Assigned(InfoLabel) then
        begin
          InfoLabel.Caption := InfoLabel.Caption + Line;
          InfoImage.Picture.Assign(iFailed.Picture);
        end;
      Result := false;
    end;
end;

begin
  if bProgramm.Caption = strOK then
    begin
      bProgramm.Caption:=acProgramm.Caption;
      pProgress.Visible:=False;
      pProgramm.Visible := True;
      exit;
    end;
  acProgramm.Enabled:=False;
  SetLanguage(Language);
  Image1.Picture.Clear;
  Image2.Picture.Clear;
  Image3.Picture.Clear;
  Image4.Picture.Clear;
  Image5.Picture.Clear;
  pProgress.Visible:=True;
  pProgramm.Visible := False;
//  pProgress.BringToFront;
  Process := TProcess.Create(nil);
  Process.CommandLine := {$IFDEF WINDOWS}AppendPathDelim(ExtractFileDir(Application.Exename))+'tools'+DirectorySeparator+{$ENDIF}'avrdude -c usbasp -F -V -p '+cbType.Text;
  if cbProgramFlash.Checked then
    Process.CommandLine := Process.CommandLine+' -U flash:w:"'+CorrectFileName(feFlashFile.FileName)+'":a';
  if cbProgramEEprom.Checked then
    Process.CommandLine := Process.CommandLine+' -U eeprom:w:"'+CorrectFileName(feEEPRomFile.FileName)+'":a';
  if cbProgramFuses.Checked then
    begin
      tmp := lFuseBits.Caption;
      tmp := Stringreplace(tmp,'LOW: ',' -U lfuse:w:',[]);
      tmp := Stringreplace(tmp,'HIGH: ',' -U hfuse:w:',[]);
      tmp := Stringreplace(tmp,'EXTENDED: ',' -U efuse:w:',[]);
      tmp := Stringreplace(tmp,#13,':m ',[rfReplaceAll]);
      Process.CommandLine := Process.CommandLine+tmp;
    end;

  if cbProgramLockBits.Checked then
    begin
      tmp := lFuseBits.Caption;
      tmp := Stringreplace(tmp,'LOCKBIT: ',' -U lock:w:',[]);
      tmp := Stringreplace(tmp,#13,':m ',[rfReplaceAll]);
      Process.CommandLine := Process.CommandLine+tmp;
    end;

  Process.Options := [poUsePipes, poNoConsole, poStdErrToOutPut,poDefaultErrorMode, poNewProcessGroup];
  Process.ShowWindow := swoNone;
  Process.Execute;
  Progress := False;
//  OutputMemo.Clear;
  while Process.Running or (Process.Output.NumBytesAvailable > 0) do
    begin
      sleep(100);
      BytesAvailable := Process.Output.NumBytesAvailable;
      BytesRead := 0;
      while BytesAvailable>0 do
        begin
          SetLength(Buffer, BytesAvailable);
          BytesRead := Process.OutPut.Read(Buffer[1], BytesAvailable);
          BytesAvailable := Process.Output.NumBytesAvailable;
          NoMoreOutput := false;
//          OutputMemo.Text := OutputMemo.Text+Buffer;
          OldBuffer := Buffer;
          while pos(LineEnding,Buffer) > 0 do
            begin
              Line := Line+copy(Buffer,0,pos(LineEnding,Buffer)-1);
              if not ProcessStuff(Line) then goto Error;
              Buffer := copy(Buffer,pos(LineEnding,Buffer)+length(LineEnding),length(Buffer));
              Line := '';
            end;
          Buffer := OldBuffer;
          if not Progress then
            begin
              if pos('Reading |',Buffer) > 0 then
                begin
                  Buffer := copy(Buffer, pos('Reading |',Buffer)+10,length(Buffer));
                  Progress := true;
                end
              else if pos('Writing |',Buffer) > 0 then
                begin
                  Buffer := copy(Buffer, pos('Writing |',Buffer)+10,length(Buffer));
                  Progress := True;
                end;
            end;
          if Progress then
            begin
              while copy(Buffer,0,1) = '#' do
                begin
                  if Assigned(InfoProgress) then
                    InfoProgress.Position:=InfoProgress.Position+1;
                  Buffer := copy(Buffer,2,length(Buffer));
                end;
              if copy(Buffer,0,2) = ' |' then
                begin
                  Progress := false;
                  if Assigned(InfoProgress) then
                    InfoProgress.Position:=0;
                end;
            end
        end;
      Application.Processmessages;
    end;
Error:
  Process.free;
  bProgramm.Caption := strOK;
  acProgramm.Enabled:=True;
  InfoImage := nil;
  InfoLabel := nil;
  InfoProgress := nil;
end;

{ TRegisterItem }

procedure TRegisterItem.SetRealValue(const AValue: word);
begin
  FValue := not aValue;
end;

function TRegisterItem.GetRealValue: word;
begin
  Result := (not FValue) and 255;
end;

procedure TRegisterItem.ChangeValue(Sender: TObject);
begin
  if Sender is TEdit then
    Value := not StrToIntDef('$'+copy(TEdit(Sender).Text,3,length(TEdit(Sender).Text)),0);
  fChangeBits.tvFuses.Invalidate;
end;

constructor TRegisterItem.Create;
begin
  inherited;
  FLength := 1;
end;

{ TFuseItem }

constructor TFuseItem.Create(Desc: string;aParent : TRegisterItem);
begin
  FDescription := Desc;
  FParent := aParent;
end;

{ TBitFieldItem }

function TBitFieldItem.GetValue: Boolean;
begin
  if Assigned(FParent) then
    Result := FParent.Value and FMask = FMask;
end;

constructor TBitFieldItem.Create(Desc: string; aMask: string;aParent : TRegisterItem);
begin
  inherited Create(Desc,aParent);
  FMask := StrToInt(StringReplace(aMask,'0x','$',[]));
end;

procedure TBitFieldItem.ChangeValue(Sender: TObject);
begin
  if Assigned(FParent) then
    begin
      if TCheckBox(Sender).Checked then
        FParent.Value := FParent.Value or FMask
      else
        FParent.Value := FParent.Value xor FMask;
    end;
  fChangeBits.tvFuses.Invalidate;
end;

{ TEnumeratorItem }

function TEnumeratorItem.GetValue: Integer;
begin
  Result := (not (FParent.Value and FMask) and FMask) shr FShiftCount;
end;

function TEnumeratorItem.GetValueName: string;
var
  i: Integer;
begin
  for i := 0 to ValuesList.Count-1 do
    if Integer(ValuesList[i]) = GetValue then
      begin
        Result := NamesList[i];
        break;
      end;
end;

constructor TEnumeratorItem.Create(Desc: string; enum_node: TDOMNode;aMask : string;
  aParent: TRegisterItem);
var
  i: Integer;
  a: LongInt;
begin
  inherited Create(Desc,aParent);
  NamesList := TStringList.Create;
  FMask := StrToInt(StringReplace(aMask,'0x','$',[]));
  a := FMask;
  FShiftCount := 0;
  while a and 1 <> 1 do
    begin
      a := a shr 1;
      inc(FShiftCount);
    end;
  ValuesList := TList.Create;
  for i := 0 to enum_node.ChildNodes.Count-1 do
    begin
      NamesList.Add(enum_node.ChildNodes[i].Attributes.GetNamedItem('text').NodeValue);
      ValuesList.Add(Pointer(StrToInt(enum_node.ChildNodes[i].Attributes.GetNamedItem('val').NodeValue)));
    end;
end;

procedure TEnumeratorItem.ChangeValue(Sender: TObject);
var
  aValue: Integer;
begin
  if NamesList.IndexOf(TComboBox(Sender).Text) = -1 then exit;
  if not Assigned(FParent) then exit;
  aValue := (Integer(ValuesList[NamesList.IndexOf(TComboBox(Sender).Text)]) shl FShiftCount);
  FParent.Value:=FParent.Value and (not FMask);
  FParent.Value:=FParent.Value or ((not aValue) and FMask);
  fChangeBits.tvFuses.Invalidate;
end;

initialization
  {$I uprogrammer.lrs}

end.

