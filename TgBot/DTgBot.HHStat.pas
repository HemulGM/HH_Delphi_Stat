unit DTgBot.HHStat;

interface

uses
  System.SysUtils, System.Json, System.NetEncoding, HGM.Common.Download,
  TgBotApi, TgBotApi.Client;

procedure ProcHHQuery(u: TtgUpdate);

implementation

uses
  System.StrUtils, System.Math, HGM.ArrayHelper;

function GetHHSalaryMedian(JSON: TJSONValue): Integer;
begin
  Result := 0;
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
      //for var i in Salaries do
      //  Writeln(i);
    end;
  end;
end;

function QueryHHVacancie(const Query: string): string;
begin
  var Response: string;
  if TDownload.GetText('https://api.hh.ru/vacancies?text=' + TURLEncoding.URL.Encode(Query) + '&per_page=100', Response) then
  begin
    var JSON := TJSONObject.ParseJSONValue(Response);
    var Count: integer;
    if Assigned(JSON) and JSON.TryGetValue('found', Count) then
    try
      var Salary := GetHHSalaryMedian(JSON);
      Result := Query + ' ' + Count.ToString + ' ~' + Salary.ToString + 'k';
    finally
      JSON.Free;
    end;
  end;
end;

procedure ProcHHQuery(u: TtgUpdate);
var
  Query: string;
begin
  Query := u.Message.Text;
  Query := Query.Replace('/hh ', '');

  if not Query.IsEmpty then
  begin
    Query := QueryHHVacancie(Query);
    if not Query.IsEmpty then
      Client.SendMessageToChat(u.Message.Chat.Id, Query);
  end;
end;

end.

