# Zombie Bloom — Campanha e Defesa Infinita

**Limpe áreas. Compre armas. Construa sua fortaleza.**

Evolução da versão de arena enviada pelo criador, preservando o visual 2.5D, o combate, as hordas iniciadas pelo jogador e a defesa do Núcleo. Godot 4.6.3, single-player offline, geometrias e sons procedurais.

## Jogar

No pacote Windows, extraia o ZIP e execute **ZombieBloom.exe**. Não precisa instalar Godot. No código-fonte, importe `project.godot` na Godot 4.6.3 e pressione F5. Escolha **Campanha / 20 hordas** ou **Defesa infinita**. Cada modo possui continuação própria.

Você começa com pistola, 140 de sucata, 12 madeiras, 4 componentes e 2 granadas. Explosões próximas ferem o sobrevivente; a parede bloqueia o dano de explosão em inimigos. **B** abre o catálogo. **M** mostra as áreas de coleta. O pátio está aberto desde o início; limpe seus infectados, recolha as três reservas com **E** e retorne pelo círculo de extração ao sul. Aproxime-se da barraca à esquerda do Núcleo e use **V** para comprar armas e materiais. Inicie a horda com **Espaço** quando estiver pronto.

## Sistemas da campanha

- Refúgio persistente e quatro áreas de combate/coleta separadas; somente a área visitada fica ativa.
- Campanha de 20 hordas e defesa infinita com quantidades, integridade e dano crescentes.
- Nove ameaças: errante, corredor, bruto, blindado, demolidor, corrosivo, cão infectado, asa infectada e Colosso Alfa a cada cinco hordas.
- Armeiro físico: pistola, espingarda, rifle, submetralhadora e lança-foguetes; granadas e foguetes finitos.
- Arenas de 110 × 110 m (antes 62 × 62 m), HUD compacto e atalhos ocultáveis.
- Barricada, torreta, muro, portão, estacas e posto de apoio; rotação, colisão, custos e três níveis por defesa.
- Núcleo melhorável até N4, reparos e desmontagem com devolução de metade dos materiais.
- XP e bônus do MVP preservados; balas comuns ilimitadas e pentes com recarga; explosivos consomem estoque.
- Checkpoints independentes por modo, importação do save 0.4, configurações e pausa.
- Construção com materiais reutilizados, prévia limitada a 10 verificações/s e grade de acesso reutilizada no clique.

## Controles

| Entrada | Ação |
| --- | --- |
| WASD / Shift | Mover / correr |
| Mouse / clique esquerdo / R | Mirar / disparar / recarregar |
| 1–5 | Equipar arma comprada |
| B | Catálogo de construção; fecha a prévia quando ativa |
| 1–6 / Q em construção | Selecionar peça / girar 90° |
| Clique esquerdo / direito | Instalar / cancelar prévia |
| E | Reparar perto no refúgio; recolher reserva ou extrair em expedição |
| G / X | Melhorar estrutura próxima / confirmar desmontagem |
| F | Abrir ou fechar portão próximo |
| V / M | Armeiro próximo / rotas de coleta |
| Espaço | Iniciar a próxima horda no refúgio |
| C / H | Lançar granada em combate / mostrar ou ocultar atalhos |
| Tab / Esc | Arsenal / pausa ou fechar painel |
| F5 / F9 | Salvar / restaurar na preparação do refúgio |

Saves: `user://zombie_bloom_campaign_v2.json` e `user://zombie_bloom_endless_v2.json`. O save 0.4 é lido e convertido ao continuar a campanha, mantendo o arquivo antigo. Checkpoint automático após horda e extração quando não há escolhas de XP pendentes. Depois de escolher uma evolução pendente, use F5 antes de sair. Morte do jogador ou do Núcleo encerra a tentativa e permite retomar o checkpoint. Nova campanha pede confirmação se existir save.

## Código e validação

Ponto de entrada: `scenes/campaign/CampaignWorld.tscn`. O `GameWorld.tscn` original permanece no repositório para a suíte de regressão, com cinco hordas e todas as armas liberadas; ele não é a campanha aberta pelo menu.

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/campaign_tests.gd
godot --headless --path . --script res://tests/defense_tests.gd
```

**267 verificações locais aprovadas**: 85 do MVP, 127 da campanha e 55 da expansão. O workflow repete as três suítes e exporta Windows x64. A arte é de protótipo; desempenho no PC alvo, execução nativa em Windows e balanceamento prolongado ainda exigem conferência.

[Regras e progressão](CAMPAIGN.md) · [Testes](TEST_REPORT.md) · [Arquitetura](ARCHITECTURE.md) · [Changelog](CHANGELOG.md)
