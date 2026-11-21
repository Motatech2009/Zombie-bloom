# Zombie Bloom 0.14.0 — exploração em equipe

## Dez minutos entre hordas

Uma partida nova começa com 600 segundos para explorar e construir. Cada vitória devolve os mesmos dez minutos, sem reduzir esse intervalo nas hordas avançadas. O alarme e o ataque automático continuam. Checkpoints anteriores sem a identificação do novo intervalo recebem os dez minutos quando restaurados durante a preparação; saves novos preservam o tempo restante.

## Escolhas sem ataques

Quando há uma melhoria de nível pendente, o combate fica pausado para todo o grupo: zumbis, habilidades de chefes, projéteis hostis, ácido, torres, geração de hordas e seus relógios param. Os jogadores também não podem continuar atacando inimigos congelados. A primeira escolha válida aplica o benefício e libera a partida. Menus comuns no cooperativo continuam sem pausar a sala.

## Taco de beisebol

O taco tem ícone, modelo de argila, animação e som de golpe. Acerta até três infectados próximos, dentro de 2,6 m e à frente do sobrevivente, respeitando paredes. O dano inicial é 32 por alvo e existe um intervalo de 0,65 s entre golpes. Não gasta munição; continua sendo necessário chegar perto de inimigos perigosos.

Partidas novas começam com um taco na bolsa. Em mundos anteriores, Bento vende um nos Suprimentos por 15 sucatas. No PC, T equipa um taco que esteja na barra rápida; números e bolsa também funcionam. No celular, selecione o taco e segure GOLPEAR. Se a arma estiver sem pente e sem reserva, pressionar tiro seleciona o taco disponível na barra e muda a página da barra para mostrá-lo. Dano e intervalo continuam validados pelo anfitrião.

## Trilha original

Uma composição instrumental sintetizada combina melodia em tom menor, base grave, acordes e percussão. A preparação usa uma versão mais calma; a horda acelera o arranjo e acrescenta percussão. Durante escolhas o volume diminui. Configurações possui volume independente para TRILHA SONORA, incluindo silêncio. A música não depende de arquivos externos, serviços ou gravações licenciadas.

## Amigos em quadrantes diferentes

Cada jogador pode atravessar sua própria saída. O anfitrião pode ir ao norte enquanto dois convidados vão ao sul. Quem permanece na base ou em outra área conserva posição, cenário e saque. Jogadores no mesmo quadrante compartilham a mesma geração e as mesmas caixas; não recebem cópias privadas do loot.

O anfitrião mantém o núcleo e os setores ocupados simultaneamente. Inimigos da exploração procuram sobreviventes do próprio setor. Cada convidado recebe a geometria e os inimigos da sua área, com revisão de cena independente. O mapa lista os nomes e quadrantes da equipe. A horda pode começar enquanto todos estão longe; as defesas e o núcleo continuam vulneráveis. Durante uma horda, continuam permitidas as saídas que aproximam o jogador do núcleo.

Quando o último jogador sai de um setor de exploração, o cenário pode ser descarregado. Seu estado parcial permanece conforme a regra existente de três minutos por geração. Uma área ainda ocupada por amigos não é regenerada quando outra pessoa entra. Entrar numa sala já em andamento coloca o novo convidado no quadrante atual do anfitrião.

## Instalação e verificação

O protocolo de rede passa a 14. Todos precisam atualizar para 0.14.0 e criar uma sala nova; versões 0.13 não participam dessa sala. O pacote Android, a assinatura de desenvolvimento e o formato de checkpoint v6 são mantidos.

1071 verificações: 929 nas 16 suítes, 113 no cooperativo com quatro processos, 9 na regressão de movimento a 30 FPS e 20 num teste novo com três processos ENet reais em setores distintos. Esse último percorre viagem independente, loot por jogador, golpes de taco confirmados e início da horda enquanto o grupo está dividido. A suíte funcional também verifica descarregamento de área, memória de loot, checkpoint e entrada de convidado com anfitrião fora da base.

Modelo, golpe e controles musicais foram inspecionados visualmente em Linux. Os testes não certificam FPS com quatro áreas ocupadas em telefone físico, rede entre casas, balanceamento de partidas longas ou qualidade sonora nos alto-falantes de cada aparelho. Recomenda-se hospedar no PC para manter vários setores ativos.
