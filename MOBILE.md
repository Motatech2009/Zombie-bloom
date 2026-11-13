# Zombie Bloom 0.12 — PC + Android

O Android usa a mesma simulação, itens, casas, fortaleza, horda e protocolo ENet do PC. A sala aceita até quatro jogadores, misturando computador e celular. Recomenda-se hospedar no PC para ele manter a simulação e os saves, enquanto o Android joga como convidado. Celular pode hospedar em rede compatível, mas deve permanecer aberto e em primeiro plano.

## Instalar para testar

1. Baixe **ZombieBloom-Android-APK** do mesmo Actions/commit da versão Windows. Extraia o ZIP e abra **ZombieBloom-Android.apk** no Android.
2. Se o Android solicitar, permita instalar por essa fonte. É um APK de desenvolvimento, fora da Play Store.
3. Abra Zombie Bloom com o aparelho na horizontal. Android 8 ou superior com OpenGL ES 3 é recomendado; o manifesto do APK registra os requisitos efetivos. O pacote inclui ARM de 32 e 64 bits. Não inclui iPhone/iOS.
4. No computador, baixe e abra **ZombieBloom-Windows-x64** dessa mesma versão.

A assinatura de desenvolvimento é fixa, permitindo atualizar por cima de APKs anteriores deste pacote. O identificador é `com.motatech.zombiebloom.preview`. Evite desinstalar para atualizar: remover o aplicativo apaga os dados locais. Mundos e perfis de convidados da sala ficam no PC anfitrião. O backup automático Android foi desativado para não clonar a identidade de conexão em outro aparelho.

## Conectar celular e PC no mesmo mundo

1. Conecte PC e Android ao mesmo Wi-Fi/rede, sem isolamento entre clientes. No PC: **JOGAR COM AMIGOS → CRIAR SALA**.
2. Confira o IPv4 do PC (por `ipconfig` ou **Esc → CONEXÃO / AMIGOS**). Não use `127.0.0.1` no celular.
3. No Android: **JOGAR COM AMIGOS**, informe nome, IP do PC e a mesma porta UDP (padrão **24567**), depois **ENTRAR NO IP**. Pode colar `IP:porta`.
4. Mantenha o PC com o jogo aberto. Se o Windows solicitar, permita o jogo no firewall da rede usada.

Em redes diferentes, o PC precisa ser alcançável: encaminhamento UDP/UPnP com IPv4 público ou rede virtual. Com Tailscale, instale nos dois dispositivos, compartilhe a máquina do anfitrião com a conta do amigo e conecte ao IP Tailscale do PC. O Android não precisa usar o mesmo Wi-Fi nesse caso. Veja [MULTIPLAYER.md](MULTIPLAYER.md) e o guia oficial no painel de conexão. Não há relay próprio ou matchmaking.

## Controles por toque

| Controle | Ação |
| --- | --- |
| Disco esquerdo | Mover; empurre até a borda para correr |
| Toque no zumbi | Trava esse alvo e dispara acompanhando seu movimento; toque no chão para cancelar |
| SEGURE ATIRAR | Escolhe um alvo visível no alcance da arma; continua procurando enquanto estiver segurado; solte para parar |
| LANÇAR GRANADA / USAR KIT | Usa uma unidade do item selecionado por toque; toque no cenário antes para apontar a granada |
| ROLAR | Esquiva com recarga de cinco segundos, validada pelo anfitrião |
| RECARGA | Recarregar a arma com munição da mochila |
| Segurar COLETAR | Abrir caixas, guardar materiais no Núcleo, reparar ou reanimar aliado conforme o contexto |
| COLETAR junto à saída | Solicitar travessia do grupo para o setor adjacente |
| BOLSA | Organizar os 18 espaços; tocar dois espaços para trocar; guardar/descartar seleção ou abrir depósito |
| Setas da barra | Alternar entre os espaços 1–5 e 6–9 |
| AÇÕES | Mapa, construção, vendedor, melhorias, portões, desmonte e save do anfitrião |
| Ⅱ / Voltar do Android | Abrir pausa ou fechar o painel atual; cooperativo continua ativo |

