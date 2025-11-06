# Documentação da Feature: Dieta Personalizada

## Visão Geral

Foi implementada uma nova funcionalidade de **Dieta Personalizada** que permite aos usuários gerar planos de dieta personalizados com base em seus objetivos nutricionais, utilizando IA para criar refeições balanceadas.

## Arquivos Criados

### 1. Models
- **`lib/models/diet_plan_model.dart`**
  - `DietPlan`: Modelo principal contendo o plano de dieta completo para um dia
  - `DailyNutrition`: Resumo nutricional (calorias, proteínas, carboidratos, gorduras)
  - `PlannedMeal`: Representa uma refeição específica com tipo, horário, nome e alimentos
  - `PlannedFood`: Alimento individual com informações nutricionais detalhadas
  - `DietPreferences`: Preferências do usuário (número de refeições, horário de maior fome, etc.)

### 2. Providers
- **`lib/providers/diet_plan_provider.dart`**
  - Gerencia o estado dos planos de dieta
  - Integra com `AIService` para geração de dietas via IA
  - Métodos principais:
    - `generateDietPlan()`: Gera um plano completo para um dia
    - `replaceMeal()`: Substitui uma refeição específica mantendo os macros
    - `replaceAllMeals()`: Regenera todas as refeições do dia
    - `updatePreferences()`: Atualiza preferências de dieta
  - Persiste dados usando `SharedPreferences`

### 3. Screens
- **`lib/screens/personalized_diet_screen.dart`**
  - Interface principal da feature
  - Componentes:
    - Calendário semanal (reutiliza `WeeklyCalendar`)
    - Resumo nutricional diário
    - Lista expansível de refeições
    - Botões para substituir refeições individualmente ou todas
    - Dialog de configuração de preferências
  - Features:
    - Visualização de alimentos por refeição com emojis
    - Informações nutricionais detalhadas
    - Integração com sistema de autenticação
    - Loading states e tratamento de erros

### 4. Agent Prompt
- **`dieta_api/diet-agent-prompt.txt`**
  - Prompt detalhado para o agente de IA
  - Define formato de entrada e saída em JSON
  - Orientações sobre distribuição de calorias
  - Diretrizes para seleção de alimentos (culinária brasileira/portuguesa)
  - Especificações de macros e variedade

## Arquivos Modificados

### 1. Navigation
- **`lib/screens/main_navigation.dart`**
  - Adicionada importação de `PersonalizedDietScreen`
  - Nova tela adicionada ao `_screens` (3ª aba)
  - Novo item no bottom navigation bar com ícone `restaurant_menu`
  - Navbar agora tem 4 abas: Chat, Ferramentas, Dieta, Perfil

### 2. Main App
- **`lib/main.dart`**
  - Adicionada importação de `DietPlanProvider`
  - Provider registrado no `MultiProvider`

## Fluxo de Funcionamento

### 1. Geração de Dieta
1. Usuário acessa a aba "Dieta Personalizada"
2. Seleciona uma data no calendário semanal
3. Clica em "Gerar Plano de Dieta"
4. Sistema abre dialog para configurar:
   - Número de refeições por dia (3-6)
   - Horário de maior fome
5. Sistema coleta informações do `NutritionGoalsProvider`:
   - Idade, sexo, peso, altura
   - Nível de atividade física
   - Objetivo fitness
   - Tipo de dieta
   - Metas nutricionais (calorias, macros)
6. Monta prompt e envia para IA via `AIService`
7. IA retorna JSON com plano completo
8. Sistema parseia JSON e salva em `SharedPreferences`
9. Tela exibe plano de dieta com:
   - Resumo nutricional total
   - Refeições expansíveis
   - Alimentos com quantidades e valores nutricionais

### 2. Substituição de Refeições
#### Refeição Individual:
1. Usuário clica no botão de "autorenew" em uma refeição
2. Sistema envia refeição atual para IA com instruções de manter macros
3. IA gera nova refeição com alimentos diferentes
4. Sistema atualiza apenas aquela refeição

#### Todas as Refeições:
1. Usuário clica em "Substituir Todas as Refeições"
2. Dialog de confirmação
3. Sistema regenera plano completo do dia

## Integração com IA

