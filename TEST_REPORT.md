# Validação 0.13.1 — ações, catálogos, mira e proporção da tela

1007 verificações locais aprovadas: 15 suítes com 894 verificações e quatro processos ENet com 113. [Resultados](docs/mobile0131-results.txt).

48 verificações móveis incluem disponibilidade contextual dos comandos, coleta demorada, depósito, melhoria e custo, vendedor, compra de arma e munição, limite de construção, encerramento por horda e interface em tela mais larga. As 35 verificações de mira incluem aquisição e tiro real contra infectado com pai deslocado em setor de exploração. As 28 verificações de experiência móvel preservam qualidade ao vivo, previsão, reconciliação e feedback imediato.

Inspeção visual do catálogo de construção, do vendedor e do HUD. Guardar materiais foi verificado com toque prolongado, seguido da atualização do estoque e ocultação do botão. O cliente de rede de toque roda em Linux; não é um Android físico. Tela cheia Windows, modo imersivo Android, recortes e FPS ainda exigem verificação nos dispositivos finais.

## Histórico da validação 0.13

# Validação 0.13 — controles, materiais e resposta de rede

985 verificações locais aprovadas: 15 suítes com 872 verificações e quatro processos ENet com 113. Importação Godot 4.6.3 sem erros. [Resultados](docs/mobile013-results.txt).

A nova suíte de 26 verificações cobre analógico flutuante, rotação ao andar e disparar, coleta contextual, qualidade aplicada em tempo real sem resetar inimigos, geometria do menu/barra, movimento durante lacuna de 200 ms sem snapshots, reconciliação, rolamento previsto, feedback de tiro sem mutar munição/vida e interpolação de 100 ms. As suítes móveis anteriores acompanham a nova regra: tocar escolhe o alvo e segurar dispara.

A sessão ENet usa quatro processos reais em loopback, com um convidado usando eventos de toque. O servidor limita o movimento à física, aceita apenas comandos validados e conserva a autoridade de dano e inventário. Os conjuntos lentos e rápidos usam canais separados e compressão. A suíte não certifica rede de operadora, perda real em 4G, nem desempenho no Moto G45/A13.

A recepção de um snapshot apenas agenda a reconciliação. Colisões e replay ocorrem no passo de física. Entradas continuam enviando a intenção mais recente quando há atraso de confirmação. Rolamento usa intenção confiável vinculada à sequência de entrada e contador de ativações confirmado pelo anfitrião. Novas cenas só recebem comandos depois de mapa e estado completo chegarem ao convidado. Os testes de transição aguardam a confirmação de todos os dispositivos antes de avançar a próxima cena, mantendo obrigatórios os critérios de vida, munição e saque.

Inspeção visual em janela 1280×800 com interface móvel 960×540: HUD de combate, pausa, configurações, qualidade detalhada restaurada durante a partida e mochila com controles de fechamento visíveis. Não houve instalação física do novo APK neste ambiente.

# Validação de exploração e suprimentos 0.12 — 2026-11-13

**953 verificações aprovadas:** 801 das treze suítes anteriores, 43 de progressão e 109 de rede (31 anfitrião +25 por desktop +28 no cliente de toque). Logs em docs/progression-results.txt e docs/coop-results.txt; registros de arsenal, casas e fortaleza atualizados para os tempos solo.

O teste de progressão exerce entrada real, saque parcial, morte de um encontro específico, casa com guardião ferido e chefe com HP reduzido. Simula o relógio autoritativo nos limites 179,99/180,01 s: a mesma geração/progresso retorna antes do prazo; depois, apenas uma entrada nova renova o cenário. O boss conserva arquétipo/HP mesmo quando a horda avança. Piles no chão e seus conteúdos reaparecem uma vez. Checkpoint serializado em JSON mantém os mesmos dados e prazo; conversão numérica normaliza quantidades. Saves v6 anteriores sem memória de setores continuam aceitos. Conteúdo inválido ou prazo fora dos limites é rejeitado.

Cooperativo em quatro processos ENet reais: além dos fluxos anteriores, a equipe entra, volta ao Núcleo, revisita a mesma área e retorna novamente. Convidados recebem a mesma semente, prazo compartilhado, caixa com sete munições de rifle/dois componentes e morte de guardião preservada. Restauração de checkpoint também rebobina bolsas de convidados, incluindo quem entrou após o save, evitando transportar itens de um estado futuro para um estoque restaurado.

