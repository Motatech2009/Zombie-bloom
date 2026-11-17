# Serviço de conta da 1.6

A candidata usa Firebase Authentication existente, Firestore e `account16Api` (HTTP, Functions v2, Node 22). A URL está em `[services16]` de `online.cfg`; ela não concede privilégios. Nenhuma credencial administrativa deve entrar no jogo.

## Publicação no projeto existente

A execução local tentou consultar `zombiebloom`, mas o CLI respondeu `Failed to authenticate, have you run firebase login?`. Não houve publicação nem alteração administrativa no projeto real.

Com acesso de administrador, a partir da raiz do repositório:

```sh
npm ci --prefix backend/firebase/functions --ignore-scripts
firebase login
firebase deploy --config backend/firebase/firebase.json --project zombiebloom --only firestore:rules,functions:account16Api
```

Se o Firebase indicar exigências de plano, permissões, API ou faturamento, resolvê-las no projeto antes de continuar; não contornar com uma carteira gravável pelo aplicativo. A candidata deve continuar identificada como RC enquanto o serviço real e o fluxo autenticado não forem conferidos.

Endpoint esperado: `https://us-central1-zombiebloom.cloudfunctions.net/account16Api`.

## Contrato e confiança

POST com ID token Firebase em `Authorization: Bearer ...`, corpo `{action, data}`. A identidade sempre vem do token verificado, nunca de `data.uid`. Ações: `profile`, `sync`, `start`, `horde`, `purchase`, `equip`.

- `accounts16/{uid}` mantém saldo, propriedade/equipamento, tempo agregado, limites e partida ativa.
- Subcoleções `sessions`, `matches`, `ledger` mantêm checkpoints e eventos idempotentes. Só o Admin SDK do serviço escreve.
- Uma vitória válida acrescenta 100 Brotos por conta, sem dividir entre aliados. ID: partida + índice da horda. Créditos anteriores não são recriados ao reabrir o save.
- A sequência é estrita, depende de partida registrada, tempo observado no servidor e participação ativa acumulada. Há intervalo global mínimo de 60 s entre créditos e limite inicial de 150 créditos por dia UTC. Preparação mínima da campanha/infinito: 600/600/480/360/300/180 s; resgate: 60 s. São limites de serviço, separados da simulação de combate.
- Tempo ativo usa checkpoints cumulativos de sessão e orçamento global de tempo decorrido, compartilhado por todos os aparelhos da conta. Reenvio não soma novamente; aparelhos simultâneos não multiplicam o mesmo orçamento. O orçamento não gasto pode cobrir reconciliação offline, limitado a sete dias. Tempo anterior ao primeiro registro online não é certificado retroativamente.
- Resultado offline não vira saldo automaticamente. Hordas anteriores ao primeiro registro de partida não são elegíveis; o retorno do registro remove essas pendências da fila e informa a limitação. Resultados posteriores sem comprovação temporal suficiente continuam pendentes para nova tentativa. A interface diferencia horas locais, horas confirmadas e saldo confirmado.
- Compra consulta preço/ID no catálogo do servidor e confirma débito + propriedade na mesma transação. Saldo insuficiente, classe errada ou operação reaproveitada com outro item falham.
- Transações concorrentes, respostas perdidas e repetições preservam idempotência. Logs de rejeições 409/429 ajudam revisão de anomalias; não registram senha nem token.

**Limite explícito:** o jogo continua P2P. Esses controles limitam abuso de economia comunitária, mas não provam cada inimigo morto em um servidor independente. Não apresentar ranking ou carteira como antitrapaça competitiva completa. Premiação física continua dependendo de validação do criador.

## Regras e testes

As regras protótipo preservam o ranking existente e negam acesso direto a todos os documentos privados `accounts16`. O endpoint devolve somente o perfil filtrado da identidade autenticada. A suíte de emuladores verificou escrita direta recusada, isolamento entre contas e transações; revisar também a configuração real antes de ampla distribuição.

```sh
node --test backend/firebase/functions/test/*.test.js
firebase emulators:exec --config backend/firebase/firebase.json --project demo-zombie-bloom --only auth,firestore,functions 'node backend/firebase/functions/test/emulator-integration.js && godot --headless --path . --script res://tests/release16_meta_emulator_test.gd'
```

Em ambientes que proíbem sockets Unix do Functions Emulator, o teste alternativo expõe **o mesmo handler** em TCP, com Auth/Firestore reais emulados:

```sh
firebase emulators:exec --config backend/firebase/firebase.json --project demo-zombie-bloom --only auth,firestore 'node backend/firebase/functions/test/run-emulator-http.js'
```

O projeto `demo-zombie-bloom` impede que esses testes criem jogadores fictícios no banco de produção.
