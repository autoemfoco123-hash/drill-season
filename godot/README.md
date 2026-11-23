# Drill Season (Godot)

Versão nativa do Drill Season para PC, feita em **Godot 3 (GLES2)**. Ela roda em placas
de vídeo antigas, como a Intel HD de primeira geração (Iron Lake / Arrandale / Clarkdale),
no Linux (Kali, Debian, Ubuntu), no Windows e no Mac.

A cidade, os carros, as armas, os sons e as quatro rádios são exportados do jogo web. O
save tem o mesmo formato, então o seu progresso do navegador vem junto.

## Baixar e jogar (Linux, Windows, Mac)

- **Linux:** `DrillSeason-linux.zip`. Descompacte e rode `./DrillSeason.x86_64` (deixe o `.pck` na mesma pasta).
- **Windows:** `DrillSeason-windows.zip`. Descompacte e abra `DrillSeason.exe`. Se o Windows mostrar
  "O Windows protegeu o computador", clique em **Mais informações → Executar assim mesmo** (o
  executável não é assinado).
- **Mac:** `DrillSeason-mac.zip`. Descompacte e arraste *Drill Season* para Aplicativos. Na primeira
  vez, clique com o botão direito no app e escolha **Abrir** (o app não é assinado). Se o macOS
  ainda bloquear, rode no Terminal `xattr -dr com.apple.quarantine "/Applications/Drill Season.app"`.

- **Android:** `DrillSeason.apk`. Copie para o celular e abra o arquivo. O Android vai pedir para
  permitir instalar apps desta fonte; permita só para o app que você usou para abrir o APK.
  Requer Android 4.4 ou mais novo, com processador ARM (praticamente todos os celulares).

Todas as versões (Linux, Windows, Mac e Android) jogam online juntas.

### No celular

- Controles na tela: o **joystick** aparece onde o polegar esquerdo encostar (empurre até a
  borda para correr); **arraste à direita** para olhar; botões de tiro, mira (toque liga/desliga),
  pulo, agachar, recarregar, carro e **E** (acende quando há algo para usar).
- Na fileira de cima: celular, **arma** (toque troca, segure e deslize para a roda), **emote**
  (segure e deslize), bola de neve e primeira/terceira pessoa.
- No carro os botões viram acelerar, frear, derrapar (freio de mão), buzina, rádio e sair.
- O botão **voltar** do Android fecha o que estiver aberto, ou abre o celular do jogo.
- Em **Settings** dá para ligar/desligar os controles na tela e ajustar a velocidade da câmera.
  Controle Bluetooth também funciona.
- No Android 11 ou mais novo, importar o save do jogo web pela pasta Downloads pode não funcionar
  (o sistema restringe o acesso a arquivos).

## Jogar no Kali Linux

### Opção 1: executável pronto

Se você tem o `DrillSeason-linux.zip`, descompacte e rode:

```bash
chmod +x DrillSeason.x86_64
```

```bash
./DrillSeason.x86_64
```

O `.pck` precisa ficar na mesma pasta que o executável.

Para gerar o zip você mesmo:

1. Abra o projeto no editor (veja a Opção 2).
2. Vá em **Projeto → Exportar → Linux/X11**.
3. Na primeira vez o editor oferece baixar os *export templates* do Godot 3.5.2.

### Opção 2: abrir o projeto no Godot

1. Instale o Godot 3:

   ```bash
   sudo apt install godot3
   ```

   Se o pacote não existir, baixe o **Godot 3.5 ou 3.6 "Standard"** (não o 4.x) em
   godotengine.org.
2. Abra o editor, clique em **Import** e escolha `godot/project.godot`.
3. Na primeira vez o editor importa a cidade e os sons, o que leva uns minutos numa
   máquina antiga.
4. Aperte **F5** para jogar.

Para rodar sem o editor depois da primeira importação:

```bash
godot3 --path godot
```

## Trazer o progresso do jogo web

1. No jogo web, abra o celular (Tab), vá em **Settings** e clique em **Export my progress**.
   O arquivo `drill-season-save.json` cai na pasta Downloads.
