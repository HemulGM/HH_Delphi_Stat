program delphi_stat_chart;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  FMX.Graphics,
  System.Types,
  System.Math,
  FMX.Types,
  System.UITypes,
  System.DateUtils,
  System.NetEncoding,
  HGM.Common.Download,
  VK.API,
  System.Generics.Collections,
  HGM.SQLang in '..\..\SQLite\HGM.SQLang.pas',
  HGM.SQLite in '..\..\SQLite\HGM.SQLite.pas',
  HGM.SQLite.Wrapper in '..\..\SQLite\HGM.SQLite.Wrapper.pas',
  System.Classes,
  VK.Types;

const
  TG_BOT_TOKEN = {$INCLUDE ..\bot_key.api_key};
  VK_BOT_TOKEN = {$INCLUDE ..\vk_bot_key.api_key};

const
  MonthStart = 1;
  MonthEnd = 30;
  {$IFDEF DEBUG}
  DATA_BASE_FILE = '..\..\..\Win32\Debug\stat.db';
  {$ENDIF}
  {$IFDEF RELEASE}
  DATA_BASE_FILE = '..\..\..\Win32\Release\stat.db';
  {$ENDIF}

type
  TChartItem = record
    Name: string;
    Value: integer;
    Date: TDateTime;
  end;

  TChartData = class(TList<TChartItem>)
    procedure Add(Name: string; Value: Integer; Date: TDateTime);
    function FindByDay(const Name: string; Day: integer; var ChartItem: TChartItem): Boolean;
  end;

  TChartElements = array[MonthStart..MonthEnd] of TChartItem;

  TChartItemInfo = record
  private
    FCaption: string;
  public
    Name: string;
    Offset: Integer;
    Color: TAlphaColor;
    constructor Create(const AName: string; AColor: TAlphaColor; ACaption: string; AOffset: Integer = 0);
    function Caption: string;
  end;

  TChartItemInfoItems = TArray<TChartItemInfo>;

function GetDate: TDateTime;
begin
  Result := Now; //.IncDay(5);
end;

{ TChartData }

procedure TChartData.Add(Name: string; Value: Integer; Date: TDateTime);
var
  Item: TChartItem;
begin
  Item.Name := Name;
  Item.Value := Value;
  if (Name = 'python_hh') or
    (Name = 'java_hh') or
    (Name = 'postgresql_hh')
    then
  begin
    Item.Value := Value - 10000;
    Item.Name := Name;
  end;
  Item.Date := Date;
  inherited Add(Item);
end;

function TChartData.FindByDay(const Name: string; Day: integer; var ChartItem: TChartItem): Boolean;
begin
  for var Item in Self do
    if (Item.Name = Name) and (DayOf(Item.Date) = Day) then
    begin
      ChartItem := Item;
      Exit(True);
    end;
  Result := False;
end;

function GetChartData(DB: TSQLiteDatabase; Data: TChartData): Boolean;
var
  Table: TSQLiteTable;
begin
  with SQL.Select('items', ['name', 'value', 'date']) do
  begin
    var Dt := GetDate;
    WhereFieldBetween('date', IncMonth(Dt, -1), Dt);
    Table := DB.Query(GetSQL);
    try
      while not Table.EoF do
      begin
        Data.Add(Table.FieldAsString('name'), Table.FieldAsInteger('value'), Table.FieldAsDateTime('date'));
        Table.Next;
      end;
      Result := Data.Count > 0;
    finally
      Table.Free;
    end;
    EndCreate;
  end;
end;

function GetChartDataFor(Data: TChartData; const Name: string): TChartElements;

  function EmptyItem: TChartItem;
  begin
    Result.Name := Name;
    Result.Value := 0;
  end;

var
  Item: TChartItem;
begin
  for var i := MonthEnd downto MonthStart do
  begin
    if Data.FindByDay(Name, DayOf(IncDay(GetDate, -i)), Item) then
      Result[30 - i + 1] := Item
    else
      Result[30 - i + 1] := EmptyItem;
  end;
end;

procedure PrintData(Data: TChartData);
begin
  for var Item in Data do
    Writeln(Item.Name, ' ', Item.Value, ' ', DateToStr(Item.Date));
end;

function GetMaxValue(Data: TChartData; Items: TChartItemInfoItems): Integer;
begin
  Result := 0;
  for var ChartItem in Items do
    for var Day := MonthEnd downto MonthStart do
    begin
      var Item: TChartItem;
      if Data.FindByDay(ChartItem.Name, DayOf(IncDay(GetDate, -Day)), Item) then
        if Item.Value > Result then
          Result := Item.Value;
    end;
end;

