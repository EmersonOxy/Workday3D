# Player: movimento, câmera e ajustes de pose

## Controles

- WASD: caminhar com aceleração e desaceleração.
- Mouse em pé: giro horizontal livre; o corpo acompanha o rumo da câmera, inclusive parado, para não expor as costas ao jogador.
- Mouse sentado: limite horizontal da cena e limite vertical.
- E: levantar ou sentar quando próximo da cadeira.
- Clique no monitor sentado: iniciar a preparação para digitar e a transição da câmera.
- Esc / Voltar: sair do foco do monitor. Enquanto usa o WorkOS, E continua sendo uma letra para os aplicativos.

A caminhada não usa a posição do pé para alterar a velocidade do personagem a cada quadro. A animação acompanha a distância realmente percorrida, com um ciclo de caminhada ou de passo lateral e mistura entre os clipes. A longa animação Start Walking não atrasa mais o início de cada caminhada. A velocidade desejada fica em Character → Movimentacao → Velocidade Caminhada M S. Os valores e transforms já salvos pelo usuário foram preservados.

## Ajustar no editor

Selecione **PoseAdjustments** na cena principal:

1. Em **Previa**, escolha Sentado, Digitando, Em pe, Levantando ou Sentando.
2. Use **Instante Animacao** para visualizar um instante do clipe.
3. Ajuste posição/rotação do quadril, coluna, peito, coxas e joelhos. As posições do quadril usam os eixos do corpo; rotações são adições em graus nos eixos locais do osso.
4. Nas categorias de dedos, cada Vector3 controla a dobra das três falanges: X é a primeira, Y é a segunda, Z é a terceira. Polegar, indicador, médio, anelar e mindinho têm controles próprios em cada mão.
5. Para qualquer outro osso, use **Rotacoes Ossos**: a chave é o nome exato do osso no Skeleton3D e o valor é sua rotação adicional local, em graus. Exemplos: LeftHand_013, RightHand_036, Spine1_03. Esses ajustes são aplicados depois da correção dos braços, permitindo um ajuste manual final.

Os ajustes de pose são usados também em execução. Na prévia, os clipes reais são amostrados antes das correções. Movimentos extremos ainda podem causar interseções: o esqueleto e os comprimentos dos braços continuam sendo os do modelo original.

## Mesa, cadeira e zona de digitação

**ArmRestTargets** acompanha OfficeChair. **TypingTargets** acompanha OfficeTable, sem herdar a escala centimétrica dos modelos. Os marcadores continuam editáveis individualmente. Mover a mesa ou a cadeira no editor atualiza o grupo associado; as posições dos marcadores são salvas com a cena.

- LeftHand e RightHand: posição desejada dos pulsos; a rotação local do marcador ajusta a orientação da mão.
- LeftElbow e RightElbow: orientação da dobra do cotovelo. Não são posições que o cotovelo é obrigado a alcançar.
- TypingTargets/TypingZone: volume de referência da digitação. Com Usar Zona Digitacao ativo em PoseAdjustments, as mãos são limitadas a esse volume. Desative a opção para posicionar os alvos fora dele.
- A altura da mão em digitação é corrigida para ficar ao menos 5,5 cm acima do ponto mais alto da malha da mesa.
- Inclinacao Digitacao Graus: inclinação adicional do tronco ao alcançar a mesa; padrão 10 graus. Pode ser zerada para usar apenas o clipe original e os ajustes manuais.

A zona é uma referência de posicionamento, não um sensor que precisa colidir com a mão. As mãos são conduzidas ao alvo por IK; se o alvo exceder o alcance dos braços, é necessário aproximar o corpo ou o alvo. O solver não estica o braço para ultrapassar seu comprimento.

Durante levantar/sentar, os alvos das mãos migram dos apoios para as laterais do corpo. Isso evita depender da trajetória original dos pulsos de um esqueleto com proporções diferentes.

## Corpo em primeira pessoa

O derivado para a câmera preserva tronco, quadril e pernas; só faces dominadas por cabeça/pescoço são retiradas. O modelo original e os FBX são preservados. As superfícies da visão em primeira pessoa descartam faces traseiras. A câmera usa uma posição estável e uma folga em relação ao pescoço; seu deslocamento horizontal acompanha o corpo sem atraso durante os giros.

A caixa amarela que aparece ao selecionar uma malha no editor é seu contorno de seleção/AABB. Não é uma parede ou um trigger de interação. As colisões de caminhada estão em Character/BodyShape e WorldCollisions; a zona de digitação está em TypingTargets/TypingZone.

## Derivados e conferência

