# Fortaleza e airdrops 0.9

## Coleta

Drops de infectados, objetos descartados e materiais de sobreviventes caídos são recolhidos automaticamente ao passar a menos de **1,65 m**. Não exige E nem afastar os inimigos. Os materiais entram na **bolsa**, respeitando suas pilhas/espaços; o excedente permanece no chão. XP e bônus são coletados mesmo quando faltam espaços para os materiais. Um mesmo drop não pode premiar duas pessoas. No cooperativo, o anfitrião escolhe o sobrevivente mais próximo com capacidade; os clientes recebem o resultado.

Drops de voadores caem no chão. Descartar coloca o objeto a 2,3 m, fora do raio de coleta imediata de quem descartou.

**Caixas regionais continuam demoradas:** segure E por 2,8 s por lote de até quatro unidades; arsenal escondido leva cinco segundos. Movimento, dano e ameaça próxima interrompem a coleta. O airdrop é outra caixa manual, com regras abaixo. Materiais de qualquer origem só pagam construções depois de depositados no Núcleo.

## Materiais e modelos das melhorias

As dez defesas possuem modelos próprios para N1, N2 e N3: madeira/sucata, aço reforçado e concreto/blindagem. Melhorar com G troca a geometria e os materiais, além de aumentar os atributos. Os primeiros seis tipos mantêm seus índices e custos anteriores. O Núcleo tem quatro modelos de fortificação e continua chegando ao N4. O portão eleva apenas a porta; o quadro fica fixo.

| Atalho na construção | Defesa | Função | Custo: sucata / madeira / componentes |
| --- | --- | --- | --- |
| 1 | Barricada | Barreira de baixo custo | 20 / 4 / 0 |
| 2 | Torreta | Tiro automático contra solo e ar | 75 / 0 / 4 |
| 3 | Muro reforçado | Barreira resistente | 35 / 6 / 2 |
| 4 | Portão | Passagem elevatória com F | 35 / 6 / 2 |
| 5 | Estacas | Dano de contato em terrestres | 15 / 5 / 0 |
| 6 | Posto de apoio | Cura o grupo e repara defesas na preparação | 60 / 4 / 5 |
| 7 | Arame farpado | Corta, deixa passar e desacelera terrestres | 25 / 2 / 1 |
| 8 | Muralha pesada | 900 de integridade inicial, contrafortes | 90 / 8 / 8 |
| 9 | Canhão automático | Projétil com dano em área | 180 / 4 / 15 |
| 0 | Torre elétrica | Descarga em até três inimigos | 150 / 2 / 18 |

B abre o catálogo com rolagem. Na prévia, 1–9/0 escolhem peças, Q gira e clique instala. Mantêm-se limite físico de 120 estruturas e cota compartilhada de 6–12 novas peças por preparação. Não é permitido selar a passagem ao Núcleo; portões, estacas e arame são tratados como rotas atravessáveis no validador. Melhorias não contam como novas peças.

O arame causa 8 × nível de dano por pulso de 0,8 s, aplica redução de 45% na velocidade por 1,2 s e sofre desgaste ao funcionar. Não afeta voadores nem desacelera aliados. O canhão começa com 68 de dano, raio de 3,8 m, alcance de 22 m e intervalo de 2,4 s; a granada defensiva não causa dano a aliados/Núcleo. A torre elétrica começa com 24 de dano, alcance de 11 m e intervalo de 1,5 s; alcança três alvos visíveis, perde 20% de dano por alvo e interrompe por 0,35 s, incluindo voadores. Ambos melhoram com o nível e podem ser desativados por EMP.

## Airdrop a cada dez minutos

A cada **600 segundos de partida ativa**, uma caixa cai em um setor aleatório a até três travessias do Núcleo. Nunca cai em (0,0). Há uma queda ativa por vez: o próximo evento substitui a anterior. Não depende de abrir o mapa nem de voltar à base. No solo, pausa real congela o relógio; mapa, mochila e menus do cooperativo mantêm a simulação ativa.

O HUD mostra o próximo horário ou a coordenada da queda. M marca o setor em dourado, mostra a direção e oferece **VER AIRDROP** para centralizar a consulta na queda, inclusive se estiver fora do trecho atual do mapa. Isso não teleporta o jogador. O paraquedas aparece durante os oito segundos da descida; depois a caixa fica no chão.

A área da queda recebe risco máximo e uma população mínima de 48 + 3 × horda (com crescimento limitado na fórmula). A escolta acrescenta **20 + 2 × horda** guardas-base, até 60, incluindo um chefe. Quantidades totais multiplicam por x1/x2/x4/x8 conforme o grupo; materialização continua limitada (até 12 guardas de escolta ativos e 24 hostis do setor, dentro do limite global de 60). Tropas da área recebem mais vida/dano; a escolta recebe reforço adicional. Chefes mantêm seus poderes.

É preciso derrotar toda a escolta exigida e esperar a caixa pousar. Os guardas derrotados ficam registrados durante o evento: fugir e entrar novamente gera outro cenário, mas não recria o chefe já morto nem zera o progresso da escolta. Os vivos podem retornar com vida cheia. Mesmo depois de abrir o bloqueio, inimigos comuns próximos interrompem a coleta, como nas outras caixas.

Segure E por **cinco segundos por lote**. Cada lote tenta transferir uma pilha do item disponível, conservando o restante se a bolsa estiver cheia. Recompensa: 160 sucata, 60 madeira, 24 componentes, munição, quatro granadas, dois kits e uma arma aleatória comprável. É necessário transportar a carga ao Núcleo. O cerco continua: decidir entre buscar a queda e defender a base é parte do risco.

## Saves e coop

Saves **v6** importam v1–v5, mantendo os arquivos originais. Gravam os dez tipos de defesa, seus níveis, bolsa/depósito e relógio/coordenada/conteúdo/progresso da queda. Clientes recebem o mesmo evento e modelos pelo anfitrião. Snapshots usam compressão e limites de decodificação para reduzir o tráfego ao transmitir escoltas e fortificações. Todos os participantes precisam atualizar para a 0.9.

Veja [ASSETS.md](ASSETS.md) para modelos editáveis e [TEST_REPORT.md](TEST_REPORT.md) para a validação. Valores são de uma versão para playtest; dificuldade prolongada e FPS no hardware alvo ainda precisam ser avaliados em partidas reais.