2. No Godot, na tela inicial, clique em **Import progress from the web game**. Também
   dá para fazer isso no celular, em Settings → **Import web progress**.

O jogo procura o arquivo em `~/Downloads` (ou `~/Transferências`), na sua pasta pessoal
e ao lado do executável. Vêm junto: nome, dinheiro, Buzz, Heat, vida, armas e
munição, visual do personagem, garagem, gangue e recrutas, estatísticas e configurações.
A qualidade gráfica sempre começa em **Fast** depois de importar.

O jogo salva sozinho a cada 20 segundos e ao sair, em
`~/.local/share/godot/app_userdata/Drill Season/save.json`.

## Controles

| Ação | Teclado e mouse | Controle |
| --- | --- | --- |
| Andar | W A S D | analógico esquerdo |
| Olhar | mouse ou setas | analógico direito |
| Atirar ou socar | botão esquerdo | RT / R2 |
| Mirar | botão direito | LT / L2 |
| Pular (freio de mão no carro) | Espaço | A / Cruz |
| Agachar | C | B / Círculo |
| Recarregar | R | X / Quadrado |
| Entrar ou sair do carro | F | Y / Triângulo |
| Interagir, falar, recrutar | E | RB / R1 |
| Trocar de arma | toque Q (ou 1 2 3 5 6, e 4 para os punhos) | toque LB / L1 |
| Roda de armas (câmera lenta) | segure Q | segure LB / L1 |
| Roda de emotes (danças, palmas, rir, sentar, anjo na neve...) | segure Z | segure D-pad esquerda |
| Bola de neve | X | pela roda de armas |
| Se jogar no chão (ragdoll) | J (Espaço ou andar para levantar) | pela roda de emotes |
| Correr | Shift | L3 |
| 1ª ou 3ª pessoa | V | R3 |
| Celular | Tab ou P | D-pad cima |
| Curativo | B | D-pad baixo |
| Acenar / dedo do meio | G / T | roda de emotes / D-pad direita |
| Chat (online) | Y | pelo celular |
| Mapa | M | Select / View |
| Pausar | Esc | Start / Menu |
| Estúdio (jogo de ritmo) | D F J K ou setas | ◀ ▶ X B |
| Pular cena | Espaço ou Enter | A / Cruz |

No carro, W ou o gatilho direito acelera, S ou o gatilho esquerdo freia e dá ré, e H
buzina.

## Gráficos para PC fraco

Os gráficos ficam no celular, em Settings → **Graphics**:

- **Fast**: o padrão, feito para Iron Lake. Usa só a luz do sol ou da lua, desenha até 160 m,
  e os postes acendem só a mancha de luz no chão.
- **Medium**: duas luzes reais de poste perto de você.
- **High**: quatro luzes de poste e sombras.

O que já foi feito para GPU antiga:

- A cidade fica em cerca de 430 blocos.
- Cada pessoa é uma malha só, com esqueleto.
- Luzes apagadas não custam nada.
- Uma cena típica fica entre 150 e 180 chamadas de desenho.

Se ainda ficar lento, rode numa janela menor:

```bash
./DrillSeason.x86_64 --resolution 960x540
```

## O que tem no Godot

Tudo do jogo web, mais algumas coisas só daqui:

- **História completa:** o elenco manda mensagens conforme a história anda, trabalhos
  (sessão no estúdio, diss paga, gravação de clipe na plataforma do L, entrega de merch, levar
  a irmã pra casa, ficar em casa, showcase no centro comunitário, o detetive, a lagoa),
  cutscenes e os **4 finais** (Way Out, Witness, Crown, Locked Up).
- **Estúdio Basement 808:** o jogo de ritmo com batidas gravadas do motor de música do jogo
  web (Chicago, UK e NY drill), notas, faixas lançadas, streams pagando.
- **Bancada de armas:** miras, canos, pentes, bocais, acabamentos e pingentes, com prévia 3D
  girando e as mudanças de atributos. As armas são montadas peça por peça no Godot.
- **Blok:** feed, perfil, curtidas, comentários e seguidores; o app Câmera tira foto do que
  você está vendo e posta.
