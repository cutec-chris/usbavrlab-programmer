unit uChangeBits;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  ComCtrls, Themes, uProgrammer, StdCtrls, Buttons, Process, Utils;

type

  { TfChangeBits }

  TfChangeBits = class(TForm)
    bRead: TBitBtn;
    bOK: TBitBtn;
    bAbort: TBitBtn;
    hcFuses: THeaderControl;
    tvFuses: TTreeView;
    procedure bReadClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure hcFusesSectionResize(HeaderControl: TCustomHeaderControl;
      Section: THeaderSection);
    procedure tvFusesAdvancedCustomDrawItem(Sender: TCustomTreeView;
      Node: TTreeNode; State: TCustomDrawState; Stage: TCustomDrawStage;
      var PaintImages, DefaultDraw: Boolean);
    procedure tvFusesSelectionChanged(Sender: TObject);
  private
    { private declarations }
    aEdit : TControl;
  public
    { public declarations }
  end; 

var
  fChangeBits: TfChangeBits;

implementation

{ TfChangeBits }

procedure TfChangeBits.hcFusesSectionResize(HeaderControl: TCustomHeaderControl;
  Section: THeaderSection);
begin
  tvFuses.Selected := nil;
  tvFuses.Invalidate;
end;

procedure TfChangeBits.FormResize(Sender: TObject);
begin
  tvFuses.Selected := nil;
end;

procedure TfChangeBits.bReadClick(Sender: TObject);
var
  Process : TProcess;
  Buffer: string;
  Output : string;
  BytesAvailable: DWord;
  BytesRead:LongInt;
  Fuse : Byte;
  f: File of byte;
  RegisterTreeNode: TTreeNode;
begin
  bRead.Enabled:=False;
  RegisterTreeNode := tvFuses.Items[0];
  while RegisterTreeNode <> nil do
    begin
      Process := TProcess.Create(nil);
      Process.CommandLine := AppendPathDelim(ExtractFileDir(Application.Exename))+'tools'+DirectorySeparator+'avrdude.exe -c usbasp -p '+fProgrammer.cbType.Text;
      if RegisterTreeNode.Text = 'LOW' then
        Process.CommandLine := Process.CommandLine+' -U lfuse:r:"'+GetTempDir+'dude.hex'+'":r'
      else if RegisterTreeNode.Text = 'HIGH' then
        Process.CommandLine := Process.CommandLine+' -U hfuse:r:"'+GetTempDir+'dude.hex'+'":r'
      else if RegisterTreeNode.Text = 'EXTENDED' then
        Process.CommandLine := Process.CommandLine+' -U efuse:r:"'+GetTempDir+'dude.hex'+'":r'
      else if RegisterTreeNode.Text = 'LOCKBIT' then
        Process.CommandLine := Process.CommandLine+' -U lock:r:"'+GetTempDir+'dude.hex'+'":r'
      else
        begin
          RegisterTreeNode := RegisterTreeNode.GetNextSibling;
          continue;
        end;
      Process.Options := [poWaitOnExit, poNoConsole, poStdErrToOutPut,poDefaultErrorMode, poNewProcessGroup];
      Process.ShowWindow := swoNone;
      Process.Execute;
      Process.Free;
      AssignFile(f,GetTempDir+'dude.hex');
      Reset(f);
      read(f,Fuse);
      CloseFile(f);
      DeleteFile(GetTempDir+'dude.hex');
      TRegisterItem(RegisterTreeNode.Data).RealValue := Fuse;
      RegisterTreeNode := RegisterTreeNode.GetNextSibling;
    end;
  fChangeBits.tvFuses.Invalidate;
  bRead.Enabled:=True;
end;

procedure TfChangeBits.tvFusesAdvancedCustomDrawItem(Sender: TCustomTreeView;
  Node: TTreeNode; State: TCustomDrawState; Stage: TCustomDrawStage;
  var PaintImages, DefaultDraw: Boolean);
var
  aRect: TRect;
  isChecked: Cardinal;
  Details: TThemedElementDetails;
