# Editar o WorkOS no Godot

Abra as cenas no modo **2D**. As cenas abaixo são as mesmas instanciadas no SubViewport do monitor durante o jogo.

- `scenes/workos_desktop.tscn`: desktop, ícones, menu Iniciar e barra de tarefas.
- `scenes/workos/window.tscn`: moldura compartilhada, barra de título, minimizar, maximizar e fechar.
- `scenes/workos/apps/`: uma cena por aplicativo: Workday, calendário, arquivo, Messenger, perfil, backup, notas, calculadora, configurações, música e sobre.
- `scenes/workos/phases/menu.tscn`: início e encerramento de carreira.
- `scenes/workos/phases/summary.tscn`: preparação e resumo do expediente.
- `scenes/workos/phases/day.tscn`: HUD, bandejas, comandos e área de pendências.
- `scenes/workos/phases/promotion.tscn`: promoção e lista de benefícios.
- `scenes/workos/components/task_card.tscn`: título, prazo e área de ações de uma pendência.
- `scenes/workos/theme.tres`: fonte, cores e texturas compartilhadas.

Os Containers organizam seus filhos. Ajuste tamanho mínimo, expansão, separação e margens pelo Inspector; a posição dos filhos de um Container é calculada pelo Godot. Os nomes e caminhos dos nós são usados pelos scripts: preserve-os ao editar o visual, ou atualize as referências correspondentes.

Os scripts conectam os controles existentes às regras do jogo. Calendário, contatos, conversas, ações de tarefas, coleções e benefícios ainda recebem seus dados em execução. Os controles fixos desses aplicativos ficam nas cenas. A cena Workday exibe uma instância de prévia do menu no editor; o controlador troca essa prévia pela fase atual ao abrir o aplicativo.

Para conferir o funcionamento com dados e interações, execute `scenes/main.tscn`. Abrir uma cena isolada no editor permite ajustar sua composição, mas não inicia os serviços de carreira, mensagens e salvamento.

Validação da migração: carregamento dos 11 aplicativos, seis estados da carreira e maximização/restauração das janelas em Godot headless. Essa conferência não substitui a revisão visual e a interação no monitor 3D.