Chefes: primeiro chefe solo acima de 1.200 HP, escala adicional com participantes e crescimento nas hordas posteriores; morte real gera pacote dourado extra com munição e componentes. A coleta coloca os recursos na bolsa e não no banco. Piles no limite de 128 por região reutilizam uma pilha compatível sem perder um prêmio raro descarregado; conteúdo que volta a existir torna a pilha visível. Biomas usam sorteio estável por geração: amostra de 400 sementes distingue maior oferta militar de floresta e inclui foguetes/células/granadas/kits.

Coleta solo: 1,68 s por lote comum, 3 s por lote de casa/arsenal/airdrop e 1,08 s para depósito. Equipe mantém 2,8/5/1,8 s. Entrada de participante altera a duração mantendo a fração concluída, sem progresso gratuito. Reparo e reanimação permanecem com seus tempos anteriores. Airdrop, bolsa cheia, armas carregadas e guarnições seguem validados nas regressões.

Revisão visual em janela com interface móvel: mapa mostra a preservação de 02:40 e texto completo no painel lateral; contador FPS oculto durante o painel, sem sobrepor as células. Fixture não grava saves. Godot 4.6.3, Linux/Mesa e áudio Dummy; não houve teste desta atualização em Android físico nem medição de FPS no A13. CI repete catorze suítes e quatro processos de rede e exporta Windows e APK do mesmo commit, com verificação da assinatura. Balanceamento de campanha inteira ainda requer playtest.

---

# Validação de controles e modo leve 0.11.2 — 2026-11-13

**898 verificações aprovadas:** 775 das doze suítes anteriores, 26 de controle/desempenho e 97 de rede (28 anfitrião, 22 por desktop e 25 pelo cliente de toque). Registros em docs/mobile-performance-results.txt, docs/targeting-results.txt, docs/mobile-results.txt e docs/coop-results.txt.

O disco direito foi substituído por ATIRAR com área de 168×146 pontos. Segurar escolhe o zumbi visível/alcançável mais próximo, preserva o alvo tocado e procura outro após uma morte; soltar ou arrastar para fora cancela. Sem alvo válido não gasta munição. Movimento usa dedo separado. Granada/kit usam uma unidade por toque e mantêm validação no anfitrião. A rede real valida seleção assistida, seleção por toque, munição e cura única por comando confiável. Mira no cão e voador agora usa os IDs corretos dos dois tipos na fixture.

Modo leve padrão em celular: cenário em 75% da resolução, UI em 960×540, sombras desativadas, materiais sem normal map/triplanar, modelos agrupados por membro com meshes compartilhados e preparação dos humanoides na entrada da partida. Evita criar o modelo legado que seria imediatamente descartado. Animação humanoide limitada a 20 Hz sem reduzir física/IA. Barras em uma única camada a 10 Hz, até 12 indicadores, priorizando alvo e chefes. Efeitos usam 20 objetos reutilizados; o limite só reduz apresentação. HUD numérico a 10 Hz e contador de FPS no aparelho. Qualidade fica estável até reabrir a partida, evitando misturar perfis após uma troca nas configurações.

Tiro em alvo usa índice por ID, consultas de cobertura limitadas/armazenadas no cliente e revalidação pelo anfitrião quando a arma pode disparar. Não consulta cobertura a cada leitura de entrada ou durante recarga/cadência. Testa referências removidas, limites de efeitos/barras, mesh compartilhado, dano e consumo reais, controle sem alvo e entrada independente.

Benchmark gráfico de apresentação, Mesa llvmpipe/Linux, sem IA ativa: 0, 24 e 72 inimigos, oito quadros de aquecimento e 40 amostras por caso. Com 72: chamadas de desenho 1.684 → 544 (-67,7%); meshes de inimigos 1.214 → 350 (-71,2%); nós totais 2.515 → 1.385 (-44,9%). Mediana de quadro observada 41,012 → 29,679 ms nesse ensaio. Método e amostras resumidas em docs/mobile-render-benchmark.json. Esses números não medem FPS do A13, física de uma horda ativa, aquecimento ou bateria.

Revisão gráfica em janela conferiu botão grande separado da coleta, contador FPS/LEVE, estilo e membros preservados, alvo escolhido ao segurar e seis tiros consumidos em 1,8 s; ao soltar, marcador e ataque foram encerrados. Ambiente com áudio Dummy. Não houve teste desta versão em Android físico. CI repete treze suítes/rede e gera Windows/APK com assinatura verificada. Dados de mundo v6 e assinatura de desenvolvimento permanecem compatíveis.

Referência técnica: https://docs.godotengine.org/en/4.6/tutorials/performance/optimizing_3d_performance.html

---

# Validação da mira por toque 0.11.1 — 2026-11-13