O alvo recebe um marcador verde quando há tiro e âmbar quando está protegido ou fora de alcance. A seleção por toque termina ao morrer, sair da tela, trocar de item, entrar em construção, começar coleta ou abrir um painel. Segurando ATIRAR, o botão pode escolher outro inimigo vivo após a morte do anterior; soltá-lo encerra o ataque. O anfitrião confere vida, alcance, cobertura e revisão do setor antes de cada tiro, inclusive quando um comando chega atrasado. Sem segurar ATIRAR, não procura outro alvo sozinho. O lança-foguetes dá um disparo por toque; granadas e kits continuam manuais. A precisão e dispersão das armas continuam valendo.

Dois dedos independentes permitem mover e segurar ATIRAR ao mesmo tempo. Não existe mais disco de mira direita. Arrastar o dedo para fora da área de tiro também interrompe esse comando. Soltar um controle não libera o outro. Perder foco, cancelar um toque ou abrir um painel limpa os comandos mantidos, evitando movimento/tiro preso. Seleções recentes da barra não são desfeitas por um snapshot antigo enquanto aguardam confirmação.

Construção: abra AÇÕES → CONSTRUIR, escolha uma defesa, toque no chão para posicionar a prévia, use GIRAR e confirme COLOCAR. CANCELAR encerra a prévia. Validação de materiais, cota, ocupação e passagem continuam no anfitrião. O depósito tem um painel próprio para evitar duas áreas de rolagem sobrepostas.

## Visual, desempenho e limites

Interface em paisagem 960×540, com proporção mantida e faixas quando necessário. O modo leve vem ativado no celular: cenário 3D a 75% da resolução, interface na resolução original, zumbis com peças agrupadas por membro, materiais sem relevo/triplanar, animação humanoide limitada a 20 Hz, até 12 barras em uma camada única e 20 efeitos reutilizados. A física, quantidade de infectados, dano e regras do anfitrião permanecem iguais. O contador FPS · LEVE no canto ajuda a medir no aparelho. Em CONFIGURAÇÕES é possível alterar o modo; salve e reabra a partida para aplicar. [Medição e método](docs/mobile-render-benchmark.json). O cenário usa o acabamento de argila anterior, câmera mais próxima, barra rápida paginada, mochila em seis colunas e catálogos/menus roláveis com botão de fechar sempre acessível. Android limita a renderização a 30 FPS e desativa sombras por padrão; as sombras podem ser reativadas nas configurações. O limite de FPS não reduz a taxa de física nem a autoridade do servidor.

A vida, mochila, saques, base e quantidade de infectados são compartilhados com a mesma regra dos PCs: x2, x4 ou x8 conforme entram dois, três ou quatro jogadores. O mapa é do anfitrião, e o grupo continua viajando junto. Trocar de aplicativo pode interromper a conexão conforme o Android; mantenha o jogo em primeiro plano durante o teste.

Validação automatizada: 953 verificações, incluindo 28 de entrada/UI móvel, 33 de mira por alvo e 26 de desempenho/controle assistido, 43 de progressão e quatro processos ENet reais com um cliente usando a interface de toque, sem substituir o frame de entrada desse cliente por input fictício. Esse cliente ainda roda em Linux no teste de rede; não é um telefone Android real. O CI exporta o APK, verifica assinatura, manifest e bibliotecas ARM, além da compilação Windows. Não houve instalação em aparelho físico, medição de FPS em telefone ou teste entre duas casas.

O keystore de desenvolvimento intencionalmente público em `.ci/android-development-key.b64` é apenas de teste e não deve assinar uma publicação na loja. Ela existe para preservar a identidade das atualizações desse protótipo. Publicação Play Store requer assinatura privada própria, AAB e validação específica; isso não foi realizado.

Fontes: [Exportação Android na Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html) · [Tailscale para compartilhar um servidor de jogo](https://tailscale.com/docs/use-cases/personal-or-at-home-use/share-private-game-server).

A 0.12 preserva cada geração por três minutos de partida e só renova ao entrar depois desse prazo. O mapa mostra o tempo restante. A coleta solo é mais rápida, chefes têm mais vida e deixam um pacote extra, e áreas militares podem fornecer munição. Atualize PC e Android juntos. [Detalhes](PROGRESSION.md).
