# Personagem e objetos — RC7

Os quatro GLBs foram enviados pelo criador. Identidades, tamanhos e SHA-256 estão em sources.json. Os originais de aproximadamente 60 MB por personagem/kit não entram no pacote do jogo. VENDEDOR.glb é a **barraca**, sem um humano novo; Bento conserva seu modelo anterior e fica atrás do balcão.

O personagem original contém uma malha estática em T, sem skin, esqueleto ou animações. O preparo local cria quinze ossos com quatro influências normalizadas por vértice. Os controles antigos de recarga, caminhada, coleta e rolamento continuam dirigindo a apresentação. A empunhadura usa um cálculo de dois segmentos; mãos vazias deixam os braços abaixados.

Quatro malhas compartilhadas atendem corpo normal, roupa, capacete/capuz e roupa com capacete/capuz. Isso reduz apenas a região coberta, sem diminuir o personagem inteiro. Os IDs, preços, regras de desbloqueio, atributos e capacidades continuam no catálogo existente. As alças originais são parte da textura/malha fornecida, não novos itens funcionais.

Para reproduzir: execute tools/art/prepare_tripo16_models.gd com budgets 16000 para personagem e 10000 para carros/COMBOIO (manifestos .glb.json são obrigatórios). Execute tools/art/build_player16.gd com --input=<personagem preparado>; execute tools/art/build_actor_props16.gd com uma pasta contendo carros.glb e COMBOIO.glb preparados e VENDEDOR.glb original. O builder de objetos rejeita hashes preparados diferentes. Importe o projeto no Godot 4.6.3 depois da geração. Os originais e intermediários ficam fora de assets; somente recursos reduzidos, cenas e atlases entram em produção.

Validação: tests/player16_models_tests.gd (desktop e touch), tests/tripo16_cosmetics_tests.gd, tests/scene_transition_tests.gd e tests/exported_models_smoke.gd no pacote exportado. tests/player16_preview.gd gera vistas reais de frente e costas com mãos livres, caminhada, recarga e kits completos.