- **O trem L andando** no horário compartilhado, parando em Calder; ficar nos trilhos derruba você.
- **Neve caindo** com o vento, fogo nos barris, vapor dos bueiros, e o **frio**: vento,
  fontes de calor, café, aquecedores de mão, ulceração.
- **Ragdoll** em todo mundo: quem cai baleado, nocauteado, atropelado ou pelo trem cai de verdade.
  Dá para escorregar no gelo correndo e se jogar no chão (J).
- **Emotes:** quatro danças (two-step, arm wave, robô e a **sturdy**: base baixa, pisão para a
  frente de um lado e do outro, os braços cruzando, e a cada dois compassos os punhos socando para
  baixo), hype, palmas, rir, dar de ombros, continência, apontar, mão na cara, músculo, sentar,
  anjo na neve e rezar. Quem está perto reage, e a sua gangue dança junto (a sturdy também).
- **Guerra de bolas de neve:** as pessoas riem, devolvem, fogem ou escorregam; a polícia não acha graça.
- **Online com servidores (Android, Linux, Windows e Mac juntos):** no celular, **Online**:
  - **Servers**: a lista de servidores do mundo inteiro, com nome, jogadores/vagas, região e
    etiquetas (**24h** para servidor dedicado, **pw** para quem tem senha, **no PvP**). Toque num
    servidor para ver a mensagem do dia, digite a senha se tiver e toque em **Join**.
  - **Create a server**: o seu próprio servidor, hospedado pelo seu jogo: nome, mensagem do dia,
    senha (opcional), vagas (4 a 64) e PvP ligado ou desligado. Ele aparece na lista de todo mundo
    enquanto você joga, e some sozinho se você fechar o jogo ou cair.
  - Dentro do servidor: a mensagem do dia, o **chat** (tecla **Y** abre direto), a lista de
    jogadores e, para quem criou, o botão **Kick** (a pessoa fica 10 minutos sem poder voltar).
  - **Quick play**: a sala pública e as salas privadas com código de 5 letras, como antes.
  - Não precisa abrir porta no roteador: o jogo se conecta a servidores públicos de mensagens (MQTT)
    que repassam as posições, tiros, socos, emotes e o chat, e mantém dois deles ligados ao mesmo
    tempo para não cair se um falhar. É assim que alguém em qualquer lugar do mundo entra no seu
    servidor.
  - **Same Wi-Fi or direct IP**: o modo antigo, sem internet. Um hospeda (UDP 24680) e os outros
    entram pelo IP ou pela lista de jogos na rede.
  - Dá para convidar gente para a gangue, e quem é da mesma gangue não se fere.
  - O que passa pelos servidores públicos é público: o seu @nome, o visual, onde você está no mapa
    e o chat. A senha de um servidor segura os curiosos, mas não é segurança forte: não use uma
    senha que você usa em outro lugar.
- **Interior do carro** em primeira pessoa (V dentro do carro): capô na cor do carro, painel com
  conta-giros e velocímetro de verdade, marcha, volante que gira com as suas mãos, retrovisor e o
  rádio mostrando a estação.
- **Som refeito:**
  - motor sintetizado ao vivo, com marchas, partida, giro, pipocos no escape;
  - pneus, neve, derrapagem e vento na carroceria;
  - por dentro do carro a rua fica abafada;
  - tiros com eco que muda com a distância dos prédios e cartuchos caindo no chão;
  - balas passando zunindo; passos leves de tênis, um por pisada da animação (com o pé esquerdo e
    o direito um pouco diferentes), com som próprio na neve, na lama da rua, na calçada, na
    escada de metal e no piso dos lugares fechados, cinco variações de cada;
  - vento que acompanha as rajadas, a cidade ao fundo, sirenes, cachorros, aviões e o gelo do lago
    rangendo; fogo crepitando nos barris e vapor nos bueiros;
  - mixagem com compressor e limitador.
- **Primeira pessoa mais viva:** a cabeça balança com os passos (menos mirando, nada no ar), a
  câmera inclina para o lado quando você anda de lado e quando vira, dá uma afundada quando você
  cai de algum lugar, e a arma fica um pouco para trás quando você mexe a mira. Dá para desligar
  em Settings → **Head bob and tilt**.
