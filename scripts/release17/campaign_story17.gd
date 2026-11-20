class_name CampaignStory17
extends RefCounted
## The horde checkpoint determines which pages are readable in every save.

const PAGES := [
	{
		"after": 0, "title": "A última chamada",
		"text": "Meu nome é Caio Vale. Eu trabalhava na manutenção da rede de água de Várzea Alta. Na noite da evacuação, recebi uma ordem para manter as bombas ligadas. Obedeci. Depois da meia-noite, ninguém respondeu do outro lado da linha.\n\n"
			+ "Minha irmã Ana conseguiu mandar uma última mensagem pelo rádio. “Caio, leva os sobreviventes pro Farol. Eu encontro vocês lá.” Voltei à cidade para cumprir essa promessa. O Núcleo é a única subestação que ainda funciona. Se eu mantiver a luz acesa, Ana vai saber onde me encontrar.",
	},
	{
		"after": 5, "title": "O relatório da madrugada",
		"text": "Depois do quinto cerco, Bento deixou um relatório na minha bancada. A enchente arrastou o lodo do Projeto Bruma para as tubulações. As primeiras vítimas perderam a fala antes de atacar quem tentava socorrê-las. A direção escondeu os casos e os avisos nunca chegaram aos bairros mais baixos.\n\n"
			+ "Reconheci minha assinatura nas planilhas das bombas. Eu sabia que a pressão estava fora dos limites. Devia ter parado a rede e ido verificar. Ainda dá para pôr os registros no ar antes que a próxima equipe repita a mesma ordem.",
	},
	{
		"after": 10, "title": "O mapa de Ana",
		"text": "O rádio voltou a captar a voz de Ana, gravada em sequência. Entre os ruídos, ela marcou ruas que ainda tinham saída e explicou onde os comboios deixaram suprimentos. Ela cruzou a cidade recolhendo gente enquanto a direção discutia o que dizer à imprensa.\n\n"
			+ "A última marca no mapa é o Farol. Anotei as passagens abertas e deixei o rádio ligado. Cada pessoa que chega ao Núcleo traz um pedaço da cidade que ainda vale a pena salvar.",
	},
	{
		"after": 15, "title": "A frequência do Farol",
		"text": "A gravação de Ana tem uma segunda faixa. Ela guardou o aviso de evacuação que a direção mandou apagar. Se conseguirmos manter a energia até o último cerco, o Farol pode transmitir o aviso, o mapa e os nomes de quem ficou.\n\n"
			+ "Hoje deixei a porta do abrigo destrancada para quem chegar antes do alarme. Amanhã, quando eu subir na torre, quero ouvir alguém do outro lado dizer que recebeu.",
	},
	{
		"after": 20, "title": "Recepção confirmada",
		"text": "O vigésimo cerco acabou ao amanhecer. Liguei o transmissor e li em voz alta as rotas seguras, os nomes dos bairros e o relatório que a direção escondeu. Na terceira tentativa, alguém respondeu do lado de fora da cidade.\n\n"
			+ "Depois veio outra voz. “Caio, aqui é a Ana. Estou com vinte e três pessoas na estrada norte. Deixa a luz acesa.” Chamei Bento. Tínhamos mais gente para buscar.",
	},
]

static func available(completed_waves: int) -> Array:
	return PAGES.filter(func(page: Dictionary) -> bool: return completed_waves >= int(page.after))

static func new_title(completed_wave: int) -> String:
	for page in PAGES:
		if int(page.after) == completed_wave:
			return str(page.title)
	return ""
