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
  VK.Types,
  HHStat.Chart in 'HHStat.Chart.pas';

const
  TG_BOT_TOKEN = {$INCLUDE ..\bot_key.api_key};
  VK_BOT_TOKEN = {$INCLUDE ..\vk_bot_key.api_key};

  {$IFDEF DEBUG}
  DATA_BASE_FILE = '..\..\..\Win32\Release\stat.db';
  {$ENDIF}
  {$IFDEF RELEASE}
  DATA_BASE_FILE = '..\..\..\Win32\Release\stat.db';
  {$ENDIF}


function GetDate: TDateTime;
begin
  Result := Now; //.IncDay(5);
end;

procedure SendToTelegram(ChatId: string; const Text: string);
begin
  TDownload.GetRequest('https://api.telegram.org/' + TG_BOT_TOKEN +
    '/sendMessage?chat_id=' + ChatId +
    '&parse_mode=Markdown' +
    '&text=' + TURLEncoding.URL.Encode(Text));
end;

procedure SendPictureToTelegram(ChatId: string; Stream: TStream);
begin
  try
    Stream.Position := 0;
    TDownload.PostFile('https://api.telegram.org/' + TG_BOT_TOKEN +
      '/sendPhoto?chat_id=' + ChatId +
      '&caption=' + TURLEncoding.URL.Encode('HH Stat ' + FormatDateTime('DD.MM.YYYY + 30', IncMonth(GetDate, -1))), ['photo'], ['image.png'], [Stream]);
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

procedure WritelnWithSend(const Text: string);
begin
  Writeln(Text);
end;

begin
  GlobalUseGDIPlusClearType := True;
  try
    var Stream := TMemoryStream.Create;
    try
      if RenderChartToStream(DATA_BASE_FILE, Stream, GetDate) then
      begin
      {$IFDEF RELEASE}
        SendPictureToTelegram('-1001212064902', Stream);
        SendPictureToVK(2000000008, Stream);
      {$ENDIF}
        SendPictureToTelegram('-1001525223801', Stream);
        Stream.Position := 0;
        Stream.SaveToFile('test.png');
      end
      else
        SendToTelegram('-1001525223801', 'Не получены данные для графика HH Stat');
    finally
      Stream.Free;
    end;
  except
    on E: Exception do
    begin
      SendToTelegram('-1001525223801', 'HH Stat Exception: ' + E.ClassName + ': ' + E.Message);
      Writeln(E.ClassName, ': ', E.Message);
    end;
  end;
  {$IFDEF DEBUG}
  readln;
  {$ENDIF}
end.

