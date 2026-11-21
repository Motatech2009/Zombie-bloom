# Zombie Bloom 0.13.1 — ações contextuais, loja e tela cheia

## Celular

- CONSTRUIR abre diretamente o catálogo. Só aparece no setor do Núcleo (0,0), na preparação e sem horda ativa.
- COLETAR aparece junto a fontes de saque manual; GUARDAR aparece junto ao Núcleo quando a bolsa contém materiais. Segure o botão para concluir a ação. Ele desaparece e libera o toque quando não há mais o que transferir.
- MELHORAR aparece junto à construção que ainda pode subir de nível. O painel mostra nome, nível seguinte e custo antes da confirmação. O anfitrião continua validando alcance, fase e materiais.
- VENDEDOR aparece perto do Bento entre hordas. MAPA e BOLSA têm atalhos próprios. Portão, viagem, reparo e reanimação usam botões separados quando necessários.
- O antigo botão genérico AÇÕES foi substituído por comandos diretos. O menu inicial conserva sua estrutura.
- Arma selecionada, munição e recarga ficam acima da barra rápida, no canto inferior direito. A posição acompanha telas mais largas.

## Construção e Bento

Os dois catálogos têm categorias, lista rolável de itens e detalhes ao lado. A confirmação fica visível fora da lista. Construções mostram integridade, preço e cota. O vendedor separa armas, munição e suprimentos, mostra quantidade e preço e informa arma já possuída, falta de sucata ou bolsa cheia. Compras atualizam o estado sem reabrir o painel. Começar uma horda fecha catálogos que deixaram de ser utilizáveis.

## Mira

A busca assistida comparava a posição local do infectado, dentro do setor, à posição global do jogador. Fora do Núcleo, o deslocamento de 120 unidades por setor podia colocar um inimigo próximo aparentemente fora de alcance. A distância agora usa coordenadas globais dos dois objetos. Seleção, cobertura, altura e consumo de munição mantêm as mesmas regras na base e na exploração.

## Tela cheia

Android mantém modo imersivo e preenche a área disponível. No PC, a primeira abertura usa tela cheia no tamanho do monitor atual. F11 e Configurações alternam com janela e guardam a preferência. A interface expande a área visível conforme a proporção da tela, em vez de adicionar faixas para encaixar uma janela fixa. A resolução interna 3D continua separada do tamanho físico da tela para preservar o modo leve.

## Verificação e instalação

1007 verificações: 15 suítes com 894 verificações e quatro processos ENet com 113. A cobertura móvel inclui coleta real com espera, depósito, melhoria, compra de arma e munição, encerramento por horda, estado recebido por convidado, tela mais larga e mira em setor deslocado. Revisão visual de vendedor, catálogo e HUD; depósito confirmado por toque.

Ainda é necessário testar o APK em telefone físico, incluindo barras do Android, recortes de câmera e ergonomia. A inspeção Linux não certifica o comportamento do compositor Windows nem mede FPS no Moto G45/A13. O CI verifica exportação Windows, assinatura do APK e bibliotecas ARM. Atualize PC e Android juntos. A assinatura, o pacote e os checkpoints v6 são preservados.
