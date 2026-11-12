# Último Refúgio — Beta 1

A Beta 1 implementa o ciclo integrado do GDD de 11/11/2026: explorar uma região procedural, extrair materiais, administrar slots e peso, retornar ao refúgio, fabricar peças e equipamentos, construir/reparar defesas e sobreviver a infectados e grupos migratórios. O mundo possui tempo contínuo, iluminação de dia/noite, neblina ajustável e persistência local por seed.

As regras novas e os números propostos no GDD foram adotados como parâmetros desta implementação, conforme a instrução do criador para concretizar o documento. Isso não transforma a lore proposta em resposta canônica sobre a infecção, o protagonista ou o Núcleo.

## Iniciar e jogar

Importe `project.godot` na Godot 4.6.3 e execute, ou use o executável exportado. **Explorar o mundo** inicia a campanha da seed selecionada em Configurações. **Continuar refúgio** retoma o arquivo dessa seed. Se já existe uma campanha, iniciar outra exige escolher explicitamente a nova partida; o arquivo antigo só é substituído quando a nova campanha for salva.

Os controles padrão podem ser redefinidos nas configurações durante a partida. Os rótulos de interação e a barra inferior acompanham as alterações. Esc e os atalhos numéricos da hotbar permanecem reservados.

| Controle padrão | Função |
| --- | --- |
| WASD / Shift | Deslocamento normalizado em relação à câmera / corrida |
| Mouse / clique esquerdo | Mira independente / ataque da ferramenta ou arma selecionada |
| Espaço | Rolar; sem WASD acompanha a mira, sem invulnerabilidade |
| E / segurar E | Entrar/sair, alternar porta, acessar recipiente, ler / extrair recurso |
| I / C | Inventário e equipamentos / fabricação |
| B / Q | Catálogo de construção / girar prévia 90 graus |
| Clique / botão direito em construção | Colocar peça validada / cancelar |
| F | Reparar estrutura próxima usando kit ou madeira e sucata |
| R / 1–6 | Recarregar com munição do inventário / usar os atalhos da mochila |
| L / M | Lanterna / mapa da região atual, sem teleporte |
| F5 / F9 | Salvar / restaurar a campanha da seed atual |
| Esc | Pausa ou fechamento do painel atual |

Uma rota inicial verificável é fabricar uma bancada com os materiais de partida, instalá-la junto ao refúgio, sair para extrair madeira/pedra e vasculhar recipientes, retornar para armazenar itens e fabricar tábuas/defesas. A residência ao norte/leste do refúgio oferece interior, portas, janela alterável e um registro ambiental. O mapa indica cidade, vila, fazenda, pátio industrial e vias de acesso.

## Matriz do GDD

| GDD | Entrega na Beta 1 | Evidência principal |
| --- | --- | --- |
| 1 e 1.1 — Identidade e loop | Campanha de exploração/construção; removidos controles de iniciar ondas e vitória por contagem | Menu e BetaWorld; execução gráfica do ciclo |
| 2, 4 — Mundo | Seed/versionamento, regiões expansíveis, limites modulados por ruído, relevo físico, rios contínuos, campos e vegetação | BetaGenerator/BetaRegion; testes de geração e colisões |
| 4.4 — Ocupação humana | Cidade, vila, fazenda, produção, imóveis isolados, lotes reservados e vias de acesso derivados da seed | Descritores determinísticos; entradas e mapa |
| 5 — Interiores | Térreo separado por transição, plantas por função, portas, recipientes, mobiliário e janelas intactas/quebradas/barricadas | Testes de reentrada, mudanças e salvamento |
| 6 e 7 — Ambiente | Relógio persistido, gradação de iluminação, noite/lanterna e neblina estável com transições | BetaTime; testes e conferência gráfica |
| 8 — Hostis/eventos | Errante e perseguidor; visão com obstrução, ruído, investigação limitada e retorno à rota; eventos aleatórios fora de visão, simulação agregada e orçamento de atores | BetaEnemy/BetaEvents; testes de visão, migração e salvamento |
| 9 — Personagem | WASD/mouse independentes, corrida e rolamento de direção travada, colisão e dano durante o rolamento | Testes físicos e direção sem WASD |
| 10 e 11 — Inventário/loot | Slots, pilhas, peso, sobrecarga, equipamentos, seis referências de hotbar, recipientes contextuais, transferências parciais, descarte persistente | BetaInventory; testes de conservação e retomada |
| 12 — Crafting | 15 receitas em Resource, fabricação manual/bancada, filtro, custos, indisponibilidade e transações com verificação de saída | catalog.tres/BetaCrafting; todas as receitas testadas |
| 13 — Base | Fundação, parede, portão, barricada, caixa, bancada e Núcleo; grade, rotação, prévia, colisão, terreno, acesso, consumo, dano e reparo | BetaBuild/BetaStructure; testes e instalação pela interface |
| 14 — Combate | Machado com alcance/obstrução reais, pistola e espingarda, recarga finita, reações, sons e estímulos | BetaWeapons; testes de raycast, melee e munição |
| 15 — Interface/opções | HUD, inventário, dois painéis de loot, crafting, construção, mapa, equipamentos, diário, áudio, resolução, teclas, texto e efeitos | BetaHUD; testes de painéis e inspeção gráfica |
| 3 — Narrativa ambiental | Cinco registros curtos entre Núcleo e categorias de edifício; sinal aberto após os cinco, sem encerrar a campanha | Diário e interações; mistério mantido sem resposta definitiva |
| 16 — Persistência | Formato e gerador explícitos, arquivo por seed, temporário/backup, validação antes da aplicação, inventários, estruturas, portas, recursos, relógio e hordas | BetaPersistence; retomada em nova instância e rejeição de dados inválidos |
| 17–19 — Arquitetura/QA | Serviços separados, vegetação e multidões instanciadas, orçamento ativo, três suítes e benchmark reproduzível | Código, CI, logs e métricas descritos abaixo |
| 20 — Exclusões | Sem veículos dirigíveis, NPCs/resgate físico, múltiplos andares, torretas, produção automatizada, fisiologia complexa ou multiplayer | Catálogo e controles da campanha não disponibilizam esses sistemas |
| 21–22 — Parâmetros e encaminhamento | Valores documentados como balanceamento inicial; não são cânone ou valores finais de lançamento | Este documento e o Resource editável |

