> Atualização de elos/combate: veja [RANK_COMBAT_1_0.md](RANK_COMBAT_1_0.md).

> **Branch de desenvolvimento 1.0:** Firebase, rankings por conta e revisão de menu/loja. Configuração pública do Firebase `zombiebloom` incluída; ativação de serviços/regras reais ainda precisa de validação. Veja [RELEASE_1_0.md](RELEASE_1_0.md). A documentação 0.15 abaixo descreve a base histórica; seu adaptador Supabase foi substituído nesta branch.

# Atualização 0.15.0

Preparação progressiva, trilha sombria e integração de contas ainda não ativada. Consulte [ACCOUNTS_015.md](ACCOUNTS_015.md) antes de usar login/rankings. Todos devem atualizar e abrir sala nova (protocolo 15).

# Zombie Bloom — PC + Android 0.14.0

**Explore por partes. Transporte sua carga. Construa o refúgio. Sobreviva ao cerco.**

Godot 4.6.3, cenário 3D low-poly e câmera 2.5D. Campanha de 20 hordas, defesa infinita e cooperativo direto para até quatro jogadores. O Núcleo em (0,0) é fixo; cada nova entrada nos outros setores gera cenário, população e saque diferentes. As hordas começam pelo relógio e atacam a base mesmo quando o grupo está longe.

## Jogar

**Atualização 0.14.0:** dez minutos entre hordas, combate pausado durante melhorias, taco de beisebol, trilha original e exploração independente por jogador. [Regras e verificação](FRONTIER_014.md).

**Na 0.13.2:** corrigidos os saltos de posição do convidado ao andar e a câmera durante reconciliação. [Causa, teste e limites](NETWORK_0132.md).

**Na 0.13.1:** ações contextuais separadas, catálogos por categoria, munição no canto direito, correção da mira nos setores e tela cheia adaptável. [Detalhes](MOBILE_0131.md).

**Na 0.13:** qualidade gráfica aplicada sem reiniciar, materiais leves corrigidos, analógico flutuante, rotação pelo movimento, disparo ao segurar, botões transparentes, coleta contextual, barra compacta e menus maiores. Movimento/rolamento previstos no cliente, feedback imediato de tiro e tráfego de rede separado. [Mudanças, regras e limites](MOBILE_013.md).

**Novo na 0.12:** áreas preservadas por 3 minutos, chefes mais resistentes e com suprimentos extras, munição/consumíveis no loot regional e coleta 40% mais rápida sozinho. [Regras de exploração e saque](PROGRESSION.md).

**Novo na 0.11.2:** botão grande ATIRAR com seleção assistida, toque em zumbis para escolher um alvo e modo leve para celular com modelos agrupados, barras/efeitos limitados e contador de FPS. Windows e Android devem ser atualizados juntos.

**Novo na 0.11:** APK Android de teste e Windows do mesmo commit, dois controles de toque, menus adaptados e cliente móvel no mesmo mundo ENet dos PCs. [Instalação, controles e limites](MOBILE.md).

**Da 0.10:** acabamento de argila com texturas pequenas compartilhadas, cantos arredondados, braço corrigido, novas poses e animações, árvores/faixas ao vento, casas com interiores/guarnições/caixas e painel de conexão para jogar entre redes. [Regras e limites](CLAY_WORLD.md).

**Da 0.9.1:** rolamento no Espaço, animação, janela de esquiva de 0,20 s e recarga de cinco segundos controlada pelo anfitrião. O HUD mostra quando está pronto. Mantém saves v6.

**Da 0.9:** drops por proximidade; dez defesas com evolução visual de materiais; quatro fortificações novas e airdrop protegido a cada dez minutos. [Regras da fortaleza e das quedas](FORTRESS.md) · [Modelos e ícones](ASSETS.md).

Windows: baixe o artefato **ZombieBloom-Windows-x64** do Actions do commit mais recente desta branch, extraia e execute **ZombieBloom.exe**. Código-fonte: importe `project.godot` na Godot 4.6.3 e pressione F5. Modelos e efeitos são de protótipo.

