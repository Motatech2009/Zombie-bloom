# Zombie Bloom 1.6 — controle de implementação

Estado: candidata **1.6.0-rc.7**, implementação integrada em validação; **não é lançamento final da 1.6**. Base de código: `0b8856c`, equivalente à árvore da revisão remota `90c3c50` da 1.5. A versão distribuída permanece separada desta branch.

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
- `account_meta16.gd` / `play_clock16.gd`: horas locais por conta, sessão, recorde, exclusão de menus/pausa/segundo plano/AFK; lotes, troca de identidade, fila e saldo confirmado. Não há gravação por segundo nem consulta de banco em menu ocioso depois de carregar perfil. Pendências antigas não bloqueiam os créditos da partida em uso.
- Backend em `backend/firebase/functions`: ID token, transações, deduplicação, relógio e limites de servidor. Guia e limites em `backend/firebase/README_1_6.md`. Não equivale a antitrapaça independente.
- Cosméticos têm representação nativa em massinha, somente visual; prévia em mundo 3D isolado, rotação e partículas limitadas/desativadas no mobile. Slots de elo são preservados; visual comprado sobrepõe o slot escolhido, sem revogar a conquista.
- Talentos e melhorias são individuais. Liga Reforçada marca a maior melhoria da estrutura sem empilhamento infinito; fusão mantém o maior bônus. Bolsa funcional não depende do visual da conta.
- Sorteio especial usa uma decisão por coordenada: 5% Titã / 10% posto / 85% normal. Somente o normal recebe os eventos 1.5 de 75%. Saves antigos marcam coordenadas já exploradas como normais, sem transformar visita histórica em descoberta nova.
- Vida do Titã normalizada pelo fator noturno e recompensa parcial sobrevivem a expiração de 180 s. O ponto fraco segue o peito e a rotação reais; mira vertical alcança o peito e impactos nos braços não recebem o bônus. Fúria própria abaixo de 25%, sem aplicar a genérica de 40%.
- Posto usa materiais carregados. A negociação não pausa nem no solo; na horda os comerciantes se abrigam. Segurança bloqueia dano recebido e ataques de saída. Não é segunda base construível.
- Resgate desativa encontros especiais/airdrop nesta tabela de modo, usa sinal em (1,1), estação em (2,1), duas defesas e extração no Núcleo. Só três hordas completas são elegíveis à moeda; buscar sinal não paga. Não salva missão intermediária nem sobrescreve campanha. Objetivo e resultado são replicados.

Evidências consolidadas: [resultados locais da candidata](docs/release16-candidate-results.txt).

## Gates restantes da candidata

1. **Concluído na revisão de código `bb4264e`:** CI integral, Functions Emulator, Windows x64, APK de teste assinado e inspeção das prévias desktop/mobile. Abertura do executável também conferida no Windows com RX 7600 e áudio real. Evidências e downloads abaixo.
2. Publicar serviço/regras no projeto real com administrador e conferir fluxo autenticado. CLI local não autenticado; não substituir isso por emulador nem declarar saldo real funcionando sem publicação.
3. Partidas físicas Windows↔Android e verificação de desempenho nos aparelhos do projeto. Linux/headless e renderização Mesa não substituem esse teste.
4. Avaliação dos defaults criativos e balanceamento pelo criador antes de promoção final. Não mesclar/publicar a RC como versão final automaticamente.

## Histórico dos pacotes RC.1 — 17/11/2026

