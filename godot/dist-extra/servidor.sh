#!/bin/sh
# Servidor dedicado do Drill Season (Linux).
# Deixe rodando num PC ou VPS: o servidor aparece em Online -> Servers para jogadores do
# mundo inteiro (Android, Linux, Windows e Mac). Nao precisa abrir portas.
# Edite as linhas abaixo e rode:  ./servidor.sh
NOME="Meu servidor"
SENHA=""            # vazio = sem senha
VAGAS=24            # 2 a 64
MENSAGEM="Bem-vindo ao meu servidor"
PVP=on              # on ou off

cd "$(dirname "$0")"
RUN=""
# sem tela (VPS): usa um display virtual (instale com: sudo apt install xvfb)
if [ -z "$DISPLAY" ]; then
  if command -v xvfb-run >/dev/null 2>&1; then RUN="xvfb-run -a"; else
    echo "Sem tela: instale o xvfb (sudo apt install xvfb) e rode de novo."; exit 1; fi
fi
exec $RUN ./DrillSeason.x86_64 --audio-driver Dummy --server --name="$NOME" --password="$SENHA" --max=$VAGAS --motd="$MENSAGEM" --pvp=$PVP
