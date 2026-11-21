# 1.0-dev — elos, combate e oficina

## Elos de massinha e classificação real

Os emblemas são desenhados pela interface do jogo, com bordas arredondadas, relevo por camadas e cores prata/dourado/lilás. O mural mostra progressão pessoal, galeria de elos e cartões dos resultados reais retornados pelo Firebase. Nenhum jogador, abate ou colocação fictícia é inserido. O banco não é consultado automaticamente pelo novo menu: mantém top 25, cache e envio em lote.

| Elo | Abates mínimos |
|---|---:|
| Sem classificação | 0–99 |
| 1 · Recruta | 100 |
| 2 · Vigia | 500 |
| 3 · Sentinela | 1.000 |
| 4 · Guardião | 1.500 |
| 5 · Veterano | 2.000 |
| 6 · Bastião | 3.000 |
| 7 · Carrasco | 4.000 |
| 8 · Colosso | 6.000 |
| 9 · Lenda | 8.000 |
| 10 · Imortal | 10.000 |

Elo não é a posição no ranking. O elo usa o total de abates da conta; a posição compara esse total com outros jogadores. Abates de torres, canhões, eletricidade e armadilhas agora contam para cada jogador conectado à equipe. Um inimigo morto é registrado apenas uma vez, mesmo se a notificação de morte se repetir. A mudança vale para novos abates, sem inventar ou distribuir retroativamente os antigos abates de defesas.

## Inimigo preso no vendedor

A barraca passa a ocupar células de navegação. O Investidor interrompe a investida ao colidir; inimigos terrestres recuperam a altura do chão e, quando ficam imóveis dentro da barraca, procuram uma posição próxima sem colisão. A recuperação mantém vida e participação na horda; não apaga o inimigo nem encerra a horda artificialmente.

## Papéis de combate e chefes

Ataques de contato passam por preparação visível dos braços e conferem o alcance novamente ao aplicar dano. Esquivar durante a preparação evita o golpe. Os ataques remotos da antiga lógica compartilhada dos chefes foram limitados à função de cada variante:

- **Quebra-Muros:** grande atacante próximo. Prepara uma pancada de chão em volta do próprio corpo; não explode diretamente na posição de jogadores distantes.
- **Caldeirão:** artilharia ácida, com projétil e zona anunciada. Prefere manter distância e não causa dano de contato.
- **Matriarca de Argila:** invoca cães e recebe armadura temporária; até três invocações, sem explosão remota genérica.
- **Tempestade Alada e Predador Alfa:** preservam seus corpos voador/cão, com poder de área limitado à proximidade do próprio corpo.
- **Lançador de Esporos:** novo infectado exclusivamente de projéteis, recua quando pressionado e entra a partir da horda 3.
- **Cutelo:** novo infectado de curta distância, golpe mais pesado e preparação maior; entra a partir da horda 6.

As animações de golpe/preparação e investida são transmitidas aos convidados. A atualização usa protocolo cooperativo 16: todos precisam atualizar. Sem aumentar o limite global de inimigos nem adicionar partículas transparentes em massa.

## Oficina do Bento

PC e Android têm acesso pelo vendedor à melhoria da arma equipada. São três níveis por tipo de arma, por sobrevivente, dentro do refúgio salvo:

| Melhoria | Sucata | Componentes |
|---|---:|---:|
| Reforçada | 80 | 2 |
| Especialista | 180 | 5 |
| Obra-prima | 360 | 10 |

Cada nível soma 15% de dano, 8% de cadência, 10% de capacidade (exceto lança-foguetes, que mantém uma carga) e reduz o tempo de recarga em 8% multiplicativos. Os multiplicadores das melhorias de nível da equipe continuam separados. A oficina exige proximidade do Bento, preparação entre hordas, arma equipada e recursos suficientes. O anfitrião valida e paga a compra. Perfis e saves antigos recebem nível de oficina zero sem perder inventário.

Defesas avançadas custam mais: muralha pesada 130 sucata/10 madeira/12 componentes; canhão 280/4/22; torre elétrica 260/2/26. Não foram adicionados novos tipos de defesa nesta entrega: a expansão de progressão está na oficina.

## Limites de validação

Regras/cadastro reais no Firebase e desempenho dos novos combates em celulares físicos ainda exigem verificação. Alterar a aparência do ranking não cria dados nem confirma que as regras do banco real foram publicadas.
