# Zombie Bloom — Defesa 0.5

A versão 0.5 continua a arena escolhida pelo criador, com construção e defesa do Núcleo, expedições separadas e hordas iniciadas com Espaço. O visual 2.5D e os equipamentos anteriores foram preservados.

## Modos e duração

**Campanha:** 20 hordas, vitória ao concluir a vigésima. Quantidades: 18, 24, 32, 40, 48, 56, 65, 74, 84, 94, 105, 116, 128, 140, 154, 168, 184, 200, 218 e 240. Não há cronômetro na preparação; o jogador decide quando enfrentar a próxima.

**Defesa infinita:** usa a mesma progressão inicial e continua após a horda 20. Quantidade a partir da 21: 240 + 16 × (horda − 20), sem condição de vitória automática. Cada horda dá sucata, madeira e componentes; o vendedor fornece materiais continuamente, mesmo após esgotar as áreas de coleta. Morrer ou perder o Núcleo encerra a tentativa nos dois modos.

Até 36 inimigos físicos simultâneos, com entradas distribuídas por quatro lados. O restante aguarda na fila da horda; não é eliminado silenciosamente pelo limite de desempenho. Intervalo de spawn diminui até 0,12 s. Vida escala por 1 + 0,12n + 0,003n², dano por 1 + 0,055n e velocidade até 1,75×, onde n = hordas anteriores. Recuperação gratuita após horda caiu de 20 para 8 de vida.

Os valores aumentam a pressão mecânica; não são uma certificação de dificuldade ou estimativa de duração de uma sessão humana. Testes usam dano de fixture para concluir ondas e verificar progressão.

## Mapa e coleta

Refúgio e quatro áreas passam a **110 × 110 m**, ante 62 × 62 m: cerca de 3,15 vezes a área. O terreno, limites, colisões e navegação também foram ampliados. Construção até ±46 m, alcance de 12 m, grade de 1 m, rotação de 90° e máximo 120 peças. A câmera mostra uma área maior, acompanha o sobrevivente e mantém a mira independente.

| Área | Libera após horda | Hostis finitos | Sucata / madeira / componentes nas reservas |
| --- | ---: | ---: | --- |
| Pátio | 0 | 10 | 65 / 24 / 6 |
| Residencial | 1 | 16 | 95 / 30 / 10 |
| Fábrica | 3 | 22 | 145 / 18 / 22 |
| Militar | 5 | 30 | 210 / 20 / 30 |

O refúgio sai da árvore ativa enquanto a expedição está carregada e volta com as mesmas instâncias de defesas. Mortes e três reservas de cada área são finitas e persistentes. Limpe a população antes de recolher reservas com E. Recuo exige chegar ao círculo ao sul. Nenhuma horda ataca o refúgio durante uma expedição.

## Construção e desempenho

Seis peças: barricada (220 vida), torreta (180), muro (440), portão (320), estacas (150), posto de apoio (260). Custos N1, respectivamente, em sucata/madeira/componentes: 20/4/0, 75/0/4, 35/6/2, 35/6/2, 15/5/0 e 60/4/5.

G melhora a defesa até N3: +65% da integridade inicial por nível; torretas também ganham dano, cadência e alcance. N1→N2 custa 20/3/2 e N2→N3 custa 40/6/4. Núcleo chega a N4 e 1350 de integridade; cada melhoria custa 75/10/5 multiplicados pelo nível atual e soma 250 de capacidade. E repara 90 por 8 sucata. X pede confirmação e devolve metade do investimento, arredondado para baixo. F abre/fecha portão, sem fechar sobre ocupantes. Apoio cura o jogador e repara estruturas próximas na preparação; estacas ferem quem passa sobre elas. Torretas detectam e atingem alvos terrestres e aéreos com visão real.

A prévia reutiliza dois materiais e verifica ocupação a 10 Hz. Não cria um material nem reconstrói a grade de acesso a cada quadro. A grade persiste e só recompõe os bloqueios após mudanças no layout; a consulta de caminho roda ao confirmar o clique, aplica células temporárias e as restaura. O script da estrutura é pré-carregado, removendo sua compilação do primeiro clique. O débito só ocorre após a validação final. Portões preservam passagem controlável ao Núcleo; cenário, jogador, vendedor e extração não podem ser sobrepostos.

