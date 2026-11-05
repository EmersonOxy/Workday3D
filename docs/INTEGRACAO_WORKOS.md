# WorkOS nativo no monitor 3D

## Implementação

A cena `scenes/workos_desktop.tscn` é uma interface Godot com raiz Control, renderizada pelo `DesktopSubViewport` de `scenes/main.tscn`. A textura do viewport é aplicada ao material do monitor. A área de trabalho pode ser aberta diretamente no editor 2D.

Os PNGs originais do Workday são usados em StyleBoxTexture, TextureRect e TextureButton. A fonte VT323 foi convertida de WOFF2 para TTF, mantendo a licença SIL OFL. O comportamento foi implementado em GDScript.

### Recursos incluídos

- Wallpaper, ícones, menu Iniciar, barra de tarefas e relógio.
- Janelas com arraste, foco pela barra de título, minimizar, restaurar, maximizar e fechar.
- Notas com salvamento automático em `user://workos.cfg`.
- Calculadora com operações aritméticas e parênteses.
- Configurações com oito wallpapers originais e seleção persistente.
- Janela Sobre e botão Voltar para sair do monitor.
- Música no menu Iniciar: quatro MP3 originais, faixas habilitáveis, avançar, pausar e volume persistente. O serviço de áudio permanece ativo com a janela fechada.

O controlador 3D encaminha eventos de pressionar/soltar, movimento, arraste, roda e teclado ao SubViewport. A projeção usa o plano da tela 3D. Esc primeiro fecha o menu Iniciar; depois retorna à cadeira. Popups Godot ficam incorporados ao SubViewport.

## Arquivos principais

- `scenes/workos_desktop.tscn`: composição estática editável da área de trabalho e tema.
- `scripts/workos_desktop.gd`: aplicativos, menu, tarefas e persistência.
- `scripts/workos_window.gd`: construção e comportamento das janelas.
- `scripts/main.gd`: câmera, material do monitor e encaminhamento de entrada.
- `assets/ui/workos/`: imagens originais, wallpapers, licença e origem.
- `assets/fonts/`: fonte VT323 e licença.

## Escopo restante

Esta etapa porta a apresentação do WorkOS e seus aplicativos básicos, incluindo música. Calendário, mensageiro, expediente, economia e demais sistemas do Workday original ainda precisam de implementação em GDScript e integração ao estado do jogo. Saves existentes em localStorage não são importados automaticamente.

### Dependências identificadas para a continuação

| Aplicativo original | Fonte | Dependências para paridade |
| --- | --- | --- |
| PORTAL_RH.EXE | 09-telas, 10-carreira-e-dias, 11-carreira-salva | Estado da carreira, dificuldade, expediente, tarefas, progressão e salvamento |
| Calendário | 40-eventos | Data da carreira, ciclo de 20 dias úteis, missões opcionais, assinatura, recompensas |
| Arquivo | 40-eventos | Missões, coleção de broches, personalizações desbloqueadas e conquistas |
| MSworkN | 43-social-motor a 48-social-inicio | Elenco, presença, afinidade, diálogos e escolhas, chamadas, eventos do expediente |
| Perfil | 29-perfil, 33-avatar, 34-foto | Nome, avatar, foto, identificação, cargo e broches |
| Personalizar | 30-personalizar, 38-cursor | Wallpapers, cores de janelas/barra/crachá, ponteiro, desbloqueios |
| Catálogo | módulos de catálogo em shared | Inventário, compras, dinheiro e decoração |

O aplicativo chamado `paint` no código original abre Personalizar; não é um editor de desenho. O Arquivo contém conquistas e missões; não é um explorador de arquivos. Essas distinções devem ser preservadas no porte.

As imagens originais foram preservadas. Os scripts web serviram como referência de organização e comportamento; a execução utiliza controles nativos do Godot.

## Revisão no jogo

Esta continuação corrigiu um erro de sintaxe encontrado no log de importação anterior e ajustou controles de janela, popups e liberação do mouse ao sair. Não foi executada uma nova sessão de testes nesta continuação. Ao revisar no jogo, conferir abertura das janelas, digitação, arraste, minimizar/restaurar, seleção de wallpaper e retorno à cadeira.
