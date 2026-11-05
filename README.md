# Workday 3D

Projeto Godot 4 com GDScript e renderizador Compatibility. Abra `project.godot` no Godot 4. A cena `scenes/main.tscn` contém os modelos como instâncias editáveis; mesa, cadeira, computador, monitor, personagem, câmera, chão e paredes aparecem no editor 3D.

## Controles

- Mouse: olhar ao redor, limitado a 65° para cada lado e com rotação vertical limitada.
- Aponte para o monitor e clique: aproximar.
- Na tela aproximada, use os ícones ou o menu Iniciar do WorkOS. Arraste janelas pela barra de título; use os botões para minimizar, maximizar e fechar.
- Digite nas Notas ou use a Calculadora. Configurações permite escolher entre oito wallpapers originais.
- Iniciar → Música: quatro faixas originais, seleção da playlist, volume e próxima faixa. A reprodução continua com a janela fechada; as preferências são salvas.
- Esc fecha o menu Iniciar aberto; caso contrário, retorna à cadeira. O botão Voltar na barra de tarefas também retorna.
- Esc fora da aproximação: alternar a captura do mouse.

A interface do monitor é renderizada em um `SubViewport` e aplicada à malha 3D da tela. O personagem usa uma pose sentada estática no esqueleto; não há animações no asset original.

O foco no monitor sempre usa o mesmo enquadramento frontal. A transição interpola a orientação pelo caminho mais curto e restaura a posição e a direção anteriores ao sair. Os marcadores de `ArmRestTargets` permitem ajustar as mãos e a direção dos cotovelos no editor, atualizando a pose estática.

A interface é renderizada em 1280×720 e preenche aproximadamente 94% da janela ao focar o monitor. As mãos usam material de pele compatível e ficam com as palmas para baixo.

A área de trabalho nativa está em `scenes/workos_desktop.tscn`, instanciada no `DesktopSubViewport`. Os assets originais usam controles Godot e GDScript. Notas e wallpaper são salvos em `user://workos.cfg`. O escopo e a origem dos recursos estão em [Integração do WorkOS](docs/INTEGRACAO_WORKOS.md).

Os GLB originais da raiz foram preservados. A cena usa cópias em `assets/models/`. Formatos, texturas e problemas encontrados estão descritos em [INSPECAO_MODELOS.md](INSPECAO_MODELOS.md).

## Movimentação

WASD para caminhar lentamente. E para levantar ou sentar perto da cadeira. Sentado, clique no monitor para entrar no WorkOS com a animação de digitação. Consulte [os controles e ajustes](docs/MOVIMENTACAO_PLAYER.md).
