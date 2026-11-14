# Zombie Bloom 0.15.0 — preparação progressiva e contas em integração

## Funcional nesta versão

- Preparação da próxima horda: 1/2 = 600 s; 3 = 480 s; 4 = 360 s; 5 = 300 s; 6+ = 180 s, campanha e infinito. O relógio é do anfitrião e o HUD recebe o restante. Política 2 nos saves v6 conserva o restante; saves antigos conservam o menor valor entre restante e novo limite. Nenhum arquivo de save foi renomeado ou apagado.
- Trilha original ambient mais grave, lenta e dissonante, sem melodia aguda contínua. Combate ganha pulsos e andamento, escolhas reduzem o volume; controle independente mantido. A preferência estética exige ouvir nos aparelhos; não há certificação de qualidade sonora física.
- Menu PERFIL / LOGIN / RANKINGS com apelido local persistente, formulário de e-mail/senha, cadastro, recuperação por código, logout e consultas separadas/paginadas de abates, hordas e sucata com filtro de modo. A tela é rolável em PC/Android. Não há dependência online para iniciar ou restaurar jogo.
- Estatísticas NÃO VERIFICADAS deste save na pausa, inclusive convidados via snapshots. Restaurar retrocede estatísticas, bolsas e loot juntos. Não são totais de carreira e não são enviados para ranking. Não há sincronização de saves entre aparelhos.

## Autoria e duplicação local

Abate pertence ao jogador que aplicou o golpe fatal (tiro, taco ou explosão atribuída); defesas/ambiente pertencem à categoria `team_defenses`, sem beneficiar automaticamente o anfitrião. Callback repetido de morte não credita novamente. Horda vencida credita uma vez por número de horda e identidade local a quem está conectado e vivo ao concluir; vale em qualquer quadrante. Não exige tempo mínimo de participação, portanto não é regra competitiva validada.

Sucata credita apenas a quantidade que entrou na bolsa a partir de caixas, casas, airdrops e drops originais. Bolsa cheia não credita o que ficou no chão. Depósito, retirada, compra, recompensa direta de horda, largar/recolher e suprimentos derrubados ao morrer não geram nova coleta. Pilhas com proveniências diferentes não se fundem. A proveniência acompanha checkpoint e memória setorial. Pilhas antigas sem proveniência restauram conservadoramente sem crédito. Consumo da fonte impede repetir coleta; memória setorial e checkpoint preservam esse consumo. As estatísticas pertencem ao save e podem ser alteradas por seu dono.

As identidades cooperativas existentes continuam locais (não são UID autenticados). Apelidos não vinculam esses dados a uma conta. Não há upload automático de estatísticas retroativas.

## Integração online implementada, mas NÃO ativada

`online.cfg` vem vazio. Adaptador em `scripts/online/account_service.gd` usa Supabase Auth/REST via HTTPS para autenticar, cadastrar, recuperar senha e salvar/carregar apelido público por UID entre PC/Android. Senhas e access tokens não são gravados em disco. Sessão expirada exige entrar novamente; não há refresh token persistido. Logout limpa sessão em memória mesmo se falhar a rede. Não criar contas de teste reais em execução automática.

Configurar um projeto Supabase dedicado e aplicar `backend/schema.sql` como administrador. Preencher apenas URL HTTPS e chave PUBLIC/anon no `online.cfg` (exportado no pacote). Nunca embutir service_role ou chave secret. Ativar confirmação de e-mail, configurar entrega e template de recuperação para incluir `{{ .Token }}`; a tela verifica o código recebido e troca a senha. Cadastro deve permitir confirmar e-mail no fluxo padrão do provedor e voltar ao jogo para entrar. Configurar limites de abuso antes de abertura pública. Nenhum projeto foi criado nem custo contratado nesta entrega.

SQL implementa perfil separado de auth.users (e-mail não sai nas consultas), escrita de apelido apenas via auth.uid(), ranking paginado de sessões fechadas e tabelas de eventos sem escrita por anon/authenticated. Chave de evento = sessão + evento + usuário + métrica; índice adicional impede dois autores para um abate. Hordas devem usar ID canônico da horda; sucata usa ID canônico da extração, não ID de requisição. Repetir evento deve usar ON CONFLICT DO NOTHING no validador. Perfil público recebe apelido, posição e pontos; nenhum e-mail.

**Bloqueio indispensável:** faltam URL/chave pública do projeto dedicado, aplicação do schema, configuração de e-mail e, principalmente, implementação/operação de servidor autoritativo que simule ou verifique partidas e vincule participantes a tokens válidos. O anfitrião ENet atual não é esse servidor. Somente esse futuro serviço poderá usar credencial de servidor para inserir sessões, participantes e eventos. Não há endpoint no cliente para submeter pontos. Sem esse serviço, os rankings permanecem indisponíveis/vazios; login sozinho não os torna competitivos. SQL é uma base de armazenamento restrita, não um anticheat nem um validador de combate.

## Evidência e limites

Godot 4.6.3. Suítes locais e CI cobrem progressão do relógio, migração/restauração, HUD, autoria de taco de convidado, mortes repetidas, vitória repetida, depósito/retirada e proveniência de sucata largada. Autenticação usa respostas simuladas para êxito/falha, confirmação, perfil remoto, recuperação e logout; menus PC e toque são instanciados em headless. Não houve teste com conta real nem execução SQL contra Supabase/PostgreSQL. Layout gráfico final, áudio e FPS em Android físico exigem teste nos aparelhos. Rede mantém exploração independente, taco, pausa de melhorias e câmera corrigida. Protocolo 15: atualizar todos para 0.15 e abrir sala nova. Assinatura Android de desenvolvimento e package ID preservados.
