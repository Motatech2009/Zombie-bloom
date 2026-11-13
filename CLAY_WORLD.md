# Refúgio de Argila 0.10

## Acabamento e animações

Cinco famílias de texturas originais são geradas localmente: argila, madeira, tijolo, terreno e estrada. Cada família usa mapa de cor e normal de 128×128 com mipmaps; os materiais usam projeção no mundo. Texturas são pré-carregadas no menu/inicialização e compartilhadas. A aparência continua low-poly, com cantos suavizados e cores próximas da versão anterior, sem downloads ou geração de imagens durante uma construção.

Caixas arredondadas usam 108 triângulos e cache de até 384 tamanhos. O descarte do cache não remove meshes que continuam em uso na cena. Modelos TSCN anteriores recebem o acabamento ao serem instanciados; colisões e estatísticas continuam separadas da superfície visual. Os exportadores de modelos mantêm primitivas simples, evitando embutir cópias de texturas em cada arquivo.

Braços apontam para a frente do personagem, corrigindo o sinal invertido da rotação. Caminhada/corrida movimentam pernas e corpo; disparo recua a arma; recarga move o braço esquerdo e inclina a arma; coleta, rolamento e ataques anunciados têm poses próprias. Convidados recebem movimento, recarga e recuo, interpolando a animação entre snapshots. Cães e voadores também animam nos convidados. Não são animações esqueléticas finais.

Oito árvores por cenário e pequenas faixas nas casas balançam. A tampa da caixa da casa abre gradualmente durante a coleta. Esses detalhes não alteram colisões, dano ou tempo de saque. O contorno dos textos soltos do HUD melhora leitura sobre o novo terreno.

## Casas de exploração

Cada visita fora do Núcleo gera duas casas no bosque, quatro no subúrbio e três nos demais biomas. Cada casa tem três variantes de acabamento, entrada física de 3,6 m, paredes que bloqueiam jogadores/infectados/tiros e interior mobiliado. Telhado e elementos altos ficam ocultos a menos de 12 m do personagem local; a parte visual das paredes baixa para 20%. A colisão continua inteira: o acesso e a linha de tiro passam pela porta. Ao afastar, a fachada volta.

Casas ficam nos quadrantes, preservando as quatro faixas de retorno. Props sobrepostos são retirados, spawns comuns ficam fora das casas, e caixas/arsenal raro permanecem separados por pelo menos quatro metros. A navegação marca paredes, preservando porta e interior.

A aproximação a 22 m ativa a guarnição. Quantidade-base: `min(12, 4 + risco×2 + horda/4)`, com divisão inteira; multiplica por x1/x2/x4/x8 conforme o grupo. São até seis guardas ativos por casa, respeitando também 24 infectados de campo e 60 ativos globais. Variantes incluem corredor, blindado, corrosivo, investidor e criogênico. Guardas têm 25% mais vida e 15% mais dano que o mesmo infectado de campo naquela horda; modificadores do setor podem somar.

É preciso derrotar toda a guarnição para liberar a caixa. Mortes de guardas não completam a população comum do setor. A caixa oferece `70 + risco×30` sucata, `40 + risco×20` madeira e `12 + risco×8` componentes. Cada coleta leva cinco segundos e transfere uma pilha, limitada pela bolsa. Bolsa cheia conserva o restante; paredes impedem coleta pelo lado externo. Os recursos precisam ser transportados até o Núcleo.

Estado, bloqueio e conteúdo são decididos pelo anfitrião e replicados sem duplicar a caixa no loot genérico. Entradas/saídas de jogadores atualizam a exigência de guardas. Como o restante do setor procedural, casas e saque são recriados ao sair e entrar novamente. Apenas a região do Núcleo é fixa; saves continuam v6.

## Internet e próximos passos

No menu da sala, **CONEXÃO / AMIGOS** mostra endereços locais/VPN e as opções de configuração externa. A opção UPnP é desmarcada por padrão. Quando solicitada, a descoberta/configuração roda em thread; o jogo não bloqueia o quadro esperando o roteador. A porta UDP é temporária (900 s), renovada a cada 300 s e removida ao desativar/encerrar; se o processo cair, depende do vencimento da concessão no roteador.

Somente um IPv4 público direto obtido do roteador é anunciado como endereço externo. Configuração da porta não comprova alcance pela internet. Falta de UPnP, conflito de porta, CGNAT, duplo NAT e firewall exigem encaminhamento manual ou uma rede virtual. O jogo aceita IP, hostname, IP:porta e IPv6 entre colchetes. O botão de copiar fica indisponível sem endereço externo configurado.

O painel inclui o guia oficial para usar Tailscale entre casas. Não existe matchmaking, relay próprio, código de convite ou servidor dedicado gerenciado. Os testes usam ENet real em loopback e um roteador simulado para o ciclo UPnP; não houve teste de um roteador residencial real nem conexão entre duas casas.

A partir da 0.11 há APK Android de desenvolvimento com controles de toque e conexão ao PC. Veja MOBILE.md. iOS, desempenho em aparelhos físicos e rede móvel real continuam sem validação.

Fontes técnicas: [Godot 4.6 UPNP](https://docs.godotengine.org/en/4.6/classes/class_upnp.html) · [Tailscale para servidor de jogo entre amigos](https://tailscale.com/docs/use-cases/personal-or-at-home-use/share-private-game-server).
