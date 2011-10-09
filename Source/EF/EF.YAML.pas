///	<summary>
///	  Simple YAML reader and writer providing persistence for EF trees.
///	</summary>
unit EF.YAML;

interface

uses
  Classes, Generics.Collections,
  EF.Tree;

type
  TEFYAMLValueType = (vtSingleLine, vtMultiLineWithNL, vtMultiLineWithSpace);

  TEFYAMLParser = class
  private
    FIndents: TList<Integer>;
    FPrevIndent: Integer;
    FLastValueType: TEFYAMLValueType;
    FLastIndentIncrement: Integer;
    FNextValueType: TEFYAMLValueType;
    FMultiLineFirstLineIndent: Integer;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
  public
    procedure Reset;
    function ParseLine(const ALine: string; out AName, AValue: string): Boolean;
    property LastValueType: TEFYAMLValueType read FLastValueType;
    property LastIndentIncrement: Integer read FLastIndentIncrement;
  end;

  TEFYAMLReader = class
  private
    FParser: TEFYAMLParser;
    function GetParser: TEFYAMLParser;
  public
    destructor Destroy; override;
    property Parser: TEFYAMLParser read GetParser;
  public
    procedure LoadTreeFromFile(const ATree: TEFTree; const AFileName: string);
    procedure LoadTreeFromStream(const ATree: TEFTree; const AStream: TStream);
  end;

  TEFYAMLWriter = class
  private
    FIndentChars: Integer;
    FSpacingChars: Integer;
    FQuote: string;
    procedure WriteNode(const ANode: TEFNode; const AWriter: TTextWriter;
      const AIndent: Integer);
  public
    procedure AfterConstruction; override;
  public
    procedure SaveTreeToFile(const ATree: TEFTree; const AFileName: string);
    procedure SaveTreeToStream(const ATree: TEFTree; const AStream: TStream);
  end;

implementation

uses
  SysUtils,
  EF.Types, EF.StrUtils;

{ TEFYAMLParser }

procedure TEFYAMLParser.AfterConstruction;
begin
  inherited;
  FIndents := TList<Integer>.Create;
  Reset;
end;

destructor TEFYAMLParser.Destroy;
begin
  FreeAndNil(FIndents);
  inherited;
end;

function TEFYAMLParser.ParseLine(const ALine: string; out AName, AValue: string): Boolean;
var
  LLine: string;
  P: Integer;
  LIndent: Integer;

  procedure AddIndent(const AIndent: Integer);
  begin
    if (FIndents.Count = 0) then
      FIndents.Add(AIndent)
    else if (FIndents[FIndents.Count - 1] = AIndent) then
      Exit
    else if (FIndents[FIndents.Count - 1] < AIndent) then
      FIndents.Add(AIndent)
    // top indent > AIndent - check.
    else if FIndents.IndexOf(AIndent) < 0 then
      raise EEFError.CreateFmt('YAML syntax error. Indentation error in ine: %s', [ALine]);
  end;

