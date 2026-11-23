#!/bin/sh
# Drill Season em modo console (Linux, Steam Deck, um PC ligado na TV).
# Tela cheia, texto maior, os botões do seu controle na tela, teclado na tela e menu de pausa
# no START. Para voltar ao modo PC: no jogo, START > Desktop mode.
cd "$(dirname "$0")"
exec ./DrillSeason.x86_64 --console "$@"
