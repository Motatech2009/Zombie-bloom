# Zombie Bloom 1.6 — controle de implementação

Estado: desenvolvimento por etapas; **não é lançamento da 1.6**. Base de código: `0b8856c`, equivalente à árvore da revisão remota `90c3c50` da 1.5. A versão distribuída permanece separada desta branch.

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

Protocolo cooperativo passa de 17 para **18**, pois o significado das escolhas e o conteúdo dos snapshots mudaram. Clientes incompatíveis recebem rejeição explícita. Não misturar cliente desta branch com binário 1.5 em sessões reais.

## Rastreamento do restante do escopo

| Entrega | Estado |
|---|---|
| ZB-UP-01 — escolhas individuais | Implementada nesta etapa, com testes automatizados |
| ZB-UX-01 — menu/abas do ranking | Pendente; ajuda atualizada apenas quanto às cartas |
| ZB-AUTH-01 — simplificação do login | Pendente; persistência 1.5 preservada |
| ZB-PROFILE-01 — horas ativas | Pendente |
| ZB-CLASS-01 — nove talentos | Proposta pendente; bônus atuais preservados |
| ZB-ECO-01 — moeda por horda | Pendente de implementação e validação remota |
| ZB-COS-01 — loja e 21 cosméticos | Proposta pendente |
| ZB-BAG-01 — bolsas funcionais | Pendente |
| ZB-EXP-01 — posto em 10% dos setores novos | Pendente |
| ZB-TITAN-01 — boss em 5%, 20.000 PV | Pendente |
| ZB-MODE-01 — novo modo | Proposta pendente |
| ZB-TEST-01 — validação integral da 1.6 | Parcial: etapa A automatizada; release integral pendente |

## Validação desta etapa

- `tests/release16_progression_tests.gd`: separação de quatro perfis, XP sem novas cartas, duplicação, IDs incorretos, reconexão, saves, migração, tetos e consultas individuais.
- `tests/release16_ui_tests.gd`: layout e ações em configurações desktop/mobile. São testes de layout headless, não prova de renderização em aparelho físico.
- `tests/run_release16_coop_test.py --players 2/3/4`: processos Godot/ENet reais, participantes em setores distintos, escolhas privadas, confirmações e replay de RPC.
- Regressões existentes de combate, inventário, base, celular, exploração, classes 1.5, contas e cooperativo; movimento previsto e exploração em regiões separadas.
- CI recebe os testes da etapa A. Nenhum novo campo Firebase foi gravado e nenhuma regra de produção foi alterada nesta etapa.

**Antes da promoção:** concluir restante do handoff, aprovar conteúdo criativo, validar economia em serviço confiável, exportar os binários candidatos e jogar em Windows/Android reais. Aprovação em testes automatizados não equivale a aprovação da atualização completa.
