// ============================================
// Script para extrair dados nutricionais do FatSecret Mobile
// Compatível com versões: Brasil (BR) e Estados Unidos (US)
// ============================================

function getNutrientsAndValues() {
    // Seleciona o elemento de nutrition facts (versão internacional/brasileira ou US)
    let nutritionFactsElement = document.querySelector('.nutrition_facts.international') ||
                                 document.querySelector('.nutrition_facts.us');

    if (!nutritionFactsElement) {
        console.error('Elemento .nutrition_facts não encontrado (testado: .international e .us)');
        return null;
    }

    // Detecta qual versão do site estamos usando
    const isUSVersion = nutritionFactsElement.classList.contains('us');
    console.log('Versão detectada:', isUSVersion ? 'US' : 'Internacional/BR');

    // Extrai o nome do alimento do h1
    let foodNameElement = document.querySelector('.page-title h1');
    let foodName = foodNameElement ? foodNameElement.innerText.trim() : null;

    // Extrai a marca do alimento (se disponível)
    let brandElement = document.querySelector('.page-title-prefix h2');
    let brandName = brandElement ? brandElement.innerText.trim() : null;

    // Extrai o ID do FatSecret
    let idFatSecret = null;

    // Tenta extrair do link alternativo (android-app)
    let alternateLink = document.querySelector('link[rel="alternate"]');
    if (alternateLink) {
        let href = alternateLink.getAttribute('href');
        let match = href.match(/\/id\/f\/(\d+)/);
        if (match) {
            idFatSecret = parseInt(match[1]);
        }
    }

    // Se não encontrou, tenta extrair do link "Editar este Alimento"
    if (!idFatSecret) {
        let editLink = document.querySelector('.nutpanel-extension a[href*="rid="]');
        if (editLink) {
            let href = editLink.getAttribute('href');
            let match = href.match(/rid=(\d+)/);
            if (match) {
                idFatSecret = parseInt(match[1]);
            }
        }
    }

    console.log('ID FatSecret:', idFatSecret);

    // Extrai a imagem do carrossel (primeira imagem disponível)
    let foodPhotoElement = document.querySelector('.carousel-item img');
    let foodPhoto = foodPhotoElement ? foodPhotoElement.src : null;

    // Extrai informações da porção selecionada
    let portionElement = document.querySelector('.portion-picker option[selected]');
    let portionDescription = portionElement ? portionElement.innerText.trim() : null;

    // Extrai valores do macroBox (calorias, gordura, carboidratos, proteína)
    let macroBox = document.querySelector('.macroBox');
    let caloriesText = macroBox ? macroBox.querySelector('td:nth-child(1) .light-text')?.innerText.trim() : null;
    let fatText = macroBox ? macroBox.querySelector('td:nth-child(3) .light-text')?.innerText.trim() : null;
    let carbsText = macroBox ? macroBox.querySelector('td:nth-child(5) .light-text')?.innerText.trim() : null;
    let proteinText = macroBox ? macroBox.querySelector('td:nth-child(7) .light-text')?.innerText.trim() : null;

    // Extrai o tamanho da porção (serving size)
    let servingSizeElement = nutritionFactsElement.querySelector('.serving_size_value');
    let servingSize = servingSizeElement ? servingSizeElement.innerText.trim() : portionDescription;

    console.log('Serving size original:', servingSize);

    // Processa o serving size para extrair valor e unidade
    let servingSizeValue = null;
    let servingSizeUnit = 'g';

    if (servingSize) {
        // Tenta extrair gramas do texto entre parênteses (ex: "1 pequena (49 g)" ou "1 pequena (49,5 g)")
        let gramMatch = servingSize.match(/\(([\d.,]+)\s*g\)/);
        if (gramMatch) {
            servingSizeValue = parseFloat(gramMatch[1].replace(',', '.'));
            servingSizeUnit = 'g';
        } else {
            // Se não encontrou gramas, tenta extrair ml
            let mlMatch = servingSize.match(/\(([\d.,]+)\s*ml\)/);
            if (mlMatch) {
                servingSizeValue = parseFloat(mlMatch[1].replace(',', '.'));
                servingSizeUnit = 'ml';
            } else {
                // Tenta extrair número direto (ex: "100 g" ou "100,5 g")
                let directMatch = servingSize.match(/^([\d.,]+)\s*(g|ml|kg|l)/i);
                if (directMatch) {
                    servingSizeValue = parseFloat(directMatch[1].replace(',', '.'));
                    servingSizeUnit = directMatch[2].toLowerCase();
                }
            }
        }
    }

    console.log('Serving size - Valor:', servingSizeValue, 'Unidade:', servingSizeUnit);

    // Inicializa objeto para armazenar nutrientes
    let nutrientDetails = {};

    // Seleciona todos os elementos de nutrientes
    let nutrientElements = nutritionFactsElement.querySelectorAll('.nutrient.left, .nutrient.black.left, .nutrient.sub.left');

    nutrientElements.forEach(nutrientElement => {
        let nutrientText = nutrientElement.innerText.trim();

        // Ignora elementos vazios ou que não são nutrientes
        if (!nutrientText || nutrientText === '' || nutrientText === '&nbsp;') {
            return;
        }

        // Busca o valor (elemento .value.left ou .right seguinte)
        let valueElement = nutrientElement.nextElementSibling;

        // Na versão US, o valor vem em .nutrient.value.left
        // Na versão BR/Internacional, pode vir em .right ou similar
        while (valueElement &&
               !valueElement.classList.contains('value') &&
               !valueElement.classList.contains('right')) {
            valueElement = valueElement.nextElementSibling;
        }

        let valueText = '';
        if (valueElement && (valueElement.classList.contains('value') || valueElement.classList.contains('right'))) {
            // Usa innerText para pegar todo o conteúdo, incluindo spans internos
            // que podem separar a parte inteira da decimal (ex: <span>45</span>.<span>5</span>g)
            valueText = valueElement.innerText.trim();

            // Se ainda assim não pegou direito, tenta pegar o textContent completo
            if (!valueText || valueText === '') {
                valueText = valueElement.textContent.trim();
            }
        }

        // Remove unidades e converte para número
        // Ignora valores que são apenas "-" (não disponível)
        if (valueText === '-' || valueText === '') {
            nutrientDetails[nutrientText] = null;
            console.log(`${nutrientText}: não disponível`);
            return;
        }

        // IMPORTANTE: Ignora valores percentuais (ex: "45%", "1138%")
        // Esses são % do valor diário, não valores absolutos
        if (valueText.includes('%')) {
            console.log(`${nutrientText}: "${valueText}" é percentual, ignorando...`);
            nutrientDetails[nutrientText] = null;
            return;
        }

        // Extrai apenas valores absolutos (g, mg, mcg, etc.)
        // Aceita formatos: "2.87g", "2,87g", "293mg", "0.819 g", "0,819 g", etc.
        // IMPORTANTE: Aceita vírgula E ponto como separador decimal
        let absoluteMatch = valueText.match(/([\d.,]+)\s*(g|mg|mcg|µg)/i);

        if (!absoluteMatch) {
            console.log(`${nutrientText}: "${valueText}" não é valor absoluto, ignorando...`);
            nutrientDetails[nutrientText] = null;
            return;
        }

        // Converte vírgula para ponto antes de fazer parseFloat
        let numericValue = parseFloat(absoluteMatch[1].replace(',', '.'));
        let unit = absoluteMatch[2].toLowerCase();

        // Lista de nutrientes que devem manter a unidade mg (não converter para g)
        const keepMgNutrients = [
            'Colesterol', 'Cholesterol',
            'Sódio', 'Sodium',
            'Potássio', 'Potassium',
            'Cálcio', 'Calcium',
            'Ferro', 'Iron',
            'Vitamina A', 'Vitamin A',
            'Vitamina C', 'Vitamin C',
            'Vitamina D', 'Vitamin D',
            'Vitamina B6', 'Vitamin B6',
            'Vitamina B12', 'Vitamin B12'
        ];

        // Verifica se esse nutriente deve manter mg
        const shouldKeepMg = keepMgNutrients.some(name =>
            nutrientText.toLowerCase().includes(name.toLowerCase())
        );

        // Converte mg e mcg para g APENAS para gorduras, carboidratos, proteínas, fibras, açúcar
        if (!shouldKeepMg) {
            if (unit === 'mg') {
                numericValue = numericValue / 1000;
                unit = 'g';
            } else if (unit === 'mcg' || unit === 'µg') {
                numericValue = numericValue / 1000000;
                unit = 'g';
            }
        }

        console.log(`${nutrientText}: "${valueText}" -> ${numericValue}${unit}`);

        nutrientDetails[nutrientText] = isNaN(numericValue) ? null : numericValue;
    });

    // Converte os valores do macroBox também (aceita vírgula como separador decimal)
    let caloriesValue = caloriesText ? parseFloat(caloriesText.replace(',', '.').replace(/[^\d.-]/g, '')) : null;

    // Extrai valores absolutos do macroBox (remove % e pega apenas valores com unidade g)
    // IMPORTANTE: Aceita vírgula E ponto como separador decimal
    let fatValue = null;
    if (fatText) {
        let match = fatText.match(/([\d.,]+)\s*g/i);
        fatValue = match ? parseFloat(match[1].replace(',', '.')) : null;
    }

    let carbsValue = null;
    if (carbsText) {
        let match = carbsText.match(/([\d.,]+)\s*g/i);
        carbsValue = match ? parseFloat(match[1].replace(',', '.')) : null;
    }

    let proteinValue = null;
    if (proteinText) {
        let match = proteinText.match(/([\d.,]+)\s*g/i);
        proteinValue = match ? parseFloat(match[1].replace(',', '.')) : null;
    }

    console.log('MacroBox extraído:', {
        calories: caloriesValue,
        fat: fatValue,
        carbs: carbsValue,
        protein: proteinValue
    });

    // Helper function para buscar nutriente por nome (suporta PT e EN)
    function getNutrient(...names) {
        for (let name of names) {
            if (nutrientDetails[name] !== undefined) {
                return nutrientDetails[name];
            }
        }
        return null;
    }

    // Retorna os dados no formato padrão (igual ao script original)
    return {
        portion: [
            {
                proportion: 1,
                description: portionDescription || servingSize
            }
        ],
        nutrient: [
            {
                serving_size: servingSizeValue,
                serving_unit: servingSizeUnit,
                calories: caloriesValue,
                carbohydrate: carbsValue || getNutrient('Carboidratos', 'Total Carbohydrate'),
                protein: proteinValue || getNutrient('Proteínas', 'Protein'),
                fat: fatValue || getNutrient('Gorduras', 'Total Fat'),
                saturated_fat: getNutrient('Gordura Saturada', 'Saturated Fat'),
                polyunsaturated_fat: getNutrient('Gordura Poliinsaturada', 'Polyunsaturated Fat'),
                monounsaturated_fat: getNutrient('Gordura Monoinsaturada', 'Monounsaturated Fat'),
                trans_fat: getNutrient('Gordura Trans', 'Trans Fat'),
                cholesterol: getNutrient('Colesterol', 'Cholesterol'),
                sodium: getNutrient('Sódio', 'Sodium'),
                potassium: getNutrient('Potássio', 'Potassium'),
                dietary_fiber: getNutrient('Fibras', 'Dietary Fiber'),
                sugars: getNutrient('Açúcar', 'Sugars'),
                added_sugars: getNutrient('Açúcares Adicionados', 'Added Sugars'),
                vitamin_a: getNutrient('Vitamina A', 'Vitamin A'),
                vitamin_c: getNutrient('Vitamina C', 'Vitamin C'),
                vitamin_d: getNutrient('Vitamina D', 'Vitamin D'),
                calcium: getNutrient('Cálcio', 'Calcium'),
                iron: getNutrient('Ferro', 'Iron')
            }
        ],
        food: {
            name: foodName,
            photo: foodPhoto,
            brand: brandName,
            id_fatsecret: idFatSecret,
            is_vegetarian: null, // Não disponível no HTML mobile
            is_vegan: null // Não disponível no HTML mobile
        },
        allergens: [] // Não disponível no HTML mobile
    };
}

