# Escopo aprovado — Zombie Bloom 1.0

A 1.0 usa Firebase Authentication + Cloud Firestore, com ranking comunitário simples. A configuração pública do projeto `zombiebloom` foi incluída; serviços e regras reais ainda precisam ser validados; veja [RELEASE_1_0.md](RELEASE_1_0.md).

1. Contas por e-mail, recuperação por link e apelido público.
2. Três rankings gerais por conta: zumbis mortos, hordas vencidas e sucata coletada.
3. Envios em lote, sem banco por abate nem ranking em tempo real.
4. Menu inicial mais limpo no PC/Android, mantendo o cenário de fundo e versão no canto inferior direito.
5. Loja do PC reorganizada em categorias, lista e detalhes antes da compra.
6. Trilha mais sombria e intervalos progressivos 10/10/8/6/5/3 minutos.
7. Preservar controles mobile, desempenho e estabilidade de conexão já aprovados pelo usuário.

Sem serviço adicional de verificação de anfitriões nesta versão. Não incluir novos modos/infectados, saves na nuvem, ranking mensal ou premiações neste escopo.

Antes da versão final: conectar projeto dedicado, testar contas/ranking entre dois dispositivos reais, conferir recuperação por e-mail, validar regras no Firebase real e repetir cooperação PC/Android.
