# Zombie Bloom 0.13.2 — saltos do convidado ao andar

## Problema e reprodução

O anfitrião andava normalmente, mas o convidado acumulava previsões e sofria recuos de vários metros. O caso foi reproduzido com dois processos ENet reais e convidado limitado a 30 FPS, em loopback. Em uma execução anterior à correção, o recuo máximo observado foi de 4,515 m e o histórico chegou a 49 entradas pendentes.

## Causa e correção

A implementação de `ENetMultiplayerPeer.create_server()` na Godot 4.6.3 encaminha a quantidade explícita de canais para o argumento de banda de entrada. A sala usa cinco canais. O limite minúsculo resultante faz o ENet descartar grande parte dos comandos não confiáveis enviados pelo convidado; ele continua prevendo movimento enquanto o anfitrião fica sem novas entradas.

Após criar a sala e antes de receber convidados, `peer.host.bandwidth_limit(0,0)` remove esse limite indevido. Os limites de frequência, tamanho e validação de comandos do jogo continuam ativos. A autoridade de movimento, dano, inventário e rolamento permanece no anfitrião.

Fonte conferida na versão usada: [Godot 4.6.3 — enet_multiplayer_peer.cpp](https://github.com/godotengine/godot/blob/4.6.3-stable/modules/enet/enet_multiplayer_peer.cpp). O teste novo observa o limite efetivo de throttle do convidado, além da trajetória, em vez de verificar apenas a chegada final.

A câmera agora acompanha a posição apresentada pelo modelo e suaviza posição e ponto observado juntos. Pequenas reconciliações não inclinam mais o cenário. Snapshots do próprio convidado somente agendam reconciliação: até correções grandes esperam o passo de física para alterar o colisor.

## Verificação

O teste real de movimento limita o convidado a 30 FPS, mantém caminhada contínua por 2,5 segundos, observa recuos e proximidade da previsão, confere orientação da câmera e solta o movimento para verificar a parada. O anfitrião valida distância percorrida e desconexão.

Primeira execução corrigida: recuo máximo de 0,0000 m, deslocamento visual máximo de 0,1050 m, limite de throttle 32 e variação da base da câmera abaixo da precisão impressa. São medidas de um teste local controlado; não representam garantia de latência em 4G ou entre casas.

Total de regressão: 1018 verificações — 896 nas 15 suítes, 113 com quatro processos cooperativos e 9 no novo teste de movimento com dois processos reais. Há também testes de câmera durante reconciliação e proteção contra escrita de posição fora da física.

Instale 0.13.2 tanto no anfitrião quanto nos convidados. A correção de transporte exige recriar a sala com o anfitrião atualizado. A assinatura Android, o pacote e os checkpoints v6 são preservados. O APK ainda precisa ser validado nos aparelhos físicos.
