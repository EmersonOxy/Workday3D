# Integração do WorkOS no monitor 3D

Análise do repositório [EmersonOxy/Workday](https://github.com/EmersonOxy/Workday), branch `main`, em 05/11/2026. Esta etapa documenta a integração; o WorkOS ainda não foi instalado ou portado para este projeto.

## O que já existe no Workday

- [src/index.html](https://github.com/EmersonOxy/Workday/blob/main/src/index.html): estrutura de `#app`, `#osdesk`, barra de tarefas e `#modal`.
- [src/js/09-telas.js](https://github.com/EmersonOxy/Workday/blob/main/src/js/09-telas.js): janelas (`osWindow`), arraste, foco, minimizar/restaurar, menu Iniciar e apps como calculadora, notas e música. Há dependências de funções e estado globais do jogo; não é um componente isolado.
- [src/js/27-escritorio.js](https://github.com/EmersonOxy/Workday/blob/main/src/js/27-escritorio.js): posiciona o HTML sobre o monitor do escritório 2D. O modo `CFG.focus` já esconde os canvases do escritório e expande `#app` para toda a janela. É um ponto útil para uma versão embutida, mas não remove sozinho as dependências do restante do jogo.
- [src/css/99-workos-materials.css](https://github.com/EmersonOxy/Workday/blob/main/src/css/99-workos-materials.css) e `80-entrega3.css`: aparência das janelas, molduras, barra de tarefas e botões.
- [assets/ui/workos](https://github.com/EmersonOxy/Workday/tree/main/assets/ui/workos): PNGs reutilizáveis da interface. `assets/workos` contém papéis de parede. A fonte VT323 é distribuída em WOFF2; para UI nativa, obter a versão TTF/OTF e manter a licença da fonte.
- [src/js/03-persistencia.js](https://github.com/EmersonOxy/Workday/blob/main/src/js/03-persistencia.js): persistência em `localStorage`. [tools/build.py](https://github.com/EmersonOxy/Workday/blob/main/tools/build.py) gera HTML web e uma versão offline com recursos embutidos.

## Opção recomendada para Godot Standard + Compatibility

Portar a interface para uma cena `workos_desktop.tscn` com raiz `Control`, instanciada dentro do `DesktopSubViewport` existente. Reutilizar os PNGs e papéis de parede originais. Converter molduras CSS para `StyleBoxTexture`/`NinePatchRect`; ícones e botões para `TextureRect`/`TextureButton`; janelas para painéis `Control` internos ao viewport, evitando janelas nativas fora do monitor.

O caminho continua: `Control WorkOS → SubViewport → ViewportTexture → material do monitor 3D`. O SubViewport renderiza nós Godot e fornece uma textura; não interpreta HTML/CSS/JavaScript. Portanto, copiar o HTML diretamente para ele não funciona. [Documentação do SubViewport](https://docs.godotengine.org/en/stable/classes/class_subviewport.html).

Proposta em etapas:

1. Área de trabalho fiel: wallpaper, ícones, barra de tarefas, relógio e menu Iniciar, substituindo os três botões de demonstração.
2. Gerenciador de janelas em GDScript: arrastar, trazer à frente, minimizar, restaurar e maximizar dentro da tela do monitor.
3. Portar calculadora, notas e configurações; depois calendário, música, mensageiro e apps ligados ao expediente. Reutilizar os desenhos não reaproveita automaticamente a lógica JavaScript.
4. Separar o estado do WorkOS do cenário 3D. Um controlador emite sinais como `app_opened`, `task_started` e `shutdown_requested`; o cenário responde sem depender dos nós internos das janelas. Persistir em `user://` com JSON/ConfigFile; saves do navegador exigem importação explícita.

Antes de portar apps, ampliar o encaminhamento de entrada: mouse pressionado e solto separados, arraste com botões mantidos, movimento relativo, roda, teclado, caracteres e foco dos campos. O código atual gera um clique completo imediatamente e só atende os botões de demonstração. Ele não basta para arrastar janelas ou digitar nas notas. Definir também a prioridade de Esc entre fechar um menu e sair do monitor.

Manter renderização 1280×720 e adaptar o layout do WorkOS a esse tamanho. Validar texto, recortes, maximização, cliques nas bordas, captura do mouse e retorno da câmera. A nova distância de foco é calculada pelo FOV e proporção da janela para preencher 94% da dimensão limitante.

## Alternativa para reaproveitar HTML e JavaScript

Embutir Chromium por uma GDExtension com renderização fora de janela e exibir sua textura em um `TextureRect` dentro do SubViewport. O build offline do Workday pode servir de base, com um modo dedicado de incorporação que expande `#app`, desativa o escritório 2D e mantém apenas os serviços exigidos pelo WorkOS. Criar uma ponte explícita JavaScript ↔ GDScript para eventos do jogo e salvamento.

Essa alternativa preserva mais lógica existente, mas adiciona o runtime Chromium, processos e consumo de memória. Antes de escolhê-la, fazer uma prova pequena com Godot 4.7.2, Windows e Compatibility/ANGLE neste computador. A matriz do [Godot CEF](https://godotcef.org/api/compatibility-matrix) exige Godot 4.6+ e lista aceleração Windows por D3D12/Vulkan; não lista OpenGL Compatibility entre os backends acelerados. Não pressupor aceleração ou desempenho adequado neste renderer. A biblioteca documenta modo de software, que precisaria ser validado na prova.

Para manter o projeto leve e centrado em GDScript, recomendo a UI nativa. Se a prioridade for conservar imediatamente os apps e a lógica web completos, a prova com navegador embutido deve vir antes da migração. Nenhuma biblioteca de navegador foi adicionada nesta etapa.
