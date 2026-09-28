// Backend seguro do NutriSnap — versão Netlify Functions.
//
// Guarda a chave do Gemini como variável de ambiente no servidor (nunca no
// app) e repassa a chamada pro Gemini. Mesmo contrato de request/response
// que o app Flutter já espera (ver lib/services/gemini_service.dart), então
// nenhuma mudança é necessária do lado do app: POST com
// { mode: "photo", base64Image } ou { mode: "text", description } → resposta
// { items: [...] }.

import type { Context, Config } from '@netlify/functions';

const GEMINI_MODEL = 'gemini-2.5-flash';

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

4. Depois de aplicar as regras acima, calcule as calorias e os macros (proteína,
   carboidrato, gordura) já como TOTAIS do item (considerando a quantidade e o
   peso real estimados), não como valores de referência por 100g.

Responda APENAS com um JSON válido (sem markdown, sem texto adicional, sem
comentários), no formato de uma lista. Para cada item, inclua os campos abaixo —
"quantity" e "unit" documentam a contagem que você usou, e "grams"/"calories"/
os macros já devem vir multiplicados pela quantidade total:
[
  {
    "name": "Pão de forma",
    "quantity": 3,
    "unit": "fatia",
    "grams": 75,
    "calories": 210,
    "protein_g": 6,
    "carbs_g": 39,
    "fat_g": 3
  }
]`;

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

  let payload: { mode?: string; base64Image?: string; description?: string };
  try {
    payload = await req.json();
  } catch {
    return Response.json({ error: 'Corpo da requisição precisa ser JSON válido.' }, { status: 400 });
  }

  const { mode, base64Image, description } = payload;

  if (mode !== 'photo' && mode !== 'text') {
    return Response.json({ error: 'Campo "mode" deve ser "photo" ou "text".' }, { status: 400 });
  }
  if (mode === 'photo' && !base64Image) {
    return Response.json({ error: 'Campo "base64Image" é obrigatório para mode=photo.' }, { status: 400 });
  }
  if (mode === 'text' && !description) {
    return Response.json({ error: 'Campo "description" é obrigatório para mode=text.' }, { status: 400 });
  }

  const parts =
    mode === 'photo'
      ? [
          { text: PHOTO_PROMPT },
          { inline_data: { mime_type: 'image/jpeg', data: base64Image } },
        ]
      : [{ text: buildTextPrompt(description!) }];

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`;

  try {
    const geminiResponse = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts }],
        generationConfig: { response_mime_type: 'application/json' },
      }),
      signal: AbortSignal.timeout(45000),
    });

    const bodyText = await geminiResponse.text();

    if (!geminiResponse.ok) {
      console.warn('Erro retornado pelo Gemini', geminiResponse.status, bodyText);
      return Response.json(
        { error: 'gemini_error', status: geminiResponse.status, body: bodyText },
        { status: geminiResponse.status },
      );
    }

    const data = JSON.parse(bodyText);
    let text: unknown = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof text !== 'string') {
      throw new Error('Resposta do Gemini sem o campo de texto esperado.');
    }
    text = text.replace(/```json/g, '').replace(/```/g, '').trim();
    const items = JSON.parse(text as string);

    return Response.json({ items });
  } catch (err) {
    console.error('Falha ao processar chamada ao Gemini', err);
    return Response.json(
      { error: 'backend_error', message: String((err as Error)?.message || err) },
      { status: 502 },
    );
  }
};

export const config: Config = {
  path: '/api/analyzeFood',
};