function GetChart(Data: TChartData; Stream: TStream; ChartItems: TChartItemInfoItems): Boolean;
begin
  Result := True;
  //Кол-во шагов по ординат
  var PointVertCount := 15;
  var TextHeigth := 28;
  var OffsetTop := 30 + 60;
  //Отступ легенды
  var TextOffset := 95;
  //Отступ слева для шкалы и легенды (начало графиков)
  var Offset := TextOffset + 75;
  var BMP := TBitmap.Create(1280, 800);
  var Mesure := (BMP.Width - Offset) div 30;
  var ChartHeigth := BMP.Height - Mesure;
  BMP.Canvas.BeginScene;
  BMP.Canvas.Clear($FF1A1B1F);
  try
    BMP.Canvas.Fill.Color := $DDFFFFFF;
    BMP.Canvas.Stroke.Color := $FF36373A;
    BMP.Canvas.Stroke.Thickness := 1;
    BMP.Canvas.Stroke.Cap := TStrokeCap.Round;
    BMP.Canvas.Font.Family := 'Roboto';
    BMP.Canvas.Font.Size := 12;

    //Рисуем ординату и основную шкалу (текст и точки)
    var MaxValue := GetMaxValue(Data, ChartItems);
    for var s := 0 to PointVertCount - 1 do
    begin
      var Value := Trunc((MaxValue / 100 * ((100 / (PointVertCount - 1)) * s)) / 100) * 100;
      var PY := ChartHeigth - ((100 / MaxValue * Value) / 100) * (ChartHeigth - OffsetTop);
      BMP.Canvas.FillText(TRectF.Create(TPointF.Create(20, PY-10), 100, TextHeigth), Value.ToString, False, 1, [], TTextAlign.Leading, TTextAlign.Leading);

      BMP.Canvas.DrawLine(TPointF.Create(Offset + Mesure, PY), TPointF.Create(BMP.Width - 10, PY), 1);

      var Pt2: TPointF;
      Pt2.X := 10;
      Pt2.Y := ChartHeigth - ((100 / MaxValue * Value) / 100) * (ChartHeigth - OffsetTop);
      var ElPt := Pt2;
      ElPt.Offset(TPointF.Create(-2, -2));
      var Ellips := TRectF.Create(ElPt, 5, 5);
      BMP.Canvas.FillEllipse(Ellips, 1);
    end;

    //Рисуем текст выбранного периода
    BMP.Canvas.Font.Size := 25;
    BMP.Canvas.Fill.Color := $DDFFFFFF;
    BMP.Canvas.Stroke.Color := $DDFFFFFF;
    var Caption := 'Статистика вакансий HeadHunter за месяц от '+ FormatDateTime('DD.MM.YYYY', IncMonth(GetDate, -1));
    var CaptionWidth := BMp.Width;
    BMP.Canvas.FillText(TRectF.Create(TPointF.Create(0, 30), CaptionWidth, TextHeigth), Caption, False, 1, [], TTextAlign.Center, TTextAlign.Leading);

    BMP.Canvas.Font.Size := 12;
    //Рисуем основные графики и их названия (легенду)
    for var n := 0 to High(ChartItems) do
    begin
      var ItemName := ChartItems[n].Name;
      var ItemCaption := ChartItems[n].Caption;

      //Рисуем название графика (текст и точки)
      var PY := TextHeigth * n + OffsetTop;
      BMP.Canvas.Fill.Color := $DDFFFFFF;
      BMP.Canvas.Stroke.Color := $DDFFFFFF;
      BMP.Canvas.FillText(TRectF.Create(TPointF.Create(TextOffset, PY), 100, TextHeigth), ItemCaption, False, 1, [], TTextAlign.Leading, TTextAlign.Leading);
      BMP.Canvas.Fill.Color := ChartItems[n].Color;
      BMP.Canvas.Stroke.Color := ChartItems[n].Color;
      BMP.Canvas.Stroke.Thickness := 3;
      BMP.Canvas.DrawLine(TPointF.Create(TextOffset - 20, PY + (TextHeigth - 20)), TPointF.Create(TextOffset - 5, PY + (TextHeigth - 20)), 1);

      //Рисуем сам график
      var Items := GetChartDataFor(Data, ItemName);
      var Pt1 := TPointF.Create(Offset + Mesure, ChartHeigth - ((100 / MaxValue * Items[MonthStart].Value) / 100) * (ChartHeigth - OffsetTop));
      BMP.Canvas.Fill.Color := ChartItems[n].Color;
      BMP.Canvas.Stroke.Color := ChartItems[n].Color;
      BMP.Canvas.Stroke.Thickness := 1;
      for var i := MonthStart to MonthEnd do
      begin
        var Pt2: TPointF;
        Pt2.X := i * Mesure + Offset;
        Pt2.Y := ChartHeigth - ((100 / MaxValue * Items[i].Value) / 100) * (ChartHeigth - OffsetTop);
        BMP.Canvas.DrawLine(Pt1, Pt2, 1);
        Pt1 := Pt2;
      end;

      //Рисуем точки на графике
      BMP.Canvas.Fill.Color := ChartItems[n].Color;
      BMP.Canvas.Stroke.Color := ChartItems[n].Color;
      for var i := MonthStart to MonthEnd do
      begin
        var Pt2: TPointF;
        Pt2.X := i * Mesure + Offset;
        Pt2.Y := ChartHeigth - ((100 / MaxValue * Items[i].Value) / 100) * (ChartHeigth - OffsetTop);
        var ElPt := Pt2;
        ElPt.Offset(TPointF.Create(-3, -2));
        var Ellips := TRectF.Create(ElPt, 4, 4);
        BMP.Canvas.FillEllipse(Ellips, 1);
      end;
    end;
    BMP.Canvas.EndScene;
    BMP.SaveToStream(Stream);
  finally
    BMP.Free;
  end;
