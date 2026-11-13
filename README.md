# Zombie Bloom — Setores e Cercos 0.6

**Explore por partes. Volte antes do cerco. Mantenha o Núcleo vivo.**

Single-player offline, Godot 4.6.3, cenário 3D low-poly e câmera 2.5D. A versão da arena evolui para setores procedurais e hordas automáticas. Construção otimizada, HUD compacto, nove famílias de infectados, cinco armas e explosivos continuam presentes.

## Jogar

No Windows, extraia o ZIP e execute **ZombieBloom.exe**. No código-fonte, importe `project.godot` na Godot 4.6.3 e pressione F5. Escolha campanha de 20 cercos ou defesa infinita; cada modo tem seu próprio save.

O Núcleo está sempre no setor **(0,0)**. Vá a uma das quatro bordas, aproxime-se do círculo e pressione **E** para ir ao Norte, Leste, Sul ou Oeste. **M** abre o mapa com posição, lugares visitados e direção de volta. O relógio continua enquanto o mapa está aberto.

A primeira horda começa em **3min30s**, mesmo com você longe. As defesas continuam atirando e o Núcleo pode ser destruído durante a exploração. Depois de vencer, o próximo intervalo diminui progressivamente. **Não existe mais botão para iniciar hordas.** Cada cerco tem um chefe.

Cada entrada gera outro setor: terreno visual, obstáculos, população e loot mudam. Há locais tranquilos, multidões e domínios de chefe. As três caixas dão mais materiais nos lugares perigosos; armas escondidas são raras. E recolhe caixas próximas quando não há infectados a menos de 6 m. Você pode fugir sem eliminar todos. Ao sair, objetos não recolhidos são perdidos e o setor será gerado novamente na próxima entrada.

## Controles

| Entrada | Ação |
| --- | --- |
| WASD / Shift | Mover / correr |
| Mouse / clique / R | Mirar / disparar / recarregar |
| 1–5 | Armas possuídas |
| C | Granada em combate ou exploração |
| B / Q | Catálogo ou cancelar construção / girar peça |
| 1–6 na prévia / clique / botão direito | Selecionar peça / instalar / cancelar |
| E | Atravessar saída, recolher caixa ou reparar na base |
| G / X / F | Melhorar defesa / desmontar com confirmação / portão |
| V | Negociar perto do vendedor no Núcleo durante preparação |
| M / H / Tab | Mapa contínuo / ocultar atalhos / arsenal |
| F5 / F9 / Esc | Salvar / restaurar no Núcleo entre cercos / pausar ou fechar painel |

Campanha e infinito compartilham a exploração, mas só a campanha termina após o cerco 20. Durante invasão, sair do Núcleo é bloqueado; se já estiver longe, as saídas permitem aproximar-se de (0,0). O mapa consulta lugares, sem teleporte.

Saves versão 3: `user://zombie_bloom_campaign_v3.json` e `user://zombie_bloom_endless_v3.json`. Continuar importa saves 0.4/0.5 mantendo os originais. São preservados base, compras, recursos e progressão; a exploração antiga vira o novo mapa procedural. O relógio e o RNG também são salvos. Checkpoint automático no Núcleo ao concluir cerco ou retornar sem escolhas de XP pendentes; depois de escolher evolução pendente, use F5.

## Validação e documentação

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/campaign_tests.gd
godot --headless --path . --script res://tests/defense_tests.gd
godot --headless --path . --script res://tests/sectors_tests.gd
```

**342 verificações locais aprovadas**: 85 do MVP, 127 da campanha anterior, 55 de combate/construção e 75 dos setores/cercos automáticos. As cenas anteriores ficam para regressão; o menu abre `scenes/sectors/RoamingWorld.tscn`. O CI repete as quatro suítes e exporta Windows x64.

[Regras dos setores e cercos](WORLD_SECTORS.md) · [Armas e construção](CAMPAIGN.md) · [Testes](TEST_REPORT.md) · [Arquitetura](ARCHITECTURE.md)

Arte e áudio procedurais de protótipo. Dificuldade prolongada, FPS no PC alvo e execução nativa do exe em Windows ainda exigem aferição; os testes não substituem uma campanha humana completa.
