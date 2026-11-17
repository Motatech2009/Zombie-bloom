# Zombie Bloom 1.6 — controle de implementação

Estado: candidata **1.6.0-rc.1**, implementação integrada em validação; **não é lançamento final da 1.6**. Base de código: `0b8856c`, equivalente à árvore da revisão remota `90c3c50` da 1.5. A versão distribuída permanece separada desta branch.

Fonte do escopo: [handoff original](docs/design/GAMEPLAY_HANDOFF_ZOMBIE_BLOOM_1_6.txt). Seus nomes, preços, talentos e novo modo marcados como proposta continuam propostas. Este registro não significa aprovação criativa nem autorização de promoção.

## Etapa A — evoluções individuais

Implementação de ZB-UP-01:

- Cada perfil conectado recebe uma escolha de três cartas por horda concluída, inclusive se estiver derrubado. A escolha beneficia exclusivamente seu personagem.
- Recompensa identificada por `account_run_id:horde:profile_id`. O anfitrião associa o comando ao avatar do remetente. Não aceita escolha sem ID, ID de outro jogador, opção fora da oferta ou comando repetido após consumo.
- Perfil estável de partida: identidade de instalação já usada pelo cooperativo; nunca nickname nem número temporário de conexão. Não é alegado que essa identidade seja UID Firebase verificado. A integração de identidade/conta e validação econômica pertence às etapas seguintes.
- Cada perfil tem níveis próprios, fila de escolhas, horda já contemplada e opção de adiar. Quem adia conserva as cartas no painel BASE/REFÚGIO; a pausa coletiva termina quando todos os conectados escolhem ou adiam. Um perfil desconectado conserva a fila sem manter os aliados em pausa.
- Os snapshots enviam somente a oferta, níveis e estado do destinatário, além do estado global de pausa. Não enviam as ofertas dos aliados.
- Reconexão com a mesma identidade recupera a fila, mesmo com outro peer/nickname. Uma identidade nova não herda melhorias do anfitrião nem cartas de hordas anteriores.
- Coleta, Engenharia, economia de munição, atributos das armas, vida e movimento consultam o progresso de quem executa a ação.
- Cartas mostram ícone, categoria, nível atual/próximo, teto, efeito cumulativo atual/próximo e cor da classe. Mobile usa rolagem vertical.
- Tetos universais preservados: 2/7/12, nas faixas 1–5/6–10/11+. Catálogo esgotado não bloqueia a partida.

### Divergência descoberta e decisão do criador

A documentação 1.5 descrevia evolução por horda, mas o código real usava XP de saque/abates para criar escolhas compartilhadas. O criador escolheu explicitamente **uma carta por horda**. XP e nível histórico permanecem nos dados; XP deixa de gerar cartas. Melhorias já conquistadas não são removidas. O HUD da sobrevivência passa a mostrar evolução/cartas, sem sugerir que o próximo nível de XP dê uma carta.

### Saves e rede

Formato 6 preservado com extensão opcional validada `progression16` (schema 1). Saves anteriores sem a extensão migram os bônus compartilhados para cada perfil já registrado; hordas antigas viram linha de base, sem recompensas retroativas. Novos perfis começam sem os bônus alheios. Fila, IDs, níveis, adiamento e horda contemplada entram no snapshot. Ofertas da primeira pendência são reconstruídas deterministicamente na recuperação, usando o catálogo válido.

O checkpoint da base aceita cartas pendentes. Escolha ou adiamento concluído no refúgio tenta atualizar o checkpoint existente, respeitando a habilitação de salvamento. A regra geral de salvar campanha entre hordas no refúgio continua; não há backup integral de partida na nuvem nem recuperação de qualquer instante de exploração.

A etapa A mudou o protocolo de 17 para 18; a integração completa usa **19**, pois o significado das escolhas e o conteúdo dos snapshots mudaram. Clientes incompatíveis recebem rejeição explícita. Não misturar cliente desta branch com binário 1.5 em sessões reais.

## Rastreamento do restante do escopo

| Entrega | Estado |
|---|---|
| ZB-UP-01 — escolhas individuais | Implementada nesta etapa, com testes automatizados |
| ZB-UX-01 — menu/abas do ranking | Implementado: cartão de conta, perfil, atalhos, abas de elos/recompensas, fluxo criar/entrar |
| ZB-AUTH-01 — simplificação do login | Implementado: estado autenticado simplificado e confirmação de logout; persistência preservada |
| ZB-PROFILE-01 — horas ativas | Implementado: relógio monotônico, AFK, foco, fila por UID e agregação de servidor |
| ZB-CLASS-01 — nove talentos | Nove talentos implementados e parametrizados; bônus iniciais preservados |
| ZB-ECO-01 — moeda por horda | Implementado e validado em emuladores; publicação/validação real pendentes |
| ZB-COS-01 — loja e 21 cosméticos | Implementados: prévia 3D isolada, filtros, confirmação, slots, compra/equipamento remoto |
| ZB-BAG-01 — bolsas funcionais | Implementadas: 18/20 → 21/23 → 24/26; redução bloqueada com espaços ocupados |
| ZB-EXP-01 — posto em 10% dos setores novos | Implementado: três comerciantes, perímetro, relógio ativo, estoque persistente |
| ZB-TITAN-01 — boss em 5%, 20.000 PV | Implementado: telegráfos, raízes, coração exposto, fúria própria, HP/loot persistentes |
| ZB-MODE-01 — novo modo | Resgate implementado com três hordas formais e save de campanha isolado |
| ZB-TEST-01 — validação integral da 1.6 | Suítes ampliadas, emuladores e renderizações reais; builds/serviço real/aparelhos ainda são gates |

