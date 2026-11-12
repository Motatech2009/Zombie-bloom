# Validação da campanha 0.4 — 2026-11-12

Godot 4.6.3 oficial, Linux: **103 verificações da campanha + 85 do MVP = 188 aprovadas, zero falhas**. Importação e execução headless da cena da campanha sem erros de script. Logs atuais em `docs/campaign-results.txt` e `docs/integration-results.txt`.

A nova suíte usa cenas, físicas e raycasts reais. Verifica posse de armas, compra única/proximidade/saldo, tratamento e materiais; transações atômicas; seis defesas, rotação, bordas contíguas, ocupação, níveis, Núcleo, portão que não fecha sobre personagem, estacas e cura; blindagem e demolidor; clique projetado a partir da posição do evento; mapas/pausa; viagem das quatro áreas, base retirada da árvore, preservação das mesmas defesas ao retornar, populações finitas, limpeza, três reservas conservativas e sem repetição; checkpoint e rejeição de dados inválidos; oito hordas com vitória e retomada em cena nova. Conclusão de hordas e limpeza nos testes usam dano de fixture para exercitar mortes e transições; não equivalem a uma partida humana completa.

Conferência gráfica por janela nativa 1280×800: menu, continuação, catálogo de seis peças, instalação de muro pelo clique (140→105 sucata), barraca/negociação, compra de espingarda (120→10), mapa com quatro cartões e bloqueios, entrada no pátio e infectados ativos. O cenário, câmera, HUD e modelos preservam a versão da imagem. Revisão corrigiu a projeção do clique que antes usava cursor do frame anterior e a validação de integridade após serialização numérica JSON.

Exportação Windows é feita pelo workflow no commit publicado. Seu resultado deve ser conferido no Actions. O ambiente nativo usa Mesa llvmpipe por CPU e não oferece áudio ALSA; não certifica desempenho na GPU do usuário nem qualidade sonora. Execução nativa do `.exe` em Windows e balanceamento de sessão longa permanecem sem validação. Arte e áudio são procedurais de protótipo.

---

## Relatório histórico do MVP

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