- **Tiro e recarga animados em todas as armas:** cada tiro dá um coice na arma, o ferrolho ou a
  corrediça vai para trás e volta, sai o clarão na boca do cano e a cápsula voa para a direita e
  quica no chão. A pistola fica com a corrediça travada para trás quando acaba a munição. Na
  recarga a arma inclina, o pente cai, a outra mão busca um novo, encaixa e puxa o ferrolho; a
  espingarda recebe os cartuchos um por um pela janela de baixo e termina com a bombada. Em
  terceira pessoa o personagem traz a arma para a frente do peito e a outra mão vai e volta com o
  pente.
- **Duas armas novas** (nomes inventados, como todas as do jogo): a **Dragon**, uma pistola no
  estilo AK curta (madeira, pente curvo, sem coronha; tecla 5) e a **Buzzsaw**, uma metralhadora
  de mão quadrada com o pente no cabo (tecla 6). Estão no balcão da Ironside Arms e na bancada.
- **Dois carros novos** (também com nomes inventados): o **Kessler Bruiser**, um sedã musculoso
  comprido e baixo, e o **Kessler Boulder**, um SUV grande de três fileiras. Aparecem no trânsito
  e estão na concessionária do app Garage.
- **Animações novas:** andar e correr são dois ciclos diferentes misturados pela velocidade, com
  a passada casada com o chão (o pé não escorrega). O joelho dobra quando a perna vai para frente
  (mais na corrida), o quadril sobe e desce, balança e gira, os ombros giram ao contrário, os braços
  vão contra as pernas (cotovelo dobrado na corrida), o corpo inclina para frente correndo e para
  dentro nas curvas. Parado, o personagem respira, muda o peso de perna e olha em volta, cada um no
  seu tempo. Toda troca de pose (mirar, acenar, mãos para cima, emotes) é suave, sem pular. Quem
  está longe da câmera anima a cada três quadros, então ficou mais barato que antes.
- **Morte como num jogo sandbox:** o corpo vira ragdoll e cai para longe de onde veio o golpe; a
  câmera fica em terceira pessoa em cima do corpo, girando devagar e se afastando (dá para girar
  com o mouse ou o analógico); a imagem perde a cor e fica vermelha, com as bordas escuras, e
  aparece "YOU DIED". Depois de 4 segundos, Espaço, E ou A acordam você no Calder General (sozinho
  aos 12 segundos).
- **Lugares para entrar de verdade:** na porta, aperte E; a tela escurece e você está dentro de uma
  sala onde anda livremente (em terceira ou primeira pessoa, a câmera para nas paredes, a neve
  para de cair e a arma fica no coldre):
  - **Basement 808**, o estúdio no porão da Calder Ave: cabine de voz com vidro, espuma e o
    microfone (grava a sessão), a mesa de som com monitores e tela (o menu do estúdio), o sofá
    debaixo das placas de disco (aquece), fitas de LED e a escada de volta para a rua.
  - **Casa**, na Bishop St: sala com a mãe dormindo no sofá debaixo do cobertor e a TV ligada
    (assistir com ela aquece), cozinha com geladeira (comer recupera vida), fogão e a mesa com o
    notebook (salvar), e o quarto com a cama (ficar na moita: Heat −20) e o armário (o editor de
    personagem).
  - **Calder Mini Mart**: corredores de produtos, as geladeiras de bebida acesas, a máquina de
    café e o balcão com o Ray (café, aquecedores de mão, curativo, munição).
  - **Ironside Arms**, a loja de armas nova na Calder Ave com a Bishop St (placa acesa e janelas
    com grade na fachada): balcão de vidro com as pistolas e o Vic atendendo (comprar armas,
    munição e curativo), fuzis na parede perfurada, prateleiras de munição e a bancada (peças e
    acabamentos).