**871 verificações aprovadas:** 742 das onze suítes anteriores, 33 de mira por alvo e 96 de rede (28 anfitrião +22 por convidado desktop +24 no convidado de toque). Registros em docs/targeting-results.txt e docs/coop-results.txt.

Toque seleciona um zumbi na tela e mantém mira/disparo ao soltar o dedo, permitindo movimento separado. Testes verificam consumo real de uma bala e dano no alvo, acompanhamento de movimento, interrupção por parede/alcance/morte/remoção/saída da tela, revisão do setor e cancelamento por chão, controle manual, coleta, painel, foco, cancelamento do sistema, troca de item, queda ou construção. Cães e voadores recebem tiros na altura correta. Lança-foguetes consome um foguete e encerra a trava; granadas e kits nunca são usados pela seleção de inimigo. Dispersão, recarga, cadência e custos continuam normais.

O cliente envia ID autoritativo do alvo e revisão do setor no frame já existente. O anfitrião reavalia alvo vivo, distância e cobertura antes de cada disparo e recalcula a direção atual; pedido falso, obsoleto ou liberado não força tiro. Réplicas de inimigos passam a manter o ID recebido do anfitrião. ENet com quatro processos reais confere toque no zumbi, envio/recebimento desse alvo, tiro e munição no servidor junto dos convidados desktop. A fixture usa um alvo resistente em corredor livre para validar Tesla; os demais objetivos de inventário, construção, casas e viagem continuam.

Revisão gráfica em janela: marcador âmbar SEM TIRO atrás do Núcleo, com munição preservada; marcador verde ALVO em zumbi acessível, vida reduzida e bala consumida; toque no chão remove marcador e interrompe a sequência. Ambiente Linux/Mesa com simulação de toque, sem novo teste desta atualização em telefone físico. CI repete doze suítes e rede e gera APK/Windows do mesmo commit, com assinatura Android verificada. Saves continuam v6 e a chave de desenvolvimento é a mesma da 0.11.

---

# Validação PC + Android 0.11 — 2026-11-13

**836 verificações locais aprovadas:** 714 de regressão, 28 móveis e 94 de rede (27 anfitrião +22 por convidado de desktop +23 no convidado de toque). Logs em docs/mobile-results.txt e nos registros das suítes/rede.

A suíte móvel simula InputEventScreenTouch/Drag, verifica dois dedos independentes, movimento físico, mira/disparo, soltura de um controle sem afetar o outro, zona morta, rolamento de 5 s, recarga, limpeza de comandos, bloqueio durante painel, acesso aos 18 espaços, catálogo em duas colunas e navegação dos nove slots. Construção usa alvo de toque, rotação, pagamento/cota reais e cancelamento. Segurar COLETAR deposita materiais após o tempo real de coleta. Mapa mantém relógio ativo; Voltar do Android fecha painel e perda de foco libera entradas. Snapshots atrasados não desfazem o slot recém-selecionado; confirmação libera a seleção pendente.

ENet/UDP: quatro processos reais em Linux, um deles com MobilePlatform e TouchControls ativos. Esse convidado envia movimento e disparo pelos eventos de toque da aplicação; Coop.test_input fica vazio. Mantém seleção/Tesla, inventário, depósitos, construções, casas, airdrop, multiplicador e cenas dos demais clientes. É teste do mesmo protocolo com frontend móvel, sem Android nativo nem redes externas.

Revisão gráfica em simulação desktop de paisagem: controles, barra paginada, mochila em seis colunas, fechamento fixo e catálogo adaptado. A fixture não grava saves. Não mede comportamento de tela sensível ao toque, FPS, temperatura, bateria ou reconexão em aparelho físico.

CI instala Java 17 e SDK Android, usa templates oficiais 4.6.3, exporta APK de desenvolvimento com assinatura fixa, verifica a assinatura, o manifest e as bibliotecas ARM e exporta Windows do mesmo código. A chave de desenvolvimento é pública e serve ao protótipo; não foi feita publicação em loja. Android real, iOS, internet entre casas e balanceamento prolongado permanecem para teste. Saves continuam v6 no anfitrião.

---

# Validação do Refúgio de Argila 0.10 — 2026-11-13

**807 verificações locais aprovadas:** 648 nas oito suítes anteriores, 35 de argila/casas, 31 de conexão e 93 de rede (27 do anfitrião +22 por convidado). Godot 4.6.3 oficial, Linux. Registros em docs/clay-results.txt, docs/internet-results.txt e logs de regressão/rede.

