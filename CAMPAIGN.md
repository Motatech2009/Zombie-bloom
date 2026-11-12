# Campanha de defesa e expedições — 0.4

Esta versão parte exatamente dos 76 arquivos do ZIP `Zombie-bloom-feat-godot-survival-mvp.zip`, correspondente ao commit b073ab6. A proposta de mundo aberto da Beta anterior fica em outra branch. A campanha atual usa a arena original, preparação sem cronômetro e hordas iniciadas voluntariamente.

## Ciclo de progressão

Preparar o refúgio → sair para uma área → eliminar os infectados → recolher reservas → extrair → negociar e construir → defender o Núcleo → desbloquear novas áreas.

| Área | Libera depois da horda | Hostis finitos | Sucata nas reservas | Madeira | Componentes |
| --- | ---: | ---: | ---: | ---: | ---: |
| Pátio de cargas | 0 | 10 | 65 | 24 | 6 |
| Quarteirão residencial | 1 | 16 | 95 | 30 | 10 |
| Fábrica abandonada | 3 | 22 | 145 | 18 | 22 |
| Depósito militar | 5 | 30 | 210 | 20 | 30 |

Cada área usa uma cena gerada com geometria e colisões próprias. O refúgio é removido da árvore ativa e mantido em memória; ao voltar, retornam as mesmas instâncias de suas defesas. A área de expedição é liberada ao sair. Não existe simulação de uma horda atacando a base durante a expedição.

Hostis entram em pequenos lotes, até 12 vivos simultâneos. A limpeza só ocorre ao eliminar toda a população. Cada morte tem índice persistente; recuar não recria os mortos. Três reservas só abrem após limpar a área, cada uma concede uma parcela exata do total e nunca se repõe. Loot de inimigos é separado dessas reservas. Ao extrair, fragmentos soltos da expedição são recolhidos; o retorno exige estar a menos de 4 m do círculo ao sul. Não há teleportar de qualquer ponto durante combate.

## Construção

| Peça | Sucata / madeira / componentes | Vida N1 | Função |
| --- | --- | ---: | --- |
| Barricada | 20 / 4 / 0 | 220 | Barreira acessível |
| Torreta | 75 / 0 / 4 | 180 | 15 de dano, intervalo 0,65 s, alcance 15 m, visão obstruída |
| Muro reforçado | 35 / 6 / 2 | 440 | Camada mais resistente |
| Portão | 35 / 6 / 2 | 320 | F abre/fecha; não fecha sobre jogador ou infectado |
| Estacas | 15 / 5 / 0 | 150 | 14 de dano por nível a cada 0,8 s a infectados sobre elas |
| Posto de apoio | 60 / 4 / 5 | 260 | Na preparação, cura jogador a 5 m e estruturas a 6 m |

Grade de 1 m, rotação de 90°, alcance 12 m, área de instalação até ±24 m, máximo 80 peças. Testa custo e ocupação antes de consumir. Peças podem compartilhar a borda. Um teste de acesso em grade recusa fechar completamente o trajeto entre saída e Núcleo; portões são passagens controláveis e estacas não bloqueiam o trajeto. Cenário e personagem também impedem sobreposição física. A barraca e a extração têm área reservada.

G reforça a peça mais próxima a até 4,5 m. Defesas têm N1–N3: integridade +65% da base por nível; torretas também ganham dano, cadência e alcance. A melhoria N1→N2 custa 20 sucata, 3 madeiras e 2 componentes; N2→N3 custa o dobro. O ganho de integridade recupera apenas a diferença de capacidade, preservando o dano já sofrido. E repara 90 por 8 sucata, limitado ao máximo. X exige confirmação e devolve 50% dos materiais pagos na peça e melhorias, arredondados para baixo; não duplica reembolso.

O Núcleo começa com 600 de integridade. Cada melhoria soma 250, até N4 / 1350. Custo: 75 sucata + 10 madeiras + 5 componentes multiplicados pelo nível atual. Seus anéis adicionais mostram o reforço. Não existem andares navegáveis ou empilhamento vertical nesta versão: a expansão consiste em linhas de defesa no terreno e níveis de resistência.

## Armeiro e combate

Bento fica junto à barraca a oeste do Núcleo. Negociação somente na preparação e a até 5 m. Espingarda: 110 sucata; rifle: 220; cada arma é compra única e fica salva na campanha. Teclas e botões não equipam armas não compradas. Tratamento: até +60 vida por 25 sucata, sem cobrar quando cheio. 10 madeiras: 30 sucata; 4 componentes: 45. Todas as compras e construções validam saldo antes de alterar qualquer recurso.

Mantidos os pentes, recarga, raycasts, mira, corrida, XP, evolução e poderes temporários do MVP. A reserva de munição continua ilimitada. Não há inventário por peso ou crafting da Beta de mundo aberto.

| Horda | Quantidade | Novas ameaças |
| --- | ---: | --- |
| 1 | 12 | Errantes |
| 2 | 18 | Corredores |
| 3 | 25 | Brutos |
| 4 | 32 | Blindados: 140 de vida base, recebem 60% do dano |
| 5 | 40 | Mistura das variantes |
| 6 | 46 | Demolidores: 380 de vida base, 32 de dano, priorizam Núcleo |
| 7 | 54 | Mistura e escala de integridade |
| 8 | 64 | Defesa final |

Vida dos inimigos cresce 10% por horda concluída, como no MVP. Corredores perseguem o sobrevivente de mais longe; em expedições todos perseguem o jogador, pois o Núcleo está fora da cena. Ao vencer horda: 35 + 10×n sucata, 8 madeiras, 2 componentes e até +20 vida. A oitava encerra em vitória. Não existe repetição infinita nesta campanha.

## Persistência e limites

Checkpoint versão 1 em `user://zombie_bloom_arena_campaign.json`, escrito em temporário e renomeado, com `.bak` do anterior. Valida estrutura de dados e limites antes de aplicar; arquivo inválido preserva a partida em curso. Inclui hordas concluídas, estoque, moedas, XP/atributos, armas e pentes, posição, Núcleo, defesas e níveis, portões, fragmentos e limpeza/recompensas de cada área. Saves antigos da Beta ou do mundo de exploração não são migrados.

Salvar/restaurar só na preparação da base. Ações de combate em andamento não são checkpoints. Escolhas de evolução precisam ser resolvidas antes de salvar. Checkpoint automático no fim da horda e no retorno se não houver escolha pendente; caso contrário, salve por F5 após escolher. Poderes temporários e tempo de recarga não são retomados. A campanha não implementa multiplayer, veículos dirigíveis, interiores exploráveis ou andares físicos. Estes valores são balanceamento inicial, não resultado de uma sessão humana completa.
