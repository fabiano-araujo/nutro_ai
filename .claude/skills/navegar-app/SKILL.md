---
name: navegar-app
description: Navega e testa o app Nutro AI com Playwright MCP. Use quando precisar testar fluxos, buscar alimentos, fazer login, verificar telas ou explorar o app.
disable-model-invocation: false
argument-hint: "[o que fazer no app - ex: busca arroz, faz login, verifica perfil]"
---

# Navegador Inteligente do Nutro AI

Voce controla o app Nutro AI via Playwright MCP. Sempre siga este fluxo.

## Passo 1: Verificar se o Flutter esta rodando

Tente navegar para `http://localhost:3000`. Se falhar, inicie o Flutter:

```bash
cd "c:/Users/Fabiano/AndroidStudioProjects/nutro_ia" && flutter run -d web-server --web-port 3000 2>&1
```

Rode em background e aguarde ~35 segundos ate ver: `lib\main.dart is being served at http://localhost:3000`

## Passo 2: Abrir o app no navegador

Use `mcp__playwright__browser_navigate` para `http://localhost:3000`.
Aguarde ~8 segundos para o Flutter carregar os modulos DDC.

## Passo 3: Habilitar Acessibilidade (OBRIGATORIO)

O Flutter CanvasKit NAO expoe elementos sem acessibilidade. Execute via `browser_run_code`:

```javascript
async (page) => {
  await page.evaluate(() => {
    const btn = document.querySelector('flt-semantics-placeholder[aria-label="Enable accessibility"]');
    if (btn) btn.click();
  });
  await page.waitForTimeout(3000);
}
```

## Passo 4: Snapshot e Agir

Use `mcp__playwright__browser_snapshot` para ver os elementos e seus refs.
IMPORTANTE: Refs mudam a cada navegacao. NUNCA reutilize refs de snapshots anteriores.

## Mapa do App

### Barra Inferior (4 abas)

| Aba | Nome no snapshot | O que faz |
|-----|-----------------|-----------|
| 1 | `"Inicio Guia 1 de 4"` | Tela principal - dieta do dia, refeicoes |
| 2 | `"Minha Dieta Guia 2 de 4"` | Plano alimentar personalizado |
| 3 | `"Social Guia 3 de 4"` | Feed social, amigos, desafios |
| 4 | `"Perfil Guia 4 de 4"` | Login, dados do usuario, configuracoes |

### Tela Home (Aba 1)

- `button "Menu"` — menu lateral
- `button "Hoje"` — refeicoes de hoje
- `button "Pesquisar alimentos"` — abre busca completa
- Dias da semana: `button "DOM 8"`, `"SEG 9"`, etc.
- Acoes rapidas:
  - `"Registrar Adicionar refeicao"` — registrar comida
  - `"Foto Analisar com IA"` — analise de foto de comida
  - `"Perfil Configurar dados"` — dados pessoais
  - `"Metas Definir objetivos"` — metas nutricionais
- `textbox "O que voce comeu?"` — busca rapida
- `button "Recentes e Favoritos"` — historico

### Buscar Alimentos

1. Clique `"Pesquisar alimentos"` ou no campo `"O que voce comeu?"`
2. Na tela de busca: `heading "Buscar Alimento"` com `textbox`
3. Digite o alimento com `browser_type`
4. Pressione Enter com `browser_press_key` → `"Enter"`
5. Resultados aparecem como: `group "🍽️ [Nome] [kcal] • [porcao]g"`
6. Abas da busca: `tab "Frequentes"` | `tab "Recentes"` | `tab "Favoritos"`

### Detalhes do Alimento

Ao clicar num resultado:
- Nome e marca do alimento
- `textbox` — quantidade (gramas)
- `button "g"` — unidade de medida
- Macros: 🔥 kcal, 💪 proteina(g), 🌾 carboidratos(g), 🥑 gordura(g)
- Tabela de micronutrientes
- `button "Add to Meal"` — adicionar a refeicao

### Perfil / Login (Aba 4)

- Se nao logado: tela de login (Google ou email/senha)
- Se logado: nome, foto, configuracoes, historico

## Regras de Ouro

1. **Sempre snapshot antes de agir** — para pegar refs atualizados
2. **Refs sao efemeros** — nunca guardar refs entre acoes
3. **App em portugues** — nomes dos elementos sao em PT-BR
4. **API retorna ate 20 itens** por busca
5. **Erros DartError UnimplementedError** no console sao normais no web
6. **Warning de fontes Noto** pode ser ignorado
7. Se um clique falhar com "element is outside viewport", use `browser_run_code` com evaluate para clicar via JS

## Tarefa

$ARGUMENTS
