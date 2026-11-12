# Último Refúgio — Zombie Bloom Beta 1

Jogo de sobrevivência isométrica single-player offline em Godot **4.6.3**. Explore um mundo procedural com relevo e interiores térreos, obtenha materiais, administre mochila/peso, fabrique itens e construa seu refúgio. Infectados investigam visão, luz e ruído; hordas são grupos migratórios aleatórios, sem ondas obrigatórias ou contador de ataque à base.

**[Leia o guia da Beta 1](BETA_1.md)** para regras, limites, dados de balanceamento, salvamento e validação do GDD.

## Jogar

1. Baixe ou clone o projeto e importe `project.godot` na Godot 4.6.3 padrão, sem .NET.
2. Execute e escolha **Explorar o mundo**. Configurações permite escolher a seed.
3. Use **E** para interagir e segure E para extrair árvores/pedras. Abra recipientes e transfira o que couber.
4. **I** abre a mochila; **C**, a fabricação. Fabrique uma bancada, abra **B**, selecione a peça e clique em local livre.
5. Retorne ao Núcleo/caixas para armazenar materiais. Salve com **F5**, restaure com **F9** e retome pelo menu.

| Entrada padrão | Ação |
| --- | --- |
| WASD / mouse / clique | Mover / mirar / atacar |
| Shift / Espaço | Correr / rolar sem invulnerabilidade |
| E / I / C | Interagir ou extrair / mochila / crafting |
| B / Q / botão direito | Construir / girar / cancelar prévia |
| F / R / 1–6 | Reparar / recarregar com munição finita / hotbar |
| L / M / Esc | Lanterna / mapa / pausa |
| F5 / F9 | Salvar / restaurar |

Movimento e ações podem ser redefinidos nas opções. Resolução, volume, sombras, neblina, escala de texto e modo leve também são ajustáveis. A reserva de munição é item real de inventário; a hotbar referencia slots, sem criar armazenamento extra.

## Escopo

A Beta inclui 25 itens, 15 receitas, seis peças construtivas, machado/pistola/espingarda, errante/perseguidor, dia/noite, neblina, cinco registros ambientais e um gancho narrativo. O catálogo editável fica em `resources/beta/catalog.tres`. Não há torretas, fome/sede, NPCs, veículos dirigíveis, múltiplos andares, multiplayer ou automação industrial.

Os parâmetros são o balanceamento inicial do protótipo. A arte é geométrica original, com animação procedural, vegetação/multidões instanciadas e sons sintetizados. As ilustrações do GDD eram esquemas de referência; não assets de produção final.

## Salvamento

Cada seed tem seu próprio arquivo Beta. O progresso inclui inventário, equipamentos, estado do personagem/interior, recipientes, recursos extraídos, portas/janelas, construções, relógio, lore e estado agregado das hordas. A gravação valida dados e usa temporário/backup. Não sobrescreve arquivo de outra seed silenciosamente.

O save é manual. Voltar ao menu não salva automaticamente. Os arquivos do protótipo 0.2 permanecem separados e não possuem migração automática. Morte permite retomar o último salvamento; resgate/respawn avançado está fora da Beta 1.

## Verificar e exportar

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/world_tests.gd
godot --headless --path . --script res://tests/beta_tests.gd
```

O GitHub Actions executa as três suítes e exporta `ZombieBloom-Windows-x64`. Após uma execução bem-sucedida, baixe o artefato da execução correspondente. Os dois protótipos anteriores são mantidos para regressão técnica; a campanha principal utiliza `scenes/beta/BetaWorld.tscn`.

Para exportar localmente, instale os templates oficiais 4.6.3 em **Editor → Gerenciar templates de exportação** e use **Projeto → Exportar → Windows Desktop**, ou:

```sh
mkdir -p builds/windows
godot --headless --path . --export-release "Windows Desktop" builds/windows/ZombieBloom.exe
```

O preset incorpora o PCK no executável. O build não é assinado. Exportar para Windows não substitui executar e avaliar o jogo nesse sistema e no hardware de destino.

## Documentação

[Guia/aceite Beta 1](BETA_1.md) · [Relatório de testes](TEST_REPORT.md) · [Arquitetura](ARCHITECTURE.md) · [Changelog](CHANGELOG.md) · [Protótipo 0.2 histórico](WORLD_IMPLEMENTATION.md)

O benchmark disponível foi executado em renderização por software llvmpipe: cerca de 15,6 FPS padrão e 34,9 FPS no modo leve com 32 infectados ativos. O alvo provisório de 60 FPS em GPU dedicada ainda requer medição no PC de destino. Dados e protocolo estão no guia; os testes de lógica não certificam diversão, desempenho universal ou áudio em um dispositivo que não está conectado ao ambiente de teste.
