# Arte da loja (Steam)

As imagens prontas estão em `marketing/steam/`. Para refazer:

1. **Cenas do jogo** (a crew na Calder Ave ao entardecer, o trem parado no L, a viatura e o
   Kessler Bruiser atrás). Em `godot/`, uma por formato:

   ```
   DS_PROMOTEST=side DS_PROMOX=33 DS_PROMOTIME=17.0 DS_NOHUD=1 DS_SHOTS=renders \
     xvfb-run -a -s "-screen 0 3840x2160x24" godot3 --path . --audio-driver Dummy --resolution 2560x1440 --autotest
   ```

   `side` (crew à direita, espaço para a logo) em 2560x1440, `key` em 2560x1440, `wide` em
   3840x1240 e `tall` em 1200x1800. Copie os PNG para `tools/steam-art/renders/`. Na `side`
   tem um bueiro no chão perto da câmera: ele foi apagado à mão (`p_side_clean.png`).
2. **Fontes** (todas OFL): `npm install @fontsource/anton @fontsource/rubik-wet-paint @fontsource/bebas-neue`
   nesta pasta.
3. **Logo**: `node shot.js $PWD/logo.html logo_raw.png 2400 1350 '#logo'` (transparente; corte
   as bordas vazias para `logo_trim.png`). O ícone: `node shot.js $PWD/logo.html icon_1024.png 1024 1024 '#logo' icon=1`.
4. **Cada peça**: `node shot.js $PWD/compose.html header.png 920 430 '#c' kind=header`
   (`small`, `main`, `vertical`, `libcap`, `libhero`, `pagebg`, `banner`).

Regras da Steam: nas cápsulas só a arte e a logo (sem "lançamento", notas ou prêmios), e o
library hero sem texto nenhum.

## Trailer e screenshots

`marketing/steam/screenshots/` tem 13 screenshots em 1920x1080, e o trailer de 53 s em 1080p
(H.264, 30 fps, AAC, -14 LUFS) é feito pelo `trailer.py`:

1. As legendas: `node shot.js $PWD/caption.html cap/name.png 1920 1080 '#c' "t=MAKE%20YOUR%20NAME..."`
   (as chaves estão em `CAPTIONS` no script; o cartão final usa `end=...`). Ponha em `work/trailer/cap/`.
2. `python3 trailer.py` renderiza cada cena dentro do jogo com `DS_TRAILER=<cena>` e
   `--fixed-fps 30` (`godot/scripts/Trailer.gd`: cada quadro é 1/30 s do jogo, por mais devagar que
   renderize, e o relógio do mundo anda junto), corta tudo na batida da faixa da WCLD 91.1
   (139,5 BPM: a logo entra na virada de 44,0 s e o final na de 85,2 s), põe legendas, a entrada
   da logo, o cartão final, a música e os efeitos (tiros, socos, trovões e o trem nos quadros em
   que acontecem) e grava `DrillSeason-trailer-1080p.mp4` e uma cópia leve em 720p.
   `python3 trailer.py walk drive` refaz só essas cenas; a montagem roda sem argumentos.
3. As screenshots saem dos quadros guardados em `work/trailer/stills/`.

## Trailer épico e arte da atualização Turf Wars (1.9.2)

Tudo sai de dentro do jogo e de scripts deste diretório; nada de música ou imagem de terceiros.

1. **Trilha** (`score.py`): drill + orquestra sintetizados do zero, 140 BPM em Fá menor, 45 compassos
   no tempo dos cortes (intro, drop na logo, parada na explosão em câmera lenta, break, segundo
   drop, logo final). `python3 score.py work/epic` grava `score.wav` e as trilhas separadas.
2. **Cenas** (`godot/scripts/Trailer.gd`, as `e_*`): as esquinas das três crews, o mapa de turf
   visto do alto (o jogo grava onde cada cruzamento cai na tela em `grid.json`), tomar uma esquina,
   primeira pessoa, o Bruiser na Calder Ave, a gangue no banco de trás, a explosão em câmera lenta,
   o ataque à noite, a esquina conquistada, o drift, a crew andando em câmera lenta e o final sob o L.
   `python3 trailer_epic.py render` renderiza tudo (3 de cada vez, 1920x1080, `--fixed-fps 30`).
3. **Montagem** (`python3 trailer_epic.py edit`): correção de cor de cinema (sombras frias, luzes
   quentes, bloom, vinheta, grão), barras 2.39:1 na abertura e no final, o mapa de turf animado no
   compasso, os títulos (`epic_caption.html`), a logo, a mixagem a -14 LUFS e dois finais:
   `...-wishlist.mp4` ("WISHLIST NOW") e `...-outnow.mp4` ("AVAILABLE NOW"), em 1080p e 720p.
4. **Arte da Steam** (`compose_epic.py`): quatro quadros renderizados em 4K com
   `DS_TRAILER=e_finale DS_KEYCAM=dx,y,z,lx,ly,lz,fov DS_NOMUG=1` (e `DS_FACEOFF=1` para a crew de
   frente para a Halo), graduados com brasas e neve, e cortados em todos os tamanhos:
   `python3 compose_epic.py <pasta dos quadros> <saída> work/epic/stills`.