end;

procedure SendPictureToTelegram(ChatId: string; Stream: TStream);
begin
  try
    Stream.Position := 0;
    TDownload.PostFile('https://api.telegram.org/' + TG_BOT_TOKEN +
      '/sendPhoto?chat_id=' + ChatId +
      '&caption=' + TURLEncoding.URL.Encode('HH Stat ' + FormatDateTime('DD.MM.YYYY + 30', IncMonth(GetDate, -1))), 'photo', 'image.png', Stream);
  except
    on E: Exception do
      Writeln('Не смогли отправить в Телеграм (', ChatId, ')', E.Message);
  end;
end;

procedure SendPictureToVK(PeerId: Integer; Stream: TStream);
begin
  try
    var VK := TCustomVK.Create(VK_BOT_TOKEN);
    try
      Stream.Position := 0;
      var Items: TAttachmentArray;
      if VK.Photos.UploadForMessage(Items, PeerId, 'chart.png', Stream) then
        VK.Messages.New.
          PeerId(PeerId).
          Message('HH Stat ' + FormatDateTime('DD.MM.YYYY + 30', IncMonth(GetDate, -1))).
          Attachment(Items).
          Send;
    finally
      VK.Free;
    end;
  except
    on E: Exception do
      Writeln('Не смогли отправить в ВК (', PeerId, '): ', E.Message);
  end;
end;

{ TChartItemInfo }

function TChartItemInfo.Caption: string;
begin
  if Offset > 0 then
    Result := FCaption + ' (-' + Offset.ToString + 'k)'
  else
    Result := FCaption;
end;

constructor TChartItemInfo.Create(const AName: string; AColor: TAlphaColor; ACaption: string; AOffset: Integer);
begin
  Name := AName;
  Color := AColor;
  Offset := AOffset;
  FCaption := ACaption;
end;

begin
  GlobalUseGDIPlusClearType := True;
  try
    var DB := TSQLiteDatabase.Create(DATA_BASE_FILE);
    try
      if DB.TableExists('items') then
      begin
        var Data := TChartData.Create;
        try
          if GetChartData(DB, Data) then
          begin
            PrintData(Data);
            writeln('--------');
            var Stream := TMemoryStream.Create;
            try
              if GetChart(Data, Stream, [
                TChartItemInfo.Create('delphi_hh', TAlphaColorRec.Red, 'Delphi'),
                TChartItemInfo.Create('pascal_hh', TAlphaColorRec.Yellow, 'Pascal'),
                TChartItemInfo.Create('python_hh', $FF279EFF, 'Python', 10),
                TChartItemInfo.Create('c-sharp_hh', $FF2AC63A, 'C#'),
                TChartItemInfo.Create('cpp_hh', $FF078787, 'C++'),
                TChartItemInfo.Create('swift_hh', $FFFFC48F, 'Swift'),
                TChartItemInfo.Create('java_hh', $FFC46F44, 'Java', 10),
                TChartItemInfo.Create('vb_hh', $FFFB6EFF, 'VB'),
                TChartItemInfo.Create('go_hh', $FFD2D2D2, 'GO'),
                TChartItemInfo.Create('fortran_hh', $FF5CB086, 'Fortran'),
                TChartItemInfo.Create('ruby_hh', $FF00FFFF, 'Ruby'),
                TChartItemInfo.Create('kotlin_hh', $FF2ED8D8, 'Kotlin'),
                TChartItemInfo.Create('rust_hh', $FF00FF80, 'Rust'),
                TChartItemInfo.Create('dart_hh', $FF6969FF, 'Dart'),
                TChartItemInfo.Create('postgresql_hh', $FFFF7070, 'Postgres', 10)])
                then
              begin
               {$IFDEF RELEASE}
                SendPictureToTelegram('-1001212064902', Stream);
                SendPictureToVK(2000000008, Stream);
               {$ENDIF}
                SendPictureToTelegram('-1001525223801', Stream);
                Stream.Position := 0;
                Stream.SaveToFile('test.png');
              end;
            finally
              Stream.Free;
            end;
          end;
        finally
          Data.Free;
        end;
      end;
    finally
      DB.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  {$IFDEF DEBUG}
  readln;
  {$ENDIF}
end.

