# Design - Melhoria da Funcionalidade de Redação

## Visão Geral

O design da funcionalidade aprimorada de redação foca em criar uma experiência integrada que combina uma interface moderna e intuitiva com correção automática por IA, feedback personalizado e acompanhamento de progresso. A solução será construída sobre a arquitetura Flutter existente, integrando-se com o backend Node.js e os serviços de IA já disponíveis.

## Arquitetura

### Arquitetura Geral
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │   Node.js API   │    │   AI Services   │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Essay UI    │ │◄──►│ │ Essay API   │ │◄──►│ │ Correction  │ │
│ │ Components  │ │    │ │ Endpoints   │ │    │ │ Engine      │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ State Mgmt  │ │    │ │ Database    │ │    │ │ Analytics   │ │
│ │ (Provider)  │ │    │ │ (Prisma)    │ │    │ │ Engine      │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Fluxo de Dados
1. **Criação/Edição**: Interface → Provider → Local Storage → API (quando salvar)
2. **Correção**: Interface → API → AI Service → Database → Interface (resultado)
3. **Histórico**: Interface → Provider → API → Database → Interface

## Componentes e Interfaces

### 1. Interface do Editor Aprimorado

#### EssayEditorWidget
```dart
class EssayEditorWidget extends StatefulWidget {
  final Essay? initialEssay;
  final String essayType;
  final Function(Essay) onSave;
  final Function(Essay) onSubmit;
}
```

**Funcionalidades:**
- Editor de texto rico com formatação básica
- Contador de palavras/caracteres em tempo real
- Auto-save a cada 30 segundos
- Sugestões de correção ortográfica
- Interface responsiva para mobile/desktop
- Barra de ferramentas contextual

#### EssayTypeSelector
```dart
class EssayTypeSelector extends StatelessWidget {
  final String selectedType;
  final Function(String) onTypeChanged;
  final List<EssayTemplate> availableTemplates;
}
```

**Templates Disponíveis:**
- ENEM (dissertativo-argumentativo)
- Vestibular (diversos formatos)
- Concurso (específicos por área)
- Livre (formato personalizado)

### 2. Sistema de Correção por IA

#### EssayCorrectionService
```dart
class EssayCorrectionService {
  Future<EssayCorrection> correctEssay(Essay essay);
  Future<List<EssaySuggestion>> generateSuggestions(Essay essay);
  Future<EssayComparison> compareWithModel(Essay essay, String type);
}
```

**Critérios de Avaliação:**
- **Competência 1**: Domínio da norma culta (0-200 pontos)
- **Competência 2**: Compreensão do tema (0-200 pontos)
- **Competência 3**: Argumentação e coesão (0-200 pontos)
- **Competência 4**: Conhecimento dos mecanismos linguísticos (0-200 pontos)
- **Competência 5**: Proposta de intervenção (0-200 pontos)

#### EssayAnalyzer
```dart
class EssayAnalyzer {
  EssayMetrics analyzeStructure(String text);
  List<GrammarError> checkGrammar(String text);
  List<StyleSuggestion> analyzeStyling(String text);
  CoherenceScore evaluateCoherence(String text);
}
```

### 3. Interface de Resultados

#### EssayResultScreen (Aprimorada)
```dart
class EssayResultScreen extends StatefulWidget {
  final String essayId;
  final EssayCorrection correction;
}
```

**Melhorias na Interface:**
- Visualização interativa da pontuação com animações
- Gráficos de radar para competências
- Seções expansíveis para feedback detalhado
- Comparação lado a lado (original vs sugestões)
- Botões de ação rápida (nova redação, compartilhar, etc.)

#### CompetencyRadarChart
```dart
class CompetencyRadarChart extends StatelessWidget {
  final Map<String, int> competencyScores;
  final bool animated;
}
```

### 4. Sistema de Progresso e Analytics

#### ProgressTracker
```dart
class ProgressTracker {
  List<ProgressPoint> getProgressHistory(String userId);
  ProgressSummary calculateSummary(String userId, DateRange range);
  List<Achievement> checkAchievements(String userId);
  ComparisonData compareWithPeers(String userId);
}
```

#### ProgressVisualization
- Gráfico de linha para evolução temporal
- Gráfico de barras para competências
- Heatmap de atividade de escrita
- Badges e conquistas

### 5. Sistema de Templates e Temas

#### ThemeProvider
```dart
class ThemeProvider {
  List<EssayTheme> getTrendingThemes();
  List<EssayTheme> getThemesByCategory(String category);
  EssayTheme generateRandomTheme(String type);
  List<Reference> getThemeReferences(String themeId);
}
```

**Categorias de Temas:**
- Atualidades
- Meio Ambiente
- Tecnologia
- Sociedade
- Educação
- Saúde
- Política
- Economia

## Modelos de Dados

### Essay (Aprimorado)
```dart
class Essay {
  final String id;
  final String title;
  final String text;
  final String type;
  final String? themeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int wordCount;
  final int characterCount;
  final String status; // draft, submitted, corrected, archived
  final Map<String, dynamic>? metadata;
  final List<String>? tags;
}
```

### EssayCorrection
```dart
class EssayCorrection {
  final String id;
  final String essayId;
  final int totalScore;
  final Map<String, int> competencyScores;
  final List<DetailedFeedback> feedback;
  final List<EssaySuggestion> suggestions;
  final DateTime correctedAt;
  final String correctionVersion;
}
```

### DetailedFeedback
```dart
class DetailedFeedback {
  final String competency;
  final int score;
  final String summary;
  final List<SpecificComment> comments;
  final List<ImprovementTip> tips;
}
```

### EssaySuggestion
```dart
class EssaySuggestion {
  final String type; // grammar, style, structure, content
  final String originalText;
  final String suggestedText;
  final String explanation;
  final int startPosition;
  final int endPosition;
  final SuggestionPriority priority;
}
```

## Tratamento de Erros

### Estratégias de Error Handling
1. **Conexão de Rede**: Cache local com sincronização posterior
2. **Falhas de IA**: Fallback para correção básica ou modo offline
3. **Perda de Dados**: Auto-save frequente e recuperação de sessão
4. **Validação**: Feedback em tempo real com mensagens claras

### Estados de Loading
- Skeleton screens durante carregamento
- Progress indicators para correção de IA
- Estados vazios com call-to-action
- Mensagens de erro com opções de retry

## Estratégia de Testes

### Testes Unitários
- Validação de modelos de dados
- Lógica de negócio dos providers
- Funções de análise de texto
- Cálculos de pontuação

### Testes de Widget
- Componentes de interface
- Interações do usuário
- Estados de loading e erro
- Responsividade

### Testes de Integração
- Fluxo completo de criação/correção
- Sincronização com API
- Persistência de dados
- Performance com textos longos

### Testes de Performance
- Tempo de resposta da correção
- Uso de memória com múltiplas redações
- Responsividade da interface
- Otimização de imagens e assets

## Considerações de UX/UI

### Design System
- Cores consistentes com o tema do app
- Tipografia otimizada para leitura
- Espaçamentos harmoniosos
- Iconografia intuitiva

### Acessibilidade
- Suporte a leitores de tela
- Contraste adequado de cores
- Tamanhos de fonte ajustáveis
- Navegação por teclado

### Responsividade
- Layout adaptativo para diferentes tamanhos
- Otimização para tablets
- Gestos touch otimizados
- Orientação portrait/landscape

### Microinterações
- Animações suaves de transição
- Feedback visual para ações
- Loading states engajantes
- Confirmações de ações importantes