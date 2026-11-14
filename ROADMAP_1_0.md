# Planejamento da versão 1.0 — contas e rankings

Status: ideia aprovada para planejamento futuro. Login, backend e rankings ainda não implementados. A 0.14 permanece focada no jogo e no cooperativo.

## Objetivo

Permitir conta e apelido próprios, com progressão vinculada ao jogador entre PC e celular e três rankings públicos separados:

| Ranking | Métrica proposta |
| --- | --- |
| Abates | Total de zumbis eliminados com autoria confirmada |
| Hordas vencidas | Total de hordas concluídas com participação válida |
| Sucata coletada | Sucata obtida do mundo e creditada uma única vez |

Mostrar apelido público e posição. Manter e-mail e dados de acesso privados. O jogo offline continua disponível; recordes competitivos exigem uma sessão validada.

## Regras a definir antes da implementação

- Separar campanha e infinito, ou mostrar filtros por modo e dificuldade. Melhor horda alcançada pode aparecer como estatística adicional, sem substituir o total de vitórias.
- Definir autoria de abates e como atribuir mortes causadas por torres do grupo. Assistências podem ser uma estatística própria.
- Somar sucata uma vez ao obtê-la do mundo. Transferir, retirar do depósito, vender ou comprar não pode contar o mesmo recurso novamente.
- Registrar eventos com identificadores únicos para que reconexões e tentativas repetidas não dupliquem pontuação.
- Reservar classificações competitivas a partidas verificáveis. O anfitrião atual e os arquivos locais podem ser alterados pelo jogador; login sozinho não torna os números confiáveis.

## Dependências de implementação

Autenticação, recuperação de conta, associação de PC/celular, serviço confiável para validar partidas e eventos, armazenamento de estatísticas e consulta paginada dos rankings. Não permitir que o aplicativo envie livremente um total de pontos para sobrescrever o placar.

Antes de abrir o ranking, testar login/reconexão, migração de perfil, eventos duplicados, transferência de recursos, atribuição cooperativa e rejeição de resultados inválidos. Escolher o provedor e a operação do serviço quando o escopo da 1.0 estiver fechado.
