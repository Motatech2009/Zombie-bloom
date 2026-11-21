# Arsenal e construção — 0.6

As regras atuais de mapa, risco e hordas automáticas estão em [WORLD_SECTORS.md](WORLD_SECTORS.md). Esta versão mantém campanha de 20 cercos e defesa infinita, com uma base fixa no Núcleo (0,0).

## Construção

| Peça | Sucata / madeira / componentes | Vida N1 | Função |
| --- | --- | ---: | --- |
| Barricada | 20 / 4 / 0 | 220 | Barreira acessível |
| Torreta | 75 / 0 / 4 | 180 | Ataque automático terrestre/aéreo, com obstrução |
| Muro | 35 / 6 / 2 | 440 | Camada mais resistente |
| Portão | 35 / 6 / 2 | 320 | F abre/fecha sem fechar sobre ocupantes |
| Estacas | 15 / 5 / 0 | 150 | Dano aos infectados que passam sobre elas |
| Posto de apoio | 60 / 4 / 5 | 260 | Cura e reparos próximos entre cercos |

B abre catálogo; 1–6 selecionam peças; Q gira 90°; clique instala; botão direito cancela. Grade de 1 m, alcance de 12 m, até ±46 m e máximo 120 defesas. Custos, ocupação e acesso às quatro saídas são validados antes do débito. O vendedor e as saídas têm espaço reservado. Portões são passagens controláveis no teste de acesso. Não existem andares navegáveis.

G melhora defesas até N3: +65% da integridade inicial por nível, com ganho de dano/cadência/alcance nas torretas. N1→N2 custa 20/3/2; N2→N3, 40/6/4. O Núcleo chega a N4 e 1350 de integridade, somando 250 por melhoria; preço 75/10/5 multiplicado pelo nível atual. E repara 90 por 8 sucata. X exige confirmação e reembolsa metade dos materiais pagos na peça/melhorias, arredondados para baixo.

A prévia reutiliza dois materiais e verifica ocupação a 10 Hz. O caminho só é consultado no commit, com grade reutilizada e bloqueios temporários revertidos. O script da peça é pré-carregado. Estado e desempenho da implementação anterior constam em docs/build-performance.json; valores headless não medem o quadro de renderização no PC do usuário.

## Arsenal

| Controle | Arma | Compra / munição |
| --- | --- | --- |
| 1 | Pistola | Inicial; balas comuns livres |
| 2 | Espingarda | 110 sucata |
| 3 | Rifle | 220 sucata |
| 4 | Submetralhadora | 175 sucata; pente 40, alta cadência |
| 5 | Lança-foguetes | 320 sucata; um carregado + cinco reservas |
| C | Granada | Duas iniciais; três por 45 sucata |

Armas também podem ser encontradas em arsenais raros de setor. Balas comuns têm reserva livre, com pentes e recarga. Explosivos são finitos: cinco foguetes por 60 sucata. A recarga do lançador gasta uma reserva só ao concluir; trocar cancela sem consumo.

Foguete: 130 dano base, área de 4,5 m. Granada: até 18 m de alcance, detonação em 0,85 s, 105 dano base, área de 4,5 m e recuperação de 1,5 s. Explosão perde potência com distância, respeita sólidos para inimigos e fere o sobrevivente perto do impacto; não danifica a própria base.

Bento negocia a até 5 m, no Núcleo durante preparação. Tratamento de até +60 vida: 25 sucata; 10 madeiras: 30; quatro componentes: 45. Compras validam o saldo e posse antes de debitar. XP, seis evoluções de personagem e três poderes temporários continuam presentes.

## Famílias de ameaça

Errantes, corredores, brutos, blindados (60% do dano recebido), demolidores, corrosivos, cães infectados, voadores e cinco variantes de chefe. A corrosão usa projétil em ponto fixo e poça de cinco segundos que causa dano ao jogador e estruturas. Cães investem; voadores passam por barreiras baixas e são atingíveis por tiro e torreta com altura real. Detalhes dos chefes e progressão em WORLD_SECTORS.md.

## Interface

Faixa superior compacta com vida, Núcleo, horda e relógio; arma/explosivos no canto; H oculta atalhos e Tab abre arsenal. M mostra mapa sem pausar. Esc e telas declaradas de pausa interrompem a simulação. Fechar o jogo não salva automaticamente: volte à preparação no Núcleo e use F5 quando necessário.
