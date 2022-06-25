unit DTgBot.HHChart;

interface

uses
  TgBotApi, System.SysUtils, TgBotApi.Client, FMX.Types, System.Classes,
  HHStat.Chart;

const
  {$IFDEF DEBUG}
  DATA_BASE_FILE = '..\..\..\Win32\Release\stat.db';
  {$ENDIF}
  {$IFDEF RELEASE}
  DATA_BASE_FILE = '..\..\..\Win32\Release\stat.db';
  {$ENDIF}

procedure ProcHHChart(u: TtgUpdate);

implementation

procedure ProcHHChart(u: TtgUpdate);
begin
  var Stream := TMemoryStream.Create;
  try
    if RenderChartToStream(DATA_BASE_FILE, Stream, Now) then
      Client.SendPhotoToChat(u.Message.Chat.Id, 'HH Stat Chart', 'image.png', Stream)
    else
      Client.SendMessageToChat(u.Message.Chat.Id, 'Не получены данные для графика HH Stat');
  finally
    Stream.Free;
  end;
end;

initialization
  GlobalUseGDIPlusClearType := True;

end.