assets/animations/generated/player_library.res contém os clipes adaptados. tools/bake_player_animations.gd regenera essa biblioteca; tools/build_world_collisions.gd regenera as colisões dos móveis caso as malhas sejam trocadas. A importação/compilação é conferida pelo assistente. A revisão visual e os testes in game ficam com o usuário, conforme solicitado.

## Controles 3D arrastáveis

Expanda **PoseAdjustments** na árvore. Os grupos **Corpo**, **BracoEsquerdo**, **BracoDireito**, **DedosEsquerdos** e **DedosDireitos** contêm marcadores posicionados nos ossos da prévia.

- Selecione Quadril, Coluna ou Peito e use a ferramenta Mover ou Girar do Godot.
- Nos braços, pernas e falanges, use Girar para ajustar a articulação. Para mover as mãos e indicar a dobra dos cotovelos com IK, continuam disponíveis ArmRestTargets e TypingTargets.
- Mude Previa e Instante Animacao no nó PoseAdjustments para ajustar sobre o clipe desejado.
- Salve a cena. A propriedade interna Ajuste de cada marcador guarda a correção e é aplicada também em execução.

Os marcadores seguem os ossos quando a prévia muda; não é necessário digitar os ângulos para editar a pose. As correções numéricas existentes continuam disponíveis. A opção Permitir Translacao de um marcador libera translação direta do osso, que pode esticar a geometria se usada em membros ou dedos.

Em pé e andando, os braços usam os clipes originais sem os alvos dos apoios da cadeira. Na transição sentar/levantar, a orientação das mãos migra para dedos apontados para baixo.

## Corpo e balanço ao caminhar

Em Character → Camera em pe, ajuste Altura Camera Em Pe, Avanco Camera Em Pe e Limite Olhar Baixo Em Pe. O avanço padrão foi reduzido para 10 cm e o limite inferior em pé ampliado para 70 graus, permitindo enxergar mais do corpo ao olhar para baixo.

Balanco Vertical e Balanco Lateral controlam um movimento leve da câmera. O ciclo acompanha a distância percorrida e desaparece gradualmente ao parar ou encontrar um obstáculo. Use zero para desativar um dos eixos.

A cadeira usa quatro caixas e um cilindro para colisão, evitando contatos com milhares de triângulos da malha visual. Os transforms dos corpos de colisão só são atualizados quando o móvel realmente muda de transform. O gerador de colisões mantém essa simplificação em regenerações futuras.

## Dedos por postura e controles da câmera

Os ajustes numéricos e os marcadores dos dedos são destinados à postura sentada/PC. Ao levantar, seu peso diminui gradualmente até zero; em pé e andando, os dedos seguem o clipe original. Ao sentar, os ajustes retornam gradualmente. A prévia Em pe no editor também ignora as correções de dedos sentados.

Selecione **CameraPivot/FirstPersonCamera → Balanco ao caminhar** para ajustar Balanco Ativo, Intensidade Vertical, Intensidade Lateral, Distancia Por Ciclo e Suavidade Balanco. As intensidades estão em metros e podem ser zeradas. Esses controles ficam na câmera, não mais no Character.

## Inclinação pelo mouse, enquadramento e visão da cadeira

Todos estes controles ficam em **CameraPivot/FirstPersonCamera**:

- **Inclinacao ao mover o mouse**: Inclinacao Ativa, Inclinacao Maxima Graus, Graus Por 100 Pixels Segundo e Suavidade Inclinacao. A câmera inclina em torno do próprio eixo de visão ao mover o mouse horizontalmente e retorna suavemente quando o movimento para. O balanço lateral por caminhada fica zerado por padrão; o balanço vertical continua independente.
- **Enquadramento do corpo em pe**: Corpo Visivel Em Pe (0 mostra menos; 1 mostra mais), Altura Em Pe e Olhar Baixo Em Pe. A proteção contra atravessar o pescoço continua limitando posições muito próximas.

**ChairCameraTargets/SeatedView** e **StandingView** são os pontos editáveis para as transições da cadeira. A visão é interpolada até esses pontos enquanto senta/levanta, com o mouse bloqueado nessas etapas. O grupo acompanha a cadeira quando ela recua ou retorna. Ao terminar, os ângulos do controlador são sincronizados com a visão final, evitando o salto no primeiro movimento do mouse.

Ao ficar em pé, os dedos recebem uma postura neutra explícita a partir do repouso do esqueleto, com uma pequena curvatura. Os ajustes sentados de dedos, pulsos e braços são retirados durante a transição, incluindo os marcadores e o dicionário de ossos. Assim, clipes de locomoção com dedos estáticos não mantêm a configuração sentada.

Em **Character → Movimentacao → Amplitude Bracos Caminhada**, 0.65 reduz o balanço dos braços em relação à postura neutra. 1 usa a amplitude original; 0 mantém os braços neutros durante a caminhada.