// Função para extrair informações de todas as porções da tabela "Quantidades comuns"
function getAllPortionsWithCalories() {
    // Busca a seção "Quantidades comuns"
    let sectionTitle = Array.from(document.querySelectorAll('.section-title h2'))
        .find(h2 => h2.textContent.includes('Quantidades') && h2.textContent.includes('comuns'));

    if (!sectionTitle) {
        console.warn('Seção "Quantidades comuns" não encontrada');
        return [];
    }

    // Navega até a tabela
    let section = sectionTitle.closest('.section');
    let tableRows = section.querySelectorAll('table.list tbody tr');

    let portions = [];

    tableRows.forEach(row => {
        // Ignora o header da tabela
        if (row.querySelector('th')) {
            return;
        }

        // Extrai a descrição da porção
        let descriptionElement = row.querySelector('td:first-child a');
        let smallTextElement = row.querySelector('td:first-child .small-text');

        if (!descriptionElement) {
            return;
        }

        let description = descriptionElement.innerText.trim();
        if (smallTextElement) {
            description += ' ' + smallTextElement.innerText.trim();
        }

        // Extrai as calorias (aceita vírgula como separador decimal)
        let caloriesElement = row.querySelector('td:last-child a');
        let calories = caloriesElement ? parseFloat(caloriesElement.innerText.trim().replace(',', '.')) : null;

        // Extrai a URL
        let url = descriptionElement.getAttribute('href');

        portions.push({
            description: description,
            calories: calories,
            url: url
        });
    });

    return portions;
}

