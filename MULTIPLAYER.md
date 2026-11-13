# Jogar com amigos — cooperativo 0.11

Até quatro jogadores, com conexão direta por ENet/UDP. Todos precisam usar a mesma versão; convidados das versões anteriores devem atualizar junto com o anfitrião. Um PC joga e hospeda a partida; ele controla movimento, tiros, dano, bolsa, compras, construção, relógio e geração dos setores. Espaço solicita rolamento; o anfitrião valida a recarga de 5 s e replica a animação e o contador para todos. Atualizem todos os PCs para a 0.10.

## Na mesma rede

1. Anfitrião: abra **JOGAR COM AMIGOS**, informe seu nome, escolha campanha/infinito e clique **CRIAR SALA**. Porta padrão: **24567 UDP**. Marque **Continuar o refúgio salvo deste modo** para retomar o checkpoint do anfitrião.
2. No Windows do anfitrião, consulte o IPv4 da rede pelo `ipconfig` (por exemplo, `192.168.1.15`). Se o Firewall pedir, permita o jogo na rede privada usada pelo grupo.
3. Convidados: **JOGAR COM AMIGOS** → nome → IP local do anfitrião → mesma porta → **ENTRAR NO IP**. `127.0.0.1` serve apenas para testar no mesmo computador.
4. O anfitrião deve permanecer com o jogo aberto. Ao encerrar a sala, os convidados voltam à tela de resultado. Para continuar depois, ele abre outra sala com a opção de retomar o salvo e os amigos reconectam.

## Pela internet

Use o endereço público do anfitrião e encaminhe a porta **UDP 24567** do roteador para o PC dele; a porta precisa corresponder à escolhida no menu. Conexões atrás de CGNAT podem impedir esse caminho: nesse caso, use uma rede virtual com conectividade UDP entre os PCs e informe o IP dessa rede. Não existe relay, matchmaking, código de convite, servidor central ou travessia automática de NAT nesta versão. Não abra configurações de rede além do necessário para sua sessão.

Se a conexão expirar, confira versão, IP, porta, sala aberta, firewall e caminho UDP. Trocar só para TCP não resolve: o transporte utilizado é UDP.

## Regras da partida

| Jogadores conectados | População total de infectados |
| --- | --- |
| 1 | x1 |
| 2 | x2 |
| 3 | x4 |
| 4 | x8 |

A escala vale para as hordas e para a população procedural dos setores. Entradas/saídas recalculam os inimigos ainda não gerados; inimigos já vivos não desaparecem quando alguém sai. Limites de materialização permanecem para controlar física e navegação. Vida do chefe também aumenta 30% por companheiro, além da evolução por horda.

O grupo viaja junto: todos os sobreviventes vivos precisam estar junto à mesma saída. Não há setores independentes por jogador. A base permanece física e ativa enquanto o grupo explora. Mochilas são individuais; depósito, cotas de construção, XP e melhorias são compartilhados. A primeira seleção válida de evolução beneficia o grupo. Novos participantes recebem as melhorias coletivas já adquiridas, mas começam com sua própria bolsa inicial se não houver perfil anterior.

O inventário, o mapa e todos os menus do cooperativo mantêm a simulação em andamento. Um caído pode ser reanimado segurando E por 3,5 segundos junto dele, consumindo um kit médico de quem ajuda. Vencer a horda reanima os caídos com 40 de vida. Todos caídos, ou Núcleo destruído, encerram a partida. Ao cair, os materiais carregados vão para o chão; armas e munição ficam na bolsa.

É uma versão para testes entre amigos. O teste automatizado executa quatro processos reais via loopback, cobrindo entrada, movimento, tiro, munição, transações, escala e troca de setores, além de seleção/modelo/consumo do Arco Tesla e avisos do novo Criogênico. Isso não certifica uma conexão entre casas, perda de pacotes, latência alta ou sessões prolongadas. O servidor é o PC do anfitrião; não há migração automática se ele sair.

A queda aérea é compartilhada: coordenada, temporizador, escolta e conteúdo são controlados pelo anfitrião. Os modelos dos níveis das fortificações também são replicados. Drops de chão coletam na bolsa do sobrevivente mais próximo sem interação. A comunicação de snapshots é comprimida; continuam valendo as limitações de latência/conectividade descritas acima.

## Painel de conexão 0.10

Ao criar a sala, pode marcar **Tentar abrir a porta no roteador (UPnP / internet)**. Também pode solicitar depois em **Esc → CONEXÃO / AMIGOS**. O painel mostra LAN/VPN, status da configuração e endereço externo copiável quando obtido. Quem entra pode colar **IP:porta**, mantendo também a entrada tradicional de endereço e porta separados.

A descoberta e as operações no roteador rodam em thread. A concessão UDP dura 900 s, renova a cada 300 s e é removida quando o anfitrião encerra/desativa. Somente o pedido explícito abre a porta; LAN/VPN continua disponível sem UPnP. A opção exige roteador compatível e IPv4 público direto, além do firewall permitir o jogo. Mensagem de porta configurada não é teste externo de conectividade.

### Alternativa para casas diferentes

1. Anfitrião e convidados instalam Tailscale pelas fontes oficiais e usam suas próprias contas.
2. O anfitrião compartilha a máquina da sala com os amigos na opção **Share** do painel do Tailscale; cada convidado aceita o convite.
3. Anfitrião abre a sala normalmente. Os convidados entram pelo IP **100.x** da máquina do anfitrião e pela porta UDP da sala (padrão **24567**).
4. Mantenham o Tailscale e o jogo abertos; o firewall e as permissões da rede virtual precisam permitir a conexão.

[Guia oficial de compartilhamento de servidor de jogo](https://tailscale.com/docs/use-cases/personal-or-at-home-use/share-private-game-server). Não é necessário ter a mesma rede doméstica. Não foi criada conta/configuração externa nesta entrega. Sem UPnP/porta acessível ou rede virtual, não existe relay próprio que contorne o bloqueio da operadora.

Casas são geradas pela mesma descrição em todos os PCs. Conteúdo e progresso da limpeza vêm do anfitrião; não são concedidos pelo convidado. Modelos de personagens recebem poses de recarga/disparo/rolamento e infectados animam também nos clientes. As 93 verificações ENet usam quatro processos em loopback; as 31 verificações auxiliares usam roteador simulado. Nenhuma certifica conectividade de uma operadora específica.

## Android + PC na 0.11

Podem participar da mesma sala, até quatro dispositivos misturados. Hospede de preferência no PC e, no Android, informe o IP do computador e a mesma porta UDP 24567. Atualizem os dois para 0.11. Controles e instalação em [MOBILE.md](MOBILE.md). O teste de rede inclui um cliente com controles de toque reais na aplicação Linux; a instalação e a rede de um celular físico ainda precisam de playtest. A escolha de slot aguarda confirmação do servidor sem ser desfeita por snapshots antigos.
