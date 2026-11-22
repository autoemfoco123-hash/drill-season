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
| Trocar de arma | Q, ou 1 2 3, e 4 para os punhos | LB / L1 |
| Correr | Shift | L3 |
| 1ª ou 3ª pessoa | V | R3 |
| Celular | Tab ou P | D-pad cima |
| Curativo | B | D-pad baixo |
| Acenar / dedo do meio | G / T | D-pad esquerda / direita |
| Mapa | M | Select / View |
| Pausar | Esc | Start / Menu |

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

## O que já está no Godot

- A cidade inteira, com o ciclo de dia e noite no mesmo relógio do jogo web e as janelas
  acendendo à noite.
- Personagem com o mesmo guarda-roupa.
- Câmera em 3ª e 1ª pessoa.
- As três armas, punhos (jab, direto, gancho e guarda), curativos, frio.
- Carros: dirigir, roubar, trânsito com semáforos, carros estacionados, a sua garagem e
  compras na Marrow Motors.
- As quatro rádios.
- Pedestres, polícia com estrelas de procurado, ser preso ou ir para o hospital.
- Crews rivais com encarada e tiroteio.
- Gangues: criar, os seis tipos de recruta, recrutar na rua, seguidores que lutam, e o
  filtro de nomes reais e ofensivos.
- HUD com minimapa.
- Celular com os apps Mapa, Gangue, Garagem, Visual, Configurações, Controle e Estatísticas.
- Loja, posto, casa, lago, quadra e centro comunitário.

Ainda só existe no jogo web:

- O estúdio (o jogo de ritmo).
- A rede social Blok.
- Missões da história e cutscenes, e os finais.
- A bancada de armas.
- O multiplayer online.
- O trem andando, a neve caindo e o sistema completo de calor.

O save guarda tudo isso, então nada se perde ao ir e voltar entre as duas versões.

## Para desenvolvedores

A pasta `tools/` na raiz do repositório regenera os assets a partir do jogo web:

- `node tools/export-godot.js [world|cars|guns|data|sfx]` exporta a cidade, os carros, as
  armas, os dados e os efeitos sonoros.
- `node tools/record-radio.js` grava as rádios.

Teste automático, sem tela:

```bash
DS_SHOTS=/tmp/shots xvfb-run godot3 --path godot --autotest
```

Ele grava capturas e um `autotest.log`.
