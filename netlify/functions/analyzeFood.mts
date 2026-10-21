// Backend seguro do NutriSnap — versão Netlify Functions.
//
// Guarda a chave do Gemini como variável de ambiente no servidor (nunca no
// app) e repassa a chamada pro Gemini. Mesmo contrato de request/response
// que o app Flutter já espera (ver lib/services/gemini_service.dart), então
// nenhuma mudança é necessária do lado do app: POST com
// { mode: "photo", base64Image } ou { mode: "text", description } → resposta
// { items: [...] }.

import type { Context, Config } from '@netlify/functions';

// Modelos tentados em ordem. Se um estiver sobrecarregado (503), sem cota (429),
// fora do ar ou aposentado (404), o backend tenta o próximo automaticamente.
// Dá pra trocar o principal sem mexer no código: variável GEMINI_MODEL no Netlify.
const MODEL_CHAIN = [
  Netlify.env.get('GEMINI_MODEL') || 'gemini-3.8-flash',
  'gemini-3.5-flash-lite',
  'gemini-2.5-flash',
];
const RETRYABLE = [404, 429, 500, 502, 503, 504];

function buildGenerationConfig(model: string, mode: string) {
  // Modelos Gemini 3.x funcionam melhor com a temperatura padrão.
  const legacy = model.startsWith('gemini-2');
  if (mode === 'transcribe') return legacy ? { temperature: 0 } : {};
  return legacy
    ? { response_mime_type: 'application/json', temperature: 0.2 }
    : { response_mime_type: 'application/json' };
}

// -----------------------------------------------------------------------
// Prompts
// -----------------------------------------------------------------------

