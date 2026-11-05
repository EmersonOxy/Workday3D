# Viagens entre escritório, rua, mercado e casa (protótipo 3D)

## Abordagem adotada
O `main.tscn` preserva o mesmo personagem, esqueleto, animações e WorkOS, enquanto o script `scripts/world/world_travel.gd` alterna os ambientes carregados em `scenes/locations/`. Não há navegador, telas de pixel art ou deslocamento contínuo por uma cidade inteira.

A primeira versão utiliza *blockouts 3D editáveis* (meshes e colisões simples). Isso cria os locais reais no Godot, mas os modelos definitivos de mercado, casa, rua, portas e relógio de ponto ainda precisam ser substituídos. A interface de compras e o ciclo de dormir também não foram implementados nesta etapa.

## Fluxo jogável previsto
- Escritório: E levanta da cadeira (sistema existente). Vá ao relógio de ponto e aperte E para registrar saída.
- Escritório: aproxime-se da porta, pressione E. A folha abre e a tela escurece brevemente.
- Rua comercial: caminhe até a porta do mercado (E), até a parada de ônibus (E) para ir para casa ou volte ao ponto de entrada para retornar ao escritório.
- Mercado: a porta de saída (E) leva de volta à rua, perto da entrada do mercado.
- Casa: a porta de entrada/saída (E) leva de volta à rua, perto da parada de ônibus.
- Quando retornar ao escritório, o relógio de ponto permite registrar a entrada novamente.

A troca visual usa somente uma breve transição escura, sem tela ilustrada. O jogador continua usando WASD, mouse e E. O prompt de interação aparece próximo ao objeto e só a área ocupada pelo personagem ativa a ação; olhar para longe não teletransporta.

## Arquivos
- `scripts/world/interaction_zone.gd`: `Area3D` com ID de ação, texto de interação e porta opcional.
- `scripts/world/world_travel.gd`: detecção do trigger, ponto, roteamento, carregamento de `PackedScene`, spawn e fade.
- `scenes/locations/street.tscn`, `market.tscn`, `home.tscn`: cenas 3D provisórias com colisor, porta, marcadores `Spawns` e interações.
- `scripts/main.gd`: E prioriza triggers de viagem, depois interação normal com cadeira; nada muda no encaminhamento do WorkOS.
- `scripts/player_controller.gd`: transferência física e sincronização de câmera sem recriar o player.

## Limites e próximas etapas
- O escritório ainda é um grupo de nós de `main.tscn`, não uma `office.tscn` independente. Isso preserva os alvos da cadeira/mesa e evita regressões agora. Os demais ambientes são `PackedScene` autônomas.
- O ponto começa como **entrada registrada** para permitir o fluxo inicial de sair do trabalho. A alternância entrada/saída é temporária, não vinculada ao horário do WorkOS.
- Faltam assets definitivos, inventário de compras e persistência de localização entre reinícios. Essas integrações devem ser adicionadas depois do teste da navegação.
- Esta implementação precisa ser executada em Godot 4.7 no editor e validada visualmente; a revisão de código não equivale a um teste em tempo de execução.