Texturas e geometria: recursos de material/textura/mesh compartilhados, mapas 128 px, projeção no mundo, limites geométricos de 108 triângulos e preservação das dimensões. Posição numérica da mão direita confirma o braço à frente nas fases de caminhada/disparo. Casas determinísticas por visita, limite de duas a quatro, preservação dos corredores, remoção de sobreposição de props, separação entre caixas/arsenal e caminho de navegação até o interior.

Fluxo real de casa: viagem a um setor, instanciação de casa, cutaway local, bloqueio de saque antes da limpeza, materialização/morte de guardas reais reforçados, contagem separada da população comum e liberação da caixa após a guarnição. Coleta exige cinco segundos, concede uma pilha na bolsa e não no banco; parede impede saque pelo exterior. Estado replica sem duplicar a caixa. Entrada/saída de jogador altera a quantidade exigida; retorno ao Núcleo descarrega os diretores das casas. A suíte de setores fixa o RNG do cenário para sempre exercitar o fluxo de inimigo/spawn/tradução, antes condicionado a um setor aleatório com população.

Rede com quatro processos ENet/UDP: mantém os fluxos anteriores e acrescenta braço correto nos convidados, geometria das casas, guarnição multiplicada por oito, mortos registrados e conteúdo exato da caixa. Campo e base, arsenal, rolamento, airdrop e transações anteriores continuam passando. Apenas loopback; sem simulação de latência/perda nem teste entre duas casas.

Conexão auxiliar: valida endereços privados/CGNAT, endpoint IP:porta/hostname/IPv6, entradas inválidas, worker assíncrono, repetição bloqueada, renovação, remoção, cancelamento com resultado tardio e erro do roteador sem falso sucesso. Usa roteador simulado; não realizou descoberta/mapeamento no roteador residencial de alguém. A configuração externa depende da rede real e não substitui um relay.

Revisão gráfica em janela 1280×800: texturas sutis, casa completa com telhado/janela/entrada, cutaway sem janelas flutuantes, braços para a frente, tampa da caixa e painel de conexão com controles legíveis. Fixtures `tests/clay_preview.gd` não gravam saves nem representam uma partida normal. Renderização por CPU/Mesa e áudio Dummy não medem desempenho no hardware alvo.

CI repete dez suítes, quatro processos de rede e exportação Windows. Execução nativa no Windows, balanceamento prolongado, roteadores/operadoras reais e desempenho móvel permanecem para playtest. Não foi criada versão de celular.

---

# Validação do Rolamento 0.9.1 — 2026-11-13

**730 verificações locais aprovadas:** 615 nas sete suítes anteriores, 33 de rolamento e 82 de rede (25 do anfitrião +19 por convidado). Godot 4.6.3 oficial, Linux. Logs em docs/roll-results.txt e nos registros de regressão/rede.

A suíte nova verifica a tecla física Espaço, direção de movimento compatível com os eixos da câmera, mira quando parado, bloqueio em menus/construção, repetição de teclado ignorada e ausência de interferência nas hordas automáticas. Confere início com exatamente 5 s de recarga, bloqueio de reativação antes do prazo, nova ativação ao vencer, rejeição de direções inválidas, cancelamento de coleta/recarga e bloqueio de tiros, kits e granadas durante o rolamento.

Física real: deslocamento ao longo de vários quadros, animação de cambalhota, proteção inicial de 0,20 s seguida de retorno do dano antes do fim da animação, retorno à pose vertical, parede sólida bloqueando a trajetória e criogênico reduzindo o alcance. Queda encerra o movimento e reanimação restaura a pose. Perfil salva a recarga, valida limites, mantém saves v6 antigos e encerra a animação transitória ao restaurar. HUD mostra texto e barra compacta.

ENet com quatro processos reais: cada convidado solicita o rolamento por RPC confiável e recebe duração, direção e recarga; a repetição da solicitação durante a recarga é rejeitada pelo anfitrião. Mantém coleta, armas, depósito, construções, airdrop, multiplicador e troca de setores. Rede por loopback, sem medir latência/perda entre casas. A animação dos convidados depende dos snapshots do anfitrião; não foi adicionada predição local.

Revisão gráfica em janela: Espaço executa o rolamento; o HUD apresenta o estado ROLANDO, o contador e a barra de recarga no painel de atalhos. Modelos da fortaleza preservados. Renderização Linux/Mesa por CPU, áudio Dummy. Não houve execução nativa em Windows nem campanha humana completa. CI repete as oito suítes, a rede e a exportação Windows no commit entregue.

---

# Validação da Fortaleza 0.9 — 2026-11-13

**688 verificações locais aprovadas:** 342 anteriores, 80 de sobrevivência, 93 de arsenal/visual, 100 de fortaleza e 73 de rede (22 do anfitrião +17 por convidado). Godot 4.6.3 oficial, Linux. Logs atuais em docs/fortress-results.txt e nos arquivos das suítes anteriores/rede.