const PHOTO_PROMPT = `Você é um nutricionista analisando uma foto de comida com extremo rigor visual. Siga estas regras OBRIGATÓRIAS, nessa ordem, para cada alimento identificado:

1. CONTAGEM E MULTIPLICAÇÃO (regra mais importante):
   Antes de calcular qualquer valor, CONTE quantas unidades idênticas ou semelhantes
   daquele alimento estão visíveis (ex: 3 fatias de pão, 2 ovos, 5 morangos, 4 pedaços
   de frango). O valor final de calorias e de cada macro DEVE ser o resultado de:
   (valor nutricional de 1 unidade) x (quantidade contada).
   Nunca devolva o valor de uma única unidade se houver mais de uma visível — some tudo.

2. ESCALA E PROPORÇÃO — fatia/pedaço/fração vs. inteiro (regra crítica,
   NUNCA pule esta etapa):
   Antes de estimar o peso de QUALQUER alimento, pergunte-se explicitamente:
   "o que está na foto é o alimento INTEIRO, ou é apenas um PEDAÇO, FATIA
   ou FRAÇÃO dele?". NUNCA assuma a unidade inteira por padrão — essa é a
   causa mais comum de erro grosseiro de calorias. Procure ativamente por
   sinais visuais de corte/fração: uma superfície de corte exposta, uma
   borda reta que não é a borda natural do alimento, metade de um formato
   simétrico (ex: meio pão francês partido ao longo, meia banana, um
   quarto de melancia), ou uma fatia fina destacada de um pão/bolo/queijo
   maior. Use referências de tamanho na própria foto (garfo, faca, colher,
   prato, copo, mão, embalagem) pra confirmar a proporção.
   - Se o alimento estiver PARTIDO/CORTADO e você ver só uma parte dele
     (ex: "meio pão", "uma fatia de pão", "um quarto de abacaxi", "metade
     de um ovo cozido"), estime o peso e as calorias APENAS dessa fração
     visível — nunca calcule como se fosse a unidade completa e depois
     divida, e nunca reporte o valor da unidade inteira "só pra
     simplificar".
   - Exemplo: uma fatia de bolo de ~3cm de largura é uma FATIA, não o bolo
     inteiro — estime o peso dessa fatia especificamente, nunca o peso do
     bolo completo. O mesmo vale pra "meio pão" (metade do peso/calorias
     de um pão inteiro do mesmo tipo) e qualquer outro alimento fracionado.
   - Só assuma a unidade INTEIRA quando o contorno completo do alimento
     estiver visível e íntegro na foto, sem nenhum corte ou parte faltando.

3. CETICISMO COM PESO/VOLUME:
   Estime o peso com base no tamanho e densidade do que está REALMENTE visível na
   foto. NUNCA assuma o peso padrão de uma embalagem, receita ou porção comercial
   inteira, a menos que a embalagem/alimento completo esteja de fato 100% exposto
   e inteiro na imagem. Na dúvida entre um valor menor e um maior, prefira o menor
   (mais realista para o que está visível).

3B. ÂNCORAS DE PESO (use SEMPRE pra estimar gramas — comida cozida pesa
   MENOS do que parece em foto). Compare com o prato/talher visível e use
   estas referências como ponto de partida:
   - Arroz cozido: 1 colher de sopa CHEIA ≈ 25g; 1 escumadeira/concha
     pequena ≈ 60-80g; um monte do tamanho de um punho fechado ≈ 120-150g.
     Ex.: 4 a 5 colheres de sopa ≈ 100-125g. Um prato raso comum, com um
     "montinho" de arroz de lado, raramente passa de 150g.
   - Feijão cozido (com caldo): 1 concha média ≈ 100g.
   - Frango: pedaço pequeno tipo coxinha da asa/mini coxa/sobrecoxa
     pequena (com osso) ≈ 30-50g; filé de frango grelhado médio (palma da
     mão) ≈ 100-120g; cubos/iscas ≈ 15-25g cada. Se tiver osso visível,
     NÃO conte o peso do osso como comida.
   - Carne bovina: bife médio (palma da mão) ≈ 100-120g.
   - Macarrão cozido: 1 pegador ≈ 110g. Batata cozida média ≈ 100-130g.
   - Salada/folhas: 1 punhado ≈ 20-30g. Ovo cozido/frito ≈ 50g.
   Antes de dar o número final, faça uma checagem de sanidade: um prato
   de refeição normal inteiro costuma pesar 350-550g no total. Se a soma
   dos seus itens passar muito disso, você está superestimando — reduza.
   Pra superestimar menos: o tamanho do PRATO e dos TALHERES na foto é a
   escala; um prato raso comum tem ~24-26cm de diâmetro.

4. Depois de aplicar as regras acima, calcule as calorias e os macros (proteína,
   carboidrato, gordura) já como TOTAIS do item (considerando a quantidade e o
   peso real estimados), não como valores de referência por 100g.

Responda APENAS com um JSON válido (sem markdown, sem texto adicional, sem
comentários), no formato de uma lista. Para cada item, inclua os campos abaixo —
"raciocinio" (UMA frase curta: o que você contou e como chegou ao peso, usando as âncoras da regra 3B; escreva ANTES dos números), "quantity" e "unit" documentam a contagem que você usou, e "grams"/"calories"/
os macros já devem vir multiplicados pela quantidade total:
[
  {
    "name": "Pão de forma",
    "raciocinio": "3 fatias visíveis, cada uma ~25g pelo tamanho em relação ao prato",
    "quantity": 3,
    "unit": "fatia",
    "grams": 75,
    "calories": 210,
    "protein_g": 6,
    "carbs_g": 39,
    "fat_g": 3
  }
]`;

