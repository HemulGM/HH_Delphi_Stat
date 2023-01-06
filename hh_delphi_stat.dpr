program hh_delphi_stat;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.StrUtils,
  System.Math,
  System.NetEncoding,
  HGM.Common.Download,
  HGM.ArrayHelper,
  HGM.SQLang in '..\SQLite\HGM.SQLang.pas',
  HGM.SQLite in '..\SQLite\HGM.SQLite.pas',
  HGM.SQLite.Wrapper in '..\SQLite\HGM.SQLite.Wrapper.pas';

const
  TG_BOT_TOKEN = {$INCLUDE bot_key.api_key};
  VK_BOT_TOKEN = {$INCLUDE vk_bot_key.api_key};

var
  Commontext: string;

procedure CreateTables(DB: TSQLiteDatabase);
begin
  with SQL.CreateTable('items') do
  begin
    AddField('id', ftInteger, True, True);
    AddField('name', ftString);
    AddField('value', ftInteger);
    AddField('salary', ftInteger);
    AddField('date', ftDateTime);
    DB.ExecSQL(GetSQL);
    EndCreate;
  end;
end;

procedure AddValue(DB: TSQLiteDatabase; Name: string; Value, Salary, SMin, SMax: integer);
begin
  with SQL.InsertInto('items') do
  begin
    AddValueAsParam('name');
    AddValueAsParam('value');
    AddValueAsParam('date');
    AddValueAsParam('min');
    AddValueAsParam('max');
    DB.ExecSQL(GetSQL, [Name, Value, Now, SMin, SMax]);
    EndCreate;
  end;
end;

function GetLastValue(DB: TSQLiteDatabase; Name: string): integer;
begin
  with SQL.Select('items', ['value']) do
  begin
    WhereFieldLike('name', '?');
    Limit := 1;
    OrderBy('id', True);
    Result := DB.GetTableValue(GetSQL, [Name]);
    EndCreate;
  end;
end;

function FormatQuery(const Value: string; Size: integer): string;
begin
  Result := Value.PadRight(Size, ' ');
end;

function GetHHSalaryMedian(JSON: TJSONValue; out SMin, SMax: Integer): Integer;
begin
  Result := 0;
  SMin := Integer.MaxValue;
  SMax := 0;
  var Salary: integer := 0;
  var Salaries: TArray<integer>;
  var Items: TJSONArray;
  if JSON.TryGetValue('items', Items) then
  begin
    var Curr: string;
    var ItemCount := 0;
    SetLength(Salaries, Items.Count);
    for var Item in Items do
    begin
      if Item.TryGetValue('salary.from', Salary) and Item.TryGetValue('salary.currency', Curr) and (Curr = 'RUR') then
      begin
        if (Salary < SMin) and (Salary <> 0) then
          SMin := Salary;
        if Salary > SMax then
          SMax := Salary;
        Salaries[ItemCount] := Salary;
        Inc(ItemCount);
      end;
    end;
    SetLength(Salaries, ItemCount);
    if ItemCount > 0 then
    begin
      TArrayHelp.Sort<integer>(Salaries,
        function(const Left, Right: integer): Integer
        begin
          Result := IfThen(Left > Right, 1, 0);
        end);
      Result := Salaries[ItemCount div 2] div 1000;
    end;
  end;
  if SMin = Integer.MaxValue then
    SMin := 0;
  SMin := SMin div 1000;
  SMax := SMax div 1000;
end;

