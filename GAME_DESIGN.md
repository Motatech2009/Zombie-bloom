# Design — Zombie Bloom 0.1

## Ciclo

Preparação sem cronômetro → Espaço inicia horda → combater e coletar → escolher evolução → concluir onda → construir/reparar → próxima horda. Vitória após cinco ondas. Morte do jogador ou destruição do núcleo causa derrota. Resultados são terminais.

## Combate

Três armas disponíveis desde o início, com reserva ilimitada e recarga obrigatória. Pistola prioriza precisão e dano por tiro. Espingarda dispara seis chumbos a curta distância. Rifle oferece fogo contínuo. Troca cancela recarga sem reabastecer a arma anterior e preserva o cooldown. Tiros usam raycast: obstáculos e estruturas interrompem o disparo, sem dano amigo. Traços são apenas feedback visual.

## Inimigos

Errantes buscam o jogador dentro de 10 m; fora disso buscam o núcleo. Corredores perseguem em 15 m. Brutos têm mais vida e dano. AStarGrid2D desvia dos veículos. Defesas construídas não bloqueiam a grade: o zumbi colide com elas e as ataca. Os inimigos não colidem entre si; isso reduz congestionamento físico, mas permite sobreposição visual nesta versão.

## Defesa

B abre a prévia. Verde aceita; vermelho rejeita e informa o motivo. A validação é repetida na confirmação. Grade de 1 m, alcance de construção de 12 m, limites de 24 m nos eixos e máximo de 24 defesas. Nenhuma sobreposição com jogador, zumbis, obstáculos ou estruturas. Construir e reparar só funciona na preparação.

Barricadas são bloqueios sólidos destrutíveis. Torretas escolhem o inimigo visível mais próximo, sem disparar através de obstáculos. E repara a estrutura danificada mais próxima em 4,5 m, cobrando sucata e respeitando a vida máxima.

## Recursos e evolução

Fragmentos verdes concedem XP e sucata, com atração em 4 m e coleta em 0,85 m. Quatro caches iniciais concedem 15 de sucata cada. XP produz níveis e sucata paga defesas. Ao ganhar nível, a árvore pausa e oferece três das seis melhorias. Uma escolha por nível; níveis simultâneos entram em fila. Dano, cadência, pente, recarga, velocidade e vida máxima mudam efetivamente.

Power-ups: velocidade, frenesi e escudo. Duram dez segundos e uma nova coleta renova a duração sem acumular intensidade. Escudo renova para 45 de absorção e perde o saldo ao expirar. Bônus de tipos diferentes podem coexistir. A pausa congela também sua duração.

## Apresentação

Câmera ortográfica elevada, paleta fria e sinalização verde. Modelos originais feitos com primitivas, membros articulados e efeitos econômicos. Animações ligadas a movimento, disparo, recarga, dano, morte, construção e reparo. Sons locais sintetizados. A expansão deve partir de observações de jogadores e medições, antes de adicionar novos sistemas.