- **Eras do drill:** uma seção **Eras** no editor com um visual por era, de 2012 até hoje (dreads
  longos, high-top, freeform, cornrows, óculos de esqui, jersey, casaco de pele, grill de ouro), e
  oito personagens originais, um de cada era, pelas esquinas (no estúdio, no Mini Mart, no lago, na
  escada do L, nas quadras, no rec, no pavilhão e na Bishop St). Eles conversam quando você chega
  perto e levantam as mãos se você apontar uma arma. Os nomes e as pessoas são inventados; não são
  pessoas reais. Cerca de um em cada cinco pedestres também usa o visual de uma era.
- **Colisões melhores:** os carros agora são retângulos girados de verdade contra prédios, muros e
  outros carros (os cantos não entram mais nas paredes, e carros rápidos andam em passos curtos
  para não atravessar nada); uma batida de raspão gira o carro um pouco. Pessoas, ragdolls e tiros
  batem no contorno real do carro, não no quadrado em volta dele. Corpos caídos na rua são
  empurrados pelo carro em vez de atravessados, e ninguém atravessa ninguém: você, os pedestres,
  a polícia, as crews e a sua gangue se empurram.
- **Celular novo**, no estilo de um flagship moderno (tipo um "Pro Max"): borda de alumínio na cor
  que você escolher (Glacier, Silver, Black ou Burgundy, em Settings → **Phone colour**), borda
  preta fina, a ilha da câmera pequena, barra de status com a hora do jogo, sinal, Wi-Fi e bateria
  (a de verdade, no celular ou notebook). Ele sobe da parte de baixo da tela. Tela inicial com
  papel de parede, widgets de vidro (clima no Calder Park e o próximo trem do L), grade de ícones,
  dock e o selo de mensagens não lidas. Os apps têm títulos grandes, listas agrupadas com linhas
  finas, chaves liga/desliga, controles deslizantes com valor, balões de conversa nas mensagens e
  cartões no Blok e em Jobs. Toque na barrinha de baixo para voltar ao início, ou fora do celular
  para guardar.
- **Editor de personagem minimalista:** o personagem num foco de luz suave, à direita; à esquerda,
  as seções numa coluna fina, linhas finas com o nome pequeno em cima do valor e ‹ › para trocar,
  bolinhas de cor pequenas e um botão Save branco.
- **HUD e menu principal no mesmo estilo** do editor e do celular: fonte Inter, cartões de vidro
  escuro com borda fina (arma e munição, dinheiro e estrelas, Buzz e Heat; rua e hora; velocidade
  e rádio no carro), minimapa arredondado, barras finas, notificações como as de celular, a tecla
  em destaque nas dicas ("E Enter…"), títulos grandes finos e espaçados, menus dos lugares em
  coluna com linhas finas, tela de finais e tela inicial com o botão branco em pílula. Os botões
  de toque viram círculos de vidro.
- **Interface nova:** minimapa arredondado com prédios e marcadores, barras de vida, calor e
  fôlego, dinheiro que rola, estrelas de procurado, caixa de ajuda, feed de notificações,
  mensagens grandes no centro, rodas de armas e de emotes, e um **editor de personagem** em tela
  cheia com prévia 3D (casa → Wardrobe, ou o app Wardrobe no celular). Num jogo novo ele
  abre depois da cena de abertura.

- **Visual em cel shading** (realista, mas não demais): luz em faixas, como num desenho, em tudo
  (cidade, pessoas, carros, armas), brilho chapado nas partes lisas, contorno de tinta nas pessoas,
  nos carros e nas armas, e texturas novas da cidade pintadas para esse estilo (tijolo com rejunte,
  pedra, ripas, galpões, janelas com moldura, cortinas e neve no peitoril, asfalto com trilhas de
  lama e neve no meio-fio, calçada com sal). O contorno pode ser desligado em Settings → **Ink
  outlines** se o PC for fraco.
- **Rostos novos:** pescoço, maxilar, queixo, maçãs do rosto, orelhas, nariz com narinas, olhos com
  íris e pálpebras, sobrancelhas e boca em duas partes. **Barbas:** cheia, cavanhaque, por fazer,
  barba de contorno (chin strap) e bigode (Wardrobe → Hair → Beard).
