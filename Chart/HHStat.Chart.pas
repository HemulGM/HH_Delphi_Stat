unit HHStat.Chart;

interface

uses
  System.SysUtils, System.Classes, FMX.Graphics, System.Types, System.Math,
  FMX.Types, System.UITypes, System.DateUtils, System.NetEncoding,
  System.Generics.Collections, HGM.SQLang, HGM.SQLite, HGM.SQLite.Wrapper;

const
  MonthStart = 1;
  MonthEnd = 30;


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

function RenderChartToStream(const BaseFileName: string; Stream: TStream; StartDate: TDateTime): Boolean;

function GetChartData(DB: TSQLiteDatabase; Data: TChartData; StartDate: TDateTime): Boolean;

function GetChart(Data: TChartData; Stream: TStream; ChartItems: TChartItemInfoItems; StartDate: TDateTime): Boolean;

implementation

function RenderChartToStream(const BaseFileName: string; Stream: TStream; StartDate: TDateTime): Boolean;
begin
  Result := False;
  var DB := TSQLiteDatabase.Create(BaseFileName);
  try
    if DB.TableExists('items') then
    begin
      var Data := TChartData.Create;
      try
        if GetChartData(DB, Data, StartDate) then
        begin
          if GetChart(Data, Stream, [
            TChartItemInfo.Create('delphi_hh', TAlphaColorRec.Red, 'Delphi'),
            TChartItemInfo.Create('pascal_hh', TAlphaColorRec.Yellow, 'Pascal'),
            TChartItemInfo.Create('python_hh', $FF279EFF, 'Python'),
            TChartItemInfo.Create('c-sharp_hh', $FF2AC63A, 'C#'),
            TChartItemInfo.Create('cpp_hh', $FF078787, 'C++'),
            TChartItemInfo.Create('swift_hh', $FFFFC48F, 'Swift'),
            TChartItemInfo.Create('java_hh', $FFC46F44, 'Java'),
            TChartItemInfo.Create('vb_hh', $FFFB6EFF, 'VB'),
            TChartItemInfo.Create('go_hh', $FFD2D2D2, 'GO'),
            TChartItemInfo.Create('fortran_hh', $FF5CB086, 'Fortran'),
            TChartItemInfo.Create('ruby_hh', $FF00FFFF, 'Ruby'),
            TChartItemInfo.Create('kotlin_hh', $FF2ED8D8, 'Kotlin'),
            TChartItemInfo.Create('rust_hh', $FF00FF80, 'Rust'),
            TChartItemInfo.Create('dart_hh', $FF6969FF, 'Dart'),
            TChartItemInfo.Create('postgresql_hh', $FFFF7070, 'Postgres')], StartDate)
            then
          begin
            Stream.Position := 0;
            Result := True;
          end;
        end;
      finally
        Data.Free;
      end;
    end;
  finally
    DB.Free;
  end;
end;

{ TChartData }

procedure TChartData.Add(Name: string; Value: Integer; Date: TDateTime);
var
  Item: TChartItem;
begin
  Item.Name := Name;
  Item.Value := Value;
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

function GetChartData(DB: TSQLiteDatabase; Data: TChartData; StartDate: TDateTime): Boolean;
var
  Table: TSQLiteTable;
begin
  with SQL.Select('items', ['name', 'value', 'date']) do
  begin
    var Dt := StartDate;
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

function GetChartDataFor(Data: TChartData; const Name: string; StartDate: TDateTime): TChartElements;

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
    if Data.FindByDay(Name, DayOf(IncDay(StartDate, -i)), Item) then
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

function GetMaxValue(Data: TChartData; Items: TChartItemInfoItems; StartDate: TDateTime): Integer;
begin
  Result := 0;
  for var ChartItem in Items do
    for var Day := MonthEnd downto MonthStart do
    begin
      var Item: TChartItem;
      if Data.FindByDay(ChartItem.Name, DayOf(IncDay(StartDate, -Day)), Item) then
        if Item.Value > Result then
          Result := Item.Value;
    end;
end;

function GetChart(Data: TChartData; Stream: TStream; ChartItems: TChartItemInfoItems; StartDate: TDateTime): Boolean;
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
    var MaxValue := GetMaxValue(Data, ChartItems, StartDate);
    for var s := 0 to PointVertCount - 1 do
    begin
      var Value := Trunc((MaxValue / 100 * ((100 / (PointVertCount - 1)) * s)) / 100) * 100;
      var PY := ChartHeigth - ((100 / MaxValue * Value) / 100) * (ChartHeigth - OffsetTop);
      BMP.Canvas.FillText(TRectF.Create(TPointF.Create(20, PY - 10), 100, TextHeigth), Value.ToString, False, 1, [], TTextAlign.Leading, TTextAlign.Leading);

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
    var Caption := 'Статистика вакансий HeadHunter за месяц от ' + FormatDateTime('DD.MM.YYYY', IncMonth(StartDate, -1));
    var CaptionWidth := BMP.Width;
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
      var Items := GetChartDataFor(Data, ItemName, StartDate);
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

end.

