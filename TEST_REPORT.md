# Validação do Arsenal 0.8 — 2026-11-13

**574 verificações locais aprovadas:** 342 anteriores, 80 de sobrevivência, 93 de arsenal/visual e 59 de rede (20 do anfitrião +13 por convidado). Logs em docs/arsenal-results.txt e nos arquivos de regressão/rede. Godot 4.6.3 oficial, Linux.

A nova suíte importa os ícones de todos os 20 itens, instancia seus modelos editáveis e confere a hierarquia de animação dos 13 modelos humanoides. Verifica nove estados de arma, seleção e modelo de cada arma nova, sniper atravessando exatamente três alvos com perda de dano, corrente Tesla de quatro alvos com perda de dano e bloqueio por parede, recarga parcial conservativa de munição pesada, compra real de Tesla/células, novos tipos na composição das hordas, telegráfico e movimento físico da investida, pulso criogênico com dano/lentidão e status replicado, EMP que interrompe e depois permite o retorno do disparo da torreta.

Saves: checkpoint automático inicial válido, v5 com nove armas, validação quando a pistola está fora da bolsa, restauração do arsenal, migração v4 incluindo perfis sem mutar a origem. Setor real contém arsenal raro com Tesla, mantém cinco segundos de coleta e concede exatamente uma arma com seu pente. Inventário e vendedor são abertos na cena real.

Rede: quatro processos reais por ENet/UDP, mantendo os testes anteriores e ampliando para nove estados de munição, concessão/seleção/disparo/modelo da Tesla com consumo validado no anfitrião, novo modelo de Criogênico e aviso de área nos três clientes. Também cobre depósito compartilhado, tiros anteriores, multiplicação x8 e troca de setores. Tudo em loopback; não certifica latência/perda nem internet entre casas.

Revisão gráfica 1280×800, Mesa llvmpipe e áudio Dummy: HUD em blocos, nove ícones de arma, destaque dourado da seleção, item/ammo no canto inferior, seis variantes com modelos diferentes e recursos/itens reconhecíveis no chão. Mochila com duas linhas de nove ícones, quantidades, depósito com imagens e sem sobreposição de controles. Fixture `tests/arsenal_preview.gd` não grava saves e não representa o início de uma partida. O PC virtual renderiza por CPU; não mede desempenho da RX 7600 ou de outro hardware alvo. Os modelos são low-poly procedurais, editáveis em Godot; não são personagens finais com animação esquelética.

Importação e suítes sem erro de script. Publicação e exportação Windows são confirmadas pelo CI no commit entregue. Não houve execução nativa em Windows nem campanha humana completa; equilíbrio prolongado permanece para playtest.

---

# Validação da Sobrevivência 0.7 — 2026-11-13

**469 verificações aprovadas localmente:** 342 anteriores, 80 da nova suíte de sobrevivência e 47 de cooperativo (17 do servidor e dez por convidado). Godot 4.6.3 oficial, Linux. Logs em `docs/survival-results.txt`, `docs/coop-results.txt` e nos quatro arquivos de regressão.

A nova suíte cobre conservação de pilhas e limites, rejeição atômica de bolsa inválida, coleta em lotes, tempo, cancelamento por movimento/dano/ameaça, excedente em bolsa cheia, depósito por proximidade e duração, retirada/armazenamento, munição finita e cancelamento de recarga, transferência do pente ao guardar/descartar, compra sem débito em bolsa cheia, seis colocações reais e bloqueio da sétima sem cobrança, cota não devolvida pelo desmonte e renovada após cerco, escala x1/x2/x4/x8, limite de participantes, queda/reanimação com kit, preservação de estado caído em perfil, poderes de chefe, telegráfico replicado, armadura/fúria/invocações, Berrador/Regenerador/Estourador, v4/migração v3 e UI de 18 espaços.

`tests/run_coop_test.py` inicia **quatro processos Godot reais** conectados por ENet/UDP em loopback. Confere entrada dos três convidados, movimento simulado no anfitrião, tiros reais matando inimigos, munição consumida no servidor e replicada, multiplicador exato, comandos indevidos sem mutação, transações simultâneas de depósito com conservação do saldo, carregamento de setor procedural por revisão de cena e retorno ao mesmo Núcleo. Desconexões reduzem a escala e removem avatares. Testes usam identidades locais distintas, porta de fixture 24577 e não gravam saves de jogo.

Revisão gráfica em janela 1280×800, Mesa llvmpipe: tela de sala, criação de anfitrião, HUD com cota e nove botões, mochila com depósito e quantidades, troca efetiva de pistola para o quinto espaço e seleção pela tecla 5. A coleta segurando E por 3,1 segundos colocou quatro madeiras na bolsa, mantendo o estoque do Núcleo em seis. Fixture visual conferiu barras constantes em pixels, fração de vida e chefe nomeado. As barras pequenas em texto 3D foram substituídas após essa inspeção. `tests/survival_preview.gd` é somente uma fixture de revisão, excluída do export e sem gravação de checkpoint.

As cinco suítes locais passaram sem erro de script, assim como os quatro processos de rede. As regressões de campanha usam cenas anteriores; não representam uma campanha humana completa nesta versão. O ambiente não tem saída ALSA, então a revisão gráfica usa driver de áudio dummy. O executável Windows é exportado pelo CI; seu resultado deve ser confirmado no commit entregue. Internet entre casas, reconexões sob perda de pacotes, desempenho no PC alvo e balanceamento de sessões longas permanecem sem certificação.

---

# Validação dos Setores 0.6 — 2026-11-12

**342 verificações aprovadas:** 85 do MVP, 127 da campanha anterior, 55 de combate/construção e 75 novas de setores/cercos. Godot 4.6.3 oficial, Linux. Logs atuais em docs/integration-results.txt, campaign-results.txt, defense-results.txt e sectors-results.txt.

A nova suíte verifica determinismo por visita e mudança ao revisitar, amostra com cinco riscos, arsenais raros, quatro saídas e mapa sem teleporte/pausa, translação de colisões/navegação/loot, conservação e reivindicação única de caixas, preservação das instâncias de base, relógio que dispara a primeira horda com o sobrevivente longe, chefe desde a primeira onda, contagens separadas de hostis, retorno permitido durante invasão e avanço bloqueado, corrosão remota, todos os 20 slots de chefe, cinco arquétipos, timer/RNG/histórico em saves, migração e infinito automático além da horda 20.

Verificação física adicional: um chefe ativado junto ao Núcleo moveu-se e aplicou dano enquanto o jogador estava em outro setor; uma torreta continuou disparando sobre um alvo da base. Não foi usado dano agregado para simular uma base distante. O resto das conclusões de onda/limpeza em testes usa dano de fixture e não representa uma partida humana completa.

Conferência em janela 1280×800: saída Norte por E, entrada procedural em (0,−1), aviso de setor infestado com 91 infectados, relógio em contagem durante exploração e mapa 7×7 com Núcleo (0,0), posição e retorno Sul. M manteve a simulação e o jogador recebeu dano durante a consulta, conforme a regra de mapa contínuo. O helper tests/sectors_preview.gd apenas posiciona o jogador junto à saída para revisão e desativa gravação de saves.

Importação sem erros de script. O ambiente usa renderização por CPU Mesa llvmpipe, sem saída ALSA. Desempenho no hardware alvo, exe nativo no Windows, qualidade sonora e balanceamento prolongado não estão certificados. O CI repete as quatro suítes e exporta Windows; seu resultado é confirmado separadamente para o commit entregue.

---

## Histórico 0.5

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
