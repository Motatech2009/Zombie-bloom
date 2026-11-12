# Último Refúgio — primeiro trecho jogável do mundo

Referência: compêndio WORLD-001 a WORLD-008 fornecido pelo autor, versão consolidada de 11/11/2026. O documento distingue decisões aprovadas de hipóteses. Esta implementação é um protótipo funcional das bases técnicas e do ciclo de exploração; não representa a entrega integral de todos os sistemas descritos.

## Como testar

Abra `project.godot` na Godot 4.6.3 e execute. O menu oferece **Explorar o mundo**, **Continuar refúgio** quando existe um salvamento e o **Desafio de cinco hordas** original. Em Configurações, altere a seed para uma nova expedição; continuar sempre recupera a seed do arquivo salvo.

No modo de exploração:

| Controle | Ação |
| --- | --- |
| WASD / Shift | Deslocamento com mira independente / correr |
| Mouse / clique / R / 1–3 | Mirar / atirar / recarregar / trocar arma |
| Segurar F junto a recurso | Extrair 3 unidades a cada 1,6 s, até esgotar o recurso ou a mochila |
| F junto a porta | Entrar, sair ou alternar porta interna |
| F a menos de 5 m do núcleo | Depositar madeira, pedra e metal como sucata reaproveitável, na proporção provisória de 1:1 |
| B / 1–2 / clique | Construir barricada ou torreta na área de 48 × 48 m do refúgio |
| E junto a estrutura | Reparar entre hordas, gastando sucata |
| U junto a estrutura | Comprar até três melhorias de resistência, +75 de vida máxima por nível; custos 40, 80 e 120 |
| Espaço no refúgio | Iniciar a próxima horda; este modo não encerra após a quinta |
| M / Esc / Tab | Mapa regional / pausa / equipamentos |
| F5 | Salvar no refúgio, entre hordas e sem hostis a menos de 20 m |
| F9 | Restaurar um salvamento válido fora de interiores e de combate |

O teste inicial mais curto é sair para leste, encontrar a árvore em (20, 9), segurar F e retornar ao núcleo com a carga. Ao norte/leste há uma casa abandonada em (30, -21), com entrada pela face norte. Use o mapa para localizar cidade, vila, fazenda, pátio industrial e ponte.

## Correspondência com WORLD-001 a WORLD-008

| Decisão | Protótipo implementado | Limite atual |
| --- | --- | --- |
| WORLD-001: território contínuo por setores | Chão e objetos carregados ao redor do personagem; retirada dos setores distantes | Processamento no thread principal, com um setor da borda por frame; ainda requer perfil de desempenho no hardware alvo |
| WORLD-002: procedural e reproduzível | Ruído ambiental, recursos, larguras/cores dos edifícios e divisões internas derivados de seed e IDs estáveis | Rede principal e centros dos assentamentos são uma composição inicial fixa. Geografia urbana totalmente procedural ainda não foi implementada |
| WORLD-003: grandes regiões | Região inicial Vale do Cedro, com classificações de regiões adjacentes e setores independentes | As regiões adjacentes ainda não possuem catálogos próprios de assentamentos; não é um sistema completo de expansão territorial |
| WORLD-004: limites orgânicos | Classificação regional modulada por ruído; rio contínuo em coordenadas globais; estradas e travessias | O rio é uma curva procedural simplificada. Não há simulação de drenagem, relevo ou segmentação geográfica completa |
| WORLD-005: rural temperado | Campo, floresta, faixa ribeirinha e zona agrícola com árvores, rochas e recursos | Superfície caminhável plana; colinas, vales e relevo físico ficam para a próxima etapa |
| WORLD-006: ocupação mista | Cidade com 16 lotes, vila com 4, fazenda com 4, pátio produtivo com 4 e casa inicial; ruas e caminhos de entrada | Catálogo low-poly de protótipo, com seis funções de edifício e variação limitada de fachadas |
| WORLD-007: interiores separados | Cena Interior.tscn instanciada com estado por edifício, recipientes e três portas internas | Dois tipos de mobiliário: residencial e produtivo/comercial. Sem simulação externa simultânea durante a visita |
| WORLD-008: apenas térreo | Quatro cômodos conectados, mobiliário sólido, portas com colisão, paredes dianteiras baixas e sem telhado interior | Estados de porta apenas aberta/fechada. Janelas apenas visuais intactas; sem trancas, destruição ou visão do exterior |

