
program INIEx;

{$APPTYPE CONSOLE}
{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

uses
  System.SysUtils,
  System.Classes,
  System.Math;

type
  TSection = class
  public
    KeysOrder: TStringList;
    KeyValues: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;

  TIniDB = class
  private
    FSections: TStringList;
    class function NormalizePath(const S: string): string; static;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function EnsureSection(const Name: string): TSection;
    procedure LoadFromFile(const FileName: string; const Encoding: TEncoding);
    function HasSection(const Sec: string): Boolean;
    function HasValue(const Sec, Key: string): Boolean;
    function ReadString(const Sec, Key: string): string;
    function GetSectionKeysCount(const Sec: string): Integer;
    function GetSectionKey(const Sec: string; Idx: Integer): string;
    function GetSubSections(const MainSec: string; RootOnly: Boolean)
      : TArray<string>;
    function GetSubSectionsCount(const MainSec: string;
      RootOnly: Boolean): Integer;
    function GetSubSection(const MainSec: string; Idx: Integer;
      RootOnly: Boolean): string;
  end;

{ ============================ Utils ( StrUtils) ============================ }
function StartsWith(const S, Prefix: string): Boolean;
begin
  Result := (Length(S) >= Length(Prefix)) and
    (Copy(S, 1, Length(Prefix)) = Prefix);
end;

function EndsWith(const S, Suffix: string): Boolean;
begin
  Result := (Length(S) >= Length(Suffix)) and
    (Copy(S, Length(S) - Length(Suffix) + 1, Length(Suffix)) = Suffix);
end;

function BuildTargetSection(const MainSec, SubSec: string): string;
var
  A, B: string;
begin
  A := StringReplace(MainSec, '|', '\', [rfReplaceAll]);
  B := StringReplace(SubSec, '|', '\', [rfReplaceAll]);

  if (A <> '') and EndsWith(A, '\') then
    Delete(A, Length(A), 1);
  if (B <> '') and StartsWith(B, '\') then
    Delete(B, 1, 1);

  if (A <> '') and (B <> '') then
    Result := A + '\' + B
  else if A <> '' then
    Result := A
  else
    Result := B;

  while Pos('\\', Result) > 0 do
    Result := StringReplace(Result, '\\', '\', []);
end;

{ ====== WRITE helpers (minimal dependencies; preserve comments/order) ====== }
function NormalizeSecPath(const S: string): string;
var
  R: string;
begin
  R := Trim(StringReplace(S, '|', '\', [rfReplaceAll]));
  while Pos('\\', R) > 0 do
    R := StringReplace(R, '\\', '\', [rfReplaceAll]);
  while (Length(R) > 0) and (R[1] = '\') do
    Delete(R, 1, 1);
  while (Length(R) > 0) and (R[Length(R)] = '\') do
    Delete(R, Length(R), 1);
  Result := R;
end;

procedure LoadUtf8NoBom(const FileName: string; L: TStrings);
var
  FS: TFileStream;
  Bytes: TBytes;
  Off: Integer;
begin
  L.Clear;
  if not FileExists(FileName) then
    Exit;
  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Bytes, FS.Size);
    if FS.Size > 0 then
      FS.ReadBuffer(Bytes[0], FS.Size);
  finally
    FS.Free;
  end;
  Off := 0;
  if (Length(Bytes) >= 3) and (Bytes[0] = $EF) and (Bytes[1] = $BB) and
    (Bytes[2] = $BF) then
    Off := 3;
  L.Text := TEncoding.UTF8.GetString(Bytes, Off, Length(Bytes) - Off);
end;

procedure SaveUtf8NoBom(const FileName: string; L: TStrings);
var
  FS: TFileStream;
  Enc: TEncoding;
  B: TBytes;
begin
  Enc := TUTF8Encoding.Create(False);
  try
    B := Enc.GetBytes(L.Text);
    if ExtractFilePath(FileName) <> '' then
      ForceDirectories(ExtractFilePath(FileName));
    FS := TFileStream.Create(FileName, fmCreate or fmShareExclusive);
    try
      if Length(B) > 0 then
        FS.WriteBuffer(B[0], Length(B));
    finally
      FS.Free;
    end;
  finally
    Enc.Free;
  end;
end;

function FindSectionRange(const L: TStrings; const Section: string;
  out FirstIdx, AfterIdx: Integer): Boolean;
var
  i, j: Integer;
  Canon, Line, Name: string;
begin
  Result := False;
  FirstIdx := -1;
  AfterIdx := L.Count;
  Canon := NormalizeSecPath(Section);

  for i := 0 to L.Count - 1 do
  begin
    Line := Trim(L[i]);
    if (Line <> '') and (Line[1] = '[') and (Line[Length(Line)] = ']') then
    begin
      Name := Copy(Line, 2, Length(Line) - 2);
      if NormalizeSecPath(Name) = Canon then
      begin
        FirstIdx := i;
        AfterIdx := L.Count;
        for j := i + 1 to L.Count - 1 do
        begin
          Line := Trim(L[j]);
          if (Line <> '') and (Line[1] = '[') and (Line[Length(Line)] = ']')
          then
          begin
            AfterIdx := j;
            Break;
          end;
        end;
        Exit(True);
      end;
    end;
  end;
end;

function SetIniValue(const FileName, Section, Key, Value: string): Boolean;
var
  L: TStringList;
  S: string;
  FirstIdx, AfterIdx, i, Eq: Integer;
  Found: Boolean;
begin
  Result := False;
  if Trim(Key) = '' then
    Exit;
  L := TStringList.Create;
  try
    L.LineBreak := sLineBreak;
    LoadUtf8NoBom(FileName, L);

    if not FindSectionRange(L, Section, FirstIdx, AfterIdx) then
    begin
      if (L.Count > 0) and (Trim(L[L.Count - 1]) <> '') then
        L.Add('');
      L.Add('[' + NormalizeSecPath(Section) + ']');
      FirstIdx := L.Count - 1;
      AfterIdx := L.Count;
    end;

    Found := False;
    for i := FirstIdx + 1 to AfterIdx - 1 do
    begin
      S := L[i];
      if (Trim(S) = '') then
        Continue;
      if (Trim(S) <> '') and CharInSet(Trim(S)[1], [';', '#']) then
        Continue;
      Eq := Pos('=', S);
      if Eq > 1 then
        if SameText(Trim(Copy(S, 1, Eq - 1)), Key) then
        begin
          L[i] := Copy(S, 1, Eq) + Value;
          Found := True;
          Break;
        end;
    end;

    if not Found then
      L.Insert(AfterIdx, Key + '=' + Value);

    SaveUtf8NoBom(FileName, L);
    Result := True;
  finally
    L.Free;
  end;
end;

function SetIniSubValue(const FileName, MainSec, SubSec, Key,
  Value: string): Boolean;
var
  FullSec: string;
begin
  if Trim(SubSec) <> '' then
    FullSec := NormalizeSecPath(MainSec) + '\' + NormalizeSecPath(SubSec)
  else
    FullSec := NormalizeSecPath(MainSec);
  Result := SetIniValue(FileName, FullSec, Key, Value);
end;

function ParamValue(const Name: string; const Def: string = ''): string;
var
  i, Eq: Integer;
  P, S: string;
begin
  Result := Def;
  for i := 1 to ParamCount do
  begin
    P := ParamStr(i);
    if StartsWith(P, '/' + Name + '=') or StartsWith(P, '-' + Name + '=') then
    begin
      Eq := Pos('=', P);
      if Eq > 0 then
      begin
        S := Copy(P, Eq + 1, MaxInt);
        if (Length(S) >= 2) and (S[1] = '"') and (S[Length(S)] = '"') then
          S := Copy(S, 2, Length(S) - 2);
        Exit(S);
      end;
    end;
  end;
end;

function LastNonSwitchParam: string;
var
  i: Integer;
  P: string;
begin
  Result := '';
  for i := ParamCount downto 1 do
  begin
    P := ParamStr(i);
    if not(StartsWith(P, '/') or StartsWith(P, '-')) then
    begin
      Result := P;
      Break;
    end;
  end;
  if (Length(Result) >= 2) and (Result[1] = '"') and
    (Result[Length(Result)] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

function StrToBoolLoose(const S: string): Boolean;
var
  L: string;
begin
  L := Trim(LowerCase(S));
  Result := (L = '1') or (L = 'true') or (L = 'yes') or (L = 'y');
end;

function ParseSizeToBytes(const S: string): Int64;
var
  L, Num: string;
  Mult, V: Double;
begin
  L := Trim(LowerCase(S));
  Mult := 1;
  Num := L;

  if EndsWith(L, 'tb') then
  begin
    Num := Copy(L, 1, Length(L) - 2);
    Mult := Power(1024, 4);
  end
  else if EndsWith(L, 'gb') then
  begin
    Num := Copy(L, 1, Length(L) - 2);
    Mult := Power(1024, 3);
  end
  else if EndsWith(L, 'mb') then
  begin
    Num := Copy(L, 1, Length(L) - 2);
    Mult := Power(1024, 2);
  end
  else if EndsWith(L, 'kb') then
  begin
    Num := Copy(L, 1, Length(L) - 2);
    Mult := 1024;
  end
  else if EndsWith(L, 'b') then
  begin
    Num := Copy(L, 1, Length(L) - 1);
    Mult := 1;
  end;

  Num := Trim(Num);
  if StartsWith(Num, '0x') then
    V := StrToInt64Def('$' + Copy(Num, 3, MaxInt), 0)
  else
    V := StrToFloatDef(Num, 0);

  Result := Trunc(V * Mult);
end;

procedure WriteOutput(const OutPath, S: string);
var
  FS: TFileStream;
  Bytes: TBytes;
  Enc: TEncoding;
begin
  if OutPath = '' then
    Exit;
  if ExtractFilePath(OutPath) <> '' then
    ForceDirectories(ExtractFilePath(OutPath));

  Enc := TUTF8Encoding.Create(False);
  try
    Bytes := Enc.GetBytes(S);
  finally
    Enc.Free;
  end;

  FS := TFileStream.Create(OutPath, fmCreate);
  try
    FS.WriteBuffer(Bytes[0], Length(Bytes));
  finally
    FS.Free;
  end;
end;

procedure PrintShortHelp;
begin
  Writeln('INIExe INI helper with nested sub-sections');
  Writeln('Usage: INIExe.exe <Command> [switches] ["/o=""C:\out.txt"""] "C:\file.ini"');
  Writeln('Try: /? or --LongHelp');
end;

procedure PrintLongHelp;
begin
  Writeln('Commands:');
  Writeln('IsSectionExists /Sec=<Section>');
  Writeln('IsSubSectionExists /MainSec=<Main> /SubSec=<A|B|C>');
  Writeln('IsValueExists /Sec=<Section> /Key=<Key>');
  Writeln('IsSubValueExists /MainSec=<Main> /SubSec=<A|B|C> /Key=<Key>');
  Writeln('ReadString /Sec=<Section> /Key=<Key>');
  Writeln('ReadSubString /MainSec=<Main> /SubSec=<A|B|C> /Key=<Key>');
  Writeln('GetSectionKeysCount /Sec=<Section>');
  Writeln('GetSectionKey /Sec=<Section> /Idx=<N>');
  Writeln('GetSubSectionsCount /MainSec=<Main> [/RootOnly=true]');
  Writeln('GetSubSection /MainSec=<Main> /Idx=<N> [/RootOnly=true]');
  Writeln('GetSubSectionKeysCount /MainSec=<Main> /SubSec=<A|B|C> [/RootOnly=true]');
  Writeln('GetSubSectionKey /MainSec=<Main> /SubSec=<A|B|C> /Idx=<N> [/RootOnly=true]');
  Writeln('CalcTotalDiskSizeByte /MainSec=<Main> /Key=<Key>');
  Writeln('SetString /Sec=<Section> /Key=<Key> /Value=<Value>');
  Writeln('SetSubString /MainSec=<Main> /SubSec=<A|B|C> /Key=<Key> /Value=<Value>');
  Writeln;
  Writeln('Notes: "\" and "|" both accepted as level delimiters. UTF-8 INI expected.');
end;

{ ================================= TSection ================================ }
constructor TSection.Create;
begin
  inherited Create;
  KeysOrder := TStringList.Create;
  KeyValues := TStringList.Create;
  KeyValues.NameValueSeparator := '=';
  KeyValues.StrictDelimiter := False;
end;

destructor TSection.Destroy;
begin
  KeyValues.Free;
  KeysOrder.Free;
  inherited;
end;

{ ================================== TIniDB ================================= }
constructor TIniDB.Create;
begin
  inherited Create;
  FSections := TStringList.Create;
  FSections.Sorted := False;
end;

destructor TIniDB.Destroy;
begin
  Clear;
  FSections.Free;
  inherited;
end;

procedure TIniDB.Clear;
var
  i: Integer;
begin
  for i := 0 to FSections.Count - 1 do
    TObject(FSections.Objects[i]).Free;
  FSections.Clear;
end;

function TIniDB.EnsureSection(const Name: string): TSection;
var
  Idx: Integer;
  N: string;
begin
  N := TIniDB.NormalizePath(Name);
  Idx := FSections.IndexOf(N);
  if Idx >= 0 then
    Result := TSection(FSections.Objects[Idx])
  else
  begin
    Result := TSection.Create;
    FSections.AddObject(N, TObject(Result));
  end;
end;

class function TIniDB.NormalizePath(const S: string): string;
var
  R: string;
begin
  R := Trim(StringReplace(S, '|', '\', [rfReplaceAll]));
  while Pos('\\', R) > 0 do
    R := StringReplace(R, '\\', '\', []);
  if (R <> '') and (R[1] = '\') then
    R := Copy(R, 2, MaxInt);
  if (R <> '') and (R[Length(R)] = '\') then
    Delete(R, Length(R), 1);
  Result := R;
end;

procedure TIniDB.LoadFromFile(const FileName: string;
  const Encoding: TEncoding);
var
  SL: TStringList;
  CurSec, Line, Key, Val: string;
  i, EqPos: Integer;
  Sct: TSection;
begin
  if not FileExists(FileName) then
    raise Exception.CreateFmt('INI not found: %s', [FileName]);

  Clear;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(FileName, Encoding);
    CurSec := '';
    for i := 0 to SL.Count - 1 do
    begin
      Line := Trim(SL[i]);
      if (Line = '') or StartsWith(Line, ';') or StartsWith(Line, '#') then
        Continue;

      if StartsWith(Line, '[') and EndsWith(Line, ']') then
      begin
        CurSec := TIniDB.NormalizePath(Copy(Line, 2, Length(Line) - 2));
        EnsureSection(CurSec);
      end
      else
      begin
        if CurSec = '' then
          Continue;
        EqPos := Pos('=', Line);
        if EqPos > 0 then
        begin
          Key := Trim(Copy(Line, 1, EqPos - 1));
          Val := Trim(Copy(Line, EqPos + 1, MaxInt));
          Sct := EnsureSection(CurSec);
          if Sct.KeyValues.IndexOfName(Key) < 0 then
            Sct.KeysOrder.Add(Key);
          Sct.KeyValues.Values[Key] := Val;
        end;
      end;
    end;
  finally
    SL.Free;
  end;
end;

function TIniDB.HasSection(const Sec: string): Boolean;
var
  N: string;
begin
  N := TIniDB.NormalizePath(Sec);
  Result := FSections.IndexOf(N) >= 0;
end;

function TIniDB.HasValue(const Sec, Key: string): Boolean;
var
  N: string;
  Idx: Integer;
  Sct: TSection;
begin
  N := TIniDB.NormalizePath(Sec);
  Idx := FSections.IndexOf(N);
  if Idx < 0 then
    Exit(False);
  Sct := TSection(FSections.Objects[Idx]);
  Result := Sct.KeyValues.IndexOfName(Key) >= 0;
end;

function TIniDB.ReadString(const Sec, Key: string): string;
var
  N: string;
  Idx: Integer;
  Sct: TSection;
begin
  Result := '';
  N := TIniDB.NormalizePath(Sec);
  Idx := FSections.IndexOf(N);
  if Idx < 0 then
    Exit;
  Sct := TSection(FSections.Objects[Idx]);
  Result := Sct.KeyValues.Values[Key];
end;

function TIniDB.GetSectionKeysCount(const Sec: string): Integer;
var
  N: string;
  Idx: Integer;
  Sct: TSection;
begin
  N := TIniDB.NormalizePath(Sec);
  Idx := FSections.IndexOf(N);
  if Idx < 0 then
    Exit(0);
  Sct := TSection(FSections.Objects[Idx]);
  Result := Sct.KeysOrder.Count;
end;

function TIniDB.GetSectionKey(const Sec: string; Idx: Integer): string;
var
  N: string;
  sidx: Integer;
  Sct: TSection;
begin
  Result := '';
  N := TIniDB.NormalizePath(Sec);
  sidx := FSections.IndexOf(N);
  if sidx < 0 then
    Exit;
  Sct := TSection(FSections.Objects[sidx]);
  if (Idx >= 0) and (Idx < Sct.KeysOrder.Count) then
    Result := Sct.KeysOrder[Idx];
end;

function TIniDB.GetSubSections(const MainSec: string; RootOnly: Boolean)
  : TArray<string>;
var
  Root, SecName, Tail, Child: string;
  List: TStringList;
  i, P: Integer;
begin
  Root := TIniDB.NormalizePath(MainSec);
  List := TStringList.Create;
  try
    for i := 0 to FSections.Count - 1 do
    begin
      SecName := FSections[i];

      if Root <> '' then
      begin
        if not StartsWith(SecName, Root + '\') then
          Continue;
      end;

      Tail := Copy(SecName, Length(Root) + 1, MaxInt);
      if (Tail <> '') and StartsWith(Tail, '\') then
        Tail := Copy(Tail, 2, MaxInt);
      if Tail = '' then
        Continue;

      if RootOnly then
      begin
        P := Pos('\', Tail);
        if P > 0 then
          Child := Copy(Tail, 1, P - 1)
        else
          Child := Tail;

        if List.IndexOf(Child) < 0 then
          List.Add(Child);
      end
      else
      begin
        Child := Tail;
        if List.IndexOf(Child) < 0 then
          List.Add(Child);
      end;
    end;

    SetLength(Result, List.Count);
    for i := 0 to List.Count - 1 do
      Result[i] := List[i];
  finally
    List.Free;
  end;
end;

function TIniDB.GetSubSectionsCount(const MainSec: string;
  RootOnly: Boolean): Integer;
begin
  Result := Length(GetSubSections(MainSec, RootOnly));
end;

function TIniDB.GetSubSection(const MainSec: string; Idx: Integer;
  RootOnly: Boolean): string;
var
  Arr: TArray<string>;
begin
  Arr := GetSubSections(MainSec, RootOnly);
  if (Idx >= 0) and (Idx < Length(Arr)) then
    Result := Arr[Idx]
  else
    Result := '';
end;

{ ============================== Command Exec =============================== }
function ExecCommand(const DB: TIniDB; const Cmd: string): string;
var
  Sec, MainSec, SubSec, Key: string;
  RootOnly: Boolean;
  Idx: Integer;
  Total: Int64;
  Subs: TArray<string>;
  S, Target, V: string;

  function OutBool(B: Boolean): string;
  begin
    if B then
      Result := '1'
    else
      Result := '0';
  end;

begin
  Result := '';

  if SameText(Cmd, '/?') or SameText(Cmd, '--help') then
  begin
    Result := 'help';
    Exit;
  end;

  if SameText(Cmd, '--LongHelp') then
  begin
    Result := 'longhelp';
    Exit;
  end;

  Sec := ParamValue('Sec');
  MainSec := ParamValue('MainSec');
  SubSec := ParamValue('SubSec');
  Key := ParamValue('Key');
  RootOnly := StrToBoolLoose(ParamValue('RootOnly', 'false'));
  Idx := StrToIntDef(ParamValue('Idx', '-1'), -1);

  if SameText(Cmd, 'IsSectionExists') then
    Result := OutBool(DB.HasSection(Sec))
  else if SameText(Cmd, 'IsSubSectionExists') then
    Result := OutBool(DB.HasSection(BuildTargetSection(MainSec, SubSec)))
  else if SameText(Cmd, 'IsValueExists') then
    Result := OutBool(DB.HasValue(Sec, Key))
  else if SameText(Cmd, 'IsSubValueExists') then
    Result := OutBool(DB.HasValue(BuildTargetSection(MainSec, SubSec), Key))
  else if SameText(Cmd, 'ReadString') then
    Result := DB.ReadString(Sec, Key)
  else if SameText(Cmd, 'ReadSubString') then
    Result := DB.ReadString(BuildTargetSection(MainSec, SubSec), Key)
  else if SameText(Cmd, 'GetSectionKeysCount') then
    Result := IntToStr(DB.GetSectionKeysCount(Sec))
  else if SameText(Cmd, 'GetSectionKey') then
    Result := DB.GetSectionKey(Sec, Idx)
  else if SameText(Cmd, 'GetSubSectionsCount') then
    Result := IntToStr(DB.GetSubSectionsCount(MainSec, RootOnly))
  else if SameText(Cmd, 'GetSubSection') then
    Result := DB.GetSubSection(MainSec, Idx, RootOnly)
  else if SameText(Cmd, 'GetSubSectionKeysCount') then
    Result := IntToStr(DB.GetSectionKeysCount
      (BuildTargetSection(MainSec, SubSec)))
  else if SameText(Cmd, 'GetSubSectionKey') then
    Result := DB.GetSectionKey(BuildTargetSection(MainSec, SubSec), Idx)
  else if SameText(Cmd, 'CalcTotalDiskSizeByte') then
  begin
    Total := 0;
    Subs := DB.GetSubSections(MainSec, False);
    for S in Subs do
    begin
      Target := BuildTargetSection(MainSec, S);
      V := DB.ReadString(Target, Key);
      if V <> '' then
        Inc(Total, ParseSizeToBytes(V));
    end;
    Result := IntToStr(Total);
  end

  else if SameText(Cmd, 'SetString') then
  begin
    Sec := ParamValue('Sec');
    Key := ParamValue('Key');
    V := ParamValue('Value');
    S := LastNonSwitchParam;
    if (Sec = '') or (Key = '') or (V = '') or (S = '') then
      raise Exception.Create
        ('SetString requires /Sec /Key /Value and ini path');
    if SetIniValue(S, Sec, Key, V) then
      Result := '1'
    else
      Result := '0';
  end
  else if SameText(Cmd, 'SetSubString') then
  begin
    MainSec := ParamValue('MainSec');
    SubSec := ParamValue('SubSec');
    Key := ParamValue('Key');
    V := ParamValue('Value');
    S := LastNonSwitchParam;
    if (MainSec = '') or (Key = '') or (V = '') or (S = '') then
      raise Exception.Create
        ('SetSubString requires /MainSec /Key /Value and ini path');
    if SetIniSubValue(S, MainSec, SubSec, Key, V) then
      Result := '1'
    else
      Result := '0';
  end
  else
    raise Exception.CreateFmt('Unknown command: %s', [Cmd]);
end;

{ ================================== Main =================================== }
var
  IniPath, OutPath, Cmd, Res: string;
  DB: TIniDB;

begin
  try
    if ParamCount = 0 then
    begin
      PrintShortHelp;
      Halt(1);
    end;

    Cmd := ParamStr(1);

    if SameText(Cmd, '/?') or SameText(Cmd, '--help') then
    begin
      PrintShortHelp;
      Halt(0);
    end;

    if SameText(Cmd, '--LongHelp') then
    begin
      PrintLongHelp;
      Halt(0);
    end;

    OutPath := ParamValue('o');
    IniPath := LastNonSwitchParam;
    if IniPath = '' then
      raise Exception.Create('INI path is not specified');

    DB := TIniDB.Create;
    try
      DB.LoadFromFile(IniPath, TEncoding.UTF8);
      Res := ExecCommand(DB, Cmd);
    finally
      DB.Free;
    end;

    if SameText(Res, 'help') then
      PrintShortHelp
    else if SameText(Res, 'longhelp') then
      PrintLongHelp
    else
    begin
      Writeln(Res);
      if OutPath <> '' then
        WriteOutput(OutPath, Res);
    end;

    Halt(0);
  except
    on E: Exception do
    begin
      Writeln('[error] ' + E.Message);
      OutPath := ParamValue('o');
      if OutPath <> '' then
        WriteOutput(OutPath, '[error] ' + E.Message);
      Halt(2);
    end;
  end;

end.