Fortaleza: 35 cenas editáveis importadas (30 defesas por nível, quatro Núcleos e um airdrop), preservação dos índices das peças antigas, morte real de infectado com coleta por proximidade, drop aéreo projetado no chão, materiais que ficam na bolsa, capacidade parcial e XP único com bolsa cheia, prioridade do convidado mais próximo. Caixa procedural real não coleta ao passar e continua exigindo tempo.

Construções: melhorias pagas trocam cores, materiais e geometria; limite N3; portão levanta só a folha e não fecha sobre personagem; arame atravessável causa dano, lentidão, desgaste e ignora voadores; canhão cria projétil, causa dano em área e poupa aliados/Núcleo; torre elétrica atinge solo/ar, interrompe e respeita EMP; comando autoritativo instala peça de índice novo e consome a cota; Núcleo troca o modelo completo ao melhorar.

Airdrop: prazo exato de 600 s, setor aleatório fora da base, risco máximo, paraquedas, escolta com chefe real reforçado, bloqueio contra coleta precoce/automática, limite de 12 guardas materializados, contagem separada da população comum, retirada e reentrada sem recriar mortos/chefe, desbloqueio após derrotar toda a escolta, cinco segundos por lote, conservação do restante, transporte até o Núcleo, próxima queda após dez minutos e validação de dados inválidos. V6 valida novos tipos, relógio/conteúdo/progresso e migra v5 preservando a origem.

Rede: quatro processos ENet/UDP reais por loopback. Os testes anteriores foram ampliados para coleta por passagem sem E, tipo/nível/material de arame no convidado, relógio/coordenada da queda, caixa e área infestada compartilhadas. Snapshots comprimidos em DEFLATE são decodificados com limite e preservam o estado; o teste confirma tamanho reduzido. Isso não certifica conexão entre casas, perdas ou latência alta.

Revisão gráfica em janela 1280×800: madeira, aço e concreto lado a lado, Núcleo N4, torretas/canhão/torre elétrica/arame/muralha, catálogo rolável com dez opções e ícones, paraquedas em descida, indicação dos guardas, marcador dourado DROP e orientação no mapa. O HUD anterior foi preservado. A fixture tests/fortress_preview.gd não grava save e não representa o inventário inicial. As suítes usam dano de fixture para testar conclusões, sem equivaler a uma campanha humana completa.

Importação/suítes sem erros de script. Ambiente gráfico Mesa llvmpipe por CPU, áudio Dummy. FPS no PC alvo, execução nativa no Windows e balanceamento de sessões prolongadas permanecem para playtest. O CI repete as sete suítes, teste de rede e exporta Windows; o resultado é confirmado no commit entregue.

---

# Validação do Arsenal 0.8 — 2026-11-13

**574 verificações locais aprovadas:** 342 anteriores, 80 de sobrevivência, 93 de arsenal/visual e 59 de rede (20 do anfitrião +13 por convidado). Logs em docs/arsenal-results.txt e nos arquivos de regressão/rede. Godot 4.6.3 oficial, Linux.

A nova suíte importa os ícones de todos os 20 itens, instancia seus modelos editáveis e confere a hierarquia de animação dos 13 modelos humanoides. Verifica nove estados de arma, seleção e modelo de cada arma nova, sniper atravessando exatamente três alvos com perda de dano, corrente Tesla de quatro alvos com perda de dano e bloqueio por parede, recarga parcial conservativa de munição pesada, compra real de Tesla/células, novos tipos na composição das hordas, telegráfico e movimento físico da investida, pulso criogênico com dano/lentidão e status replicado, EMP que interrompe e depois permite o retorno do disparo da torreta.

Saves: checkpoint automático inicial válido, v5 com nove armas, validação quando a pistola está fora da bolsa, restauração do arsenal, migração v4 incluindo perfis sem mutar a origem. Setor real contém arsenal raro com Tesla, mantém cinco segundos de coleta e concede exatamente uma arma com seu pente. Inventário e vendedor são abertos na cena real.

Encerramento: o transporte de alto nível é removido antes de fechar ENet, e o relay entre convidados fica desativado porque todas as ações passam pelo anfitrião. Após um alerta intermitente de canal durante desconexões simultâneas no CI inicial, a correção passou em três execuções locais consecutivas com quatro processos, sem erros.