## Parâmetros provisórios

- Gerador versão 1; setores de 64 × 64 m; anel de 3 × 3 setores e setor do refúgio mantido carregado. Máximo de dez setores residentes.
- Anel inicial de 192 × 192 m; navegação local em células de 2 m, reconstruída quando muda o conteúdo carregado. O setor que contém o jogador é criado imediatamente; os demais entram gradualmente.
- Câmera ortográfica centralizada no jogador; comportamento escolhido para o teste de mundo extenso. Fachadas e telhados próximos tornam-se translúcidos para não ocultar o jogador; colisões permanecem ativas.
- Mochila com 45 unidades. Os tipos de material são registrados durante a viagem e convertidos no depósito para reutilizar a economia de construção já existente. Receitas de materiais separados ainda não existem.
- Hostis errantes aparecem fora do refúgio, com limite de população e remoção por distância; não há persistência individual desses inimigos.
- Hordas da base continuam manuais. Curva, calendário de ataques, dia/noite, fome, sede e resgate não fazem parte deste trecho.
- A entrada em interiores exige ausência de hostis próximos e não é permitida durante hordas. O exterior fica congelado e invisível durante a visita. Isso não é simulação persistente de ataques fora da tela.

## Persistência e compatibilidade

`user://ultimo_refugio_v1.json` guarda formato e versão do gerador, seed, recursos retirados, portas internas, recipientes esvaziados, setores carregados anteriormente, carga, posição no refúgio, banco de sucata, XP, melhorias do jogador, estado do núcleo e defesas colocadas/melhoradas. O estado de alterações é aplicado quando cada setor ou interior é recriado; não depende da ordem da visita.

A gravação usa um temporário e mantém uma cópia `.bak` do arquivo anterior. Leitura incompatível ou inválida é recusada, sem substituir a expedição em andamento. A cópia de segurança não é restaurada automaticamente. O salvamento é manual; sair ao menu sem salvar descarta o progresso desde o último checkpoint. Bônus temporários e inimigos não são restaurados.

A versão do gerador é parte do contrato do arquivo. Alterações futuras de coordenadas, IDs e geração exigem migração explícita ou nova versão. O protótipo não promete compatibilidade automática com geradores futuros.

## Arquitetura

- `WorldGenerator`: dados puros, seed, descritores de setores, regiões, estradas, lotes e plantas.
- `WorldState`: alterações persistentes, carga e leitura/gravação versionada.
- `StreamedRegion`: geometria, colisões, carregamento de setores e navegação local.
- `WorldHouse` / `WorldInteraction`: fachada, entrada, recursos, portas e recipientes.
- `InteriorRoom`: quatro módulos térreos com circulação e mobiliário.
- `FrontierWorld`: conecta exploração, depósito, interiores, inimigos, defesas e checkpoint.
- `FrontierWaves` / `frontier_hud.gd` / `WorldMap`: hordas sem fim obrigatório e interface de expedição.

O modo clássico usa suas cenas originais. A implementação nova reutiliza combate, recursos, construção, áudio e progressão, sem trocar a semântica do desafio antigo.

## Validação reproduzível

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/world_tests.gd
```

Para revisão gráfica, o auxiliar abaixo abre cenas reais do jogo em pontos fixos, sem adicionar teleporte aos controles normais:

```sh
godot --path . --script res://tests/preview_world.gd -- --zone=interior
godot --path . --script res://tests/preview_world.gd -- --zone=city
godot --path . --script res://tests/preview_world.gd -- --zone=bridge
```

A suíte de mundo verifica determinismo e independência da ordem de visita, IDs únicos, lotes e acessos, capacidade e conservação de recursos, emendas físicas do chão, streaming, persistência ao recriar setores/interiores, circulação derivada das colisões reais, melhorias e defesas salvas, rejeição de arquivos inválidos, mapa/pausa e continuação além da quinta horda. Testes headless não certificam fluidez, memória ou qualidade visual no PC do jogador.