procedure QueryHHVacancie(DB: TSQLiteDatabase; const Name, Query: string);
begin
  var Response: string;
  if TDownload.GetText('https://api.hh.ru/vacancies?text=' + TURLEncoding.URL.Encode(Query) + '&professional_role=96&search_field=description&search_field=name&enable_snippets=true&per_page=100', Response) then
  begin
    var JSON := TJSONObject.ParseJSONValue(Response);
    var Count: integer;
    if Assigned(JSON) and JSON.TryGetValue('found', Count) then
    try
      var DeltaStr := '';
      var Delta := GetLastValue(DB, Name);
      if Delta >= 0 then
      begin
        Delta := Count - Delta;
        DeltaStr := ' (' + IfThen(Delta > 0, '+') + Delta.ToString + ')';
      end;
      var SMin, SMax: Integer;
      var Salary := GetHHSalaryMedian(JSON, SMin, SMax);
      CommonText := CommonText + FormatQuery(FormatQuery(Query + ': ', 14) + FormatQuery(Count.ToString, 4) + DeltaStr, 28) + ' ~' + FormatQuery(Salary.ToString + 'k', 4) + ' (' + SMin.ToString + '-' + SMax.ToString + ')' + #13#10;
      Writeln('Вакансий на HH для ', Query, ': ', Count, DeltaStr, ' ~', Salary, 'k', ' ', SMin, '-', SMax);
      AddValue(DB, Name, Count, Salary, SMin, SMax);
    finally
      JSON.Free;
    end;
  end;
end;

procedure SendToTelegram(ChatId: string; const Text: string);
begin
  TDownload.GetRequest('https://api.telegram.org/' + TG_BOT_TOKEN +
    '/sendMessage?chat_id=' + ChatId +
    '&parse_mode=Markdown' +
    '&text=' + TURLEncoding.URL.Encode(Text));
end;

procedure SendToVk(ChatId: integer; const Text: string);
begin
  TDownload.GetRequest('https://api.vk.com/method/messages.send?access_token=' + VK_BOT_TOKEN +
    '&peer_id=' + ChatId.ToString +
    '&random_id=0' +
    '&v=5.144' +
    '&message=' + TURLEncoding.URL.Encode(Text));
end;

begin
  try
    var Ticks := TThread.GetTickCount;
    var DB := TSQLiteDatabase.Create('stat.db');
    try
      CreateTables(DB);
      CommonText := CommonText + 'Вакансий на HH: ' + #13#10;
      QueryHHVacancie(DB, 'delphi_hh', 'Delphi');
      QueryHHVacancie(DB, 'pascal_hh', 'Pascal');
      QueryHHVacancie(DB, 'python_hh', 'Python');
      QueryHHVacancie(DB, 'c-sharp_hh', 'C#');
      QueryHHVacancie(DB, 'cpp_hh', 'C++');
      QueryHHVacancie(DB, 'swift_hh', 'Swift');
      QueryHHVacancie(DB, 'java_hh', 'Java');
      QueryHHVacancie(DB, 'vb_hh', 'Visual Basic');
      QueryHHVacancie(DB, 'go_hh', 'Go');
      QueryHHVacancie(DB, 'ruby_hh', 'Ruby');
      QueryHHVacancie(DB, 'kotlin_hh', 'Kotlin');
      QueryHHVacancie(DB, 'rust_hh', 'Rust');
      QueryHHVacancie(DB, 'fortran_hh', 'Fortran');
      QueryHHVacancie(DB, 'dart_hh', 'Dart');
      //
      CommonText := CommonText + #13#10;
      QueryHHVacancie(DB, 'flutter_hh', 'Flutter');
      QueryHHVacancie(DB, 'fmx_hh', 'FireMonkey');
      QueryHHVacancie(DB, 'electron_hh', 'Electron');
      QueryHHVacancie(DB, 'lazarus_hh', 'Lazarus');
      QueryHHVacancie(DB, 'react_hh', 'React Native');
      QueryHHVacancie(DB, 'postgresql_hh', 'PostgreSQL');
      //QueryHHVacancie(DB, 'fgx_hh', 'FGX');
      {$IFDEF RELEASE}
      //Delphi оффтоп
      SendToTelegram('-1001212064902', '#hhwork ' + '```'#13#10 + CommonText + '```');
      SendToVk(2000000008, CommonText);
      //DevGeeks
      {$ENDIF}
      //Тестовый чат
      SendToTelegram('-1001525223801', '#hhwork ' + '```'#13#10 + CommonText + '```');
      Writeln(CommonText);
    finally
      DB.Free;
    end;
    Writeln(TThread.GetTickCount - Ticks, 'ms');
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  {$IFDEF DEBUG}
  readln;
  {$ENDIF}
end.