- **Mochila:** 18 espaços; os primeiros nove são a barra rápida. I abre bolsa/depósito. Clique dois espaços para trocar. Munição, armas, materiais, granadas e kits ocupam espaço.
- **Casas:** duas a quatro por setor, com entrada física, teto ocultado por proximidade e caixa rica bloqueada pela guarnição. Guardas ficam mais fortes e numerosos com risco/horda/equipe. Cinco segundos por pilha; carga vai para a mochila.
- **Coleta:** drops no chão entram automaticamente na bolsa ao passar por perto. Caixas: 1,68 s por lote no solo ou 2,8 s em equipe; armas escondidas, casas e airdrops: 3 s no solo ou 5 s em equipe. Bolsa cheia mantém excedente no local.
- **Depósito:** leve os materiais ao Núcleo e segure E por 1,8 segundo para guardar. Construções gastam o estoque compartilhado do Núcleo. Itens carregados não pagam obras diretamente.
- **Construção:** dez tipos de defesa, incluindo arame, muralha pesada, canhão e torre elétrica. Melhorias trocam modelos/materiais. Seis novas peças na primeira preparação; a cota aumenta em uma a cada três hordas vencidas, até doze. É compartilhada pelo grupo e renova após o cerco. Desmontar não devolve cota. Melhorias/reparos de peças existentes não consomem colocações.
- **Combate:** nove armas, munição finita para todas, explosivos e kits. Barras de vida legíveis em tela; chefes com ataque anunciado em área, armadura temporária, invocações e fúria. Investidor, Criogênico e Sabotador ampliam as famílias anteriores. Revólver, rifle de precisão, metralhadora e Arco Tesla ampliam o arsenal.
- **Recursos:** estoque inicial menor, caixas com aproximadamente 45% dos materiais anteriores e metade da sucata por infectado. Saque precisa ser transportado. Vencer a horda continua creditando uma recompensa ao Núcleo.

A primeira horda chega em **3min30s**; depois, o intervalo diminui até 100 segundos. Não há botão para iniciar hordas. O mapa M e a mochila continuam com o relógio ativo. Há setores tranquilos e outros onde fugir é melhor que tentar limpar. Saque abandonado e progresso ficam preservados até vencer o prazo de três minutos da geração; depois, uma nova entrada renova o setor. Use as quatro saídas e o mapa para voltar antes do alarme.

O airdrop cai a cada **dez minutos**, marcado em M, em uma área infestada com escolta e chefe. Elimine os guardas para abrir a caixa. O evento mantém progresso durante a visita e o retorno; o próximo substitui a queda anterior.

## Jogar com amigos

**JOGAR COM AMIGOS → CRIAR SALA** no PC anfitrião. Os outros informam o IP dele e a mesma porta, padrão **24567 UDP**, e clicam **ENTRAR NO IP**. Na mesma rede, use o IPv4 local do anfitrião. Pela internet, é preciso conectividade UDP até ele, por encaminhamento da porta ou rede virtual adequada; não há relay ou código de convite.

Dois jogadores: **x2** infectados; três: **x4**; quatro: **x8**. A quantidade total cresce, mantendo limite de inimigos ativos e gerando o restante em levas. Grupo viaja junto entre setores. Mochilas individuais, estoque e construção compartilhados. Menus do cooperativo mantêm a simulação ativa. Segure E junto de um aliado caído por 3,5 segundos, com kit na bolsa, para reanimá-lo.

Em casas diferentes, abra **Esc → CONEXÃO / AMIGOS**. O anfitrião pode solicitar configuração UPnP e copiar o endereço externo, quando o roteador permitir. Convidados podem colar IP:porta. Em CGNAT ou sem porta alcançável, o painel orienta conexão por Tailscale. Não há relay próprio nem garantia de abertura pelo roteador.

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
godot --headless --path . --script res://tests/clay_tests.gd
godot --headless --path . --script res://tests/internet_tests.gd
godot --headless --path . --script res://tests/mobile_tests.gd
python3 tests/run_coop_test.py
```

**1071 verificações aprovadas localmente**: 342 anteriores, 80 de sobrevivência, 95 de arsenal, 100 de fortaleza, 33 de rolamento, 35 de argila/casas, 31 de conexão, 48 móveis, 35 de mira por toque, 26 de desempenho/controle assistido, 43 de progressão, 30 de experiência móvel, 113 de rede com quatro processos reais 9 de movimento com dois processos ENet e convidado limitado a 30 FPS, 31 das novas mecânicas e 20 de exploração em setores distintos com três processos. Um cliente de rede usa a interface de toque em Linux; não substitui teste em aparelho físico. O menu abre `scenes/survival/SurvivalWorld.tscn`; as cenas anteriores permanecem para regressão. CI repete as suítes, o teste de ENet/UDP, exporta Windows x64 e APK Android assinado para desenvolvimento.

[Regras de sobrevivência](SURVIVAL.md) · [Cooperativo](MULTIPLAYER.md) · [Setores](WORLD_SECTORS.md) · [Armas e defesas anteriores](CAMPAIGN.md) · [Testes](TEST_REPORT.md)

Verificação de rede foi por loopback, sem latência/perda simulada. Conexão real entre casas, desempenho no hardware alvo, execução nativa no Windows e balanceamento de uma campanha humana completa ainda precisam de playtest. O artefato Windows só deve ser considerado exportado após sucesso do Actions do commit entregue.

Android: baixe o artefato **ZombieBloom-Android-APK**, extraia e instale o APK de teste. No PC, crie uma sala; no celular, entre pelo IPv4 do PC e porta UDP 24567. Atualize ambos. Fora da mesma rede, veja as opções de conexão externa e Tailscale em MOBILE.md. Ainda não há versão iOS nem validação em telefone físico.

Planejamento futuro: [login e rankings da versão 1.0](ROADMAP_1_0.md).
