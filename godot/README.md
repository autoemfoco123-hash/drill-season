# Drill Season (Godot)

Versão nativa do Drill Season para PC, feita em **Godot 3 (GLES2)**. Ela roda em placas
de vídeo antigas, como a Intel HD de primeira geração (Iron Lake / Arrandale / Clarkdale),
no Linux (Kali, Debian, Ubuntu) e no Windows.

A cidade, os carros, as armas, os sons e as quatro rádios são exportados do jogo web. O
save tem o mesmo formato, então o seu progresso do navegador vem junto.

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
  músculo, sentar e anjo na neve. Quem está perto reage, e a sua gangue dança junto.
- **Guerra de bolas de neve:** as pessoas riem, devolvem, fogem ou escorregam; a polícia não acha graça.
- **Online:** um jogador hospeda (celular → Online → Host), os outros entram pelo IP ou pela
  lista de jogos na mesma rede. Todo mundo se vê andando, dirigindo, atirando, socando e
  dançando; dá para convidar gente para a gangue, e quem é da mesma gangue não se fere. Pela
  internet, quem hospeda libera a porta UDP 24680 no roteador. O online liga cópias do Godot;
  o jogo de navegador tem as salas dele.
- **Interface nova:** minimapa arredondado com prédios e marcadores, barras de vida, calor e
  fôlego, dinheiro que rola, estrelas de procurado, caixa de ajuda, feed de notificações,
  mensagens grandes no centro, rodas de armas e de emotes, e um **editor de personagem** em tela
  cheia com prévia 3D (casa → Wardrobe, ou o app Wardrobe no celular). Num jogo novo ele
  abre depois da cena de abertura.

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

`tools/record-beats.js` grava as batidas do estúdio a partir do jogo web.

Ele grava capturas e um `autotest.log`.
