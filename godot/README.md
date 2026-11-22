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
| Trocar de arma | toque Q (ou 1 2 3, e 4 para os punhos) | toque LB / L1 |
| Roda de armas (câmera lenta) | segure Q | segure LB / L1 |
| Roda de emotes (danças, palmas, rir, sentar, anjo na neve...) | segure Z | segure D-pad esquerda |
| Bola de neve | X | pela roda de armas |
| Se jogar no chão (ragdoll) | J (Espaço ou andar para levantar) | pela roda de emotes |
| Correr | Shift | L3 |
| 1ª ou 3ª pessoa | V | R3 |
| Celular | Tab ou P | D-pad cima |
| Curativo | B | D-pad baixo |
| Acenar / dedo do meio | G / T | roda de emotes / D-pad direita |
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
- **Emotes:** três danças, hype, palmas, rir, dar de ombros, continência, apontar, mão na cara,
  músculo, sentar, anjo na neve e rezar. Quem está perto reage, e a sua gangue dança junto.
- **Guerra de bolas de neve:** as pessoas riem, devolvem, fogem ou escorregam; a polícia não acha graça.
- **Online (Linux, Windows e Mac juntos):** no celular, **Online**:
  - **Play online · public room**: entra na sala pública; todo mundo que fizer o mesmo aparece.
  - **Create a private room**: cria uma sala com um código de 5 letras. Mande o código para os
    amigos; eles digitam em **Join private room**.
  - Não precisa abrir porta no roteador nem ter alguém hospedando: o jogo se conecta a servidores
    públicos de mensagens (MQTT) que repassam as posições, tiros, socos e emotes. Ele mantém dois
    servidores ligados ao mesmo tempo para não cair se um falhar.
  - **Same Wi-Fi or direct IP**: o modo antigo, sem internet. Um hospeda (UDP 24680) e os outros
    entram pelo IP ou pela lista de jogos na rede.
  - Dá para convidar gente para a gangue, e quem é da mesma gangue não se fere.
  - O que passa pelos servidores públicos é público: o seu @nome, o visual e onde você está no mapa.
- **Interior do carro** em primeira pessoa (V dentro do carro): capô na cor do carro, painel com
  conta-giros e velocímetro de verdade, marcha, volante que gira com as suas mãos, retrovisor e o
  rádio mostrando a estação.
- **Som refeito:**
  - motor sintetizado ao vivo, com marchas, partida, giro, pipocos no escape;
  - pneus, neve, derrapagem e vento na carroceria;
  - por dentro do carro a rua fica abafada;
  - tiros com eco que muda com a distância dos prédios e cartuchos caindo no chão;
  - balas passando zunindo; passos diferentes na rua, na calçada e na plataforma de metal;
  - vento que acompanha as rajadas, a cidade ao fundo, sirenes, cachorros, aviões e o gelo do lago
    rangendo; fogo crepitando nos barris e vapor nos bueiros;
  - mixagem com compressor e limitador.
- **Interface nova:** minimapa arredondado com prédios e marcadores, barras de vida, calor e
  fôlego, dinheiro que rola, estrelas de procurado, caixa de ajuda, feed de notificações,
  mensagens grandes no centro, rodas de armas e de emotes, e um **editor de personagem** em tela
  cheia com prévia 3D (casa → Wardrobe, ou o app Wardrobe no celular). Num jogo novo ele
  abre depois da cena de abertura.

- **Céu novo** (desenhado por um shader atrás do mundo):
  - degradê do zênite ao horizonte, faixa laranja no pôr do sol e o cinturão rosa do lado oposto;
  - sol com brilho e halo, lua com fases e halo, estrelas que cintilam e giram com a noite, Via Láctea;
  - nuvens em duas camadas iluminadas pelo sol, pela lua e, à noite, pelo laranja da cidade;
  - o centro da cidade ao norte, com janelas acesas e luzes vermelhas piscando no alto das torres;
  - aurora boreal em algumas noites limpas e estrelas cadentes;
  - o tempo muda com o dia (céu limpo, nuvens, nublado) e em algumas noites cai **neve com trovoada**:
    raios no céu, clarões nas nuvens e trovões que chegam atrasados conforme a distância.
  Tudo segue o relógio compartilhado, então todo mundo online vê o mesmo céu.
- **Homenagem a King Von e XXXTentacion:**
  - **Jardim memorial** no Calder Park, a oeste do pavilhão: uma réplica do mausoléu do XXXTentacion,
    feita a partir da foto que a família compartilhou. Granito cinza, frontão com
    "XXXTENTACION / JAHSEH D. ONFROY", colunas, portas de bronze com arabescos, degrau de granito,
    canteiro vermelho, gramado, palmeiras, cascatas de rosas vermelhas nos cavaletes e rosas pretas e
    prateadas, velas no degrau. Lá dentro, uma placa com o nome e as datas.
  - Preste homenagem no mausoléu (**E**) e acenda uma vela: o céu fecha, cai um raio no frontão, as portas se abrem,
    a luz sai lá de dentro e uma **figura de luz** aparece, vem até o degrau, abre asas de anjo
    sob uma auréola, sobe e vira pombas brancas. É uma figura de luz, sem rosto: não é a imagem de
    uma pessoa real.
  - As pessoas que passam param para rezar; o jardim aparece no mapa do celular.
  - Na tela inicial: "In memory of King Von (1994–2020) and XXXTentacion (1998–2018). Long live."

Os personagens, crews, marcas e lugares da história são fictícios. A homenagem é a artistas reais.

O save tem o mesmo formato do web; o progresso importado traz a história, as faixas, o Blok,
as peças das armas, a gangue e o visual.

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
sintetiza os sons extras (vento, cidade, partida, gelo, fogo, trovões, o coro e as asas das pombas).
`tools/make-memorial.py` pinta as texturas do mausoléu (frontão, portas, granito, placa) e
`tools/make-sky-noise.py` gera o ruído que o shader do céu usa para nuvens e aurora.

Para ver só o céu: `DS_SKYTEST=medium godot3 --path . --autotest` (com `DS_SHOTS=pasta`) tira fotos
ao meio-dia, nublado, pôr do sol, noite com aurora, estrelas, trovoada e amanhecer.

Para testar o online sem internet, rode um servidor MQTT local (por exemplo `mosquitto` com um
listener websockets) e aponte o jogo para ele com
`DS_BROKERS=ws://127.0.0.1:9001/mqtt,tcp://127.0.0.1:1883`.

Ele grava capturas e um `autotest.log`.