const MEDIDAS_CASEIRAS = `8. MEDIDAS CASEIRAS — CONVERTA SEMPRE EM GRAMAS ANTES DE CALCULAR:
   Passo 1: identifique a medida (colher de sopa/sobremesa/chá/café, xícara,
   copo, scoop, concha...) e a quantidade ("meia" = 0,5, "uma" = 1).
   Passo 2: converta em GRAMAS com a tabela abaixo. NUNCA use um valor único
   de gramas por colher: o peso muda muito de um alimento pra outro (a mesma
   colher de sopa pesa ~8 g de farinha láctea e ~30 g de requeijão).
   Passo 3: calcule calorias e macros A PARTIR dessas gramas (gramas x valor
   nutricional por grama do alimento). O campo "grams" é o total em gramas.
   Se o usuário disser gramas ou ml, use exatamente o que ele disse.

   Quando o usuário não disser "rasa" ou "cheia": use colher de sopa RASA para
   pós, farinhas e açúcares (padrão das tabelas de nutrição) e CHEIA para
   pastas e cremosos. Relações: cheia ≈ 1,5 a 2x a rasa; colher de sobremesa
   ≈ 2/3 da de sopa; colher de chá ≈ 1/3 da de sopa; colher de café ≈ 1/6.

   GRAMAS POR COLHER DE SOPA RASA (valores médios de tabelas de medidas
   caseiras; arredonde sempre pra média, nunca pro extremo):
   farinha láctea 8 | leite em pó 9 | achocolatado em pó 10 | cacau/chocolate
   em pó 8 | aveia em flocos 7 | farinha de trigo 10 | farinha de mandioca ou
   de rosca 10 | amido de milho 8 | açúcar refinado 12 (cheia: 24) | açúcar
   mascavo 10 | café em pó 5 | whey/proteína em pó 10 (1 scoop/dose ≈ 30 g)
   NA MEDIDA USUAL: óleo/azeite 8 | manteiga/margarina 14 | requeijão cremoso
   (cheia) 30 | arroz cozido (cheia) 25 | milho verde em conserva 17 |
   parmesão ralado (cheia) 15

   LÍQUIDOS: colher de sopa = 15 ml, sobremesa = 10 ml, chá = 5 ml, café =
   2 ml; 1 ml ≈ 1 g (mel e leite condensado ≈ 1,4 g/ml).
   XÍCARA: de chá (culinária) = 240 ml; de café/cafezinho = 50 ml; copo
   americano = 200 ml. Xícara de chá rasa de pó: farinha de trigo 120 g |
   açúcar 200 g | aveia 80 g | achocolatado ou chocolate em pó 90 g | leite em
   pó 120 g | farinha de mandioca 150 g.

   Alimento que não está na tabela: estime o peso pela densidade real dele
   (pós e farinhas são leves, ~0,3 a 0,6 g/ml; cremes e líquidos ~1 g/ml).
   NÃO use 15 g por colher pra tudo. Se a medida for ambígua, escolha a
   interpretação mais comum, nunca a maior.
`;

const TRANSCRIBE_PROMPT = `Transcreva este áudio em português do Brasil EXATAMENTE como foi dito,
palavra por palavra, sem resumir, sem corrigir e sem interpretar. Mantenha todos os números,
quantidades, medidas e nomes de alimentos/marcas. Remova apenas pausas e sons como "hum" e "é...".
Responda somente com a transcrição, sem aspas nem comentários.`;

