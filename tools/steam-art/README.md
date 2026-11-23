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