## Validação desta etapa

- `tests/release16_progression_tests.gd`: separação de quatro perfis, XP sem novas cartas, duplicação, IDs incorretos, reconexão, saves, migração, tetos e consultas individuais.
- `tests/release16_ui_tests.gd`: layout e ações em configurações desktop/mobile. São testes de layout headless, não prova de renderização em aparelho físico.
- `tests/run_release16_coop_test.py --players 2/3/4`: processos Godot/ENet reais, participantes em setores distintos, escolhas privadas, confirmações e replay de RPC.
- Regressões existentes de combate, inventário, base, celular, exploração, classes 1.5, contas e cooperativo; movimento previsto e exploração em regiões separadas.
- CI recebe os testes da etapa A. Não houve gravação de teste em produção. Serviço novo e regras foram preparados e testados em emuladores; publicação real exige autenticação administrativa.

**Antes da promoção:** concluir restante do handoff, aprovar conteúdo criativo, validar economia em serviço confiável, exportar os binários candidatos e jogar em Windows/Android reais. Aprovação em testes automatizados não equivale a aprovação da atualização completa.

## Integração das etapas B–F

- `data/release16/catalog.json`: moeda, nove talentos e 21 cosméticos, preços e parâmetros de exploração. Nomes/artes/valores de proposta são defaults configuráveis da candidata, sem atribuir aprovação criativa não dada.
- `account_meta16.gd` / `play_clock16.gd`: horas locais por conta, sessão, recorde, exclusão de menus/pausa/segundo plano/AFK; lotes, troca de identidade, fila e saldo confirmado. Não há gravação por segundo nem consulta de banco em menu ocioso depois de carregar perfil.
- Backend em `backend/firebase/functions`: ID token, transações, deduplicação, relógio e limites de servidor. Guia e limites em `backend/firebase/README_1_6.md`. Não equivale a antitrapaça independente.
- Cosméticos têm representação nativa em massinha, somente visual; prévia em mundo 3D isolado, rotação e partículas limitadas/desativadas no mobile. Slots de elo são preservados; visual comprado sobrepõe o slot escolhido, sem revogar a conquista.
- Talentos e melhorias são individuais. Liga Reforçada marca a maior melhoria da estrutura sem empilhamento infinito; fusão mantém o maior bônus. Bolsa funcional não depende do visual da conta.
- Sorteio especial usa uma decisão por coordenada: 5% Titã / 10% posto / 85% normal. Somente o normal recebe os eventos 1.5 de 75%. Saves antigos marcam coordenadas já exploradas como normais, sem transformar visita histórica em descoberta nova.
- Vida do Titã normalizada pelo fator noturno e recompensa parcial sobrevivem a expiração de 180 s. O ponto fraco segue o peito e a rotação reais; mira vertical alcança o peito e impactos nos braços não recebem o bônus. Fúria própria abaixo de 25%, sem aplicar a genérica de 40%.
- Posto usa materiais carregados. A negociação não pausa nem no solo; na horda os comerciantes se abrigam. Segurança bloqueia dano recebido e ataques de saída. Não é segunda base construível.
- Resgate desativa encontros especiais/airdrop nesta tabela de modo, usa sinal em (1,1), estação em (2,1), duas defesas e extração no Núcleo. Só três hordas completas são elegíveis à moeda; buscar sinal não paga. Não salva missão intermediária nem sobrescreve campanha. Objetivo e resultado são replicados.

Evidências consolidadas: [resultados locais da candidata](docs/release16-candidate-results.txt).

## Gates restantes da candidata

1. CI da árvore final: testes, exportação Windows, APK assinado e inspeção de prévias.
2. Publicar serviço/regras no projeto real com administrador e conferir fluxo autenticado. CLI local não autenticado; não substituir isso por emulador nem declarar saldo real funcionando sem publicação.
3. Partidas físicas Windows↔Android e verificação de desempenho nos aparelhos do projeto. Linux/headless e renderização Mesa não substituem esse teste.
4. Avaliação dos defaults criativos e balanceamento pelo criador antes de promoção final. Não mesclar/publicar a RC como versão final automaticamente.