function buildTextPrompt(description: string): string {
  return `Você é um nutricionista experiente, especialista em culinária brasileira e em
suplementação de academia, interpretando uma descrição em texto livre
(português coloquial, escrita por um usuário comum de app) do que ele comeu
ou vai comer. Você NUNCA se recusa a interpretar e NUNCA deixa de responder
por falta de detalhes — sempre faz a melhor estimativa possível, mesmo com
informação incompleta. Siga estas regras OBRIGATÓRIAS, nessa ordem, para
cada alimento identificado:

1. SEGMENTAÇÃO: A frase pode conter um ou vários alimentos separados por "e",
   vírgula, ou apenas espaço (ex: "3 ovos mexidos e uma fatia de pão", "café
   com leite e 2 colheres de açúcar"). Identifique CADA alimento/ingrediente
   como um item separado na lista de resposta — não agrupe itens diferentes
   em um só.

2. RIGOR COM QUANTIDADES (regra mais importante — nunca falhe nisso):
   Leia a quantidade informada pelo usuário, seja em algarismo ("4", "2") ou
   por extenso ("quatro", "duas", "uma", "meia", "meio"). Se nenhuma
   quantidade for mencionada, assuma 1 unidade/porção padrão do alimento.
   Interprete corretamente variações de escrita como "4 pão de forma",
   "4 fatias de pão de forma", "quatro fatias de pão de forma" e "pão de
   forma x4" como a MESMA coisa: 4 fatias de pão de forma — o número
   (escrito em algarismo OU por extenso) SEMPRE deve disparar a
   multiplicação, sem exceção, e SEMPRE deve ser mapeado pro alimento certo
   da frase (nunca ignore nem confunda qual alimento aquele número se refere).
   O valor final de calorias e de cada macro DEVE ser o resultado de:
   (valor nutricional de 1 unidade/porção) x (quantidade detectada).
   Nunca devolva o valor de uma única unidade se a quantidade for maior —
   some tudo.

3. EXTRAÇÃO DE UNIDADE: Identifique a unidade usada pelo usuário (fatia,
   unidade, colher (de sopa/chá), xícara, copo, grama, pedaço, fatia, prato,
   concha, scoop, dose etc.). Se o usuário não mencionar unidade nenhuma
   (ex: "4 pão de forma"), infira a unidade mais natural para aquele
   alimento (nesse exemplo, "fatia").

4. FLEXIBILIDADE DE ESPECIFICIDADE — dos dois extremos, você deve lidar bem:
   a) TERMOS ULTRA ESPECÍFICOS (marca, sabor, tipo exato): ex: "Whey Protein
      Isolado Growth sabor chocolate", "Refrigerante Coca-Cola zero lata",
      "Iogurte Grego Nestlé Nature". Use seu conhecimento sobre o produto
      real (marca + tipo) pra estimar os macros com precisão de rótulo
      quando souber; senão, use a média de categoria (ex: whey isolado
      genérico) sem travar ou pedir mais informação.
   b) TERMOS VAGOS/GENÉRICOS: ex: "um pedaço de bolo", "um prato de almoço
      normal", "um lanchinho", "uma marmita". NUNCA falhe ou devolva
      vazio nesses casos — estime como um nutricionista experiente
      estimaria, usando a composição mais provável e comum no Brasil:
      - "um pedaço de bolo" → assuma bolo caseiro comum (ex: bolo de
        chocolate/cenoura), porção de 60g a 80g.
      - "um prato de almoço normal"/"prato feito" → assuma arroz, feijão,
        uma proteína (carne/frango) e salada, nas proporções típicas de um
        prato brasileiro médio (~500-650 kcal).
      - "um lanchinho" → assuma algo leve e comum tipo um sanduíche simples
        ou uma fruta com algo, ~150-250 kcal.
      Escolha sempre o cenário mais COMUM e realista, nunca o extremo
      (nem o menor nem o maior possível), e nunca deixe de dar uma resposta
      numérica completa.

5. DICIONÁRIO CULTURAL BRASILEIRO E DE ACADEMIA: Reconheça e interprete
   corretamente gírias, expressões regionais e termos típicos do dia a dia
   e da rotina fitness no Brasil, incluindo mas não se limitando a:
   "pão na chapa" (pão francês tostado na chapa com manteiga), "cafezinho"
   (café pequeno, geralmente com açúcar), "shake de hipercalórico"/"massa"
   (suplemento hipercalórico batido com leite), "filé de frango grelhado",
   "tapioca", "pão de queijo", "marmita fitness", "whey", "bcaa", "creatina",
   "coxinha", "pastel", "misto quente", "suco natural", "vitamina de
   banana", "quentinha", "self-service"/"por quilo". Interprete essas
   expressões com o mesmo rigor de qualquer alimento formal.

6. CONHECIMENTO NUTRICIONAL: Calcule o peso estimado (gramas) de cada
   unidade/porção usando seu conhecimento nutricional padrão (ex: 1 fatia de
   pão de forma ≈ 25g, 1 ovo médio ≈ 50g, 1 colher de sopa de açúcar ≈ 12g),
   e a partir daí as calorias e macros (proteína, carboidrato, gordura) já
   como TOTAIS do item (considerando a quantidade detectada), não como
   valores de referência por 100g.

7. TOLERÂNCIA A ESCRITA INFORMAL: O usuário pode escrever sem acentos, com
   abreviações, gírias ou erros de digitação (ex: "pao de forma", "cafe com
   leite"). Interprete o alimento mesmo assim, sem pedir esclarecimento —
   faça sua melhor estimativa nutricional sempre. Você NUNCA responde com
   lista vazia, erro ou pedido de mais informação — sempre entrega pelo
   menos uma estimativa completa e razoável.

${MEDIDAS_CASEIRAS}
Responda APENAS com um JSON válido (sem markdown, sem texto adicional, sem
comentários), no formato de uma lista. Para cada item, inclua os campos
abaixo — "quantity" e "unit" documentam a quantidade/unidade que você
detectou, e "grams"/"calories"/os macros já devem vir multiplicados pela
quantidade total:
[
  {
    "name": "Pão de forma",
    "quantity": 4,
    "unit": "fatia",
    "grams": 100,
    "calories": 280,
    "protein_g": 8,
    "carbs_g": 52,
    "fat_g": 4
  }
]

Texto do usuário para interpretar: "${description}"`;
}

