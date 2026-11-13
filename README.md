# Zombie Bloom — Fortaleza e Suprimentos 0.9.1

**Explore por partes. Transporte sua carga. Construa o refúgio. Sobreviva ao cerco.**

Godot 4.6.3, cenário 3D low-poly e câmera 2.5D. Campanha de 20 hordas, defesa infinita e cooperativo direto para até quatro jogadores. O Núcleo em (0,0) é fixo; cada nova entrada nos outros setores gera cenário, população e saque diferentes. As hordas começam pelo relógio e atacam a base mesmo quando o grupo está longe.

## Jogar

**Novo na 0.9.1:** rolamento no Espaço, animação, janela de esquiva de 0,20 s e recarga de cinco segundos controlada pelo anfitrião. O HUD mostra quando está pronto. Mantém saves v6.

**Da 0.9:** drops por proximidade; dez defesas com evolução visual de materiais; quatro fortificações novas e airdrop protegido a cada dez minutos. [Regras da fortaleza e das quedas](FORTRESS.md) · [Modelos e ícones](ASSETS.md).

Windows: baixe o artefato **ZombieBloom-Windows-x64** do Actions do commit mais recente desta branch, extraia e execute **ZombieBloom.exe**. Código-fonte: importe `project.godot` na Godot 4.6.3 e pressione F5. Modelos e efeitos são de protótipo.

- **Mochila:** 18 espaços; os primeiros nove são a barra rápida. I abre bolsa/depósito. Clique dois espaços para trocar. Munição, armas, materiais, granadas e kits ocupam espaço.
- **Coleta:** drops no chão entram automaticamente na bolsa ao passar por perto. Caixas exigem E por 2,8 segundos por lote; armas escondidas e airdrops exigem cinco segundos. Bolsa cheia mantém excedente no local.
- **Depósito:** leve os materiais ao Núcleo e segure E por 1,8 segundo para guardar. Construções gastam o estoque compartilhado do Núcleo. Itens carregados não pagam obras diretamente.
- **Construção:** dez tipos de defesa, incluindo arame, muralha pesada, canhão e torre elétrica. Melhorias trocam modelos/materiais. Seis novas peças na primeira preparação; a cota aumenta em uma a cada três hordas vencidas, até doze. É compartilhada pelo grupo e renova após o cerco. Desmontar não devolve cota. Melhorias/reparos de peças existentes não consomem colocações.
- **Combate:** nove armas, munição finita para todas, explosivos e kits. Barras de vida legíveis em tela; chefes com ataque anunciado em área, armadura temporária, invocações e fúria. Investidor, Criogênico e Sabotador ampliam as famílias anteriores. Revólver, rifle de precisão, metralhadora e Arco Tesla ampliam o arsenal.
- **Recursos:** estoque inicial menor, caixas com aproximadamente 45% dos materiais anteriores e metade da sucata por infectado. Saque precisa ser transportado. Vencer a horda continua creditando uma recompensa ao Núcleo.

A primeira horda chega em **3min30s**; depois, o intervalo diminui até 100 segundos. Não há botão para iniciar hordas. O mapa M e a mochila continuam com o relógio ativo. Há setores tranquilos e outros onde fugir é melhor que tentar limpar. Saque abandonado some ao sair. Use as quatro saídas e o mapa para voltar antes do alarme.

O airdrop cai a cada **dez minutos**, marcado em M, em uma área infestada com escolta e chefe. Elimine os guardas para abrir a caixa. O evento mantém progresso durante a visita e o retorno; o próximo substitui a queda anterior.

## Jogar com amigos

**JOGAR COM AMIGOS → CRIAR SALA** no PC anfitrião. Os outros informam o IP dele e a mesma porta, padrão **24567 UDP**, e clicam **ENTRAR NO IP**. Na mesma rede, use o IPv4 local do anfitrião. Pela internet, é preciso conectividade UDP até ele, por encaminhamento da porta ou rede virtual adequada; não há relay ou código de convite.

Dois jogadores: **x2** infectados; três: **x4**; quatro: **x8**. A quantidade total cresce, mantendo limite de inimigos ativos e gerando o restante em levas. Grupo viaja junto entre setores. Mochilas individuais, estoque e construção compartilhados. Menus do cooperativo mantêm a simulação ativa. Segure E junto de um aliado caído por 3,5 segundos, com kit na bolsa, para reanimá-lo.

Instruções completas, reconexão e limites: [MULTIPLAYER.md](MULTIPLAYER.md).

## Controles

| Entrada | Ação |
| --- | --- |
| WASD / Shift | Mover / correr |
| Espaço | Rolar na direção do movimento; parado, seguir a mira. Recarga de 5 s |
| Mouse / clique / R | Mirar / usar item ou disparar / recarregar |
| 1–9 / I ou Tab | Selecionar espaço da barra / mochila e depósito |
| C | Atalho de granada |
| B / Q | Catálogo ou cancelar construção / girar peça |
| 1–9 / 0 na prévia / clique / botão direito | Selecionar peça / instalar / cancelar |
| Passar pelos drops / segurar E nas caixas | Coleta automática / coleta demorada |
| Segurar E no Núcleo ou junto a aliado | Depositar / reparar / reanimar |
| E junto à saída | Viajar ao setor adjacente |
| G / X / F | Melhorar defesa / confirmar desmonte / abrir portão |
| V / M / H | Vendedor / mapa contínuo / ocultar atalhos |
| F5 / F9 | Salvar / restaurar na preparação no Núcleo (anfitrião controla o save) |
| Esc | Fechar painel / menu; cooperativo continua em andamento |

## Saves e validação

Saves v6: `user://zombie_bloom_campaign_v6.json` e `user://zombie_bloom_endless_v6.json`. Importam v1–v5 preservando os arquivos antigos. Bolsa, depósito, cota, base e perfis dos convidados ficam no save do anfitrião. Marque **Continuar o refúgio salvo deste modo** ao abrir outra sala. No solo, cada modo mantém sua opção de continuar.

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/campaign_tests.gd
godot --headless --path . --script res://tests/defense_tests.gd
godot --headless --path . --script res://tests/sectors_tests.gd
godot --headless --path . --script res://tests/survival_tests.gd
godot --headless --path . --script res://tests/arsenal_tests.gd
godot --headless --path . --script res://tests/fortress_tests.gd
godot --headless --path . --script res://tests/roll_tests.gd
python3 tests/run_coop_test.py
```

**730 verificações aprovadas localmente**: 342 anteriores, 80 de sobrevivência, 93 de arsenal/visual, 100 de fortaleza, 33 de rolamento e 82 de rede com quatro processos reais. O menu abre `scenes/survival/SurvivalWorld.tscn`; as cenas anteriores permanecem para regressão. CI repete as suítes, o teste de ENet/UDP e exporta Windows x64.

[Regras de sobrevivência](SURVIVAL.md) · [Cooperativo](MULTIPLAYER.md) · [Setores](WORLD_SECTORS.md) · [Armas e defesas anteriores](CAMPAIGN.md) · [Testes](TEST_REPORT.md)

Verificação de rede foi por loopback, sem latência/perda simulada. Conexão real entre casas, desempenho no hardware alvo, execução nativa no Windows e balanceamento de uma campanha humana completa ainda precisam de playtest. O artefato Windows só deve ser considerado exportado após sucesso do Actions do commit entregue.
