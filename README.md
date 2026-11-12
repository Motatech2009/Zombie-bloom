# Zombie Bloom — Último Refúgio

Protótipo Godot **4.6.3**, single-player offline, GDScript, cenário 3D low-poly e câmera ortográfica isométrica. Geometrias, animações e áudio são gerados pelo projeto, sem assets pagos ou serviços externos.

**Saia da base, extraia recursos, carregue-os na mochila e volte para construir, reparar e fortalecer as defesas.** O primeiro trecho do mundo inclui recursos por seed, setores contínuos, estradas, rio com travessias, cidade, vila, fazenda, pátio industrial e interiores térreos com portas e recipientes persistentes.

É um protótipo das ideias WORLD-001–008. A localização principal dos assentamentos e a rede viária inicial ainda são fixas; relevo físico, cidades integralmente procedurais e simulação externa durante visitas a interiores não estão implementados. Consulte [o estado detalhado do mundo](WORLD_IMPLEMENTATION.md).

## Abrir e jogar

1. Instale a [Godot 4.6.3 padrão, sem .NET](https://godotengine.org/download/archive/4.6.3-stable/).
2. Baixe ou clone o repositório e importe `project.godot`.
3. Pressione F5 na engine e selecione **Explorar o mundo**.
4. Procure recursos fora do círculo do refúgio. Segure F junto a uma árvore, rocha ou caixa.
5. Retorne ao núcleo e pressione F para depositar; use B para construir.
6. Salve com F5 dentro do refúgio, entre hordas e sem hostis próximos. O menu passa a oferecer **Continuar refúgio**.

O **Desafio de cinco hordas** original continua disponível como modo separado, com vitória após a quinta onda. No modo de exploração, as hordas são iniciadas manualmente na base e podem continuar além da quinta.

A seed de uma nova expedição pode ser alterada em Configurações. Continuar usa a seed do arquivo salvo.

## Controles

| Entrada | Ação |
| --- | --- |
| WASD / Shift | Mover em relação à câmera / correr |
| Mouse / clique / R | Mirar / disparar / recarregar |
| 1 / 2 / 3 | Pistola / espingarda / rifle |
| Segurar F | Extrair recursos próximos, até o limite de 45 unidades |
| F | Entrar/sair de edifício, abrir/fechar porta ou depositar junto ao núcleo |
| B / 1–2 / clique | Construir barricada ou torreta; botão direito cancela |
| E | Reparar uma estrutura próxima entre hordas |
| U | Melhorar a resistência de uma estrutura próxima |
| Espaço | Iniciar horda no refúgio |
| M / Tab / Esc | Mapa / equipamentos / pausa |
| F5 / F9 no jogo | Salvar na base / restaurar o checkpoint |

Você começa com 140 de sucata e três armas. A munição de reserva é ilimitada, mas os pentes exigem recarga. XP concede escolhas de evolução e há bônus temporários. No mundo, a sucata dos inimigos também ocupa a mochila até ser depositada. Madeira, pedra e metal são convertidos em sucata reaproveitável 1:1 no depósito; receitas separadas ainda não existem.

O salvamento é manual. Voltar ao menu sem salvar descarta o progresso desde o checkpoint. Portas, recipientes, recursos retirados, carga, atributos, núcleo e defesas são restaurados. Inimigos e bônus temporários não são. A morte do jogador ou a destruição do núcleo encerra a expedição em andamento.

## Testes

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/world_tests.gd
```

As suítes usam cenas e física reais da engine. Consulte [TEST_REPORT.md](TEST_REPORT.md) e [WORLD_IMPLEMENTATION.md](WORLD_IMPLEMENTATION.md) para evidências, parâmetros provisórios e comandos de revisão visual.

## Windows

Instale os templates 4.6.3 em **Editor → Gerenciar templates de exportação** e use **Projeto → Exportar → Windows Desktop**, ou:

```sh
mkdir -p builds/windows
godot --headless --path . --export-release "Windows Desktop" builds/windows/ZombieBloom.exe
```

O preset incorpora o PCK. Assinatura digital não configurada. O GitHub Actions está configurado para validar os dois modos e gerar `ZombieBloom-Windows-x64` quando a execução termina com sucesso. A configuração do workflow não comprova que uma exportação terminou ou que o executável foi testado no Windows.

## Documentação e limites

[Estado do mundo](WORLD_IMPLEMENTATION.md) · [Design original](GAME_DESIGN.md) · [Arquitetura](ARCHITECTURE.md) · [Balanceamento clássico](BALANCING.md) · [Testes](TEST_REPORT.md) · [Changelog](CHANGELOG.md)

A arte é geométrica e provisória. Balanceamento, diversão, FPS e consumo de memória precisam de avaliação com jogadores e no hardware alvo. Não há multiplayer, remapeamento de teclas, crafting complexo, fome/sede, resgate ou dia/noite. Interiores suspendem o exterior e não possuem inimigos nesta versão. Compatibilidade futura dos arquivos salvos depende de migração explícita do gerador.