// -----------------------------------------------------------------------
// Handler
// -----------------------------------------------------------------------

export default async (req: Request, _context: Context) => {
  if (req.method !== 'POST') {
    return Response.json({ error: 'Método não permitido. Use POST.' }, { status: 405 });
  }

  const apiKey = Netlify.env.get('GEMINI_API_KEY');
  if (!apiKey) {
    // Só acontece se a variável de ambiente não foi cadastrada nas
    // configurações do site no Netlify — erro de configuração do
    // servidor, não do app.
    return Response.json(
      { error: 'server_misconfigured', message: 'GEMINI_API_KEY não configurada no servidor.' },
      { status: 500 },
    );
  }

  let payload: { mode?: string; base64Image?: string; description?: string; base64Audio?: string };
  try {
    payload = await req.json();
  } catch {
    return Response.json({ error: 'Corpo da requisição precisa ser JSON válido.' }, { status: 400 });
  }

  const { mode, base64Image, description, base64Audio } = payload;

  if (mode !== 'photo' && mode !== 'text' && mode !== 'transcribe') {
    return Response.json({ error: 'Campo "mode" deve ser "photo", "text" ou "transcribe".' }, { status: 400 });
  }
  if (mode === 'transcribe' && !base64Audio) {
    return Response.json({ error: 'Campo "base64Audio" é obrigatório para mode=transcribe.' }, { status: 400 });
  }
  if (mode === 'photo' && !base64Image) {
    return Response.json({ error: 'Campo "base64Image" é obrigatório para mode=photo.' }, { status: 400 });
  }
  if (mode === 'text' && !description) {
    return Response.json({ error: 'Campo "description" é obrigatório para mode=text.' }, { status: 400 });
  }

  const parts =
    mode === 'transcribe'
      ? [
          { text: TRANSCRIBE_PROMPT },
          { inline_data: { mime_type: 'audio/wav', data: base64Audio } },
        ]
      : mode === 'photo'
      ? [
          { text: PHOTO_PROMPT },
          { inline_data: { mime_type: 'image/jpeg', data: base64Image } },
        ]
      : [{ text: buildTextPrompt(description!) }];

  const startedAt = Date.now();
  let last = { status: 502, body: 'sem resposta' };

  for (const model of MODEL_CHAIN) {
    if (Date.now() - startedAt > 38000) break; // não estoura o tempo do app (50 s)
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    try {
      const geminiResponse = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts }],
          generationConfig: buildGenerationConfig(model, mode),
        }),
        signal: AbortSignal.timeout(20000),
      });
      const bodyText = await geminiResponse.text();

      if (!geminiResponse.ok) {
        console.warn('Erro do Gemini', model, geminiResponse.status, bodyText);
        last = { status: geminiResponse.status, body: bodyText };
        if (!RETRYABLE.includes(geminiResponse.status)) break; // erro do pedido: trocar de modelo não ajuda
        continue;
      }

      const data = JSON.parse(bodyText);
      const textParts = (data?.candidates?.[0]?.content?.parts ?? [])
        .filter((p: any) => typeof p?.text === 'string' && !p.thought)
        .map((p: any) => p.text as string);
      if (textParts.length === 0) throw new Error('Resposta do Gemini sem texto.');
      const text = textParts.join('');

      if (mode === 'transcribe') {
        return Response.json({ transcript: text.trim() });
      }
      const items = JSON.parse(text.replace(/```json/g, '').replace(/```/g, '').trim());
      return Response.json({ items, model });
    } catch (err) {
      console.error('Falha com o modelo', model, err);
      last = { status: 502, body: String((err as Error)?.message || err) };
      // timeout, rede ou JSON inválido: tenta o próximo modelo
    }
  }

  return Response.json(
    { error: 'gemini_error', status: last.status, body: last.body },
    { status: last.status },
  );
};

export const config: Config = {
  path: '/api/analyzeFood',
};
