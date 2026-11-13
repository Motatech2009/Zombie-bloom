# Sobrevivência 0.10

## Construção e depósito

Cada preparação permite `min(12, 6 + floor(horda/3))` novas peças para o grupo inteiro. A cota começa em seis e renova ao vencer o cerco; desmontar não devolve cota. Reparar e melhorar peças existentes continuam custando materiais, mas não contam como novas peças. O limite físico continua sendo 120 defesas.

Materiais no chão vão primeiro para a bolsa. Construção e vendedor gastam o estoque compartilhado do Núcleo, nunca os materiais carregados. Junto ao Núcleo, segure E por 1,8 segundo para depositar todos os materiais. I abre bolsa e depósito: selecione um espaço e use GUARDAR SELEÇÃO, ou retire um item disponível do depósito. A transação exige proximidade real do Núcleo, inclusive no cooperativo. Segurar E junto a uma estrutura danificada, sem carga para depositar, repara após 1,8 segundo e cobra sucata.

## Bolsa e armas

18 espaços físicos; os primeiros nove correspondem às teclas 1–9. Clique em dois espaços na bolsa para trocar suas posições. Uma arma na segunda metade da bolsa precisa ir para a barra para ser usada. Munição, materiais, kits e explosivos também ocupam espaços.

| Item | Limite por pilha |
| --- | --- |
| Armas | 1 de cada modelo por bolsa |
| Sucata / madeira / componentes | 40 / 20 / 12 |
| Munição leve / rifle / cartuchos | 60 / 60 / 20 |
| Foguetes / granadas / kits | 3 / 4 / 3 |

Clique usa o item selecionado: dispara a arma, lança granada ou consome kit médico se estiver ferido. C mantém o atalho de granada. Nove armas com silhuetas próprias: pistola, espingarda, rifle, submetralhadora, lança-foguetes, revólver, rifle de precisão, metralhadora e Arco Tesla. Todos os tipos de munição são finitos. A recarga consome apenas as balas transferidas da bolsa; trocar de item cancela a recarga. Guardar uma arma descarrega seu pente para o depósito. Descartar uma arma preserva as balas carregadas no objeto do chão; recolhê-la não cria munição adicional.

## Coleta e escassez

Drops de infectados são automáticos por proximidade. Nas caixas, segure E parado junto ao saque: 1,68 s no solo ou 2,8 s em equipe por lote de até quatro unidades do primeiro tipo disponível; arsenal escondido exige 3 s no solo ou 5 s em equipe. Movimento, dano e infectados a menos de 4,5 m da fonte interrompem a coleta. Bolsa cheia mantém o excedente na fonte. Drops no chão são recolhidos por proximidade; caixas mantêm a coleta demorada. Nenhuma coleta transfere materiais diretamente ao estoque. Uma arma repetida permanece no local até você guardar/descartar a que já carrega. Ao sair, saque parcial, inimigos e casas ficam preservados até vencer o prazo da geração de três minutos. Apenas a próxima entrada após o prazo renova a área.

O estoque inicial cai para 85 sucata, seis madeiras e dois componentes. Caixas entregam aproximadamente 45% do orçamento anterior e sucata de inimigos cai pela metade (arredondamentos mínimos preservam recompensas pequenas). O dinheiro por sobreviver a uma horda continua sendo crédito direto ao Núcleo.

As novidades de armas, infectados e HUD estão detalhadas em [ARSENAL.md](ARSENAL.md).

## Inimigos e chefes

Barras em pixels de tela, com vida atual/máxima, substituem os números 3D pequenos dos inimigos. O chefe tem barra laranja maior e nome. Inimigos próximos ou feridos exibem integridade; os distantes intactos ficam sem indicador para reduzir poluição.

As famílias anteriores permanecem: comum, corredor, bruto, blindado, demolidor, corrosivo, cão, voador e chefe. Novas variantes: **Estourador** (horda 5, explode ao morrer), **Berrador** (horda 7, invoca dois cães) e **Regenerador** (horda 9, cura outros infectados num raio de sete metros). Também aparecem em setores de risco elevado.

Chefes mantêm cinco arquétipos. A vida base agora é `650 + 110n + 8n²`, multiplicada pela escala da horda e 1,6 e 50% extra por companheiro. A cada oito segundos, após aviso de 1,1 segundo, atacam uma área de seis metros na última posição do alvo. O ataque causa `28 + 2 × horda` de dano; depois o chefe reduz dano recebido em 65% por dois segundos. As primeiras três ativações também invocam um cão. Abaixo de 40% de vida, entram em fúria: +25% velocidade e +30% dano. O aviso da área aparece também para convidados.

Vida, dano e velocidade continuam crescendo com as hordas; inimigos normais recebem ainda +4% de vida por horda além da primeira. Invocações não geram saque nem progresso de população, evitando cultivar recompensas. Mantêm-se limites de inimigos materializados para não multiplicar o custo de física por oito de uma vez: a população extra chega em levas.

## Saves

Versão 6, separada por campanha/infinito. Salva bolsa, depósito, cota consumida, materiais no chão da base, construções e perfis dos convidados. Saves v1–v5 migram sem sobrescrever os arquivos originais. O anfitrião mantém o checkpoint; o convidado não grava a partida compartilhada. Identidade de reconexão é local ao dispositivo; apagar seus dados locais faz o jogo tratá-lo como novo jogador. Um sobrevivente caído continua caído ao reconectar.

Leia [MULTIPLAYER.md](MULTIPLAYER.md) para abrir a sala.

As dez defesas, troca de materiais e os airdrops periódicos estão em [FORTRESS.md](FORTRESS.md).

## Rolamento

Espaço inicia um rolamento de 0,42 s na direção de WASD; parado, segue a mira. Recarga de cinco segundos contada desde a ativação, com texto e barra no HUD. Velocidade de 13 m/s, sem multiplicar com corrida ou bônus; a lentidão criogênica reduz também o alcance do rolamento. Colide com construções e obstáculos. Os primeiros 0,20 s protegem contra dano; o restante da animação continua vulnerável.

Interrompe coleta e recarga da arma. Durante a animação não dispara, usa kits, lança granadas nem coleta caixas. Não pode começar caído, com partida encerrada, com menu aberto ou em prévia de construção. Segurar Espaço não repete a ação. Ao viajar, cair ou restaurar um checkpoint, a pose transitória é encerrada. A recarga fica no perfil salvo; saves v6 anteriores continuam válidos.

No cooperativo, comandos de rolamento são confiáveis e o anfitrião controla movimento, colisão, proteção e recarga. Animação, direção e contador são replicados para os convidados. Não há predição local: o início visual no convidado depende da latência até o anfitrião.

## Casas e aparência 0.10

Casas procedurais fora da base podem ser invadidas. Aproxime para ativar os defensores, elimine a guarnição e segure E na caixa interna por 3 s no solo ou 5 s em equipe por pilha. Guardas e saque são compartilhados, com carga em bolsas individuais. Saque não entra no banco sem voltar ao Núcleo. O cenário só é recriado ao reentrar depois de vencer o prazo de três minutos da geração. O telhado se oculta por proximidade apenas visualmente; paredes continuam bloqueando tiros e movimento. [Regras completas](CLAY_WORLD.md).

Chefes também deixam um pacote dourado extra de munição/componentes/sucata, com chances de consumíveis e arma rara. Áreas militares têm 80% de chance de munição por caixa; outros biomas usam tabelas diferentes. Ver [PROGRESSION.md](PROGRESSION.md).