Rede: quatro processos reais por ENet/UDP, mantendo os testes anteriores e ampliando para nove estados de munição, concessão/seleção/disparo/modelo da Tesla com consumo validado no anfitrião, novo modelo de Criogênico e aviso de área nos três clientes. Também cobre depósito compartilhado, tiros anteriores, multiplicação x8 e troca de setores. Tudo em loopback; não certifica latência/perda nem internet entre casas.

Revisão gráfica 1280×800, Mesa llvmpipe e áudio Dummy: HUD em blocos, nove ícones de arma, destaque dourado da seleção, item/ammo no canto inferior, seis variantes com modelos diferentes e recursos/itens reconhecíveis no chão. Mochila com duas linhas de nove ícones, quantidades, depósito com imagens e sem sobreposição de controles. Fixture `tests/arsenal_preview.gd` não grava saves e não representa o início de uma partida. O PC virtual renderiza por CPU; não mede desempenho da RX 7600 ou de outro hardware alvo. Os modelos são low-poly procedurais, editáveis em Godot; não são personagens finais com animação esquelética.

Importação e suítes sem erro de script. Publicação e exportação Windows são confirmadas pelo CI no commit entregue. Não houve execução nativa em Windows nem campanha humana completa; equilíbrio prolongado permanece para playtest.

---

# Validação da Sobrevivência 0.7 — 2026-11-13

**469 verificações aprovadas localmente:** 342 anteriores, 80 da nova suíte de sobrevivência e 47 de cooperativo (17 do servidor e dez por convidado). Godot 4.6.3 oficial, Linux. Logs em `docs/survival-results.txt`, `docs/coop-results.txt` e nos quatro arquivos de regressão.

A nova suíte cobre conservação de pilhas e limites, rejeição atômica de bolsa inválida, coleta em lotes, tempo, cancelamento por movimento/dano/ameaça, excedente em bolsa cheia, depósito por proximidade e duração, retirada/armazenamento, munição finita e cancelamento de recarga, transferência do pente ao guardar/descartar, compra sem débito em bolsa cheia, seis colocações reais e bloqueio da sétima sem cobrança, cota não devolvida pelo desmonte e renovada após cerco, escala x1/x2/x4/x8, limite de participantes, queda/reanimação com kit, preservação de estado caído em perfil, poderes de chefe, telegráfico replicado, armadura/fúria/invocações, Berrador/Regenerador/Estourador, v4/migração v3 e UI de 18 espaços.

`tests/run_coop_test.py` inicia **quatro processos Godot reais** conectados por ENet/UDP em loopback. Confere entrada dos três convidados, movimento simulado no anfitrião, tiros reais matando inimigos, munição consumida no servidor e replicada, multiplicador exato, comandos indevidos sem mutação, transações simultâneas de depósito com conservação do saldo, carregamento de setor procedural por revisão de cena e retorno ao mesmo Núcleo. Desconexões reduzem a escala e removem avatares. Testes usam identidades locais distintas, porta de fixture 24577 e não gravam saves de jogo.

Revisão gráfica em janela 1280×800, Mesa llvmpipe: tela de sala, criação de anfitrião, HUD com cota e nove botões, mochila com depósito e quantidades, troca efetiva de pistola para o quinto espaço e seleção pela tecla 5. A coleta segurando E por 3,1 segundos colocou quatro madeiras na bolsa, mantendo o estoque do Núcleo em seis. Fixture visual conferiu barras constantes em pixels, fração de vida e chefe nomeado. As barras pequenas em texto 3D foram substituídas após essa inspeção. `tests/survival_preview.gd` é somente uma fixture de revisão, excluída do export e sem gravação de checkpoint.

As cinco suítes locais passaram sem erro de script, assim como os quatro processos de rede. As regressões de campanha usam cenas anteriores; não representam uma campanha humana completa nesta versão. O ambiente não tem saída ALSA, então a revisão gráfica usa driver de áudio dummy. O executável Windows é exportado pelo CI; seu resultado deve ser confirmado no commit entregue. Internet entre casas, reconexões sob perda de pacotes, desempenho no PC alvo e balanceamento de sessões longas permanecem sem certificação.

---

# Validação dos Setores 0.6 — 2026-11-12

**342 verificações aprovadas:** 85 do MVP, 127 da campanha anterior, 55 de combate/construção e 75 novas de setores/cercos. Godot 4.6.3 oficial, Linux. Logs atuais em docs/integration-results.txt, campaign-results.txt, defense-results.txt e sectors-results.txt.

