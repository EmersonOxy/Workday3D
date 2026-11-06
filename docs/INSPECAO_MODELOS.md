# Inspeção dos modelos

Os arquivos originais foram preservados. A cena usa cópias byte a byte dos GLB em `assets/models/`; as pastas fonte e texturas originais também continuam no lugar.

| Modelo | Formatos disponíveis | Texturas | Esqueleto e animações |
| --- | --- | --- | --- |
| Cadeira (`office_chair`) | GLB 2.0 e fonte FBX | 12 imagens incorporadas no GLB. O pacote fonte contém albedo, AO, metallic, normal e roughness para tecido, couro, metal e plástico. | Estática, sem skin ou animação. |
| Mesa (`office_table`) | GLB 2.0 e fonte FBX | 3 imagens incorporadas no GLB. O pacote fonte oferece BaseColor, Metallic, Normal e Roughness. | Estática, sem skin ou animação. |
| Computador (`pc_setup_-_game_ready`) | GLB 2.0 e fonte FBX | 4 imagens incorporadas no GLB. O pacote contém AO, C, M, N e R, além de uma imagem com nome em cirílico. | Estático, sem skin ou animação. |
| Trabalhador (`the_character_of_an_office_worker`) | GLB 2.0; fonte FBX dentro de `OfMale.zip` | 14 imagens incorporadas no GLB; o pacote inclui texturas JPEG e PNG externas. | Um skin com 83 juntas; nenhum clip de animação incluído. A cena dobra as pernas por pose óssea estática para mantê-lo sentado. |

## Problemas encontrados e correções

- A cena anterior criava objetos somente por código ao iniciar o jogo. Por isso, o editor mostrava apenas o nó raiz. Agora as instâncias e os elementos da sala estão declarados em `scenes/main.tscn` e podem ser selecionados, movidos e redimensionados no editor.
- Os GLB da cadeira e da mesa têm transformações de escala de 100 embutidas e origens diferentes. Instanciá-los em escala 1 deixava o espaço fora de proporção. A mesa usa escala `0.01`; a cadeira usa `0.01` nos eixos horizontais e `0.008` no vertical para alinhar o assento ao tampo e ao quadril do rig. A origem da mesa foi compensada e suas pernas chegam ao chão.
- O modelo do computador inclui um plano quadrado de apresentação junto à malha da máquina. A cena oculta esse plano e mantém o gabinete sobre a mesa.
- O arquivo do trabalhador contém um rig em pose de pé e não oferece animações sentadas. O script aplica rotações aos ossos das coxas e joelhos no editor e em execução; o asset original continua intacto.
- O monitor foi montado como nós próprios da cena. O conteúdo 2D do `SubViewport` é atribuído à tela 3D e cliques no monitor encaminham entrada para os botões.
- O log de execução apontou caminhos inválidos para a câmera. A árvore atual mantém `CameraPivot` na raiz da cena, então `main.gd` usa `$CameraPivot` e `$CameraPivot/FirstPersonCamera`; isso evita o acesso a `position` em uma referência nula.
- Os GLB já contêm texturas. As pastas de origem contêm também mapas separados e FBX, e foram mantidas sem alterações.
- A câmera limita o giro horizontal a 65° para cada lado da direção inicial, mantendo o limite vertical. O foco usa um enquadramento frontal calculado pelo FOV e proporção da janela para ocupar 94% da dimensão limitante, sem cortar a interface. A interpolação de transformações usa o caminho angular mais curto; ao sair, restaura posição e orientação anteriores. Entradas na interface ficam bloqueadas durante a transição.
- O conteúdo do `SubViewport` aparece espelhado quando observado pela face usada pelo personagem. A textura da tela agora inverte o eixo U, e o encaminhamento do mouse inverte o mesmo eixo para que os botões continuem clicáveis na posição visual correta.
- O ajuste anterior dos braços girava o osso do braço inteiro como se fosse o cotovelo e levantava as mãos acima da cabeça. Agora a pose resolve os segmentos braço/antebraço a partir dos comprimentos reais do esqueleto e dos marcadores `ArmRestTargets`. Os alvos das mãos ficam em Y=0,71 m, sobre os apoios cujo topo está em aproximadamente Y=0,675 m. Os marcadores podem ser movidos no editor; a pose se atualiza sem animações. Coxas e joelhos continuam ajustáveis pelas propriedades `seated_thigh_angle` e `seated_knee_angle`. A cabeça permanece oculta pela junta `Head_06`.
- Verificação headless no Godot 4.7.2: limites laterais nos dois sentidos, enquadramento frontal idêntico após focar a partir de direções diferentes e restauração da transformação anterior passaram. As posições dos ossos confirmaram mãos nos alvos e cotovelos abaixo dos ombros. A aparência final da pose deve ser revisada no jogo. O ambiente headless emitiu um erro de acesso ao repositório de certificados do Windows, sem impedir essas verificações locais.
- Os GLB originais foram preservados. As mudanças de pose e visibilidade são feitas na instância da cena e pelo script, sem editar os arquivos-fonte.

## Material das mãos e foco ampliado — 05/11/2026

- A textura difusa original do corpo tem 2×2 pixels com tom de pele RGB (202, 138, 110). O material importado `Wolf3D_Body` aparecia preto no renderer Compatibility. A instância agora usa `assets/materials/worker_skin.tres`, com a cor difusa original, sem mapas PBR importados, metalicidade zero e maior rugosidade. Não foi necessário modificar o GLB nem suas texturas.
- O eixo local +Z das mãos foi orientado para baixo e +Y para a frente da cadeira, corrigindo o giro dos punhos sem alterar os alvos dos braços.
- O SubViewport renderiza em 1280×720 para manter o texto nítido no foco ampliado. Cliques são projetados no plano real da tela, compensando a espessura da caixa de colisão.
- Verificação com renderização real no Godot 4.7.2/Compatibility: capturas confirmaram mãos com cor de pele e palmas para baixo. A tela ocupou 94% da largura e 93,27% da altura em 1280×720. Os três botões responderam corretamente aos cliques encaminhados pelo mapeamento 3D→2D.