Fragmentos comuns têm população visual limitada: acima de 256, recompensas são somadas a uma pilha existente, preservando XP e sucata. Novos power-ups excedentes são descartados. Projéteis e poças também têm limites e são limpos nas transições. Isso evita acumular milhares de objetos ao longo do infinito.

## Ameaças

| Inimigo | Característica |
| --- | --- |
| Errante / corredor / bruto | Variantes anteriores; corredor aparece desde a primeira horda |
| Blindado | 140 vida base; recebe 60% do dano |
| Demolidor | 380 vida base, 32 de dano; prioriza Núcleo |
| Corrosivo | Desde horda 4; lança projétil arqueado em posição fixa com aviso; poça de 2,5 m dura 5 s e causa dano por segundo ao jogador e defesas |
| Cão infectado | Desde horda 2; quadrúpede de 55 vida base, rápido, investida curta e perseguição do sobrevivente |
| Asa infectada | Desde horda 3; 75 vida base, voo sobre barreiras baixas e ataque ao Núcleo; armas ajustam altura quando miradas em sua direção |
| Colosso Alfa | Um no início de cada quinta horda; 850 vida base e 42 de dano antes da escala da horda |

O voo não exige acertar um collider invisível no chão: a colisão está elevada. Mira assistida ajusta apenas a trajetória de tiro perto da silhueta de cão/voador; paredes continuam bloqueando raycasts. O corrosivo usa um alvo fixo, não projétil teleguiado, e a poça expira.

## Arsenal

| Controle | Arma | Compra / munição |
| --- | --- | --- |
| 1 | Pistola | Inicial; balas comuns livres |
| 2 | Espingarda | 110 sucata; balas comuns livres |
| 3 | Rifle | 220 sucata; balas comuns livres |
| 4 | Submetralhadora | 175 sucata; 40 no pente, cadência alta e maior dispersão |
| 5 | Lança-foguetes | 320 sucata; um carregado + cinco de reserva; 130 de dano base em área de 4,5 m |
| C | Granada | Duas iniciais; pacote de três por 45 sucata; alcance até 18 m, detonação após 0,85 s, 105 de dano base em área de 4,5 m |

Foguetes de reserva: cinco por 60 sucata. Cada recarga do lança-foguetes consome exatamente um ao concluir; cancelamento preserva a reserva. Granadas têm recuperação de 1,5 s. Dano de explosão cai com a distância, é bloqueado por sólidos para inimigos e fere o jogador perto do impacto. Explosivos não danificam a própria base. Compras exigem estar a até 5 m de Bento durante preparação. Materiais e tratamento continuam disponíveis.

## HUD e persistência

HUD: faixa superior compacta de vida, Núcleo, horda e recursos; arma e explosivos no canto inferior; três botões pequenos na preparação. H oculta atalhos, Tab abre arsenal. Lista de peças e comércio aparecem apenas em painéis; a loja usa rolagem. Mensagens e rótulos 3D são menores e contexto de construção só aparece quando útil.

Checkpoints versão 2 separados: `user://zombie_bloom_campaign_v2.json` e `user://zombie_bloom_endless_v2.json`. A continuação da campanha pode importar o save 0.4, acrescentando slots de armas e explosivos, sem sobrescrever o original. Um modo rejeita o snapshot do outro. Saves incluem estoque, atributos, cinco armas/pentes, explosivos, áreas finitas e defesas. Temporário + renomeação, backup e validação antecedem aplicação.

F5/F9 somente na preparação do refúgio. Checkpoint automático ao concluir horda ou extrair sem escolhas de XP pendentes. Se houver evolução pendente, resolva e use F5. Ataques, projéteis, poças e bônus temporários não são retomados. Continuar após derrota retoma o checkpoint anterior. O jogo segue single-player com arte procedural de protótipo, sem andares navegáveis ou veículos dirigíveis.