// Função para processar todas as porções e calcular proporções
function processAllPortions() {
    // Processa a porção atual (selecionada) para obter os nutrientes base
    let currentData = getNutrientsAndValues();

    if (!currentData) {
        console.error('Erro ao processar dados nutricionais');
        return null;
    }

    // Extrai todas as porções com suas calorias
    let allPortions = getAllPortionsWithCalories();
    console.log('Porções disponíveis:', allPortions);

    // Se não encontrou porções na tabela, usa apenas a porção única do serving_size_value
    if (allPortions.length === 0) {
        console.warn('Tabela de porções não encontrada. Usando porção única do serving_size_value');

        // Mantém a porção única que já foi extraída em currentData
        // com proportion = 1 (já é o padrão em getNutrientsAndValues)
        console.log('Usando porção única:', currentData.portion);
        return currentData;
    }

    // Identifica qual é a porção base (geralmente 100g ou 100ml)
    let basePortionIndex = allPortions.findIndex(p =>
        p.description.includes('100 g') || p.description.includes('100g')
    );

    // Se não encontrou 100g, procura por 100ml
    if (basePortionIndex === -1) {
        basePortionIndex = allPortions.findIndex(p =>
            p.description.includes('100 ml') || p.description.includes('100ml')
        );
    }

    // Se ainda não encontrou, usa a primeira porção
    if (basePortionIndex === -1) {
        basePortionIndex = 0;
    }

    let basePortion = allPortions[basePortionIndex];
    let baseCalories = basePortion.calories;

    console.log('Porção base identificada:', basePortion);

    // Calcula as proporções de todas as porções com base nas calorias
    let portionsWithProportions = allPortions.map(portion => {
        let proportion = baseCalories !== 0 && baseCalories !== null && portion.calories !== null
            ? portion.calories / baseCalories
            : 1;

        return {
            proportion: proportion,
            description: portion.description
        };
    });

    console.log('Porções com proporções calculadas:', portionsWithProportions);

    // Atualiza o resultado com todas as porções
    currentData.portion = portionsWithProportions;

    return currentData;
}

async function sendPostRequest(data) {
    let url = `https://nutro.snapdark.com/food/script?region=BR&language=&source=mobile`;

    try {
        console.log('Enviando dados para o servidor (fonte: mobile)...');
        let response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
        });

        if (!response.ok) {
            let errorText = await response.text();
            throw new Error(`HTTP error! status: ${response.status} - ${errorText}`);
        }

        let result = await response.json();
        console.log('=== SUCESSO AO SALVAR NO SERVIDOR ===');
        console.log(result);
        console.log('=====================================');
        return result;
    } catch (error) {
        console.error('=== ERRO AO SALVAR NO SERVIDOR ===');
        console.error(error);
        console.error('===================================');
        throw error;
    }
}

// Função principal
async function main() {
    console.log('Iniciando extração de dados nutricionais...');

    // Processa os dados da página atual
    let data = processAllPortions();

    if (!data) {
        console.error('Falha ao processar dados');
        return;
    }

    // Exibe os resultados no console
    console.log('=== DADOS PROCESSADOS ===');
    console.log(JSON.stringify(data, null, 2));
    console.log('=========================');

    // Envia os dados para o servidor
    await sendPostRequest(data);
}

// Executa a função principal
main();
