# Validação da Defesa 0.5 — 2026-11-12

**267 verificações aprovadas:** 85 do MVP, 127 da campanha ampliada e 55 da expansão. Godot 4.6.3 oficial, Linux. Logs atuais: `docs/integration-results.txt`, `docs/campaign-results.txt` e `docs/defense-results.txt`.

A expansão verifica modo infinito além da campanha (hordas 21/22), checkpoints separados, migração do save anterior, cinco armas, compra/consumo/recarga cancelada de foguetes, granadas finitas e recuperação, explosão em área com obstrução e dano próprio, poça corrosiva com expiração e dano às defesas, projétil do corrosivo, tiro e torreta em cães/voadores, atributos do Alfa e mapa físico além do limite antigo. A campanha percorre as 20 hordas e retoma o checkpoint 19 em cena nova.

Construção: 120 atualizações de prévia sem consulta completa de caminho; materiais mantêm suas instâncias; ocupação é limitada a 10 verificações por segundo; a grade de acesso é reutilizada e células temporárias são revertidas. Oito colocações reais tiveram mediana de **0.444 ms**, máximo de **1.799 ms**; uma colocação com **80 defesas existentes levou 6.21 ms**. Dados em `docs/build-performance.json`. São tempos de CPU da operação headless; excluem o quadro seguinte, shaders e renderização e não certificam ausência de travamento no Windows do usuário.

Conferência em janela nativa 1280×800, Mesa llvmpipe: seleção de campanha/infinito, HUD compacto, catálogo, colocação de barricada (140→120 sucata), nove silhuetas por fixture visual, seleção do lança-foguetes, lançamento de granada e arsenal de cinco armas. Modelos e efeitos continuam de protótipo. O helper `tests/defense_preview.gd` não integra o executável e usa hostis parados para revisão de arte.

Importação e suítes sem erros de script. A liberação do áudio aguarda o processamento do mixer nos testes, evitando falso vazamento de playback no encerramento rápido. Sem dispositivo ALSA para ouvir som. Não foi executada uma campanha humana completa nem o exe em Windows; dificuldade e desempenho no hardware alvo ainda precisam ser aferidos. Exportação/CI devem ser confirmados no Actions do commit entregue.

---

## Histórico 0.4

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