## Regras concretas desta versão

- Setores de **64 × 64 m**, com anel de 3 × 3 e retenção do setor do refúgio: no máximo dez residentes. O setor do jogador entra imediatamente e os vizinhos são carregados de forma escalonada. A escolha ajusta a hipótese de 128 m do GDD para o protótipo medido.
- Regiões técnicas de 512 m com identificação geográfica modulada por ruído. A primeira região é um recorte jogável; a expansão produz novos assentamentos sem alterar os descritores existentes. Não é uma campanha de dezenas de regiões nem um simulador hidrológico: o relevo suaviza em direção aos rios e caminhos, e a água tem bloqueio/travessias em vez de física de líquidos.
- Câmera ortográfica centralizada, sem antecipação de mira, zoom de 26 a 40 m. Paredes dianteiras internas permanecem baixas visualmente e sólidas fisicamente; fachadas próximas podem ficar translúcidas.
- Mochila inicial de **24 slots / 30 kg**, ampliável para **30 slots / 40 kg**. Até 100%: movimento integral; 100–125%: 75%; 125–150%: 45%, sem corrida/rolamento; acima de 150% não entram novas unidades. Equipamentos e munição nos pentes contam no peso. Nenhum estágio imobiliza o jogador.
- Ferramentas/equipamentos individualizados ocupam um slot por unidade; pilhas de materiais e munição seguem o catálogo. O estado dos equipamentos referencia a mochila; não há inventários duplicados. Mochila equipada não pode ser transferida e a redução de capacidade é recusada quando os itens não cabem.
- Recipientes externos possuem inventário próprio e ID estável. Transferência parcial conserva o restante na origem. Derrubar itens dentro de um edifício mantém o recipiente naquele interior; caixas destruídas preservam o conteúdo em recipiente recuperável.
- **15 receitas** úteis, conhecidas desde o início. Crafting é instantâneo: não há fila ou cancelamento com consumo parcial. A bancada deve estar a menos de 4 m. O teste é feito sobre uma cópia do inventário antes de consumir insumos; saídas sem espaço não apagam ingredientes. Cliques repetidos imediatos têm proteção transacional.
- Construção consome a peça fabricada somente após validar posição. Área inicial de expansão: raio de 64 m, alcance de colocação de 10 m, grade de 2 m e até 80 estruturas. Fundação/paredes/portões seguem dimensões modulares. O validador mantém acesso lógico ao Núcleo e considera portões como aberturas controláveis.
- Reparos: um kit restaura até 100 de integridade; sem kit, 1 madeira + 1 sucata restaura até 60. O Núcleo tem 600 de integridade; sua destruição ou a queda do jogador encerra a expedição atual, permitindo retomar o último salvamento. A implementação não define resgate ou permadeath.
- Rolamento de 2,5 m / 0,55 s e recuperação de 0,50 s; deliberadamente não é transporte mais rápido que caminhar. Dano recebido continua válido. Movimento cancela o progresso de extração; ataque/extração simultâneos são bloqueados e rolar cancela a extração.
- Machado não usa munição e não atravessa paredes. Pistola e espingarda têm pentes próprios e consomem itens compatíveis na recarga; troca de arma cancela recarga sem duplicar itens. Guardar ou descartar a última arma de um tipo devolve a munição do pente à mochila na mesma transação, sem manter pentes ocultos fora da arma. Rifle e resistente são opcionais do GDD e não integram o catálogo jogável desta Beta.
- Um dia leva **48 minutos reais**, com iluminação contínua e noite entre 18h e 06h. O tempo continua nos interiores; pausa e menus de inventário/loot interrompem a simulação.
- Diretor avalia oportunidades em intervalos aleatórios e realiza sorteios ponderados por ocupação regional e progressão de dias, sem garantir evento por dia. Hordas têm **12–40 infectados**, grupos locais **3–8**, até duas migrações concorrentes e um grupo local. Atores físicos ativos limitados a 48; fora da área ativa a posição/rota/contagem são agregadas e salvas.
- O diretor nunca ordena ataque ao Núcleo pela passagem de um dia ou pelo anoitecer. Grupos podem investigar ruído ou luz próxima. Materialização exige setor residente, ausência de colisão, distância do jogador e margem fora do campo da câmera. Entrar em interiores exige afastar os hostis próximos; não há perseguição entre cenas.
- Interiores suspendem os atores físicos externos, mas relógio e eventos agregados continuam. Um grupo agregado já atraído até o Núcleo pode causar dano fora da tela. Isso não é simulação individual de todos os zumbis descarregados.
- A lore permanece deliberadamente contraditória. O sinal final abre uma possibilidade de exploração; não revela a natureza do Núcleo nem encerra a campanha.

