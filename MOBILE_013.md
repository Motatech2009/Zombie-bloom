# Zombie Bloom 0.13 — controles, qualidade e rede

PC e Android precisam ser atualizados juntos. Esta versão mantém os mundos e checkpoints v6.

## Controles de celular

- O analógico aparece no ponto inicial do polegar na metade esquerda. Arraste para andar e leve à borda para correr. Um segundo dedo não reposiciona o analógico que já está em uso.
- Sem disparar, o personagem olha na direção da caminhada. Segurar ATIRAR mantém a mira independente e permite recuar ou andar de lado.
- Um toque no infectado escolhe o alvo. Ele só recebe tiros enquanto ATIRAR estiver pressionado. Soltar interrompe o fogo imediatamente. Um alvo escolhido atrás de uma parede fica selecionado, mas não gasta munição. Segurar o disparo assistido sem alvo escolhido procura um infectado visível e alcançável.
- Botões de combate usam fundo quase transparente, contorno e ícones brancos a 40% quando ociosos. O toque realça o botão. O alcance de toque permanece maior que o ícone.
- COLETAR aparece quando há caixa, depósito, saída, reanimação ou reparo próximo. O texto indica a ação. As condições de segurança e o tempo de coleta continuam no anfitrião.
- A barra mostra quatro espaços compactos por página, com três páginas para alcançar os nove. A bolsa conserva seus 18 espaços.
- Pausa, configurações, mochila e catálogos ocupam a tela, com fechamento fixo fora da rolagem. O menu principal usa a largura disponível. Os controles param ao abrir um painel ou perder foco.

## Qualidade gráfica

A opção de qualidade agora atualiza a partida em andamento. Desativar o modo leve restaura resolução 3D integral, texturas de argila, projeção dos materiais e modelos detalhados. Reativá-lo volta aos modelos agrupados e materiais simplificados. Inimigos mantêm vida e identidade durante a troca.

O modo leve usa argila opaca com cor e iluminação, evitando texturas deformadas sobre as primitivas. Corrigimos as coordenadas UV das caixas arredondadas. A resolução leve fica em 85%, com interface integral, sombras desligadas e até 30 FPS no Android. O modo detalhado custa mais GPU. A câmera móvel passa de 30 para 27 unidades, aproximando personagem e ameaças.

O relato do teste anterior no Moto G45 foi de 28–30 FPS. Esse número pertence à versão anterior e ao aparelho do usuário. O novo APK ainda precisa da medição no mesmo telefone. O A13 relatado apresenta lentidão também fora do jogo, portanto não há promessa de desempenho para esse aparelho.

## Custo da horda

As rotas já eram recalculadas por temporizadores de aproximadamente meio segundo, e não a cada quadro. Agora os recálculos vencidos distribuem-se em quatro grupos e possuem orçamento por passo de física. Modelos fora da câmera ocultam-se e deixam de atualizar animações. Efeitos móveis continuam sendo formas sólidas de argila em um conjunto reutilizado de 20 elementos, inclusive no modo detalhado.

A física de colisão e os ataques continuam ativos a 60 Hz. A base segue vulnerável quando o grupo está longe. Não usamos movimento sem colisão que permita infectados atravessarem as muralhas. O custo total de CPU/GPU não tem uma redução percentual certificada por essas mudanças.

## Resposta do cooperativo

O personagem local prevê movimento e rolamento a cada passo, usando as mesmas colisões de movimento. O anfitrião confirma entradas e posição. A reconciliação ocorre no passo de física, e o rolamento também envia uma intenção confiável vinculada à sequência de entrada. O cliente descarta entradas confirmadas, reaplica as pendentes e suaviza pequenas correções no modelo. Divergências grandes, queda e troca de setor exigem correção direta. O histórico limita-se a dois segundos e o envio mantém a intenção mais recente. A troca de setor bloqueia comandos até o convidado receber o mapa e o estado completo.

O servidor usa a intenção mais recente, preserva toques breves de tiro/recarga e limita a simulação à própria frequência. Sequências repetidas não repetem o rolamento. Nenhuma previsão concede dano, vida, munição ou itens.

Tiros do convidado produzem som, recuo e rastro local imediatamente, com limite da arma e munição confirmada. Dano e consumo dependem do servidor. A confirmação do próprio disparo não repete o rastro. Esse feedback visual não inclui compensação histórica de acertos por latência.

Outros jogadores e infectados interpolam amostras com 100 ms de atraso visual. Em ausência de pacote, mantêm o último ponto confirmado. Movimento e ameaças usam atualizações de 20 Hz, entradas saem a 30 Hz e construções, saque, casas e depósito trafegam a cerca de 3 Hz. Os conjuntos são comprimidos e usam canais distintos de eventos e comandos. Isso separa o tráfego, sem prometer prioridade de roteador ou eliminar a latência da internet.

## Verificação

A validação combina as suítes anteriores, testes de controles e qualidade ao vivo, lacuna de 200 ms sem snapshots no teste de previsão, replay de entradas e quatro processos ENet reais. Esses cenários não representam uma medição de FPS no Moto G45 ou uma partida real em 4G. Instalação em aparelho, estabilidade térmica, ergonomia de sessões longas e rede entre casas continuam exigindo teste dos jogadores.
