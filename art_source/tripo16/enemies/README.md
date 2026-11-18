# Infectados e bosses enviados pelo criador — RC9

Os originais permanecem nos arquivos bosses.glb e zombies.glb, identificados em sources.json. Não entram nos pacotes. Preparar no Godot 4.6.3 com tools/art/prepare_tripo16_models.gd, budgets 200000/220000 e texture_size 2048; os LODs escolhidos possuem 121039 e 121185 triângulos. Rodar analyze_enemy_components16.py nos dois GLBs preparados para gerar .components.json e .components.bin. Copiar build.json para a pasta de preparo e executar build_enemies16.gd passando essa pasta. O mapa de componentes está vinculado aos hashes preparados.

O builder cria recursos compactos com skin e controles locais: 15 ossos humanoides, sete nos quadrúpedes e cinco nos voadores. clay_enemy16.gd conecta os controles de animação do jogo aos ossos; enemy_models16.gd seleciona os modelos. Os atlases são compartilhados por kit. Preservar mipmaps, compressão VRAM e limite 2048 nas configurações .import.

Oito bosses estão separados. O kit comum possui 19 componentes, incluindo o Colosso antigo. Não há Parasita separado; sua forma pequena reutiliza a malha do cão, como adaptação explícita, e sua transformação utiliza o Bruto novo. O Colosso antigo não substitui a rotação atual dos sete bosses.

O corpo anatômico do Titã tem 1,9 unidades antes da escala existente; os galhos chegam a 2,5. O marcador do coração permanece em y=1,22 e recebe profundidade calculada da superfície do peito. Colisões, dano e habilidades não dependem das malhas.

Validação: enemy16_models_tests.gd desktop/touch; release16_content_tests.gd; rc8_combat_events_tests.gd; exported_models_smoke.gd no pacote. render_enemy_references16.gd -- --overview gera galerias reais; omitir --overview gera três vistas por criatura.
