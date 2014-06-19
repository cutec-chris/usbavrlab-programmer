program usbavrlabavrprogrammer;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms
  { you can add units after this }, uProgrammer, general,
uChangeBits, LResources;

{$IFDEF WINDOWS}{$R usbavrlabavrprogrammer.rc}{$ENDIF}

begin
  {$I usbavrlabavrprogrammer.lrs}
  Application.Initialize;
  Application.CreateForm(TfProgrammer, fProgrammer);
  Application.CreateForm(TfChangeBits, fChangeBits);
  Application.Run;
end.

