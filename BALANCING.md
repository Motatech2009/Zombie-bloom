# Balanceamento inicial

Números de protótipo; diversão e dificuldade ainda exigem testes com jogadores. Edite os Resources citados abaixo e o catálogo.

## Armas — resources/weapons

| Resource | Dano | Intervalo | Alcance | Pente | Recarga | Chumbos |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| pistol.tres | 22 | 0,30 s | 26 m | 12 | 1,15 s | 1 |
| shotgun.tres | 13 | 0,85 s | 15 m | 6 | 1,90 s | 6 |
| rifle.tres | 12 | 0,105 s | 29 m | 30 | 1,55 s | 1 |

Dispersão em radianos no Resource. Cadência mínima 0,04 s; recarga mínima 0,2 s. Espingarda pode causar 78 por disparo se todos os chumbos acertarem. Não há dano por distância dentro do alcance.

## Inimigos — resources/enemies

| Resource | Vida | Velocidade | Dano | Intervalo de ataque | XP | Sucata |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| walker.tres | 44 | 2,15 m/s | 9 | 1 s | 7 | 5 |
| runner.tres | 30 | 4 m/s | 7 | 0,8 s | 10 | 6 |
| brute.tres | 180 | 1,45 m/s | 23 | 1,35 s | 22 | 15 |

Vida efetiva = vida base × (1 + 0,1 × max(0, onda − 1)). Dano e velocidade sem multiplicação oculta.

## Ondas — core/catalog.gd e systems/wave_manager.gd

| Onda | Quantidade | Composição | Intervalo de spawn | Recompensa |
| --- | ---: | --- | ---: | ---: |
| 1 | 12 | Errantes | 0,76 s | 45 sucata |
| 2 | 18 | Errantes | 0,67 s | 55 sucata |
| 3 | 25 | Corredor a cada 4 spawns | 0,58 s | 65 sucata |
| 4 | 32 | Corredor a cada 4 spawns | 0,49 s | 75 sucata |
| 5 | 40 | Bruto a cada 8; corredor a cada 4 restantes | 0,40 s | 85 sucata |

Primeiro índice é zero. Quinta onda: cinco brutos, cinco corredores e trinta errantes. Conclusão exige zero pendentes e zero vivos e recupera até 15 de vida do jogador.

## Estruturas — resources/buildings

| Resource | Custo | Vida | Custo de reparo | Recuperação | Ataque |
| --- | ---: | ---: | ---: | ---: | --- |
| barricade.tres | 25 | 180 | 8 | 65 | Bloqueio sólido |
| turret.tres | 75 | 140 | 10 | 55 | 15 dano / 0,4 s / 15 m |
| core.tres | — | 600 | 15 | 80 | Nenhum |

Sucata inicial 140; quatro caches de 15. Reparo cobra custo integral mesmo se a recuperação necessária for menor. Estruturas intactas não consomem recursos.

## Jogador, upgrades e bônus

Vida 100; movimento 6,3 m/s; corrida ×1,3. XP para próximo nível = 28 + 18 × (nível − 1). Excedente preservado. Upgrades repetíveis: dano ×1,2; cadência ×1,15; pente ×1,25, arredondado para cima; duração de recarga ×0,85; velocidade ×1,1; vida máxima +25 e cura de 25.

Drop de bônus: 22% por morte, tipos equiprováveis. Duração dez segundos. Velocidade ×1,45; cadência ×1,65; escudo 45. Nova coleta do mesmo tipo renova, sem acumular intensidade.