### Endpoint Utilizado
- **`/ai/generate-text`** (via `AIService.getAnswerStream()`)
- Parâmetros:
  - `quality`: 'bom'
  - `agentType`: 'diet'
  - `provider`: 'google'
  - `userId`: ID do usuário autenticado

### Formato de Resposta Esperado
```json
{
  "date": "YYYY-MM-DD",
  "totalNutrition": {
    "calories": number,
    "protein": number,
    "carbs": number,
    "fat": number
  },
  "meals": [
    {
      "type": "breakfast|lunch|dinner|snack",
      "time": "HH:MM",
      "name": "Nome da Refeição",
      "foods": [
        {
          "name": "Nome do Alimento",
          "emoji": "🍳",
          "amount": number,
          "unit": "g|ml|unidade",
          "calories": number,
          "protein": number,
          "carbs": number,
          "fat": number
        }
      ],
      "mealTotals": {
        "calories": number,
        "protein": number,
        "carbs": number,
        "fat": number
      }
    }
  ]
}
```

## Persistência de Dados

### SharedPreferences Keys:
- **`diet_preferences`**: Preferências do usuário (JSON)
- **`diet_plans`**: Mapa de planos por data (JSON)
  - Chave: "YYYY-MM-DD"
  - Valor: DietPlan completo

## Dependências

### Existentes (já no projeto):
- `provider`: State management
- `shared_preferences`: Persistência local
- `http`: Requisições HTTP para IA
- Componentes existentes:
  - `WeeklyCalendar`: Calendário semanal reutilizado
  - `AIService`: Serviço de IA
  - `NutritionGoalsProvider`: Dados nutricionais do usuário
  - `AuthService`: Autenticação

## UX/UI Features

### Design:
- Segue o tema existente do app (dark/light mode)
- Usa emojis para melhor visualização
- Cards expansíveis para economizar espaço
- Cores e estilos consistentes com o resto do app

### Loading States:
- Indicador de progresso durante geração
- Mensagens de feedback ao usuário
- Tratamento de erros com SnackBar

### Navegação:
- Calendário permite navegar entre datas
- Botão "Hoje" para retornar rapidamente
- Date picker para datas distantes

## Próximos Passos Sugeridos

1. **Backend**: Criar endpoint dedicado `/ai/generate-diet` no backend
2. **Cache**: Implementar cache de dietas geradas
3. **Exportar**: Adicionar funcionalidade de exportar dieta como PDF/imagem
4. **Histórico**: Visualização de histórico de dietas
5. **Favoritos**: Marcar refeições favoritas para reutilizar
6. **Shopping List**: Gerar lista de compras baseada na dieta
7. **Notificações**: Lembrete de refeições nos horários configurados
8. **Variações**: Sugerir variações de refeições similares
9. **Tracking**: Marcar refeições como consumidas
10. **Analytics**: Gráficos de aderência ao plano

## Notas Técnicas

- A feature foi implementada de forma independente, não afetando funcionalidades existentes
- Todos os providers são lazy-loaded para melhor performance
- JSON parsing inclui tratamento de erros robusto
- Suporta múltiplos formatos de resposta da IA
- Código bem documentado e seguindo padrões do projeto

## Como Testar

1. Faça login no app
2. Configure seus objetivos nutricionais (se ainda não tiver)
3. Acesse a nova aba "Dieta" no bottom navigation
4. Configure suas preferências (número de refeições e horário de maior fome)
5. Clique em "Gerar Plano de Dieta"
6. Aguarde a IA gerar o plano
7. Explore as refeições expandindo os cards
8. Teste a substituição de refeições individuais
9. Teste a substituição de todas as refeições
10. Navegue entre diferentes datas no calendário

## Troubleshooting

- **Erro "Configure seus objetivos nutricionais primeiro"**:
  - Acesse o perfil e configure idade, peso, altura e objetivos

- **Erro ao gerar dieta**:
  - Verifique conexão com internet
  - Verifique se usuário está autenticado
  - Verifique logs do backend para erros de IA

- **JSON inválido**:
  - IA pode retornar resposta em formato incorreto
  - Sistema tenta extrair JSON da resposta
  - Se falhar, mostrar erro ao usuário
