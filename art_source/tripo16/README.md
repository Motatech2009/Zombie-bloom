# Zombie Bloom — modelos Tripo 1.6 RC6

Originais fornecidos pelo criador. Nenhuma chamada paga de geração foi feita nesta preparação.

O Núcleo usa a primeira versão (texturas originais 4K) reduzida para 15.468 triângulos nos quatro níveis. A versão 8K foi comparada visualmente e preservada como referência. Tesla, elevada e canhão usam três níveis independentes. `assets/defenses/tripo16-geometry.json` registra a geometria final, incluindo os triângulos acrescentados ao separar as juntas.

Os 19 acessórios físicos usam `assets/cosmetics/tripo16/`: 12.781 triângulos no conjunto e um único atlas de 2048², com margem extrudada entre os mapas. Os três efeitos do catálogo continuam procedurais. A coroa usa o modelo enviado e mantém o desbloqueio exclusivo do Titã.

## Reconstrução offline

Coloque os originais em `art_source/tripo16/incoming/` com os nomes de `prepare.json`; use `cannon_original.glb` para o arquivo Canhao.glb. Coloque também `cosmeticos.glb`. Os hashes estão em `sources.json`. Com Godot 4.6.3:

```text
godot --headless --path . --script res://tools/art/prepare_tripo16_models.gd -- --config=res://art_source/tripo16/prepare.json
godot --headless --path . --script res://tools/art/build_tripo16_models.gd -- --config=res://art_source/tripo16/build.json
godot --headless --path . --script res://tools/art/build_tripo16_cosmetics.gd -- --source=res://art_source/tripo16/incoming/cosmeticos.glb --plan=res://art_source/tripo16/cosmetics.json
godot --headless --path . --editor --quit
```

Preserve os arquivos `.import` versionados: texturas com mipmaps, compressão VRAM para desktop/Android e limites de 1024² nas defesas e 2048² no atlas de cosméticos. Os originais e intermediários ficam fora do controle de versão e dos pacotes de jogo.

As plataformas e bases não giram. A elevada articula os canos na saída da carcaça; o canhão articula a montagem superior. Marcadores independentes alternam os dois canos sem multiplicar dano. A Tesla emite a partir do topo da bobina. Geometria, vida, preços e capacidade de inventário continuam separados.
