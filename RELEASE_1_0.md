# Zombie Bloom 1.0 — candidata em desenvolvimento

Esta branch mantém a jogabilidade da 0.15 e implementa as decisões da 1.0 com Firebase. **Não é uma versão final: a configuração pública do projeto `zombiebloom` está incluída; ativação de Authentication, banco e regras reais ainda precisam de validação.**

## Entregas

- Cadastro, login e recuperação por link usando Firebase Authentication (e-mail/senha).
- Apelido e três rankings gerais por conta: abates, hordas vencidas e sucata obtida do mundo. Campanha e infinito somam no mesmo placar.
- Autoria de abates e coleta individual usa as estatísticas que o jogo já possui. Mortes por defesas de equipe ficam nas estatísticas da equipe, sem somar falsamente para o host.
- Não existe serviço adicional para verificar anfitriões nesta etapa. É um ranking comunitário: clientes modificados podem falsificar seus próprios totais.
- Menu inicial mantém o cenário original, com botões compactos na lateral e versão lida de `project.godot` no canto inferior direito.
- Bento reposicionado mais à esquerda do Núcleo: de `(-6,0,5)` para `(-15,0,5)`, cerca de 16 m do centro.
- Loja do PC com categorias, ícones, descrição, atributos, preço e compra explícita. Arma já possuída, espaço insuficiente e falta de sucata bloqueiam a compra.
- Mantidos da 0.15: preparação de 10/10/8/6/5/3 minutos (por próxima horda) e trilha original mais sombria, com drones dissonantes, graves e percussão de combate.
- Controles mobile, previsão de movimento e suavização de câmera preservados.

## Configurar o Firebase dedicado ao jogo

Não reutilizar os projetos de saúde ou educação.

1. Criar/selecionar um projeto **dedicado ao Zombie Bloom** no Firebase.
2. Ativar Authentication → Sign-in method → E-mail/senha.
3. Criar Cloud Firestore em modo produção, banco `(default)`.
4. Registrar um aplicativo Web para obter a configuração pública; Godot usa a API REST diretamente, sem SDK Web.
5. Preencher `online.cfg` com `project_id` (projectId) e `api_key` (apiKey). Essas duas informações são públicas; nunca usar chave de conta de serviço nem senha.
6. Publicar `backend/firebase/firestore.rules` no banco dedicado. Via CLI, a partir dessa pasta: `firebase deploy --only firestore:rules --project SEU_PROJECT_ID`.
7. Conferir o modelo de e-mail de recuperação no Authentication e testar no PC e no Android.
8. Exportar novamente os dois aplicativos com a configuração preenchida. A versão sem configuração continua jogável como convidado e informa que as contas ainda não estão disponíveis.

A configuração pública fornecida pelo usuário foi incluída. O provisionamento real (Authentication, banco e regras) e sua verificação permanecem pendentes. Os emuladores usam exclusivamente `demo-zombie-bloom`, sem dados ou cobrança de um projeto real.

## Operações do banco

- Sem listeners, Analytics, gravação por abate, polling do ranking ou consultas sem limite.
- Contadores acumulam em memória e em arquivo local por conta/aparelho. Nenhuma senha, ID token ou refresh token é persistido. É preciso entrar novamente ao reabrir o jogo.
- Flush a cada 120 s de sessão, ao concluir horda e ao sair da partida. Sem diferenças: **zero leituras e zero escritas**.
- Cada lote com diferenças faz **1 leitura** do checkpoint privado do aparelho e um commit atômico com **2 escritas**: checkpoint e incremento dos três totais públicos.
- O checkpoint usa precondição `updateTime`/`exists`; se o servidor aceitar e a resposta se perder, a nova tentativa lê o checkpoint e não incrementa novamente.
- Durante jogo contínuo: normalmente até **30 leituras e 60 escritas por hora/jogador**, mais vitórias/saídas, login, troca de apelido e novas tentativas. Esse número é uma contagem de operações do cliente, não uma estimativa de cobrança.
- Cada login consulta o perfil uma vez. Criar perfil ou mudar apelido faz uma escrita.
- Ranking: top 25, consultado apenas pelo jogador; cache de 60 s por categoria e intervalo global de 15 s entre consultas remotas. Até 25 documentos retornados por consulta. Sem posição global individual calculada nem paginação por offset.
- O arquivo local é salvo periodicamente e ao pausar/sair; encerramento forçado pode perder os últimos segundos ainda não persistidos. Uma requisição pode não terminar durante o fechamento do processo; o lote persistido é retomado no próximo login da mesma conta.

## Regras de contagem

- Apenas progresso obtido enquanto a conta está conectada é registrado; o login durante partida estabelece uma linha inicial.
- Saves antigos não importam retroativamente seus totais. O progresso posterior conta normalmente.
- Transferência para o núcleo, retirada do depósito e recolher sucata descartada por jogador não contam como nova coleta.
- Recarregar e repetir um checkpoint não duplica o mesmo avanço já creditado naquele refúgio. Cada refúgio possui um identificador persistido no save e transmitido aos convidados.
- O checkpoint é local ao aparelho. Apagar dados locais pode remover lotes ainda não enviados e o histórico usado para evitar repetição de saves.
- Contas diferentes têm filas locais separadas. E-mail só vai para Authentication; documentos públicos contêm apelido e os três contadores. Checkpoints de aparelhos só são legíveis pelo dono.
- Login não sincroniza campanhas/saves entre dispositivos.

## Verificação

A candidata passou no [CI de 14/11/2026](https://github.com/Motatech2009/Zombie-bloom/actions/runs/43604055944): 1.206 verificações locais/integradas e 14 nos emuladores Firebase, totalizando 1.220. Exportações Windows e Android, assinatura do APK e quatro renders de interface concluídos. O projeto Firebase real permanece pendente.

- `tests/account_tests.gd`: respostas simuladas, falha de rede, resposta perdida, progresso durante envio, renovação de token, cache e formulários.
- `tests/account_world_tests.gd`: ligação das estatísticas ao jogo, troca de conta, save restaurado, autoria de convidado e compra real na loja do PC.
- `tests/firebase_emulator_test.gd`: HTTP real contra Authentication/Firestore emulados com as regras do repositório, contas distintas, contadores, consultas limitadas e negação de acesso cruzado. Executado pelo CI; não confundir com teste no projeto de produção.
- `tests/release_preview.gd`: renderização real dos menus PC/mobile e loja para revisão visual.

Referências: [Auth REST](https://firebase.google.com/docs/reference/rest/auth), [Firestore REST](https://firebase.google.com/docs/firestore/use-rest-api), [commit atômico](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/commit).