A nova suíte verifica determinismo por visita e mudança ao revisitar, amostra com cinco riscos, arsenais raros, quatro saídas e mapa sem teleporte/pausa, translação de colisões/navegação/loot, conservação e reivindicação única de caixas, preservação das instâncias de base, relógio que dispara a primeira horda com o sobrevivente longe, chefe desde a primeira onda, contagens separadas de hostis, retorno permitido durante invasão e avanço bloqueado, corrosão remota, todos os 20 slots de chefe, cinco arquétipos, timer/RNG/histórico em saves, migração e infinito automático além da horda 20.

Verificação física adicional: um chefe ativado junto ao Núcleo moveu-se e aplicou dano enquanto o jogador estava em outro setor; uma torreta continuou disparando sobre um alvo da base. Não foi usado dano agregado para simular uma base distante. O resto das conclusões de onda/limpeza em testes usa dano de fixture e não representa uma partida humana completa.

Conferência em janela 1280×800: saída Norte por E, entrada procedural em (0,−1), aviso de setor infestado com 91 infectados, relógio em contagem durante exploração e mapa 7×7 com Núcleo (0,0), posição e retorno Sul. M manteve a simulação e o jogador recebeu dano durante a consulta, conforme a regra de mapa contínuo. O helper tests/sectors_preview.gd apenas posiciona o jogador junto à saída para revisão e desativa gravação de saves.

Importação sem erros de script. O ambiente usa renderização por CPU Mesa llvmpipe, sem saída ALSA. Desempenho no hardware alvo, exe nativo no Windows, qualidade sonora e balanceamento prolongado não estão certificados. O CI repete as quatro suítes e exporta Windows; seu resultado é confirmado separadamente para o commit entregue.

---

## Histórico 0.5

# Validação da Defesa 0.5 — 2026-11-12

**267 verificações aprovadas:** 85 do MVP, 127 da campanha ampliada e 55 da expansão. Godot 4.6.3 oficial, Linux. Logs atuais: `docs/integration-results.txt`, `docs/campaign-results.txt` e `docs/defense-results.txt`.

A expansão verifica modo infinito além da campanha (hordas 21/22), checkpoints separados, migração do save anterior, cinco armas, compra/consumo/recarga cancelada de foguetes, granadas finitas e recuperação, explosão em área com obstrução e dano próprio, poça corrosiva com expiração e dano às defesas, projétil do corrosivo, tiro e torreta em cães/voadores, atributos do Alfa e mapa físico além do limite antigo. A campanha percorre as 20 hordas e retoma o checkpoint 19 em cena nova.

Construção: 120 atualizações de prévia sem consulta completa de caminho; materiais mantêm suas instâncias; ocupação é limitada a 10 verificações por segundo; a grade de acesso é reutilizada e células temporárias são revertidas. Oito colocações reais tiveram mediana de **0.444 ms**, máximo de **1.799 ms**; uma colocação com **80 defesas existentes levou 6.21 ms**. Dados em `docs/build-performance.json`. São tempos de CPU da operação headless; excluem o quadro seguinte, shaders e renderização e não certificam ausência de travamento no Windows do usuário.

Conferência em janela nativa 1280×800, Mesa llvmpipe: seleção de campanha/infinito, HUD compacto, catálogo, colocação de barricada (140→120 sucata), nove silhuetas por fixture visual, seleção do lança-foguetes, lançamento de granada e arsenal de cinco armas. Modelos e efeitos continuam de protótipo. O helper `tests/defense_preview.gd` não integra o executável e usa hostis parados para revisão de arte.

Importação e suítes sem erros de script. A liberação do áudio aguarda o processamento do mixer nos testes, evitando falso vazamento de playback no encerramento rápido. Sem dispositivo ALSA para ouvir som. Não foi executada uma campanha humana completa nem o exe em Windows; dificuldade e desempenho no hardware alvo ainda precisam ser aferidos. Exportação/CI devem ser confirmados no Actions do commit entregue.

---

## Histórico 0.4

# Validação da campanha 0.4 — 2026-11-12

Godot 4.6.3 oficial, Linux: **103 verificações da campanha + 85 do MVP = 188 aprovadas, zero falhas**. Importação e execução headless da cena da campanha sem erros de script. Logs atuais em `docs/campaign-results.txt` e `docs/integration-results.txt`.

A nova suíte usa cenas, físicas e raycasts reais. Verifica posse de armas, compra única/proximidade/saldo, tratamento e materiais; transações atômicas; seis defesas, rotação, bordas contíguas, ocupação, níveis, Núcleo, portão que não fecha sobre personagem, estacas e cura; blindagem e demolidor; clique projetado a partir da posição do evento; mapas/pausa; viagem das quatro áreas, base retirada da árvore, preservação das mesmas defesas ao retornar, populações finitas, limpeza, três reservas conservativas e sem repetição; checkpoint e rejeição de dados inválidos; oito hordas com vitória e retomada em cena nova. Conclusão de hordas e limpeza nos testes usam dano de fixture para exercitar mortes e transições; não equivalem a uma partida humana completa.