- **Dedo do meio em todo lugar** (T, ou o botão **FINGER** no celular dentro do carro): em terceira
  pessoa parado, andando ou correndo; em **primeira pessoa** a mão aparece na frente da câmera; no
  **carro** em terceira pessoa o braço sai pela janela acima do teto, e no interior em primeira
  pessoa a mão esquerda solta o volante. Online, os outros veem também.

- **Céu novo** (desenhado por um shader atrás do mundo):
  - degradê do zênite ao horizonte, faixa laranja no pôr do sol e o cinturão rosa do lado oposto;
  - sol com brilho e halo, lua com fases e halo, estrelas que cintilam e giram com a noite, Via Láctea;
  - nuvens em duas camadas iluminadas pelo sol, pela lua e, à noite, pelo laranja da cidade;
  - o centro da cidade ao norte, com janelas acesas e luzes vermelhas piscando no alto das torres;
  - aurora boreal em algumas noites limpas e estrelas cadentes;
  - o tempo muda com o dia (céu limpo, nuvens, nublado) e em algumas noites cai **neve com trovoada**:
    raios no céu, clarões nas nuvens e trovões que chegam atrasados conforme a distância.
  Tudo segue o relógio compartilhado, então todo mundo online vê o mesmo céu.
- **Homenagem a XXXTentacion e King Von:**
  - **Jardim memorial** no Calder Park, a oeste do pavilhão: a réplica do mausoléu do XXXTentacion,
    feita a partir da foto que a família compartilhou. Granito cinza em placas, base em dois níveis
    com degraus, colunas jônicas caneladas com volutas, entablamento com dentículos e cornija, o
    frontão com "XXXTENTACION / JAHSEH D. ONFROY" gravado, e portas de bronze com arabescos sobre
    vidro escuro e puxadores dourados. Lá dentro, a placa de granito preto com o nome e as datas,
    vasos de rosas e uma luz eterna.
  - Em volta, como na foto: canteiro vermelho, gramado, palmeiras imperiais, cascatas de rosas
    vermelhas nos cavaletes (uma com faixa "LONG LIVE"), rosas pretas e prateadas, um buquê no vaso
    branco, pétalas e velas no degrau. Cerca de ferro com pilares de granito, lanternas e um arco
    com o nome dele no portão.
  - **Poison Tree** ao lado do mausoléu, num canteiro redondo de granito preto: uma árvore seca e
    retorcida, com raízes, frutos envenenados e veias violetas que brilham à noite, e uma placa
    "POISON TREE" com a árvore gravada em dourado.
  - Preste homenagem (**E** no degrau): o personagem reza, o céu fecha em segundos e cai um raio no
    frontão. A câmera assume (Espaço pula): as portas se abrem, a luz sai do túmulo e uma **figura
    de luz** aparece lá dentro, vem até o degrau, abre asas de penas sob uma auréola dourada com
    faíscas girando em volta, sobe para a tempestade entre pétalas de rosa e vira pombas brancas.
    A Poison Tree acende a cada raio. É uma figura de luz, sem rosto: não é a imagem de uma pessoa
    real.
  - Em noites de neve com trovoada, um raio pode cair no mausoléu sozinho quando você está perto.
    As pessoas que passam param para rezar; o jardim aparece no mapa do celular.
  - Na tela inicial: "In memory of King Von (1994–2020) and XXXTentacion (1998–2018). Long live."

Os personagens, crews, marcas e lugares da história são fictícios. A homenagem é a artistas reais.

O save tem o mesmo formato do web; o progresso importado traz a história, as faixas, o Blok,
as peças das armas, a gangue e o visual.

## Servidor dedicado (24 horas)

Para ter um servidor sempre ligado, que aparece na lista de todo mundo mesmo com você fora do jogo,
deixe o próprio jogo rodando em modo servidor num PC ou numa VPS. Não precisa abrir portas: ele
também se conecta para fora, nos servidores públicos de mensagens.

- **Windows:** no zip do Windows, edite `servidor.bat` (nome, senha, vagas, mensagem, PvP) e dê dois
  cliques. Deixe a janela aberta.
