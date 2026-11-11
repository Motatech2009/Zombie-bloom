# Zombie Bloom

**O mundo acabou. Seu refúgio ainda resiste.**

Jogo single-player offline de sobrevivência e defesa de base. Projeto Godot **4.6.3**, GDScript, cenário 3D low-poly e câmera ortográfica elevada (2.5D). Geometrias, animações e sons próprios gerados pelo projeto, sem assets pagos ou serviços externos.

## Abrir e jogar

1. Instale a [Godot 4.6.3 padrão, sem .NET](https://godotengine.org/download/archive/4.6.3-stable/).
2. Baixe ou clone este repositório.
3. Na Godot, clique em **Importar** e selecione `project.godot`.
4. Pressione **F5** e clique em **Iniciar sobrevivência**.
5. Use **B** para construir e **Espaço** para iniciar a primeira horda.

Não há pacotes adicionais para instalar. `project.godot` abre o projeto fonte; o executável Windows exige exportação.

## Implementado

- Um mapa com ruas, veículos abandonados, obstáculos sólidos e núcleo central.
- Movimento, corrida, mira, câmera suave e personagens articulados com animações procedurais.
- Pistola, espingarda e rifle com dano, dispersão, alcance, pente, cadência e recarga próprios.
- Cinco hordas; errantes, corredores e brutos com perseguição, navegação e ataques.
- XP, níveis, seis melhorias reais e três power-ups temporários.
- Sucata, prévia de construção, barricadas, torretas e reparos.
- Menu, instruções, configurações persistentes, HUD, equipamentos, pausa, reinício, vitória e derrota.
- Efeitos de disparo, impacto, dano, construção, reparo e morte; sons sintetizados.

## Controles

| Entrada | Ação |
| --- | --- |
| WASD | Mover em relação à câmera |
| Shift | Correr |
| Mouse / botão esquerdo | Mirar / disparar |
| R | Recarregar |
| 1 / 2 / 3 | Pistola / espingarda / rifle |
| B | Abrir/fechar construção durante a preparação |
| 1 / 2 em construção | Barricada / torreta |
| Clique esquerdo / direito | Instalar / cancelar construção |
| E | Reparar estrutura danificada próxima, até 4,5 m |
| Espaço | Iniciar a próxima horda |
| Tab | Equipamentos e atributos |
| Esc | Pausar / continuar / cancelar construção |

Você começa com 140 de sucata e as três armas. Reserva de munição ilimitada; cada pente exige recarga. Recolha fragmentos verdes para ganhar XP e sucata. A preparação não tem cronômetro. Morte do jogador ou destruição do núcleo encerra a partida. Sobreviva às cinco hordas para vencer.

## Testes

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
```

A suíte usa cenas e física reais da engine. Veja [TEST_REPORT.md](TEST_REPORT.md) para as evidências e limitações.

## Windows

Instale os templates 4.6.3 em **Editor → Gerenciar templates de exportação**. Use **Projeto → Exportar → Windows Desktop**, ou:

```bash
mkdir -p builds/windows
godot --headless --path . --export-release "Windows Desktop" builds/windows/ZombieBloom.exe
```

O preset incorpora o PCK no executável. Assinatura digital não configurada. O workflow do GitHub Actions valida o projeto e gera o artefato `ZombieBloom-Windows-x64` quando a execução termina com sucesso. Não confunda um workflow configurado com uma exportação já validada.

## Documentação

[Design](GAME_DESIGN.md) · [Arquitetura](ARCHITECTURE.md) · [Balanceamento](BALANCING.md) · [Testes](TEST_REPORT.md) · [Changelog](CHANGELOG.md)

## Limites

MVP com arte procedural simples. Balanceamento e diversão ainda exigem sessões com jogadores; testes de sistemas não substituem essa avaliação. Não há salvamento de partidas, remapeamento de teclas, multiplayer, mundo aberto ou crafting complexo. Armadilhas e estação de reparo ficam para expansão. FPS e compatibilidade do executável Windows precisam ser medidos nos equipamentos de destino.