Conferência gráfica por janela nativa 1280×800: menu, continuação, catálogo de seis peças, instalação de muro pelo clique (140→105 sucata), barraca/negociação, compra de espingarda (120→10), mapa com quatro cartões e bloqueios, entrada no pátio e infectados ativos. O cenário, câmera, HUD e modelos preservam a versão da imagem. Revisão corrigiu a projeção do clique que antes usava cursor do frame anterior e a validação de integridade após serialização numérica JSON.

Exportação Windows é feita pelo workflow no commit publicado. Seu resultado deve ser conferido no Actions. O ambiente nativo usa Mesa llvmpipe por CPU e não oferece áudio ALSA; não certifica desempenho na GPU do usuário nem qualidade sonora. Execução nativa do `.exe` em Windows e balanceamento de sessão longa permanecem sem validação. Arte e áudio são procedurais de protótipo.

---

## Relatório histórico do MVP

# Relatório de testes — 2026-11-11

## Ambiente e comandos executados

Godot **4.6.3.stable.official.7d41c59c4**, Linux. Testes sem plugins de terceiros.

```bash
godot --headless --path . --editor --quit
godot --headless --path . --scene res://scenes/main/GameWorld.tscn --quit-after 60
godot --headless --path . --script res://tests/run_tests.gd
```

Resultado da suíte: **85 verificações, zero falhas**, código de saída 0. Importação final sem erros de script. O log reproduzível da suíte está em `docs/integration-results.txt`.

## Cobertura executada

| Área | Verificação |
| --- | --- |
| Vida | Dano negativo rejeitado, cura limitada, morte terminal |
| Jogador | Movimento por InputMap no CharacterBody3D real |
| Armas | Raycast e dano da pistola; seis chumbos da espingarda; dano/pente do rifle |
| Recarga | Cadência, bloqueio durante recarga, pente vazio, cancelamento ao trocar |
| Recompensas | Morte e coleta únicas, contagem de eliminações |
| Carteira | Rejeição de saldo insuficiente e gasto negativo |
| XP | Excedente, múltiplos níveis e pausa para escolher |
| Upgrades | Seis alterações efetivas e rejeição de seleção duplicada |
| Bônus | Absorção, renovação sem acumular e expiração dos três tipos |
| Construção | Sobreposição, jogador, núcleo, limites, distância e custo |
| Defesas | Instalação, reparo pago, limite de vida e não cobrar reparo desnecessário |
| Torreta | Dano em alvo visível e bloqueio por obstáculo sólido |
| IA | Ataque à barricada e ausência de penetração em seu volume durante movimento |
| Ondas | Spawn automático pelo temporizador, progressão, quantidades e tipos |
| Pausa | Congelamento do relógio e retomada |
| Desfecho | Vitória na quinta onda; derrota por jogador e por núcleo; resultado imutável |
| Menus | Construção das telas inicial, ajuda e configurações |

A conclusão das cinco ondas na suíte usa spawns reais e aplica dano de teste para verificar mortes e transições. **Não representa uma partida humana completa nem uma validação de dificuldade.**

## Conferência gráfica executada

O projeto foi importado no editor e executado em janela independente, com OpenGL Compatibility e Mesa llvmpipe. Foram observados menu, cenário 3D, personagens animados, HUD, painel de equipamentos, prévia de construção, instalação de torreta (saldo 140 → 65), início da primeira horda e troca para rifle (30/30).

Foram corrigidas barras excessivamente altas e a escala dos indicadores 3D. A execução embutida do editor apresentou erros X11 do ambiente; a conferência continuou em janela independente. O ambiente não fornece dispositivo de áudio: a geração dos sons foi executada, mas a qualidade sonora não foi ouvida.

## Correções encontradas durante a validação

- Vida de inimigo criado antes da onda 1 usava multiplicador 0,9; agora a escala nunca fica abaixo da vida base.
- Construção confirma a posição atual do cursor, em vez de depender da prévia do frame anterior.
- Verificação de barricada mede penetração no volume ocupado; desviar pela lateral é movimento válido.

## Limites

- Sem medição representativa de FPS, memória ou hardware mínimo.
- Sem playtest humano completo das cinco hordas.
- Execução de um `.exe` em Windows não validada neste ambiente Linux.
- O workflow configura validação e exportação; seu status deve ser consultado no GitHub Actions.
- Modelos procedurais e animações são de protótipo, sem rigging ou assets externos.