- **Linux:** no zip do Linux, edite `servidor.sh` e rode `./servidor.sh`. Numa VPS sem tela, instale
  antes o display virtual:

```bash
sudo apt install xvfb
```

- **À mão** (qualquer sistema):

```bash
./DrillSeason.x86_64 --audio-driver Dummy --server --name="Meu servidor" --max=24 --password=segredo --motd="Bem-vindo" --pvp=on
```

Opções: `--name=`, `--max=` (2 a 64), `--password=`, `--motd=` (mensagem do dia), `--pvp=on|off`,
`--region=` (sigla, ex.: BR) e `--id=`. O id é guardado na primeira vez, então o servidor volta com
o mesmo lugar na lista quando reinicia. A janela (ou o terminal) mostra quem entrou, quem saiu,
quem foi barrado (senha errada ou servidor cheio) e o chat.

## Para desenvolvedores

A pasta `tools/` na raiz do repositório regenera os assets a partir do jogo web:

- `node tools/export-godot.js [world|cars|guns|data|sfx]` exporta a cidade, os carros, as
  armas, os dados e os efeitos sonoros.
- `node tools/record-radio.js` grava as rádios.

Teste automático, sem tela:

```bash
DS_SHOTS=/tmp/shots xvfb-run godot3 --path godot --autotest
```

`tools/record-beats.js` grava as batidas do estúdio a partir do jogo web, e `tools/make-sfx.py`
sintetiza os sons extras (vento, cidade, partida, gelo, fogo, trovões, o coro, as asas das pombas e os passos).
`tools/make-memorial.py` pinta as texturas do jardim memorial (granito, frontão, arabescos das portas, placas, casca e veias da Poison Tree, palmeiras, grama, asas) e
`tools/make-sky-noise.py` gera o ruído que o shader do céu usa para nuvens e aurora.
`tools/make-city.py` pinta as texturas da cidade no estilo cel (fachadas, rua e calçada, em `godot/assets/tex/`).
`tools/make-ui.py` desenha o celular (borda, ilha, sombra), o papel de parede, os ícones dos apps e o fundo do editor de personagem (em `godot/assets/ui/`). O celular e o editor usam a fonte Inter (licença SIL OFL, em `godot/fonts/`).

Para ver só o céu: `DS_SKYTEST=medium godot3 --path . --autotest` (com `DS_SHOTS=pasta`) tira fotos
ao meio-dia, nublado, pôr do sol, noite com aurora, estrelas, trovoada e amanhecer.

Para testar o online sem internet, rode um servidor MQTT local (por exemplo `mosquitto` com um
listener websockets) e aponte o jogo para ele com
`DS_BROKERS=ws://127.0.0.1:9001/mqtt,tcp://127.0.0.1:1883`.

Ele grava capturas e um `autotest.log`.

Para ver rostos, barbas, o dedo do meio e o visual cel: `DS_LOOKTEST=1`. Para ver o editor de personagem e todas as telas do celular: `DS_UITEST=1`. Para os lugares de entrar: `DS_ROOMTEST=1`. Para as animações (andar, correr e parado, de lado, mais quantas pisadas por segundo em cada velocidade): `DS_ANIMTEST=1`; só a dança sturdy: `DS_ANIMTEST=sturdy`. Para a morte: `DS_DEATHTEST=1`. Para as armas (tiro e recarga de cada uma, em primeira e terceira pessoa) e os carros novos: `DS_GUNTEST=1`. Para as colisões (carro no muro, batida de frente, corpo contra carro girado, multidão): `DS_COLTEST=1`. Para testar servidores,
com um servidor dedicado rodando (`--server --name="Test Dedicated" --password=...`): `DS_SRVTEST=client`
(com `DS_PW=` para a senha) acha o servidor, é barrado com a senha errada, entra com a certa, conversa
e depois cria o "Test Host"; `DS_SRVTEST=joiner` noutro jogo entra nele. `DS_BROKERS=` troca os
servidores de mensagens por um seu (por exemplo um mosquitto local, `ws://127.0.0.1:9001`).
