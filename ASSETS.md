# Assets visuais 0.8

33 ícones vetoriais e 33 modelos low-poly editáveis, criados para este projeto. Não dependem de download de assets ou plugins de geração durante o jogo.

| Conteúdo | Local | Quantidade |
| --- | --- | --- |
| Ícones de armas, munição e itens | assets/icons/*.svg | 20 |
| Ícones de HUD | assets/icons/*.svg | 7 |
| Ícones de construção | assets/icons/*.svg | 6 |
| Modelos de armas | assets/models/weapon_*.tscn | 9 |
| Modelos de itens/recursos | assets/models/item_*.tscn | 11 |
| Modelos de infectados humanoides | assets/models/infected_*.tscn | 13 |

Abra os SVGs em um editor vetorial. Abra os TSCNs como cenas Godot para editar geometria, materiais, hierarquia e proporções. Modelos usam primitivas e materiais reutilizados, preservando o estilo da arena. Os rigs humanoides mantêm LegL/LegR/ArmL/ArmR para a animação existente. Cães e voadores usam os rigs próprios anteriores com complementos de geometria.

`ModelFactory` em scripts/presentation/model_factory.gd é a fonte reproduzível dos modelos. Para regenerar os 33 TSCNs depois de modificar essa fábrica:

```sh
godot --headless --path . --script res://tests/export_models.gd
```

Esse comando sobrescreve os TSCNs gerados; edições feitas diretamente nas cenas devem ser portadas à fábrica antes de regenerar. O runtime instancia os modelos salvos. `ItemIcons` carrega e mantém as texturas em cache; `ItemSlot` mantém ícone, atalho, quantidade e estado de seleção sem reconstruir controles por quadro.

`tests/arsenal_preview.gd` é uma fixture sem gravação de checkpoint para revisar o HUD, as nove armas, seis variantes de infectados e objetos no chão. Não representa o inventário inicial e fica excluída do executável.
