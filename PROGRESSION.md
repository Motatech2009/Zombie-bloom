# Zombie Bloom 0.12 — exploração, chefes e suprimentos

Cada geração de um setor dura pelo menos **180 segundos de partida**, contados desde a primeira entrada daquela geração. Sair e voltar antes do prazo retoma o mesmo mapa: caixas parcialmente saqueadas, armas encontradas, casas, guardas, vida dos inimigos e itens largados continuam no estado em que foram deixados. A volta não reinicia nem estende esse relógio.

O tempo não troca o cenário enquanto você está nele. Depois de vencer o prazo, a **próxima entrada** gera outra área e outro loot. O Núcleo continua fixo. O mapa e o aviso de entrada mostram o prazo. Pausar sozinho pausa também esse tempo; o cooperativo continua rodando em menus.

Somente os dados dos setores ficam guardados; os modelos e a física da área desocupada são descarregados. Dados expirados são removidos. O checkpoint v6 guarda esses estados e o relógio; arquivos v6 anteriores continuam aceitos. Restaurar um checkpoint também restaura as bolsas dos convidados conectados, para não levar itens de um momento posterior ao mundo restaurado.

## Coleta

| Ação | Um jogador | Dois a quatro |
| --- | ---: | ---: |
| Caixa regional, por lote | 1,68 s | 2,8 s |
| Arsenal, casa ou airdrop, por lote | 3 s | 5 s |
| Depósito no Núcleo | 1,08 s | 1,8 s |
| Reparo | 1,8 s | 1,8 s |

Entrar/sair da equipe ajusta a duração sem conceder progresso gratuito. Movimento, dano, alcance, paredes e inimigos próximos continuam podendo interromper a coleta. Drops de infectados continuam automáticos ao passar. Materiais entram na bolsa; ainda é necessário levá-los ao Núcleo.

## Chefes

O primeiro chefe de horda, sozinho, começa com aproximadamente **1.229 de vida**, antes de eventuais reforços especiais. A base é `650 + 110n + 8n²`, com a escala de saúde da horda e multiplicador 1,6. Cada jogador adicional acrescenta 50% ao multiplicador de grupo do chefe. Airdrops e regiões especiais podem reforçar mais. Armadura temporária, fúria, invocações e arquétipos continuam.

Além do saque normal, cada chefe deixa um pacote dourado extra: sucata, componentes, munição leve e outra família de munição são garantidos; granada tem 65% de chance, kit 45%, e uma arma rara cerca de 2–5%, conforme o estágio. O pacote deve ser recolhido e transportado. Bolsa cheia conserva o restante. Chefes derrotados não voltam antes da renovação da geração.

## Loot regional

Caixas e casas podem conter munição e consumíveis além dos três materiais. O conteúdo é sorteado por geração; reentrar antes do prazo não faz outro sorteio.

| Bioma | Chance de munição por caixa | Perfil |
| --- | ---: | --- |
| Subúrbio | 28% | Leve, cartuchos, rifle; mais kits |
| Pátio industrial | 40% | Leve, pesada, células ou rifle |
| Bosque morto | 12% | Reservas escassas |
| Zona agrícola | 20% | Munição comum e consumíveis |
| Ruínas militares | 80% | Rifle, cartuchos, leve, pesada, células ou foguete; mais granadas |

Arsenais escondidos mantêm a raridade e incluem munição compatível com a arma encontrada. Infectados também podem deixar pequenas quantidades de munição, com chance maior em setores militares. Os orçamentos básicos de madeira/sucata/componentes das caixas foram mantidos.

O anfitrião decide prazo, dano, sorteios e transferências. Todos devem usar a mesma versão no PC e Android.
