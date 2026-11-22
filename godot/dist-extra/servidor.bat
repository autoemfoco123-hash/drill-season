@echo off
rem Servidor dedicado do Drill Season (Windows).
rem Deixe esta janela aberta: o servidor aparece em Online -> Servers para jogadores do
rem mundo inteiro (Android, Linux, Windows e Mac). Nao precisa abrir portas.
rem Edite as linhas abaixo e de dois cliques neste arquivo.
set NOME=Meu servidor
set SENHA=
set VAGAS=24
set MENSAGEM=Bem-vindo ao meu servidor
set PVP=on
cd /d "%~dp0"
DrillSeason.exe --audio-driver Dummy --server --name="%NOME%" --password="%SENHA%" --max=%VAGAS% --motd="%MENSAGEM%" --pvp=%PVP%
