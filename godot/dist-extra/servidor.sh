#!/bin/sh
# Servidor dedicado do Drill Season (Linux).
# Deixe rodando num PC ou VPS: o servidor aparece em Online -> Servers para jogadores do
# mundo inteiro (Android, Linux, Windows e Mac). Os jogadores conectam direto na porta UDP
# abaixo (o servidor pede ao roteador para abri-la sozinho, via UPnP); quem nao alcancar
# entra pelo relay. Na VPS o endereco e o da propria maquina.
# Edite as linhas abaixo e rode:  ./servidor.sh
NOME="Meu servidor"
SENHA=""            # vazio = sem senha
VAGAS=24            # 2 a 64
MENSAGEM="Bem-vindo ao meu servidor"
PVP=on              # on ou off
PORTA=24680         # porta UDP para conexao direta
ENDERECO=""         # opcional: seu IP publico, se o roteador nao abrir a porta sozinho

cd "$(dirname "$0")"
RUN=""
# sem tela (VPS): usa um display virtual (instale com: sudo apt install xvfb)
if [ -z "$DISPLAY" ]; then
  if command -v xvfb-run >/dev/null 2>&1; then RUN="xvfb-run -a"; else
    echo "Sem tela: instale o xvfb (sudo apt install xvfb) e rode de novo."; exit 1; fi
fi
exec $RUN ./DrillSeason.x86_64 --audio-driver Dummy --server --name="$NOME" --password="$SENHA" --max=$VAGAS --motd="$MENSAGEM" --pvp=$PVP --port=$PORTA ${ENDERECO:+--addr=$ENDERECO}
