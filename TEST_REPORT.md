# Relatório de testes — 2026-11-11

## Ambiente e comandos executados

Godot **4.6.3.stable.official.7d41c59c4**, Linux. Testes sem plugins de terceiros.

```bash
godot --headless --path . --editor --quit
godot --headless --path . --scene res://scenes/main/GameWorld.tscn --quit-after 60
godot --headless --path . --script res://tests/run_tests.gd
```

Resultado da suíte: **85 verificações, zero falhas**, código de saída 0. Importação final sem erros de script. O log reproduzível da suíte está em `docs/integration-results.txt`.

## Cobertura executada

| Área | Verificação |
| --- | --- |
| Vida | Dano negativo rejeitado, cura limitada, morte terminal |
| Jogador | Movimento por InputMap no CharacterBody3D real |
| Armas | Raycast e dano da pistola; seis chumbos da espingarda; dano/pente do rifle |
| Recarga | Cadência, bloqueio durante recarga, pente vazio, cancelamento ao trocar |
| Recompensas | Morte e coleta únicas, contagem de eliminações |
| Carteira | Rejeição de saldo insuficiente e gasto negativo |
| XP | Excedente, múltiplos níveis e pausa para escolher |
| Upgrades | Seis alterações efetivas e rejeição de seleção duplicada |
| Bônus | Absorção, renovação sem acumular e expiração dos três tipos |
| Construção | Sobreposição, jogador, núcleo, limites, distância e custo |
| Defesas | Instalação, reparo pago, limite de vida e não cobrar reparo desnecessário |
| Torreta | Dano em alvo visível e bloqueio por obstáculo sólido |
| IA | Ataque à barricada e ausência de penetração em seu volume durante movimento |
| Ondas | Spawn automático pelo temporizador, progressão, quantidades e tipos |
| Pausa | Congelamento do relógio e retomada |
| Desfecho | Vitória na quinta onda; derrota por jogador e por núcleo; resultado imutável |
| Menus | Construção das telas inicial, ajuda e configurações |

A conclusão das cinco ondas na suíte usa spawns reais e aplica dano de teste para verificar mortes e transições. **Não representa uma partida humana completa nem uma validação de dificuldade.**

## Conferência gráfica executada

O projeto foi importado no editor e executado em janela independente, com OpenGL Compatibility e Mesa llvmpipe. Foram observados menu, cenário 3D, personagens animados, HUD, painel de equipamentos, prévia de construção, instalação de torreta (saldo 140 → 65), início da primeira horda e troca para rifle (30/30).

Foram corrigidas barras excessivamente altas e a escala dos indicadores 3D. A execução embutida do editor apresentou erros X11 do ambiente; a conferência continuou em janela independente. O ambiente não fornece dispositivo de áudio: a geração dos sons foi executada, mas a qualidade sonora não foi ouvida.

## Correções encontradas durante a validação

- Vida de inimigo criado antes da onda 1 usava multiplicador 0,9; agora a escala nunca fica abaixo da vida base.
- Construção confirma a posição atual do cursor, em vez de depender da prévia do frame anterior.
- Verificação de barricada mede penetração no volume ocupado; desviar pela lateral é movimento válido.

## Limites

- Sem medição representativa de FPS, memória ou hardware mínimo.
- Sem playtest humano completo das cinco hordas.
- Execução de um `.exe` em Windows não validada neste ambiente Linux.
- O workflow configura validação e exportação; seu status deve ser consultado no GitHub Actions.
- Modelos procedurais e animações são de protótipo, sem rigging ou assets externos.

## Mundo de exploração 0.2

Execução local em Godot 4.6.3: **55 verificações do mundo e 85 do modo clássico, zero falhas**. Logs em `docs/world-results.txt` e `docs/classic-results.txt`.

A suíte nova verifica determinismo entre seeds e independência da ordem de visita, posse de setores negativos, IDs únicos em 49 setores, lotes sem sobreposição, entradas fora de vias/água, ponte, conservação de recursos e limite de carga, emendas físicas do chão, câmera em coordenadas distantes, descarregamento/recriação de setores, portas e recipientes persistentes, circulação pelos quatro cômodos a partir das colisões reais, compra/restauração de melhorias, arquivos inválidos, mapa/pausa, continuação além da quinta horda e retomada do disco em nova instância da cena.

Conferência gráfica por janela nativa: menu de exploração, terreno, caminho até a primeira casa, transição para interior com quatro cômodos, ruas/lotes da cidade e mapa regional. A revisão identificou e corrigiu faces do terreno invisíveis, deslocamento da câmera em viagens longas, sobreposição do painel de carga sobre modais e linhas do mapa fora da área prevista. Relevo, receitas separadas e simulação externa durante interiores permanecem fora desta entrega, conforme `WORLD_IMPLEMENTATION.md`.

Não foi feita certificação de desempenho no PC alvo, teste do executável Windows ou validação de diversão por sessão prolongada. Resultado do GitHub Actions deve ser lido separadamente do resultado local.