A revisão de código `bb4264eecfc7e478e8e7b6b8ca8f9dc6dc0b9627` passou nas execuções de [push](https://github.com/Motatech2009/Zombie-bloom/actions/runs/44063597516) e [pull request](https://github.com/Motatech2009/Zombie-bloom/actions/runs/44063604788). As correções finais de loot do Titã e cenários determinísticos estão incluídas. Não é necessário retomar a execução anterior nem distribuir o binário que antecede essas correções.

| Pacote de teste | Download da revisão validada | SHA-256 do ZIP |
|---|---|---|
| Windows x64 | [Windows](https://github.com/Motatech2009/Zombie-bloom/actions/runs/44063597516/artifacts/14319627648) | `87918e7978ea931f9089c7b0809d387aa3d2f986d9eac10a73c6a5de5b76017f` |
| Android | [APK em ZIP](https://github.com/Motatech2009/Zombie-bloom/actions/runs/44063597516/artifacts/14320540131) | `2b42ac4d5507e10e4951b263a7de8546fecb7ee4ba3f114abf081e370e8c8776` |

Os hashes foram recalculados após baixar os arquivos. Os artefatos exigem sessão no GitHub e têm retenção até 15/02/2027. Extraia `ZombieBloom.exe` no PC e `ZombieBloom-Android.apk` no Android. O APK usa o identificador de prévia `com.motatech.zombiebloom.preview`; PC e Android precisam desta mesma revisão/protocolo 19 para cooperativo.

Abertura Windows conferida com o executável exportado, perfil temporário isolado, renderizador OpenGL e AMD Radeon RX 7600. Inicialização headless e inicialização gráfica com áudio real encerraram com código 0, sem erros de script/renderer nem aviso ObjectDB. A variante gráfica com áudio Dummy emitiu aviso de dois objetos de áudio no encerramento forçado; ele não ocorreu com o driver real. Isso é teste curto de abertura, não certificação de uma campanha completa, FPS ou coop físico.

As 18 prévias foram geradas no CI; menu desktop, loja e cartas mobile foram inspecionados. O controle interativo de janelas ficou indisponível no ambiente, portanto não há alegação de clique manual ou partida completa validada por essa via.

O endpoint real `account16Api` respondeu **HTTP 404** na checagem somente de leitura. Não há sessão administrativa Firebase disponível no ambiente. A moeda, compras e horas confirmadas no servidor permanecem bloqueadas até publicação e teste autenticado. O guia de publicação está em `backend/firebase/README_1_6.md`; não foram criadas contas fictícias em produção.

Pendências para a versão final: publicar/validar o Firebase real; testar APK em aparelho físico e Windows↔Android; avaliar balanceamento e os parâmetros criativos. Os downloads acima são **1.6.0-rc.1 para teste**, não a promoção da versão final.

## Adições confirmadas pelo criador — 1.6.0-rc.2

- **Isca de Desvio:** chance de 30% apenas no loot dos chefes das hordas de Campanha/Defesa Infinita. Não sai do Titã nem de chefes de exploração. Usar pela mochila na preparação congela o contador por 600 segundos; infectados da exploração continuam ativos. Preserva o tempo anterior, limita a uma ativação por preparação e não permite encadear iscas. O efeito é da equipe e validado pelo anfitrião.
- A próxima horda recebe `ceil(população normal final × 1,20)`, incluindo os fatores de jogadores e o mutador de hordas dobradas. Continua com um único boss, sem bônus oculto de vida/dano. Recalcular população por entrada/saída de jogadores conserva o multiplicador. A horda seguinte volta ao normal. Temporizador, uso e penalidade persistem no save e nos snapshots.
- **Titã:** baú compartilhado único de 800–1.200 sucatas, 30–45 componentes, 60 munições de rifle e um kit. Restante do baú continua no setor para outras viagens, inclusive após renovação normal. Coleta de baús de boss usa pilhas para evitar centenas de interações de quatro unidades.
- **Coroa do Enraizado / COS-TITAN-01:** visual de cabeça universal, exclusivo por causar dano e estar no setor na derrota. Todos os participantes elegíveis recebem; o último golpe não monopoliza a conquista. Não tem atributos nem preço de compra. Os elos e outros cosméticos são preservados. A coroa tem modelo provisório nativo; modelagem definitiva será feita no Blender.
- A conquista local é persistida separadamente por conta/convidado; não migra automaticamente ao trocar conta. O perfil da partida inclui destinatário e registro privados para reconexão. Confirmação online usa a nova operação `titan`, token Firebase e ledger transacional idempotente; compra direta do troféu é recusada no cliente e no servidor.
- **Torreta elevada:** 150 sucatas +6 madeiras +8 componentes; 150 PV básicos, alcance 17/18/19 m, dano/cadência da torreta normal. Modelo e ponto de disparo a 3,6 m; passa sobre barricadas baixas conforme a linha física de tiro. Casas e muralhas altas continuam bloqueando. Índice 11 acrescentado ao catálogo sem mudar os índices anteriores.
- **Alcance:** área no chão ao posicionar uma defesa ou aproximar-se de uma existente. Torres mostram limite e trechos obstruídos; estacas/arames mostram área de contato; apoio mostra raio de reparo com indicação de cura. Apenas uma prévia ativa, atualização a 5 Hz e 32 amostras no celular/64 no desktop.
- **Compatibilidade:** protocolo 20 e APK 1602; ambos os participantes precisam da RC.2. Save continua formato 6 com campos opcionais, mantendo os saves antigos. Resgate tem sequência própria e não usa a isca.

Os valores de sucata, componentes e da nova defesa são parâmetros iniciais de balanceamento, ajustáveis. O serviço online real e os testes físicos Android continuam pendentes. A operação de conquista usa a confiança comunitária P2P: os controles de conta/tempo/repetição não substituem validação independente de combate.

## Downloads da RC.2 validada

Revisão de código: `5fd7232d3fb6f8686ef08cef4a4c04b1be9c1760`. [CI aprovado](https://github.com/Motatech2009/Zombie-bloom/actions/runs/44088324771).

- [Windows x64 — ZIP](https://github.com/Motatech2009/Zombie-bloom/actions/runs/44088324771/artifacts/14331720099)
- [Android — APK em ZIP](https://github.com/Motatech2009/Zombie-bloom/actions/runs/44088324771/artifacts/14331171272)

Extraia o ZIP. Atualize PC e Android para esta mesma RC.2/protocolo 20. Os hashes e a verificação de abertura do executável exportado estão em `docs/release16-additions-results.txt`. Os links do histórico RC.1 acima não incluem as novas adições. A sincronização real ainda exige publicação do Firebase; os testes físicos do Android e entre aparelhos permanecem necessários.

## RC3 — retorno ao menu e alcance na construção

O alcance da defesa selecionada aparece exclusivamente durante a construção e some imediatamente ao sair desse modo. A aproximação de uma defesa fora da construção não exibe mais a área.

A troca para o menu e o reinício aguardam o fim do callback do botão e ignoram acionamentos repetidos. Ao sair, o progresso captura o último resultado, persiste as filas e libera a referência à partida. O relógio e os pedidos assíncronos não consultam cenas já removidas da árvore. A base só recebe liberação manual quando foi de fato desanexada; os filhos da cena são liberados pelo próprio motor.

Validação local: 48 verificações de transição em cada execução desktop, toque e Windows com vídeo/áudio reais; 35 verificações de isca/troféu/defesas; 13 de sincronização; 127 da campanha; quatro processos ENet reais com saída do convidado e encerramento pelo anfitrião (56 verificações). Os logs não registraram erros de script nem vazamentos ObjectDB. O teste ENet ainda registra o aviso anterior de snapshot acima do MTU, sem falhar as verificações.

Candidata: Android 1603, versão 1.6.0-rc.3; protocolo de rede 20 preservado. A execução completa no GitHub e os pacotes desta revisão serão registrados no PR #5 quando concluídos. O Firebase real e Android físico continuam pendentes conforme as limitações já registradas.

## RC4 — modelos Tripo da torreta básica

Os três modelos enviados pelo criador substituem as cenas da torreta básica nos níveis 1, 2 e 3. Cada nível possui base fixa, cabeça com giro e elevação, bocas de cano e escala compatível com a colisão existente. A mira considera a rotação da fundação; a troca de nível preserva a orientação e o cooperativo replica os dois eixos. Os níveis 2 e 3 alternam as bocas sem duplicar dano ou cadência.

São preservados os 9.608 triângulos do arquivo original: 2.410 / 3.368 / 3.830 por nível, com apenas duas malhas e um material compartilhado em cada cena. O atlas de produção tem limite de 1K com mipmaps. Originais e reconstrução ficam em art_source/basic_turret e tools/art, excluídos dos pacotes.

Validação local: 40 verificações novas com tiros reais, inimigos encostados no cano, alvo elevado, base rotacionada, troca de nível, snapshots e compatibilidade; 35 das adições RC2 e 101 de defesas; quatro processos ENet reais com 116 verificações, incluindo três confirmações dos convidados sobre modelo N3 e orientação. Prévia desktop e toque renderizada no Windows/OpenGL. APK 1604, versão 1.6.0-rc.4, protocolo 20; código anterior de salvamento preservado. Pacotes e CI serão vinculados no PR #5 ao concluir.


## RC.5 — economia Spark e maior pressão das hordas

- Configuração padrão agora usa Firestore nativo gratuito, com carteira privada community16, catálogo/preços fixos nas regras e compra atômica. Serviço Functions permanece opcional. Regras reais ainda precisam ser publicadas; [guia manual](backend/firebase/README_1_6.md).
- Recompensas comunitárias continuam informadas pelo cliente, com sequência, intervalo e teto diário validados no banco; não constituem prova de combate independente. Cache do backend antigo não cria saldo novo.
- Zumbi comum: 44→70 PV; corredor: 30→48 PV. Pistola básica de 22 causa morte em quatro/três acertos normais na primeira horda, antes de bônus/críticos. Demais infectados comuns da sobrevivência recebem +25% PV; bosses/Titã mantêm vida anterior.
- Campanha/infinito: ceil(total anterior×1,25), inclusive crescimento após a horda 20. Primeira horda 18→23, quinta 48→60, vigésima 240→300; fatores cooperativos e isca continuam acumulados sobre o novo total. Resgate: 12/15/19 inimigos solo nas três hordas. Limite simultâneo de 36 preservado, sem aumentar velocidade/dano nem retirar força da pistola.
- APK 1605, protocolo 21: atualizar todos os participantes para a mesma candidata. Saves anteriores preservados.
- Validação específica: 37 verificações de regras/concorrência, 17 de integração Godot/Firestore, 10 de balanceamento; regressões existentes de jogo e interface. Novos pacotes serão vinculados ao PR ao concluir o CI.


### Pacotes RC.5 validados — 17/11/2026

Código f6d90c7514dac9217e3b8c5be3a242bfaab2851d: [CI integral aprovado](https://github.com/Motatech2009/Zombie-bloom/actions/runs/44155874484).

| Plataforma | Pacote | SHA-256 do ZIP |
|---|---|---|
| Windows x64 | [Baixar RC5](https://github.com/Motatech2009/Zombie-bloom/actions/runs/44155874484/artifacts/14360449226) | b3aaeaadfb0626284fa09b1f465aecc4ad9ce6b4fd95639ca178cdf7279658a4 |
| Android | [Baixar APK em ZIP](https://github.com/Motatech2009/Zombie-bloom/actions/runs/44155874484/artifacts/14361486821) | d4e823e2e19083ccceb092f701390c76e4180e43c131171f66eeaf02dfd67b00 |

Os artefatos exigem login GitHub. Hashes recalculados após download. Evidências detalhadas e limites da abertura Windows em [resultados RC5](docs/release16-spark-results.txt). Android físico permanece pendente. Publicar as [regras](backend/firebase/firestore.rules) pelo console e conferir a conta real para ativar a economia; sem dependência do deploy de Functions na configuração atual.


## RC6 — modelos enviados pelo criador

- Canhão, Tesla e torreta elevada: N1–N3; Núcleo: N1–N4; peças separadas e otimizadas.
- 19 cosméticos 3D no catálogo existente, incluindo o troféu do Titã; encaixes no personagem e atlas compartilhado. Mochilas continuam apenas visuais.
- Base fixa, articulação e disparos pelas bocas reais; elevada respeita barricadas e muralhas. Correção de inicialização de material no modo leve sem texturas pré-aquecidas.
- Defesas usam atlas 1K com mipmaps/compressão VRAM; cosméticos usam um atlas 2K compartilhado.
- Candidata RC6/APK1606/protocolo21; regras Firebase reais continuam pendentes. Pacotes RC5 descritos nas evidências anteriores não contêm estes modelos. CI RC6 aprovado: 1.856 verificações Godot e pacotes PC/Android gerados. Evidências e hashes em `docs/release16-models-results.txt`.

## RC7 — personagem articulado e objetos de massinha

- Personagem enviado pelo criador integrado com esqueleto local de 15 ossos e 15.010 triângulos, reduzido a partir de 1.921.388. Braços abaixados sem item e empunhadura em frente ao corpo com arma; caminhada, recarga, coleta e rolamento usam a animação existente.
- Os 19 acessórios físicos vestem o novo corpo. Cabeça e tronco recebem ajustes locais por roupa, mantendo malhas e atlases compartilhados. Cosméticos não alteram colisão, dano, vida, mochila funcional ou progressão.
- Quatro carros distintos na base; comboio com reboque; barraca fornecida com atlas único e Bento atrás do balcão. Eventos, recompensas e áreas bloqueadas preservados.
- Canhão N2/N3 dispara uma salva de dois tiros retos mais grossos, um por cano, com dano total preservado. O cliente também reproduz os projéteis espessos. N1 mantém seu único cano.
- Candidata RC7/APK1607, protocolo21. A ativação da economia no Firebase real permanece pendente. Evidências desta candidata serão registradas após a compilação.

## RC8 — braço, elos, combate e encontros de exploração

- Braço direito usa o mesmo plano de articulação no ombro e cotovelo, com empunhadura à frente do corpo. Ajustes conferidos nas sete roupas, nove armas e taco, incluindo recarga e golpe.
- Dez recompensas de elo agora vestem peças em 3D: acessórios importados nos sete primeiros e medalhões/cristais de massinha nos três últimos. Escolhas do catálogo mantêm prioridade no mesmo espaço. Atributos e capacidade não mudam.
- Taco: até três alvos por golpe, dano base 18, intervalo 0,90 s e alcance 2,15 m. Não aplica mais paralisia repetida; zumbis em contato continuam atacando.
- Ninho produz guardas com limite de seis vivos, respeita presença do jogador e aceita tiros, explosões e corpo a corpo. Vida e vínculo dos guardas ficam no salvamento; destruir interrompe a geração e remove o bônus regional.
- Posto seguro aparece também para convidados. Botão NEGOCIAR no toque abre a troca correta; compras continuam validadas pelo anfitrião e usam materiais da mochila.
- Novos Titãs só são sorteados fora do quadrado central de nove setores: max(|x|,|y|) >= 2. Chance de 5% nas áreas elegíveis e 10% do posto preservadas. Encontros já salvos continuam. Aviso do Titã inclui setor e aparece depois do aviso de entrada.
- Candidata RC8/APK1608/protocolo21. Testes específicos: 61 de apresentação e 22 de combate/eventos no desktop e 24 no toque. CI integral e pacotes desta revisão serão registrados após a execução. Economia Firebase real e Android físico continuam pendentes.

## RC9 — bosses e infectados enviados pelo criador

- bosses.glb e zombies.glb foram separados por componentes, reduzidos e articulados localmente. Originais somam 3.875.668 triângulos e ficam fora do executável/APK.
- As oito criaturas do kit de bosses e dezoito formas de infectados da sobrevivência agora usam suas malhas fornecidas. O kit normal também contém o Colosso antigo, mantido como recurso de referência; o índice 8 da sobrevivência continua selecionando os sete bosses por etapa.
- O Parasita não existe como componente separado no arquivo. Conserva a forma de cão pequeno com a malha nova do cão e escala 0,45; sua transformação em Bruto também recria o modelo articulado novo.
- Modelos comuns ficam em até 3 mil triângulos e bosses em até 10 mil, com dois materiais compartilhados e atlas 2K com mipmaps/compressão VRAM. Esqueletos locais dirigem braços/pernas e asas; não havia animações nos GLBs originais.
- Vida, dano, colisões, habilidades, drops, IA e regras das hordas continuam nos atores existentes. O corpo do Titã considera os galhos acima da cabeça para manter o coração na altura correta do peito.
- Inclui integralmente as correções RC8: braço direito, elos 3D, taco com três alvos e sem paralisia, ninho ativo, negociação por toque e Titã apenas em novos setores da camada 2 em diante, com aviso.
- Validação local específica: 218 verificações por execução desktop/toque; 81 de encontros e resgate; 24 de combate/negociação por toque. RC9/APK1609/protocolo21. CI integral e pacotes desta revisão serão vinculados ao concluir. Android físico e ativação do Firebase real permanecem pendentes.
