# Jogar com amigos — cooperativo 0.8

Até quatro jogadores, com conexão direta por ENet/UDP. Todos precisam usar a mesma versão; convidados da 0.7 devem atualizar junto com o anfitrião. Um PC joga e hospeda a partida; ele controla movimento, tiros, dano, bolsa, compras, construção, relógio e geração dos setores.

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
