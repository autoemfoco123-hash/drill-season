# Drill Season

Jogo de ação em terceira ou primeira pessoa em **Calder Park**, um bairro fictício de Chicago no
inverno. Você escolhe um @nome, grava faixas num estúdio de porão, ganha Buzz, foge do Heat e
decide como sair. Feito em **Godot 3 (GLES2)**: roda no Android, no Linux, no Windows, no Mac e em
placas de vídeo antigas.

## Baixar para Android

**https://autoemfoco123-hash.github.io/drill-season/** (página de download, quando o GitHub Pages
estiver ligado no repositório)

Link direto do APK: [downloads/DrillSeason.apk](downloads/DrillSeason.apk)

Requer Android 4.4 ou mais novo e processador ARM. Ao abrir o APK, permita instalar desta fonte só
para o app que você usou. Se o Play Protect avisar que o app é desconhecido, toque em
**Mais detalhes → Instalar mesmo assim**.

## O que tem

- A cidade inteira aberta: Calder Ave, o parque e a lagoa, o L, a orla do lago, o pátio de trens.
- História com trabalhos, cutscenes e quatro finais; o estúdio Basement 808 (jogo de ritmo); a
  rede social Blok; a bancada de armas; carros com interior; o trem passando; frio, neve e vento.
- Online sem abrir portas (sala pública ou privada com código), com controles na tela no celular.
- Um céu que muda com a hora e o tempo: nuvens, pôr do sol, estrelas, aurora e neve com trovoada.
- **Homenagem a XXXTentacion:** no Calder Park, o jardim memorial com a réplica do mausoléu dele,
  feita a partir de uma foto que a família compartilhou, e a **Poison Tree** ao lado. Preste
  homenagem e o céu responde: um raio cai no frontão, as portas se abrem e uma figura de luz (sem
  rosto, não é a imagem de uma pessoa real) sai, abre as asas e sobe como pombas.
- Na tela inicial: em memória de King Von (1994–2020) e XXXTentacion (1998–2018).

Os personagens, crews, marcas e lugares da história são fictícios.

## Para desenvolvedores

- `godot/`: o jogo (Godot 3.5.2). Veja [godot/README.md](godot/README.md) para controles, builds de
  PC, online e testes.
- `src/` e `build.sh`: o protótipo original, usado só pelas ferramentas que regeneram a cidade, os
  carros, os dados e os sons do Godot (`./build.sh` e depois `node tools/export-godot.js`). Não é
  publicado.
- `tools/`: as ferramentas de exportação, os sons sintetizados (`make-sfx.py`), as texturas do
  jardim memorial (`make-memorial.py`) e o ruído do céu (`make-sky-noise.py`).
- `index.html` e `shots/`: a página de download para Android.
- `downloads/DrillSeason.apk`: o APK publicado.
