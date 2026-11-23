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
- **Visual em cel shading**, realista mas não demais: luz em faixas, contorno de tinta nas
  pessoas, carros e armas, texturas da cidade pintadas para o estilo, rostos com mais detalhe e
  cinco tipos de barba.
- **Servidores online para o mundo inteiro:** crie o seu (nome, senha, vagas, mensagem do dia,
  PvP) ou entre num da lista, com chat e kick. Para um servidor 24 horas, rode o próprio jogo em
  modo servidor num PC ou VPS (`servidor.bat` / `servidor.sh` nos zips de PC). Não precisa abrir
  portas. Também há sala pública e sala privada com código. Controles na tela no celular.
- Dedo do meio em primeira pessoa, andando e dentro do carro (o braço sai pela janela).
- **Lugares para entrar:** a casa (sala, cozinha, quarto), o Calder Mini Mart, o estúdio Basement
  808 (cabine, mesa de som, sofá) e a loja de armas Ironside Arms (balcão, parede de fuzis, bancada).
- **Duas armas novas** (uma pistola estilo AK e uma metralhadora de mão) e **dois carros novos**
  (um sedã musculoso e um SUV grande), com tiro e recarga animados em todas as armas, clarão no
  cano, cápsulas, e balanço e inclinação da câmera em primeira pessoa.
- **Site com tudo**: o trailer, screenshots e o download das quatro versões (Windows, Mac, Linux e
  Android), e o material da Steam em `marketing/steam/` (logo, cápsulas, screenshots).
- **Modo console** para jogar na TV com controle (Xbox ou PlayStation): tela inicial de console,
  teclado na tela, menu de pausa, tela de controles, os botões do seu controle na tela, mira
  assistida e vibração. E **mais danças**: griddy, shmoney, woah e hit dem folks.
- **Dança sturdy** na roda de emotes (a gangue e as pessoas na rua dançam junto) e **passos mais
  leves**: um som curto de tênis por pisada, em sincronia com a animação, diferente na neve, na
  lama, na calçada, na escada de metal e dentro dos lugares fechados.
- **Animações novas** de andar, correr e ficar parado, e **morte como num jogo sandbox**: ragdoll,
  câmera em terceira pessoa no corpo e a tela ficando vermelha.
- **Eras do drill:** visuais de 2012 até hoje no editor e oito personagens originais pelas esquinas.
- **Colisões melhores** entre carros, prédios, pessoas e ragdolls.
- **Celular no estilo de um flagship moderno** (borda de alumínio em 4 cores, ilha pequena, widgets,
  dock, apps com listas agrupadas) e um **editor de personagem minimalista**.
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
  jardim memorial (`make-memorial.py`), o ruído do céu (`make-sky-noise.py`), as texturas da cidade
  (`make-city.py`) e o celular e o editor de personagem (`make-ui.py`).
- `index.html` e `shots/`: a página de download para Android.
- `downloads/DrillSeason.apk`: o APK publicado.
