# Mundo em setores e cercos automáticos — 0.6

O Núcleo e suas construções são o único lugar fixo. O mundo é percorrido por quadrados de 110 × 110 m, com coordenadas e quatro saídas físicas. Há espaço entre as cenas; atravessar exige E próximo ao círculo na borda, sem caminhada contínua ou teleporte pelo mapa. Entrar em um quadrado cria sua população e cenário; sair descarta esse setor. Retornar gera outro conteúdo.

## Relógio, invasão e chefes

Primeira preparação: 210 segundos de simulação. Após vencer a horda n: máximo entre 100 e (180 − 3n) segundos. Não há início manual nem sobreposição forçada de cercos: a preparação seguinte só começa quando todos os infectados e o chefe da horda atual morrerem. Pausa por Esc e telas que declaram pausa congelam a simulação; o mapa de setores permanece em tempo real.

O relógio segue durante exploração. Avisos em 60, 30 e 10 segundos; no zero, a horda começa no Núcleo, fecha o mapa se aberto e emite alarme. Estar longe não oferece imunidade à base: terreno, núcleo, defesas e inimigos permanecem na árvore e na física. Torretas e estacas continuam lutando; chefes, corrosão e ataques podem destruir estruturas e causar derrota. Contagem de horda usa apenas seus próprios inimigos, sem incluir a população do setor explorado.

Durante invasão, sair do setor (0,0) é bloqueado. Fora dele, uma transição só é aceita se reduzir a distância de Manhattan até o Núcleo. Não há botão que leve instantaneamente de volta. Uma incursão profunda pode exigir percorrer várias saídas; é possível perder a base antes de chegar.

Cada horda reserva o primeiro spawn para um chefe, alternando Carrasco Alfa, Carapaça Alfa, Arqui-corrosivo, Matriarca Alada e Predador Alfa. Eles usam comportamentos melee, blindagem, corrosão, voo e investida. Vida base do chefe: 220 + 32 × nível, multiplicada pela escala de vida da horda; ao menos 18 de dano base e recompensas de chefe. Os tipos normais mais fortes também aparecem progressivamente conforme a horda avança.

A campanha mantém 20 cercos, de 18 a 240 infectados. O infinito continua depois da horda 20, somando 16 inimigos por horda adicional. Vida: 1 + 0,12n + 0,003n²; dano: 1 + 0,055n; velocidade até 1,75×, onde n é o número de hordas anteriores. Limites ativos: 36 inimigos de horda + até 24 do setor, no máximo 60 físicos. As filas aguardam vagas; o limite não concede vitória nem remove ameaças pendentes.

## Geração por visita

Entrada sorteia uma seed nova e incrementa a visita do quadrado. Seed, coordenadas e visita determinam o descritor; ele contém bioma, risco, obstáculos, posições de spawn, população, caixas e possível arma. A ordem do RNG é preservada no checkpoint. Repetir o mesmo checkpoint reproduz sua sequência; atravessar normalmente e revisitar produz outra geração.

Biomas visuais: subúrbio, pátio industrial, bosque morto, zona agrícola e ruínas militares. Entre 10 e 18 grupos de obstáculos com tamanhos e posições variáveis. Uma cruz de passagem é reservada entre as quatro bordas; geração não fecha as rotas por geometria. As posições de spawn precisam estar livres e a pelo menos 18 m do jogador; a população entra aos poucos. Não há perseguição de uma cena descartada para outra.

| Risco | População total | Recursos-base nas três caixas: sucata / madeira / componentes |
| --- | ---: | --- |
| Tranquilo | 0–5 | 45 / 18 / 3 |
| Patrulhado | 8–16 | 90 / 30 / 8 |
| Denso | 28–45 | 180 / 55 / 20 |
| Infestado | 65–95 | 390 / 110 / 42 |
| Domínio de chefe | 90–140, incluindo chefe | 700 / 180 / 75 |

Recursos variam ±15% por entrada e são divididos de forma conservativa entre as três caixas. A distância até o Núcleo e as hordas vencidas aumentam a tendência a risco alto. Perto da base, o sorteio pode produzir poucos ou nenhum infectado; não há garantia de que um lugar tranquilo continue tranquilo na próxima visita.

E recolhe uma caixa a até 3 m, se não houver inimigo a menos de 6 m dela. Limpar todo o setor é opcional: atrair os guardas para longe e recolher sob risco também é possível. Cada caixa só paga uma vez na visita. Ao sair, infectados, caixas, perigos e fragmentos daquele quadrado são descartados; materiais já recolhidos e armas adquiridas permanecem com o jogador. Drops da base não são descartados na viagem.

## Armas escondidas

Cada entrada tem 2% de chance de gerar um arsenal extra; em domínio de chefe, 6%. O sorteio não garante arma depois de determinada quantidade de visitas. O arsenal fica oculto até o jogador chegar a menos de 10 m, em posição aleatória nas passagens internas, fora das zonas de chegada.

Pode conter espingarda, rifle, submetralhadora ou lança-foguetes. Arma inédita libera o slot e o pente; o lançador inclui três foguetes de reserva. Se já possuída, converte em duas granadas e 35 sucata. Não há duplicação por repetir E no mesmo arsenal. Armas também continuam compráveis com Bento.

## Orientação

M abre mapa 7 × 7 em torno do jogador, sem pausar. Mostra coordenadas, quadrados visitados e último risco observado; (?) é desconhecido e (!) marca o último risco alto. Núcleo (0,0) tem destaque fixo quando está no recorte. O texto indica quantos setores seguir em cada direção mesmo quando o Núcleo estiver fora da janela. Norte reduz y, Leste aumenta x, Sul aumenta y e Oeste reduz x.

Clique consulta/seta referência de um quadrado e não move o personagem. O risco histórico é informação da visita anterior, não previsão do próximo sorteio. A grade técnica vai de −4096 a +4096 em cada eixo; o mapa mantém os últimos 8192 registros, retendo o Núcleo. Somente o setor atual e o Núcleo possuem cenário e física ativos; os demais não são um mundo carregado em paralelo.

## Checkpoints

Formato 3, arquivos separados por modo: `zombie_bloom_campaign_v3.json` e `zombie_bloom_endless_v3.json` em user://. Incluem contador de horda, tempo restante da preparação, seed, estado do RNG em string de 64 bits, histórico do mapa e todo o estado da base/arsenal preservado da 0.5.

Continuar procura primeiro o formato 3, depois importa o formato 2 ou 1 sem modificar o arquivo original. A importação mantém compras, recursos e defesas e inicia o novo relógio em 210 s; as quatro áreas finitas antigas não são convertidas em setores persistentes. Saves inválidos são recusados antes de aplicar.

Salvar/restaurar somente na preparação do Núcleo. Não há checkpoint de combate ou de setor transitório; após derrota, retoma-se a última preparação salva. Permanecem escrita temporária, renomeação e backup. Helpers visuais de tests/ não escrevem campanhas e são excluídos dos exports.

Os números são balanceamento inicial. Não houve sessão humana completa para certificar a curva de dificuldade ou duração de uma incursão profunda.
