@echo off
rem Servidor dedicado do Drill Season (Windows).
rem Deixe esta janela aberta: o servidor aparece em Online -> Servers para jogadores do
rem mundo inteiro (Android, Linux, Windows e Mac). Os jogadores conectam direto na porta UDP
rem abaixo (o servidor pede ao roteador para abri-la sozinho, via UPnP); quem nao alcancar
rem entra pelo relay. Se o roteador nao abrir, libere a porta UDP e preencha ENDERECO.
rem Edite as linhas abaixo e de dois cliques neste arquivo.
set NOME=Meu servidor
set SENHA=
set VAGAS=24
set MENSAGEM=Bem-vindo ao meu servidor
set PVP=on
set PORTA=24680
set ENDERECO=
cd /d "%~dp0"
DrillSeason.exe --audio-driver Dummy --server --name="%NOME%" --password="%SENHA%" --max=%VAGAS% --motd="%MENSAGEM%" --pvp=%PVP% --port=%PORTA% --addr=%ENDERECO%
