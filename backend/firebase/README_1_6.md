# Economia comunitária da 1.6 — Firestore / Spark

A RC.5 usa Firebase Authentication existente e acesso REST ao Firestore nativo, sem Cloud Functions. Em online.cfg, services16.backend=firestore. A carteira não depende do endpoint account16Api.

## Ativação manual no projeto zombiebloom

1. Abrir Firestore Database > Regras no console do Firebase.
2. Substituir o conteúdo pelo arquivo completo firestore.rules desta pasta e clicar Publicar.
3. Usar a RC.5 nos aparelhos; entrar na conta, jogar uma partida registrada online, concluir uma horda e conferir o saldo. Comprar um item e entrar novamente para conferir saldo/inventário.

Não é necessário criar moedas/documentos manualmente, habilitar faturamento ou fornecer credenciais ao jogo. A carteira começa com zero. As regras preservam players e devices do ranking. Não houve publicação real: o CLI continua sem autenticação administrativa; não foi possível confirmar a edição do banco real por essa via. É mantido o banco nativo (default) usado pelo jogo, sem provisionar instâncias. A edição Standard foi validada no emulador.

## Dados e garantias verificadas

- community16/{uid}: carteira privada por conta, saldo, IDs de cosméticos, equipamentos, horas e limites. Compras consultam preços fixos nas regras. Só são aceitos débitos exatos com propriedade criada na mesma gravação atômica; nenhum saldo livre enviado pelo aplicativo é aceito.
- matches/{run}: partida, modo, linha de base e última horda creditada. Avanço e +100 Brotos precisam acontecer juntos. Sequência estrita e controle de concorrência por updateTime evitam crédito repetido. Compra repetida do mesmo item retorna propriedade já existente sem novo débito.
- sessions/{id}: checkpoint cumulativo de horas. A soma e o checkpoint são atômicos, com orçamento global limitado ao tempo desde a criação online da conta. Sessões repetidas não somam duas vezes. Horas locais anteriores continuam no aparelho, sem certificação retroativa.
- Hordas anteriores ao primeiro registro não pagam retroativamente. Mínimos entre créditos da partida: 600/600/480/360/300/180 s; resgate 60 s (três hordas). Mínimo global 60 s e teto 150 créditos/dia UTC. Relógio do banco valida os limites, sem aceitar datas de crédito do cliente.
- Troféu do Titã não pode ser comprado; concessão única exige partida ativa Campanha/Infinito registrada há 120 s. O jogo conserva a regra de contribuição local/P2P.
- Catálogo de 22 IDs fechado; equipamentos só aceitam itens possuídos, da classe e slot corretos. Preços e IDs das regras devem acompanhar data/release16/catalog.json.
- Menu ocioso não fica consultando o banco. Horas são enviadas em lotes a cada 120 s, com até 16 checkpoints por sincronização. Pendências econômicas param no primeiro erro, conservando a fila.
- Troca do backend não importa saldo/cache local como dinheiro. accounts16 permanece reservado ao serviço opcional. Saldos de backends diferentes não são misturados nem migrados automaticamente.

## Limites de confiança

Regras validam contabilidade, identidade e limites, mas não executam o combate. Um cliente alterado pode simular vitórias ao longo do tempo ou declarar uma vitória contra o Titã; não há prova independente por servidor. Horas ativas reportadas também não provam atividade humana. Esta é uma economia comunitária para cosméticos, sem dinheiro real ou promessa de antitrapaça competitivo. Limites gratuitos e cotas do Firestore continuam aplicáveis.

I've set up prototype Security Rules to keep the data in Firestore safe. They are designed to be secure for owner isolation, fixed catalog prices, atomic debits and bounded reward transitions. However, you should review and verify them before broadly sharing your app. If you'd like, I can help you harden these rules.

As regras são um protótipo com testes em emuladores; revisar configuração e fluxo reais antes de ampla distribuição.

## Validação local / CI

A partir da raiz do repositório, com Firebase CLI, Java 21+ e Godot 4.6.3:

~~~sh
firebase emulators:exec --config backend/firebase/firebase.json --project demo-zombie-bloom --only auth,firestore 'node backend/firebase/test/spark-economy.js && godot --headless --path . --script res://tests/spark_economy_emulator_test.gd'
godot --headless --path . --script res://tests/balance16_tests.gd
~~~

37 verificações REST de regras e concorrência, 17 de integração Godot, 10 de balanceamento. Os únicos seeds administrativos ficam em testes excluídos dos executáveis e usam explicitamente o emulador demo-zombie-bloom.

## Serviço com Functions preservado para o futuro

backend/firebase/functions conserva o serviço account16Api (Node 22). É opcional e exige seu próprio deploy/plano; não é usado na configuração atual. Para mudar, configurar services16.backend=service e publicar/conferir o serviço e suas regras. accounts16 permanece sem acesso direto do cliente. Nenhuma chave administrativa entra no jogo. Essa implementação também não substitui um servidor independente de combate.
