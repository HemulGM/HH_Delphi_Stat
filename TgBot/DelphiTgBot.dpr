program DelphiTgBot;

uses
  System.SysUtils,
  System.Classes,
  TgBotApi.Client in '..\..\TGBotMini\TgBotApi.Client.pas',
  TgBotApi in '..\..\TGBotMini\TgBotApi.pas',
  HGM.JSONParams in '..\..\JSONParam\HGM.JSONParams.pas',
  HGM.ArrayHelpers in '..\..\ArrayHelpers\HGM.ArrayHelpers.pas',
  DTgBot.HHStat in 'DTgBot.HHStat.pas',
  HHStat.Chart in '..\Chart\HHStat.Chart.pas',
  DTgBot.HHChart in 'DTgBot.HHChart.pas',
  HGM.SQLang in '..\..\SQLite\HGM.SQLang.pas',
  HGM.SQLite in '..\..\SQLite\HGM.SQLite.pas',
  HGM.SQLite.Wrapper in '..\..\SQLite\HGM.SQLite.Wrapper.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  Client := TtgClient.Create({$INCLUDE BOT_TOKEN.key});
  Client.Hello;
  while True do
  try
    Client.Polling(
      procedure(u: TtgUpdate)
      begin
        //ProcCallbackQuery(u);
        if Assigned(u.Message) and Assigned(u.Message.Chat) then
        begin
          if u.Message.Text.StartsWith('/hh ') then
            ProcHHQuery(u)
          else if u.Message.Text = '/hhchart' then
            ProcHHChart(u);
        end;
      end);
    Sleep(5000);
  except
    on E: Exception do
      Writeln('Error: ' + E.Message);
  end;
end.