begin
  Result := False;

  FLastValueType := vtSingleLine;
  // Handle multi-line values.
  if FNextValueType in [vtMultiLineWithNL, vtMultiLineWithSpace] then
  begin
    LIndent := CountLeading(ALine, ' ');
    // The indentation of the first line in a multi-line value is important
    // because we need to strip exactly that number of spaces from the
    // beginning of all other lines.
    if FMultiLineFirstLineIndent < 0 then
      FMultiLineFirstLineIndent := LIndent;
    // A multi-line value continues as long as lines are indented. Note that in
    // this case we exit WITHOUT updating FPrevIndent.
    if LIndent > FPrevIndent then
    begin
      AName := '';
      AValue := Copy(ALine, FMultiLineFirstLineIndent + 1, MaxInt);
      FLastValueType := FNextValueType;
      Result := True;
      Exit;
    end
    else
    begin
      // Multi-line value finished. Reset variables.
      FLastValueType := vtSingleLine;
      FMultiLineFirstLineIndent := -1;
    end;
  end;

  if Pos(#9, ALine) > 0 then
    raise EEFError.CreateFmt('YAML syntax error. Tab character (#9) not allowed. Use spaces only for indentation. Line: %s', [ALine]);

  LLine := Trim(ALine);
  // Skip comments.
  if (LLine = '') or (LLine[1] = '#') then
    Exit;

  P := Pos(':', ALine);
  if P = 0 then
    raise EEFError.CreateFmt('YAML syntax error. Missing ":" in line: %s', [ALine]);

  AName := Copy(ALine, 1, Pred(P));
  LIndent := CountLeading(AName, ' ');
  AddIndent(LIndent);

  AName := Trim(AName);
  AValue := Trim(Copy(Aline, Succ(P), MaxInt));

  // Watch for special introducers.
  if AValue = '|' then
  begin
    FNextValueType := vtMultiLineWithNL;
  end
  else if AValue = '>' then
  begin
    FNextValueType := vtMultiLineWithSpace
  end
  else
    FNextValueType := vtSingleLine;

  if FNextValueType = vtSingleLine then
    AValue := StripPrefixAndSuffix(AValue, '"', '"')
  else
    AValue := '';
  // Keep track of how many indents we have incremented or decremented.
  // Users of this class will use this information to track nesting.
  FLastIndentIncrement := FIndents.IndexOf(LIndent) - FIndents.IndexOf(FPrevIndent);
  FPrevIndent := LIndent;
  Result := True;
end;

procedure TEFYAMLParser.Reset;
begin
  FIndents.Clear;
  FPrevIndent := 0;
  FMultiLineFirstLineIndent := -1;
end;

{ TEFYAMLReader }

destructor TEFYAMLReader.Destroy;
begin
  FreeAndNil(FParser);
  inherited;
end;

function TEFYAMLReader.GetParser: TEFYAMLParser;
begin
  if not Assigned(FParser) then
    FParser := TEFYAMLParser.Create;
  Result := FParser;
end;

procedure TEFYAMLReader.LoadTreeFromFile(const ATree: TEFTree; const AFileName: string);
var
  LFileStream: TFileStream;
begin
  Assert(Assigned(ATree));

  LFileStream := TFileStream.Create(AFileName, fmOpenRead + fmShareDenyWrite);
  try
    LoadTreeFromStream(ATree, LFileStream);
  finally
    FreeAndNil(LFileStream);
  end;
end;

procedure TEFYAMLReader.LoadTreeFromStream(const ATree: TEFTree; const AStream: TStream);
var
  LStack: TStack<TEFNode>;
  LLine: string;
  LName, LRawValue: string;
  LTop: TEFTree;
  LReader: TStreamReader;
  LCurrentValue: string;

  procedure TryPopFromStack(const AAmount: Integer);
  var
    I: Integer;
  begin
    for I := 0 to AAmount do
      if LStack.Count > 0 then
        LStack.Pop;
  end;

begin
  Assert(Assigned(ATree));

  LReader := TStreamReader.Create(AStream);
  try
    LStack := TStack<TEFNode>.Create;
    try
      ATree.Clear;
      Parser.Reset;

      repeat
        LLine := LReader.ReadLine;
        if Parser.ParseLine(LLine, LName, LRawValue) then
        begin
          if Parser.LastValueType = vtSingleLine  then
            TryPopFromStack(-Parser.LastIndentIncrement);
          if LStack.Count = 0 then
            LTop := ATree
          else
            LTop := LStack.Peek;
          case Parser.LastValueType of
            vtSingleLine: LStack.Push(LTop.AddChild(LName, LRawValue));
            vtMultiLineWithNL:
            begin
              LCurrentValue := (LTop as TEFNode).AsString;
              if LCurrentValue = '' then
                LCurrentValue := LRawValue
              else
                LCurrentValue := LCurrentValue + sLineBreak + LRawValue;
              (LTop as TEFNode).AsString := LCurrentValue;
            end;
            vtMultiLineWithSpace:
            begin
              LCurrentValue := (LTop as TEFNode).AsString;
              // When not preserving line breaks, empty lines mark paragraphs.
              if LRawValue = '' then
                LCurrentValue := LCurrentValue + sLineBreak
              else if LCurrentValue = '' then
                LCurrentValue := LRawValue
              else
                LCurrentValue := LCurrentValue + ' ' + LRawValue;
              (LTop as TEFNode).AsString := LCurrentValue;
            end;
          end;
        end;
      until LReader.EndOfStream;
    finally
      FreeAndNil(LStack);
    end;
  finally
    FreeAndNil(LReader);
  end;
end;

{ TEFYAMLWriter }

procedure TEFYAMLWriter.AfterConstruction;
begin
  inherited;
  FIndentChars := 4;
  FSpacingChars := 1;
  FQuote := '';
end;

procedure TEFYAMLWriter.SaveTreeToFile(const ATree: TEFTree; const AFileName: string);
var
  LFileStream: TFileStream;
begin
  Assert(Assigned(ATree));

  LFileStream := TFileStream.Create(AFileName, fmCreate + fmShareExclusive);
  try
    SaveTreeToStream(ATree, LFileStream);
  finally
    FreeAndNil(LFileStream);
  end;
end;

procedure TEFYAMLWriter.SaveTreeToStream(const ATree: TEFTree; const AStream: TStream);
var
  LWriter: TStreamWriter;
  I: Integer;
  LIndent: Integer;
begin
  Assert(Assigned(ATree));

  LIndent := 0;
  LWriter := TStreamWriter.Create(AStream, TEncoding.UTF8);
  try
    for I := 0 to ATree.ChildCount - 1 do
      WriteNode(ATree.Children[I], LWriter, LIndent);
    LWriter.Flush;
  finally
    FreeAndNil(LWriter);
  end;
end;

procedure TEFYAMLWriter.WriteNode(const ANode: TEFNode;
  const AWriter: TTextWriter; const AIndent: Integer);
var
  I: Integer;
begin
  AWriter.Write(StringOfChar(' ', AIndent) + ANode.Name + ':');
  { TODO : format value }
  if ANode.AsString <> '' then
    AWriter.Write(StringOfChar(' ', FSpacingChars) + FQuote + ANode.AsString + FQuote);
  AWriter.WriteLine;
  for I := 0 to ANode.ChildCount - 1 do
    WriteNode(ANode.Children[I], AWriter, AIndent + FIndentChars);
end;

end.