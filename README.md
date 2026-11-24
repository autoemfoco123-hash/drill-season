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

**iPhone e iPad:** [downloads/DrillSeason-iOS-Xcode.zip](downloads/DrillSeason-iOS-Xcode.zip) é o
projeto Xcode do jogo. Precisa de um Mac com o Xcode para instalar; o passo a passo está no
LEIAME-iOS.txt dentro do zip.

## O que tem

**Na próxima versão (1.9.3): ataque**

- **Drive-by:** no carro, segure o botão direito (ou Q / LB) para pôr o braço com a arma pra fora
  da janela e atire com o botão esquerdo (RB). Funciona com a K9, a Draft e a Buzzsaw. A sua
  gangue no carro também atira. À noite, carros das crews rivais passam atirando em você:
  derrube quem está na janela ou destrua o carro.
- **Granada e molotov:** escolha na roda de armas, segure para ver o arco e onde cai, solte para
  jogar (ou X). A granada quica e explode; o molotov quebra e deixa o chão pegando fogo. À venda na
  Ironside Arms (você começa com duas de cada).
- **Taco e faca**, também na Ironside Arms. Por trás, agachado, num rival que não te viu: E para
  neutralizar sem barulho. Os parceiros dele só reagem se virem.
- **Ordens para a gangue:** mirando num rival, toque E e a sua gangue vai pra cima; segure E para a
  roda de ordens: atacar, flanquear pelos dois lados, segurar um ponto (eles se agacham e abrem
  fogo em quem passar) ou reagrupar.
- **Emboscadas:** à noite as crews rivais andam pelas ruas delas. Acerte antes que vejam você e
  elas demoram a reagir, e a luta paga um bônus.
- **Missões online** (Phone → Online → Missions): corrida de rua, entrega da mochila e tomada de
  quarteirão, com quem estiver no servidor.
- **Rodas que giram e esterçam**, luz de freio e de ré, chamas no escapamento e farol iluminando a
  rua à noite.

**Novo na 1.9.2: Turf Wars**

- **O mapa é dividido em 16 quarteirões**, cada um de alguém: Halo, Low End e Sable Row (crews
  inventadas), ninguém, ou a Area 7 (o quarteirão da delegacia, que não dá para tomar).
- **Tomar um quarteirão:** com uma gangue, vá até a esquina dele (o anel na calçada, na cor do
  dono; nas esquinas rivais tem gente parada que manda você seguir andando) e segure E. O
  pessoal do dono vem em ondas: segure a esquina e limpe o quarteirão. O que estava na esquina
  é seu na hora.
- **Dinheiro todo dia:** cada quarteirão seu paga às 6h do relógio do jogo ($160 a $320).
- **Ataques à noite:** as crews vêm atrás dos seus quarteirões. Chegue em 2:30 e segure, com
  bônus; se não der, os recrutas que ficaram em casa defendem sozinhos (quanto mais, melhor).
- **No celular:** aba Turf no app Gang, e o mapa e o minimapa com a cor de cada dono.
- **Online:** todo mundo no mesmo servidor joga no mesmo mapa. O servidor dedicado salva o mapa.
- **Trailer novo** na página de download, com trilha original. A arte da Steam e o trailer em
  1080p estão em `marketing/steam/turf-wars/`.

**Novo na 1.9.1**

- **iPhone e iPad:** projeto Xcode pronto (iPhone e Simulador). Abra no Mac, escolha o seu
  Apple ID e instale no celular.
- **Carros novos por dentro e por fora:** os dez modelos refeitos, com carroceria esculpida,
  caixas de roda, farol fino de LED, rodas com raios, disco e pinça. O sedã muscle e o SUV de
  três fileiras seguem o estilo dos muscle cars de 2026 (marcas fictícias). 0 a 100 mais rápido
  em todos, câmbio de 8 marchas, tração nas quatro nos mais fortes e freio mais forte.
- **Carros explodem:** tiro demais e o carro solta fumaça, pega fogo e explode, ferindo quem
  está perto e arremessando a carcaça, que fica queimada na rua.
- **Banco de trás:** a sua gangue entra no carro com você e senta no carona e atrás. Olhe para
  trás e veja o banco, os cintos e o vidro traseiro.
- **Servidor direto:** crie um servidor com conexão direta, mais rápida (o jogo abre a porta no
  roteador sozinho quando dá; se não der, volta para o relay). Entre pelo endereço na rede de
  casa. O servidor dedicado aceita `--port`, `--addr` e `--direct`.
- **Motion blur leve** ao virar a câmera e em alta velocidade (desliga no app Settings do celular do jogo).
- **Correções:** os prédios e o som do motor voltaram nos downloads, e o celular abre de novo
  no Android.

**Novo na 1.9**

- **Som de motor no nível de simulador:** cinco motores (4 cilindros, V6, seis em linha turbo,
  V8 crossplane e V8 musculoso com compressor), cada um gravado em escadas de loops por RPM, com
  e sem carga, cruzados e afinados na rotação como nos simuladores de corrida. Por fora domina o
  escapamento; no banco do motorista a cabine abafa e sobem a admissão e o ronco pelo assoalho.
  Turbo enchendo e a válvula de alívio, chiado do câmbio (alto na ré), estalos no alívio e nas
  trocas rápidas, corte do limitador, "blip" ao reduzir. Os carros da rua também têm motor, com
  efeito Doppler.
- **Interior completo:** painel com conta-giros numerado e faixa vermelha, velocímetro, marcha,
  hodômetro, combustível, temperatura, pressão do turbo e luzes de aviso (freio de mão, injeção,
  controle de tração piscando quando o pneu patina); alavanca de câmbio e freio de mão que se
  mexem, pedais, saídas de ar, botões, porta-copos, portas com apoio de braço e alto-falante,
  banco de trás, cinto, retrovisor com imagem ao vivo, dadinhos pendurados balançando com as
  curvas e freadas, limpadores tirando a neve e o painel aceso à noite.
- **Dirigibilidade nova:** pneus com ângulo de deriva, transferência de peso e círculo de atrito,
  tração traseira, controle de tração e ABS. Puxe o freio de mão para driftar e segure no
  acelerador. **Borrachão:** acelerador e freio juntos com o carro parado; vire para fazer
  donuts. Fumaça dos pneus e marcas no asfalto.
- **Cidade reconstruída em low poly detalhado:** janelas com profundidade (moldura, peitoril com
  neve, verga), vidros que refletem o céu de dia e mostram as salas acesas à noite, lojas com
  letreiro e toldo, portas com degraus, cornijas com mísulas e dentículos, platibandas, escadas de
  incêndio, caixas d'água, ar-condicionado e antenas nos telhados. Na rua: meio-fio, faixas de
  pedestre, hidrantes, lixeiras, caixas de jornal, pontos de ônibus, placas, árvores e postes com
  fios nos becos.
- **Animação em camadas:** a cabeça e o peito seguem para onde você olha, o corpo inclina ao
  acelerar e frear, troca o peso de perna parado, respira (ofegante depois de correr), dá passos
  ao girar no lugar, encolhe as pernas no pulo e amortece na queda. O balanço da cabeça em primeira
  pessoa ficou maior.
- **App Música** no celular: toque as músicas do jogo e as suas (MP3, OGG ou WAV na pasta
  Música/Drill Season, com o nome "Artista - Título"), com aleatório, repetir e as teclas de mídia,
  e um botão que abre o Spotify. Desligue "Game music" no app para ouvir só o Spotify.

**Já tinha**

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
