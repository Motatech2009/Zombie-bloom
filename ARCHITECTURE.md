# Arquitetura

## Cenas

`MainMenu.tscn` abre a aplicação e carrega `GameWorld.tscn`. A partida instancia `Player.tscn`, `BaseCore.tscn` e `HUD.tscn`. WaveManager instancia as três cenas de zumbi. BuildManager instancia barricada e torreta. Inimigos e construções recebem Resources pelo editor.

Geometria e controles de UI são montados no `_ready()`. Os `.tscn` são pontos de entrada editáveis; os modelos são gerados por código, sem assets binários externos.

## Responsabilidades

| Módulo | Responsabilidade |
| --- | --- |
| `core/game_spec.gd`, `resources/**/*.tres` | Configurações reutilizáveis |
| `core/catalog.gd` | Catálogo, ondas e seis upgrades |
| `core/health.gd` | Dano, cura e morte única |
| `core/visual_factory.gd` | Geometria, materiais compartilhados e animação |
| `core/controls.gd` | InputMap em runtime |
| `core/game_settings.gd` | Volume/sombras em `user://settings.cfg` |
| `entities/player.gd` | Movimento, mira e bônus |
| `entities/zombie.gd` | Busca, movimento, ataque e morte |
| `entities/building.gd` | Vida, reparo, núcleo e tiro da torreta |
| `entities/pickup.gd` | Atração e coleta única |
| `systems/game_world.gd` | Composição, preparação/combate/desfecho |
| `systems/weapon_system.gd` | Raycasts, cadência, munição e recarga |
| `systems/wave_manager.gd` | Spawn, contagem e conclusão das ondas |
| `systems/resource_manager.gd` | Carteira, XP e níveis pendentes |
| `systems/upgrade_manager.gd` | Ofertas e alterações reais |
| `systems/build_manager.gd` | Prévia, custo, validação e instalação |
| `systems/arena.gd` | Cenário, colisões e navegação |
| `systems/effects.gd`, `game_audio.gd` | Feedback limitado, cache e síntese |
| `ui/hud.gd`, `ui_kit.gd` | HUD, menus e tema |

## Dano e colisões

Entidades expõem `take_damage(amount)` e delegam ao componente Health. Vida nunca negativa; cura não ressuscita; sinal de morte único. Jogador aplica absorção e 0,35 s de invulnerabilidade antes de encaminhar dano.

| Camada | Valor | Conteúdo |
| --- | --- | --- |
| Terreno | 1 | Piso, veículos, muros |
| Jogador | 2 | Sobrevivente |
| Inimigos | 4 | Zumbis vivos |
| Estruturas | 8 | Núcleo e defesas |

Raycasts usam 1 + 4 + 8 e excluem o emissor. Jogador colide com 1 + 8; inimigos com 1 + 2 + 8. A IA ataca estruturas danificáveis encontradas em colisões de move_and_slide().

## Estados e pausa

GameWorld.phase: `prep`, `combat`, `ended`. HUD usa PROCESS_MODE_ALWAYS; o resto acompanha a pausa da árvore. Escolhas de evolução não podem ser canceladas. A oferta é consumida antes da aplicação; a próxima é criada em chamada diferida para impedir duplo clique. Resultados descartam escolhas pendentes. Reinício recarrega a cena.

Relógio de sobrevivência conta preparação e combate ativos; pausas e escolhas não contam. Configurações persistem, partidas não.

## Desempenho

Navegação recalculada a cada 0,5–0,85 s, distribuída entre inimigos. Materiais reutilizados. Limites de 55 inimigos vivos, 24 defesas, 80 efeitos e oito vozes de áudio. As cinco ondas somam 127 inimigos. Objetos transitórios são liberados; sem pooling prematuro. FPS e requisitos mínimos não foram medidos em hardware de destino.

## Mundo de exploração

A arquitetura nova, a persistência e os parâmetros provisórios estão descritos em [WORLD_IMPLEMENTATION.md](WORLD_IMPLEMENTATION.md). A cena de entrada desse modo é `scenes/world/FrontierWorld.tscn`.

## Beta 1 atual

A campanha entra por `scenes/beta/BetaWorld.tscn`. Os serviços e contratos da arquitetura atual estão em [BETA_1.md](BETA_1.md). O código dos marcos anteriores permanece como base/revisão de regressão, sem disponibilizar as ondas e torretas antigas na campanha.