begin
  if Assigned(Node.Data) and (not (cdsSelected in State)) then
    begin
      DefaultDraw := False;
      aRect := Node.DisplayRect(False);
      Sender.Canvas.Font.Color:=Sender.Font.Color;
      if TObject(Node.Data) is TRegisterItem then
        Sender.Canvas.Brush.Color := cl3DLight
      else
        Sender.Canvas.Brush.Color := clWindow;
      if cdsSelected in State then
        begin
          Sender.Canvas.Brush.Color := clHighlight;
          Sender.Canvas.Font.Color:= clHighlightText;
        end;
      Sender.Canvas.Pen.Color:=Sender.Canvas.Brush.Color;
      Sender.Canvas.Rectangle(aRect);
      Sender.Canvas.TextOut(aRect.Left+4,aRect.Top+(arect.Bottom-aRect.Top-Sender.Canvas.TextExtent(Node.text).cy) div 2,Node.text);
      if TObject(Node.Data) is TRegisterItem then
        Sender.Canvas.TextOut(hcFuses.Sections[0].Width+4,aRect.Top,'0x'+IntToHex(TRegisterItem(Node.Data).RealValue,TRegisterItem(Node.Data).RegisterLength*2));
      if TObject(Node.Data) is TBitFieldItem then
        begin
          Sender.Canvas.TextOut(hcFuses.Sections[0].Width+4+14+4,aRect.Top,TFuseItem(Node.Data).Description);
          if TBitFieldItem(Node.Data).Value then
            Details := ThemeServices.GetElementDetails(tbCheckBoxCheckedNormal)
          else
            Details := ThemeServices.GetElementDetails(tbCheckBoxUnCheckedNormal);
          ThemeServices.DrawElement(Sender.Canvas.Handle, Details, Rect(hcFuses.Sections[0].Width+4,aRect.Top+2,hcFuses.Sections[0].Width+4+14,aRect.Bottom-2));
        end
      else if TObject(Node.Data) is TEnumeratorItem then
        Sender.Canvas.TextOut(hcFuses.Sections[0].Width+4,aRect.Top+(arect.Bottom-aRect.Top-Sender.Canvas.TextExtent(TEnumeratorItem(Node.Data).ValueName).cy) div 2,TEnumeratorItem(Node.Data).ValueName)
      else if TObject(Node.Data) is TFuseItem then
        Sender.Canvas.TextOut(hcFuses.Sections[0].Width+4,aRect.Top+(arect.Bottom-aRect.Top-Sender.Canvas.TextExtent(TEnumeratorItem(Node.Data).ValueName).cy) div 2,TFuseItem(Node.Data).Description);
    end;
end;

procedure TfChangeBits.tvFusesSelectionChanged(Sender: TObject);
var
  aRect : TRect;
begin
  if Assigned(aEdit) then
    FreeAndNil(aEdit);
  with Sender as TTreeView do
    begin
      if (not Assigned(Selected)) or (not Assigned(Selected.Data)) then exit;
      if TObject(Selected.Data) is TRegisterItem then
        begin
          aEdit := TEdit.Create(Self);
          aEdit.Visible:=False;
          TEdit(aEdit).Text := '0x'+IntToHex(TRegisterItem(Selected.Data).RealValue,TRegisterItem(Selected.Data).RegisterLength*2);
          TEdit(aEdit).OnChange:=@TRegisterItem(Selected.Data).ChangeValue;
        end
      else if TObject(Selected.Data) is TBitFieldItem then
        begin
          aEdit := TCheckBox.Create(Self);
          aEdit.Visible:=False;
          TCheckBox(aEdit).Checked:=TBitFieldItem(Selected.Data).Value;
          TCheckBox(aEdit).Color:= clHighlight;
          TCheckBox(aEdit).Caption := TBitFieldItem(Selected.Data).Description;
          TCheckBox(aEdit).OnChange:=@TBitFieldItem(Selected.Data).ChangeValue;
          TCheckBox(aEdit).AutoSize:=False;
        end
      else if TObject(Selected.Data) is TEnumeratorItem then
        begin
          aEdit := TComboBox.Create(Self);
          aEdit.Visible:=False;
          TCombobox(aEdit).Items.Assign(TEnumeratorItem(Selected.Data).NamesList);
          TCombobox(aEdit).Text := TEnumeratorItem(Selected.Data).ValueName;
          TCombobox(aEdit).DropDownCount:=20;
          TCombobox(aEdit).OnChange:=@TEnumeratorItem(Selected.Data).ChangeValue;
        end;

      if not Assigned(aEdit) then exit;
      aEdit.Parent := TTreeView(Sender);
      aRect := Selected.DisplayRect(False);
      aEdit.SetBounds(hcFuses.Sections[0].Width+4,aRect.Top,aRect.Right-hcFuses.Sections[0].Width-4,aRect.Bottom-aRect.Top);
      aEdit.Visible:=True;
    end;
end;

initialization
  {$I uchangebits.lrs}

end.

