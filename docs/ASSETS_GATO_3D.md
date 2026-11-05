# Gato do Workday no cenário 3D

Os dez PNGs em `assets/workday/cats/` são os sprites pixel art originais do Workday, mantidos com transparência e resolução nativa de 80 × 120 pixels. A cena `scenes/props/workday_cat_3d.tscn` mostra uma pelagem por vez e usa billboarding vertical para o gato ficar voltado ao jogador sem tombar quando a câmera olha para cima ou para baixo.

O gato é posicionado sobre o tampo a partir dos limites reais da mesa. No nó raiz `Workday3D`, `desk_cat_offset` ajusta a posição local sobre a mesa; no nó `DeskCat`, `pelagem` troca a aparência. Os arquivos originais do Workday em `.godot/workday-source/` não são modificados.