## Dados, módulos e arquivos

`resources/beta/catalog.tres` é a fonte dos 25 itens, pesos, pilhas, 15 receitas e seis tipos de estrutura. Alterações de balanceamento não exigem editar a interface.

| Módulo | Contrato |
| --- | --- |
| BetaGenerator / BetaRegion | Descritores por seed/coordenadas, relevo e colisão, streaming/navegação |
| BetaInventory | Adição limitada, remoção, transferência, equipamentos e serialização |
| BetaCrafting / BetaBuild | Validação antes de consumir; resultado explícito e motivo de recusa |
| BetaWeapons / BetaPlayer | Pentes e reserva, dano/obstrução, mobilidade e interação |
| BetaEvents / BetaEnemy | IDs e estado agregado de grupos, estímulos, percepção e atores físicos |
| BetaCrowd | Onze lotes de desenho instanciado para corpos articulados, com limite de população |
| BetaTime / BetaOptions | Tempo, iluminação, fog, lanterna e preferências persistidas |
| BetaPersistence | Snapshot validado, escrita temporária, proteção de seed e restauração |
| BetaHUD | Painéis ligados aos serviços; não implementa uma economia paralela |

Salvamento: `user://ultimo_refugio_beta_<seed>.json`. Os arquivos 0.2 permanecem separados e não são migrados automaticamente. Uma gravação guarda `.bak`, mas a recuperação desse backup não é automática. O save é manual; o menu informa que sair não salva. Recursos/loot não reaparecem ao sair e voltar. Hordas preservam o estado agregado, sem prometer identidade e dano individual de cada ator após descarregamento.

## Verificação e desempenho

As suítes headless usam física e cenas reais. Os relatórios atuais estão em `docs/beta-results.txt`, `docs/classic-results.txt` e `docs/world-results.txt`. Os dois modos anteriores ficam como regressão técnica; a interface da Beta não oferece as ondas e torretas antigas.

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/world_tests.gd
godot --headless --path . --script res://tests/beta_tests.gd
```

Conferência gráfica reproduzível:

```sh
godot --path . --script res://tests/beta_preview.gd -- --zone=interior
godot --path . --script res://tests/beta_preview.gd -- --zone=night
godot --path . --script res://tests/beta_preview.gd -- --zone=city
godot --path . --script res://tests/beta_preview.gd -- --zone=migration --benchmark
godot --path . --script res://tests/beta_preview.gd -- --zone=migration --benchmark --low
```

O helper cria fixtures de revisão, inclusive população fixa e proteção temporária do personagem durante o benchmark, para manter a simulação ativa por 300 amostras após 90 frames de aquecimento. Esses controles não estão no jogo e `tests/` é excluído do executável exportado.

O ambiente gráfico disponível usa **Mesa llvmpipe (renderização por CPU)**, não uma GPU dedicada. Na cena de 32 infectados e nove setores, foram medidos aproximadamente **15,6 FPS** no padrão e **34,9 FPS** no modo leve (3D 50%, sombras desativadas), mantendo a interface em 1280 × 800. As métricas brutas ficam em `docs/beta-render-benchmarks.json`. São medições curtas deste ambiente, não certificação de 60 FPS nem estimativa de resultado em uma RX 7600. A meta provisória de 60 FPS do GDD precisa ser aferida no PC de destino.

A revisão de interface incluiu inventário, filtro de crafting, fabricação e colocação de bancada pelo clique real, retomada, dia/neblina e renderização da multidão. Som real depende do dispositivo disponível; o ambiente de teste não possui saída ALSA e usa o driver de áudio dummy. O código de áudio e os estímulos de gameplay continuam presentes no executável.
