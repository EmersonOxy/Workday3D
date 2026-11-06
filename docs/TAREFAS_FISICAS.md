# Tarefas físicas do expediente (escritório 3D)

Mire com o ponto central e use **E**. O tempo do expediente corre fora do computador (`game_state.active()`); a pausa de janelas só vale com o jogador olhando o monitor.

| Tarefa | Como funciona |
| --- | --- |
| Telefone (`call`) | Toca na mesa. Mire e **segure E** até a barra completar. |
| Impressora (`printer`) | Círculos brilhantes aparecem ao redor da impressora, no canto. Mire em cada um e aperte E. |
| Lixo | Bolas de papel surgem no chão fora do campo de visão (a partir do dia 2). Pegue (E), leve à lixeira e solte (E). Enquanto ficam no chão, o estresse sobe devagar. |
| Chefe | Entra pela porta. É preciso estar **sentado na cadeira** antes do prazo; senão o estresse sobe. |
| Café | Máquina no canto: E pega a xícara; na mesa, E deixa a xícara (alivia 25 de estresse e deixa o tempo lento por 5 s; espera de 25 s). |
| E-mail, spam, vírus | Continuam no WorkOS. |

## Luz e janelas (`scripts/world/office_lighting.gd`)
- Três janelas de verdade (aberturas nas paredes esquerda e direita) com vista para uma rua: céu, calçada, prédios com janelas acesas e postes, tudo seguindo o relógio do jogo.
- Sol com sombras: só entra pelas janelas, desenha manchas e a sombra da esquadria no chão; feixes de luz (raios) aditivos com poeira marcam o caminho.
- À noite os postes jogam luz pela janela; com as luzes do teto acesas, a luz também sai pela janela e ilumina a calçada.
- **Interruptor** (ao lado da porta): E liga/desliga as lâmpadas do teto. **Cortina**: mire na janela e aperte E. Cortina fechada bloqueia sol, vista e raios.
- As duas luzes de preenchimento do cenário foram reduzidas (antes iluminavam a sala sem janela nem lâmpada).

## Modelos
- Café: salve os GLB em `assets/models/biblioteca/coffee-machine/coffee_machine.glb` e `coffee-cup/coffee_cup.glb` (ou troque as constantes em `office_tasks.gd`). Sem eles, aparecem peças provisórias.
- Teclado e mouse: não há modelos no projeto; são caixas provisórias criadas em `_build_peripherals()`.

## Depuração (builds de debug)
F1 telefone · F2 impressora · F3 lixo · F4 chefe · F6/F7 avançam o relógio.

## Créditos de shaders
- `assets/shaders/light_shaft.gdshader`: esmaecimento por ângulo de visão a partir de [Fake Godrays (Godot 4.x)](https://godotshaders.com/shader/fake-godrays-godot-4-2/), de Ivan Isaev (CC0).
- `assets/shaders/curtain_fabric.gdshader`: perturbação de normal com ruído de valor segundo o [Procedural Cloth Wrinkles Shader](https://godotshaders.com/shader/procedural-cloth-wrinkles-shader/), de Yui Kinomoto (arlez80), licença MIT. O código é uma reescrita; a ideia e o crédito são dele.
- Os demais (`exterior_sky`, `exterior_building`, `light_patch`) são originais deste projeto.

## Desempenho (RX550, 1280×720)
Os spots dos postes com sombra eram o item mais caro (também de dia, pois seguiam sendo renderizados com energia 0). Foram trocados por uma mancha de luz no chão (`light_patch.gdshader`) calculada a partir do poste. Pior caso: 76 → 258 fps. O sol continua com sombra real (custa uns 25 % do quadro de dia).
