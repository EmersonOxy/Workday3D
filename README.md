# Workday 3D

Protótipo de simulação de escritório feito em **Godot 4.7 Standard**, com **GDScript** e renderizador **Compatibility**. A cena principal combina um ambiente 3D explorável com a interface 2D do WorkOS, exibida na tela de um monitor 3D.

## Estado e escopo

- O escritório 3D tem mesa, cadeira, monitor e personagem em primeira pessoa. O mini PC do modelo de referência foi removido da cena; os arquivos originais do modelo continuam preservados em `assets/models/`.
- O WorkOS é uma interface nativa do Godot dentro de um `SubViewport`, não um navegador. A área de trabalho e cada aplicativo ficam em cenas editáveis em `scenes/workos/`.
- O personagem pode sentar, levantar e caminhar. Clique no monitor para acessar o WorkOS.
- As transições por proximidade entre escritório, rua, mercado e casa estão implementadas. Rua, mercado e casa são blockouts 3D provisórios; os sistemas de compras e ciclo de dormir ainda não estão concluídos.
- Os sprites originais de gatos estão em `assets/workday/cats/`. Um gato aparece sobre a mesa como `Sprite3D` voltado ao jogador.

## Abrir e executar

Abra `project.godot` no Godot 4.7 ou posterior e execute `scenes/main.tscn`, que também é a cena principal do projeto. A cena 3D e os aplicativos 2D podem ser inspecionados e ajustados no editor.

## Controles

- **Mouse:** olhar ao redor. A visão horizontal é limitada para manter o personagem à frente; a visão vertical também é limitada.
- **WASD:** caminhar lentamente.
- **E:** sentar ou levantar perto da cadeira; em outros locais, interagir com o objeto indicado pelo prompt.
- **Clique no monitor:** aproximar e usar o WorkOS com a animação de digitação.
- **Esc:** sair do foco do monitor ou alternar a captura do mouse.
- No WorkOS, use os ícones e janelas. Notas e wallpaper são salvos em `user://workos.cfg`.

## Estrutura principal

| Caminho | Conteúdo |
| --- | --- |
| `scenes/main.tscn` | Escritório 3D, monitor, personagem, câmera, gato e SubViewport do WorkOS |
| `scenes/workos/` | Área de trabalho e cenas dos aplicativos 2D |
| `scenes/locations/` | Cenas 3D de rua, mercado e casa |
| `scenes/props/` | Objetos 2D apresentados no ambiente 3D, como o gato |
| `scripts/` | Movimento, câmera, WorkOS, pose e transições entre locais |
| `assets/models/` | Cópias importadas dos modelos 3D usados pelas cenas |
| `assets/workday/cats/` | Sprites originais de gatos, em dez pelagens |
| `docs/` | Notas de integração, edição, modelos e protótipos |

## Ajustes no editor

- Selecione `Workday3D` em `main.tscn` para ajustar `desk_cat_offset`, que posiciona o gato no tampo da mesa.
- Selecione `DeskCat` e altere `pelagem` para trocar o sprite.
- Os alvos `ArmRestTargets` e `TypingTargets` controlam a posição das mãos e dos cotovelos do personagem.
- Os aplicativos do WorkOS têm cenas próprias para facilitar a edição visual.

## Documentação

- [Movimentação e ajustes do personagem](docs/MOVIMENTACAO_PLAYER.md)
- [Cenas e transições entre locais](docs/CENAS_E_TRANSICOES.md)
- [Assets de gatos no cenário 3D](docs/ASSETS_GATO_3D.md)
- [Integração do WorkOS](docs/INTEGRACAO_WORKOS.md)
- [Edição das cenas do WorkOS](docs/EDICAO_WORKOS.md)
- [Inspeção dos modelos originais](INSPECAO_MODELOS.md)
