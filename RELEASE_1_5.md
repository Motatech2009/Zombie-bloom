# Zombie Bloom 1.5 - controle de entrega

Fonte: `ideias para o jogo.txt`, recebido em 15/11/2026. Esta lista é cumulativa. Não chamar a versão de pronta enquanto houver requisito pendente ou validação bloqueada.

## Etapas e critérios

- [x] A1 Canalização de construção/melhoria, cancelada por dano/distância; custo apenas na conclusão.
- [x] A2 Dia 900 s / noite 900 s, transição suave, +30% HP e detecção noturna.
- [x] A3 Noite Vermelha (25% ao anoitecer): +50% HP substitui +30%, +30% dano, céu e áudio de alerta.
- [x] A4 Pistola inicial mais rápida.
- [x] A5 Upgrades com tetos 2/7/12 nas faixas 1-5/6-10/11+, ganhos menores, coleta/engenharia/munição/carga.
- [x] B1 Quebra-Muros: investida, dano x3 em bloqueios, onda frontal com empurrão.
- [x] B2 Caldeirão: poça corrosiva por 6 s, dano em atores e estruturas.
- [x] B3 Matriarca: vínculo/cura enquanto cães próprios vivos.
- [x] B4 Tempestade: rasante e quatro explosões em linha.
- [x] B5 Predador: salto, imobilização 1,5 s, liberação por rolamento/tiro aliado.
- [x] B6 Parasita: busca torre, drena e vira Bruto.
- [x] B7 Escudeiro: 80% de bloqueio frontal; explosivos/flancos ignoram.
- [x] B8 Ponte de Carne: rampa de 10 s para Errantes/Corredores.
- [x] B9 Oleiro: paredes temporárias com colisão/linha de visão.
- [x] B10 Colmeia: enxames a cada 15% de vida perdida.
- [x] C1 Fusão de torres idênticas adjacentes, torre dupla e alívio de cota.
- [x] C2 Reciclador: madeira/excedentes em componentes, transação sem duplicação.
- [x] C3 Sinalizador raro do Bento: canalização 4 s e retorno ao Núcleo.
- [x] D1 Comboio: defesa de 45 s e arma Reforçada/munição.
- [x] D2 Ninho: mapa roxo, inimigos mais rápidos e casas com saque dobrado até destruição.
- [x] D3 Escolta: NPC ferido e recompensa ao alcançar o refúgio.
- [x] E1 Cosméticos por elo real, seleção e visual sincronizado.
- [x] E2 Engenheiro/Batedor/Atirador, seleção inicial e efeitos persistidos.
- [x] E3 Mutadores após vitória: Escuridão Total/Sem Vendedor/Hordas Dobradas.
- [x] E4 Pontuação de desafios separada de abates reais; envio em lote ao Firestore.
- [x] F1 Aviso visual/sonoro do Núcleo sob ataque, com orientação ao setor zero.
- [x] F2 Estilhaços de argila limitados, duração 2 s, críticos/explosões.
- [x] G1 Saves antigos migrados, estado novo validado e persistido.
- [x] G2 Host autoritativo, réplicas de habilidades/eventos/classes e novo protocolo.
- [x] G3 UI PC/mobile revisada, controles existentes preservados.
- [ ] G4 Suítes locais, coop e Firebase emuladores aprovadas.
- [ ] G5 Windows e Android exportados e APK verificado.

## Decisões de implementação

- Os valores ausentes na proposta terão defaults documentados e limites, com ajuste posterior por teste de partida.
- O ranking de abates continua significando mortes reais. Bônus de mutadores entram em uma pontuação separada.
- Nenhuma nova gravação por morte: manter lotes e cache existentes.
- A cota de 12 é por preparação, não limite total de estruturas. Fusão deve devolver uma unidade consumida da preparação, sem permitir desmontagem infinita.
- Não desinstalar APK antigo nem apagar saves para atualizar.

## Parâmetros da candidata

- Ganhos por nível: dano 4%; cadência 3%; pente 4%; recarga -2%; movimento 1,5%; vida +10. Coleta +50% de velocidade, engenharia -40% de duração, economia 25% de chance e pilhas dobradas no nível 12.
- Noite Vermelha: chance 25% em cada anoitecer. Dano/vida nunca empilham com os fatores noturnos anteriores; a fração de vida é mantida ao trocar período.
- Fusão de torres do mesmo tipo/nível a até 4 m: intervalo de disparo ×0,55. Não pode fundir uma torre já dupla. Sem reembolso de materiais; libera uma unidade da preparação.
- Reciclador: custa 150 sucata, 8 madeira e 8 componentes. Uma arma não inicial → 5 componentes; 20 madeira → 2 componentes.
- Extração: 140 sucata e 6 componentes; estoque compartilhado de uma unidade por preparação; canal de 4 s, cancelável antes de consumir.
- Evento em 75% das visitas novas; tipos distribuídos por seed/coordenada/visita. Comboio: 45 s perto do objetivo, rifle com nível Reforçada e suprimentos; ninho: +20% velocidade regional e saque dobrado das casas; escolta: 12 componentes ao chegar ao refúgio.
- Pontos: cada abate concede 1 × (1 + quantidade de mutadores ativos). Kills, hordes e scrap mantêm seu significado e ficam separados de points. Nada é escrito individualmente por morte.
- Até 12 paredes temporárias e 12 rampas por mundo; até quatro fragmentos por morte relevante, respeitando o orçamento de efeitos existente.

## Validação e promoção

As suítes locais e os testes cooperativos de quatro jogadores, previsão de movimento e setores separados passaram na candidata. Capturas reais de PC/mobile foram inspecionadas; o botão de base foi reposicionado para preservar os controles de tiro. CI/exportações e emulador ainda precisam ser confirmados nesta revisão.

**Bloqueio de produção:** o Firestore precisa aceitar o campo `points` nos documentos públicos e privados de checkpoint. Publicar `backend/firebase/firestore.rules` no projeto `zombiebloom` antes de distribuir a 1.5 como final. Credenciais administrativas não fazem parte do jogo e não foram solicitadas nem gravadas no repositório. A validação em emulador não substitui a publicação das regras reais.
