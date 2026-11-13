# Arquitetura atual — Setores 0.6

Menu → scenes/sectors/RoamingWorld.tscn. RoamingWorld deriva CampaignWorld e substitui serviços por factories de script, preservando os modos anteriores para regressão. SectorGenerator gera descritores por seed/coordenada/visita; SectorArena compõe piso, obstáculos e navegação. RoamingWaves administra preparação, alertas, spawn automático, chefe e contagens de horda separadas da população de exploração. RoamingHUD adiciona mapa sem pausa, coordenadas e direção ao Núcleo.

Base permanece no SceneTree em (0,0); o setor ativo é uma segunda raiz em coordenada × 120 m, enquanto seus pisos têm 110 m. Transições descartam apenas a raiz exploratória. Inimigos recebem rotas da arena correta, convertidas para coordenadas globais; drops e hazards também têm identidade de região. Perigos do Núcleo continuam ativos ao retornar e a conclusão de um cerco só limpa os perigos da base. Até 36 inimigos de cerco e 24 de setor, no máximo 60.

Núcleo, defesas e combate distante usam física real, não simulação agregada. Os demais setores não são residentes nem persistem layout: histórico guarda visitas/último risco. Snapshot 3 salva relógio e estado RNG em string, preservando os 64 bits; migração de 1/2 produz cópia. Salvar exige preparação na base. Helpers de revisão não escrevem arquivos do jogador.

Regras em WORLD_SECTORS.md e CAMPAIGN.md. Quatro suítes e evidências em docs/ e TEST_REPORT.md. As seções abaixo descrevem versões históricas.

---

# Arquitetura atual — Defesa 0.5

A composição segue `CampaignWorld`. `next_mode` escolhe campanha ou infinito; `game_mode` e a versão 2 dos snapshots isolam os arquivos. A migração do save 0.4 produz cópia validada. O menu consulta caminhos leves e só carrega os serviços da campanha ao entrar, evitando reter dependências desnecessárias.

`defense_arena.gd` amplia piso, bordas e AStar para 110 m; `campaign_arena.gd` deriva as áreas. `campaign_build.gd` mantém materiais e uma grade persistente, invalidados por `layout_revision` ao construir, destruir, desmontar ou restaurar. A prévia não consulta caminho; o commit valida fisicamente e aplica/reverte apenas células candidatas antes de debitar.

`campaign_weapons.gd` estende o contrato de WeaponSystem para cinco slots e recarga finita do lançador. `campaign_projectile.gd` contém arco/voo/colisão, `acid_pool.gd` contém a duração/ticks de corrosão. Áreas e mudança de fase removem perigos transitórios. `campaign_enemy.gd` separa perseguição humana, cão, voador e atirador; mantém a colisão aérea real e altura de mira. O HUD compacto atualiza informação a 10 Hz; mira permanece por quadro.

Balanceamento e regras atuais em [CAMPAIGN.md](CAMPAIGN.md). Evidência da construção em `docs/build-performance.json` e três suítes headless. Relatórios antigos abaixo são históricos.

---

# Arquitetura atual — campanha 0.4

O menu carrega `scenes/campaign/CampaignWorld.tscn`. O código de `scripts/campaign/` estende os componentes do MVP e preserva seu cenário e linguagem visual. `campaign_data.gd` centraliza áreas, oito hordas, peças/custos e novas variantes. `campaign_world.gd` compõe serviços, transações, viagens e checkpoints; `campaign_waves.gd` administra as hordas; `campaign_structure.gd` implementa seis peças e níveis; `campaign_build.gd` valida espaço, acesso e clique; `campaign_enemy.gd` adapta percepção de alvo e blindagem; `campaign_arena.gd` gera cada área; `campaign_hud.gd` apresenta suas ações.

As alterações compartilhadas no MVP são a lista de armas possuídas em WeaponSystem (padrão mantém as três para regressão), novas ações em Controls e a nova rota no menu. A cena original continua testável separadamente.

Duas raízes alternam a presença no SceneTree: base persistida em memória e expedição recriada de descritor/estado finito. Jogador, câmera, recursos e HUD pertencem à campanha. Ao encerrar na expedição, a base destacada é liberada explicitamente. Estado de campanha e layout detalhados em [CAMPAIGN.md](CAMPAIGN.md).

---

## Arquitetura histórica do MVP

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


## Sobrevivência 0.7

`SurvivalWorld` estende o mundo procedural e injeta fábricas de jogador, arma, construção, ondas e HUD. `ItemBag` mantém 18 espaços com validação e operações conservativas. Coleta por canalização e transações de depósito são autoritativas; construção consulta apenas estoque do Núcleo e cota compartilhada. Saves v4 estendem a validação/migração v3.

`Coop` é singleton ENet (até três convidados), com RPC de comandos confiáveis, input em canal separado e snapshots de estado a 10 Hz. Servidor valida remetente, tipos, finitude, frequência, proximidade, fase, saldo e capacidade; cliente renderiza proxies e transmite intenção. Descritor de cenário via RPC confiável por revisão; snapshots incompatíveis são descartados até a cena correta chegar. O grupo ocupa uma única região procedural e mantém a base física. Perfis individuais são persistidos pelo anfitrião com identidade local de reconexão; não há autenticação central ou migração de host.

`SurvivalEnemy` acrescenta três variantes e poderes com aviso, proteção temporária e fúria. Avisos são incluídos na replicação de hazards. `enemy_bar.gd` projeta a posição 3D em controles do HUD para manter tamanho legível em pixels; libera os controles ao sair da árvore e mantém os modais acima das barras.


## Arsenal/visual 0.8

`Arsenal` centraliza os nove specs, preços e pacotes; a campanha anterior continua usando seus cinco specs para regressão. `ItemBag` amplia IDs e munições, mantendo índices anteriores. `SurvivalWeapons` especializa sniper perfurante e corrente Tesla com consultas físicas; os outros modelos reutilizam o contrato de disparo/recarga. O save v5 expande arrays e perfis v4; o validador herdado recebe uma ponte de cinco armas somente para validar mundo/base, enquanto posse/munição reais são validadas separadamente.

`ModelFactory` gera cenas editáveis que o runtime instancia para armas, itens e humanoides. `ItemIcons` mantém texturas SVG em cache; `ItemSlot` evita reconstrução da barra/inventário por quadro. O HUD mantém os campos usados pelos diretores anteriores, com apresentação própria. Novos infectados usam telegráficos, investida física, status de lentidão e interrupção temporária de torretas. Snapshots incluem esses estados e o item segurado; RPC visual de tiros vem apenas do anfitrião.
