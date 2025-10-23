import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../main.dart'; // Importar o arquivo main.dart para acessar navigatorKey

/// Classe responsável pela formatação de mensagens, incluindo fórmulas LaTeX, tabelas e listas
class MessageFormatter {
  /// Formata texto, detectando e renderizando fórmulas matemáticas
  static Widget buildFormattedText(String text,
      {required TextStyle style, required bool isDarkMode}) {
    // Verificar se o texto contém fórmulas matemáticas
    bool containsFormulas = text.contains('\\') ||
        text.contains('\$') ||
        text.contains('\\frac') ||
        text.contains('\\sqrt') ||
        text.contains('\\Delta') ||
        RegExp(r'\\([a-zA-Z])\\').hasMatch(text) || // Formato \a\, \b\, etc
        RegExp(r'\\([a-zA-Z])\^').hasMatch(text) || // Formatos como \a^2\
        RegExp(r'\\([a-zA-Z][0-9])\\')
            .hasMatch(text) || // Formato \a1\, \x2\, etc.
        RegExp(r'\\\\').hasMatch(text); // Backslashes escapados

    // Verificar se temos blocos de código para renderizar
    if (text.contains('```')) {
      // Verificamos se realmente existem blocos de código fechados (``` seguido por ```)
      final RegExp codeBlockPattern =
          RegExp(r'```(?:[\w-]+\n)?[\s\S]*?```', dotAll: true);
      if (codeBlockPattern.hasMatch(text)) {
        return formatCodeBlocks(text, style, isDarkMode);
      }
    }

    // Se contém fórmulas, priorizar o processamento de fórmulas
    if (containsFormulas) {
      return _processTextWithFormulas(text, style, isDarkMode);
    }

    // Verificar se temos cabeçalhos markdown (###, ##, #)
    if (text.contains('###') ||
        text.contains('##') ||
        text.contains('\n# ') ||
        text.startsWith('# ')) {
      return formatMarkdownHeadings(text, style, isDarkMode);
    }

    // Verificar se temos formatação markdown básica (negrito, itálico)
    if (text.contains('**') ||
        text.contains('__') ||
        text.contains('*') ||
        text.contains('_')) {
      // Se o texto não contém quebras de linha, podemos usar apenas processInlineMarkdown
      if (!text.contains('\n')) {
        List<InlineSpan> spans = processInlineMarkdown(text, style, isDarkMode);
        return SelectableText.rich(
          TextSpan(children: spans),
        );
      } else {
        // Se contém quebras de linha, processar como marcações em múltiplas linhas
        return formatMarkdownText(text, style, isDarkMode);
      }
    }

    // Verificar se temos listas ou tabelas para formatar
    if (text.contains('|') || text.contains('-') && text.contains('+')) {
      return formatTablesAndLists(text, style, isDarkMode);
    }

    // Retornar texto simples se não houver nenhuma formatação especial
    return SelectableText(
      text,
      style: style,
    );
  }

  // Novo método para processar texto com fórmulas
  static Widget _processTextWithFormulas(
      String text, TextStyle style, bool isDarkMode) {
    print('Processando fórmulas em texto: $text');

    // Corrigir fórmulas mal formatadas
    text = corrigirFormulasMalFormatadas(text);

    print('Texto após correções: $text');

    // Extrair fórmulas matemáticas e texto regular
    final RegExp inlineFormula = RegExp(r'\$(.*?)\$', dotAll: true);
    final RegExp blockFormula = RegExp(r'\$\$(.*?)\$\$', dotAll: true);
    final RegExp slashBracketFormula =
        RegExp(r'\\\[(.*?)\\\]', dotAll: true); // Para fórmulas como \[ ... \]
    final RegExp slashParensFormula =
        RegExp(r'\\\((.*?)\\\)', dotAll: true); // Para fórmulas como \( ... \)

    // Primeiro, analisamos o texto em blocos
    List<Widget> textWidgets = [];
    List<String> parts = [];
    List<bool> isFormulaFlags = [];
    List<MathStyle> mathStyleFlags = [];

    // Verificar fórmulas de bloco primeiro (entre $$...$$ ou \[ ... \])
    int lastEnd = 0;

    // Função para processar diferentes tipos de delimitadores de bloco
    void processBlockDelimiters(RegExp regExp, {bool isDisplayMode = true}) {
      for (Match match in regExp.allMatches(text)) {
        // Adicionar texto antes da fórmula
        if (match.start > lastEnd) {
          parts.add(text.substring(lastEnd, match.start));
          isFormulaFlags.add(false);
          mathStyleFlags.add(MathStyle.display); // Valor padrão, não será usado
        }

        // Adicionar a fórmula
        parts.add(match.group(1)!);
        isFormulaFlags.add(true);
        mathStyleFlags.add(isDisplayMode ? MathStyle.display : MathStyle.text);

        lastEnd = match.end;
      }
    }

    // Processar todos os tipos de delimitadores de bloco
    processBlockDelimiters(blockFormula);
    processBlockDelimiters(slashBracketFormula);

    // Adicionar qualquer texto restante
    if (lastEnd < text.length) {
      parts.add(text.substring(lastEnd));
      isFormulaFlags.add(false);
      mathStyleFlags.add(MathStyle.display); // Valor padrão, não será usado
    }

    // Processar fórmulas inline e texto normal
    for (int i = 0; i < parts.length; i++) {
      if (isFormulaFlags[i]) {
        // Este é um bloco de fórmula, adicionar como bloco Math
        try {
          textWidgets.add(
            Container(
              margin: EdgeInsets.symmetric(vertical: 8),
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Builder(builder: (context) {
                    // Criar um ScrollController para verificar se realmente necessita de rolagem
                    final ScrollController controller = ScrollController();

                    // Ajustar tamanho da fonte com base no comprimento da fórmula
                    double fontSize = style.fontSize! * 1.1;

                    // Detectar fórmulas complexas que normalmente ocupam mais espaço
                    bool isComplexFormula = parts[i].contains('\\frac') ||
                        parts[i].contains('\\sqrt') ||
                        parts[i].contains('\\sum') ||
                        parts[i].contains('\\int') ||
                        parts[i].contains('\\matrix');

                    // Fórmulas com muitas frações aninhadas
                    bool hasNestedFractions =
                        parts[i].contains('\\frac') && parts[i].contains('}{');

                    if (parts[i].length > 80 ||
                        (isComplexFormula && parts[i].length > 50)) {
                      // Redução mais agressiva para fórmulas extremamente longas ou complexas
                      fontSize = style.fontSize! * 0.8;
                    } else if (hasNestedFractions || parts[i].length > 50) {
                      // Reduzir bastante para fórmulas com frações aninhadas ou muito grandes
                      fontSize = style.fontSize! * 0.9;
                    } else if (isComplexFormula || parts[i].length > 30) {
                      // Reduzir um pouco para fórmulas médias com elementos complexos
                      fontSize = style.fontSize!;
                    }

                    return Column(
                      children: [
                        SingleChildScrollView(
                          controller: controller,
                          scrollDirection: Axis.horizontal,
                          physics: BouncingScrollPhysics(),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: SelectableText.rich(
                              TextSpan(
                                children: [
                                  WidgetSpan(
                                    child: Math.tex(
                                      parts[i],
                                      textStyle: style.copyWith(
                                        fontSize: fontSize,
                                      ),
                                      mathStyle: mathStyleFlags[i],
                                      onErrorFallback: (errMsg) {
                                        print(
                                            'Erro ao renderizar fórmula: $errMsg');
                                        return Text(
                                          isFormulaFlags[i]
                                              ? '\$${parts[i]}\$'
                                              : parts[i],
                                          style: style,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Usar um futuro para verificar se a fórmula precisa de rolagem
                        FutureBuilder(
                          // Aumentar o atraso para garantir que o layout esteja completo
                          future:
                              Future.delayed(Duration(milliseconds: 200), () {
                            // Verificar se o controlador tem conteúdo que excede o tamanho visível
                            // Usamos um valor mínimo de 10 pixels para compensar pequenas diferenças
                            if (controller.hasClients &&
                                controller.position.maxScrollExtent > 10) {
                              return true; // Precisa de rolagem
                            }
                            return false; // Não precisa de rolagem
                          }),
                          builder: (context, snapshot) {
                            final needsScroll = snapshot.data == true;

                            if (needsScroll) {
                              return Container(
                                margin: EdgeInsets.only(top: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.swipe,
                                      size: 12,
                                      color: isDarkMode
                                          ? Colors.grey[500]
                                          : Colors.grey[600],
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Deslize para ver completo',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDarkMode
                                            ? Colors.grey[500]
                                            : Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return SizedBox.shrink(); // Sem mensagem
                            }
                          },
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          );
        } catch (e) {
          print('Erro ao renderizar fórmula: $e');
          // Caso haja erro no parsing da fórmula, mostrar como texto comum
          textWidgets.add(
            Container(
              margin: EdgeInsets.symmetric(vertical: 4),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDarkMode)
                    Text(
                      'Erro ao processar fórmula:',
                      style: TextStyle(
                        color: Colors.red[300],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Text(
                      'Erro ao processar fórmula:',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  SizedBox(height: 4),
                  Text(
                    '\$${parts[i]}\$',
                    style: style,
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        // Para texto normal, verificar se contém fórmulas inline
        String currentPart = parts[i];

        // Se o texto normal contém marcação markdown, processar isso também
        if (currentPart.contains('###') ||
            currentPart.contains('##') ||
            currentPart.contains('\n# ') ||
            currentPart.startsWith('# ')) {
          // Processar cabeçalhos markdown
          textWidgets
              .add(formatMarkdownHeadings(currentPart, style, isDarkMode));
        } else if (currentPart.contains('**') ||
            currentPart.contains('__') ||
            currentPart.contains('*') ||
            currentPart.contains('_')) {
          // Processar markdown inline
          if (!currentPart.contains('\n')) {
            List<InlineSpan> spans =
                processInlineMarkdown(currentPart, style, isDarkMode);
            textWidgets.add(
              SelectableText.rich(
                TextSpan(children: spans),
              ),
            );
          } else {
            // Se contém quebras de linha, processar como markdown multilinha
            textWidgets.add(formatMarkdownText(currentPart, style, isDarkMode));
          }
        } else {
          // Verificar se há fórmulas inline no texto
          final List<InlineSpan> spans = processarFormulasInline(
              currentPart, style, inlineFormula, slashParensFormula);

          if (spans.isNotEmpty) {
            textWidgets.add(
              SelectableText.rich(
                TextSpan(
                  children: spans,
                  style: style,
                ),
              ),
            );
          } else {
            textWidgets.add(
              Text(
                currentPart,
                style: style,
              ),
            );
          }
        }
      }
    }

    // Retorna todos os widgets em uma coluna
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: textWidgets,
    );
  }

  /// Método para corrigir fórmulas mal formatadas
  static String corrigirFormulasMalFormatadas(String text) {
    // Corrigir problemas comuns de formatação em LaTeX

    // Detectar e corrigir notações problemáticas com o formato da tela do tutor
    if (text.contains("1. Identifique os coeficientes") ||
        text.contains("2. Calcule o discriminante") ||
        text.contains("3. Substitua os valores") ||
        text.contains("Encontre os valores de")) {
      // Corrigir formatos específicos do passo a passo
      text = text.replaceAll('\\(a\\)', '\$a\$');
      text = text.replaceAll('\\(b\\)', '\$b\$');
      text = text.replaceAll('\\(c\\)', '\$c\$');
      text = text.replaceAll(
          '\\( ax^{2} + bx + c = 0 \\)', '\$ax^{2} + bx + c = 0\$');
      text = text.replaceAll(
          '\\(ax^{2} + bx + c = 0\\)', '\$ax^{2} + bx + c = 0\$');
      text = text.replaceAll(
          '\\(\\Delta = b^{2} - 4ac\\)', '\$\\Delta = b^{2} - 4ac\$');
      text = text.replaceAll('\\(\\Delta > 0\\)', '\$\\Delta > 0\$');
      text = text.replaceAll('\\(\\Delta = 0\\)', '\$\\Delta = 0\$');
      text = text.replaceAll('\\(\\Delta < 0\\)', '\$\\Delta < 0\$');
    }

    // Substituir os caracteres que não funcionam bem no LaTeX primeiro
    text = text.replaceAll('~', ' ');
    text = text.replaceAll('·', '\\cdot ');
    text = text.replaceAll('±', '\\pm ');
    text = text.replaceAll(' × ', ' \\times ');

    // Tratar qualquer caso mais genérico de \(letra\)
    text = text.replaceAllMapped(
        RegExp(r'\\([a-zA-Z])\\', caseSensitive: false),
        (match) => '\$${match.group(1)}\$');

    // Tratar casos específicos como ax^{2} + bx + c = 0
    text = text.replaceAllMapped(
        RegExp(
            r'\\([a-zA-Z])\^({\d+}|\d+)( ?\+ ?)\\([a-zA-Z])( ?\+ ?)\\([a-zA-Z])( ?= ?0)',
            caseSensitive: false),
        (match) =>
            '\$${match.group(1)}^${match.group(2)}${match.group(3)}${match.group(4)}${match.group(5)}${match.group(6)}${match.group(7)}\$');

    // Verificar e corrigir valores de Delta
    text = text.replaceAll('\\(\\Delta', '\$\\Delta\$');
    text = text.replaceAll('Delta\\)', 'Delta\$');
    text = text.replaceAll(
        '\\(\\Delta = b^{2} - 4ac\\)', '\$\\Delta = b^{2} - 4ac\$');
    text = text.replaceAll('\\(\\Delta > 0\\)', '\$\\Delta > 0\$');
    text = text.replaceAll('\\(\\Delta = 0\\)', '\$\\Delta = 0\$');
    text = text.replaceAll('\\(\\Delta < 0\\)', '\$\\Delta < 0\$');

    // Formatação específica para o modelo Mistral-Small-3.1
    // Mistral pode usar delimitadores como ```math...``` para fórmulas
    text = text.replaceAllMapped(
        RegExp(r'```math\s*([\s\S]*?)```', caseSensitive: false),
        (match) => '\$\$${match.group(1)}\$\$');

    // Corrigir acentos circunflexos duplos que o Mistral pode gerar
    text = text.replaceAll('^^', '^');

    // Quando o Mistral usa ** para potências em vez de ^
    text = text.replaceAllMapped(
        RegExp(r'(\d+)\*\*(\d+)', caseSensitive: false),
        (match) => '${match.group(1)}^{${match.group(2)}}');

    // Verificar e corrigir comandos \frac sem chaves
    text = text.replaceAllMapped(
        RegExp(r'\\frac([^{])(.)([^{])(.)', caseSensitive: false),
        (match) =>
            '\\frac{${match.group(1)}${match.group(2)}}{${match.group(3)}${match.group(4)}}');

    // Corrigir frac com apenas um conjunto de chaves (comum no Mistral)
    text = text.replaceAllMapped(
        RegExp(r'\\frac{([^{}]+)}([^{])', caseSensitive: false),
        (match) => '\\frac{${match.group(1)}}{${match.group(2)}}');

    // Substituir delimitadores especiais entre \[ e \] para $$ e $$
    // Isso ajuda em casos onde o parser do flutter_math_fork tem problemas
    text = text.replaceAll('\\[', '\$\$');
    text = text.replaceAll('\\]', '\$\$');

    // Corrigir caso específico do Parser Error na fórmula de Bhaskara
    if (text.contains("4. Aplique a fórmula de Bhaskara")) {
      // Substituir a linha problemática da fórmula de Bhaskara
      text = text.replaceAll(
          'x = Parser Error: Expected group after \\frac{-(-4) ± 64}{2 · 2} = 4',
          'x = \\frac{-(-4) \\pm \\sqrt{64}}{2 \\cdot 2} = 4');

      // Alternativa para o mesmo caso
      text = text.replaceAll(
          'x = Parser Error: Expected group after \\frac{-', 'x = \\frac{-');

      // Substituição direta também
      text = text.replaceAll(
          'x = Parser Error: Expected group after \\frac{-(-4) ± 64{2 · 2} = 4',
          'x = \\frac{-(-4) \\pm \\sqrt{64}}{2 \\cdot 2} = 4');
    }

    // Corrigir equações de Bhaskara incompletas
    text = text.replaceAll(
        '\\frac{-b ± \\sqrt{b^2 - 4ac}', '\\frac{-b \\pm \\sqrt{b^2 - 4ac}}');

    // Corrigir formato específico do Mistral para a fórmula de Bhaskara
    text = text.replaceAll('\\frac{-b ± √(b² - 4ac)}{2a}',
        '\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}');

    // Substituir qualquer Parser Error em fórmulas
    if (text.contains('Parser Error')) {
      // Fórmula de Bhaskara geral
      text = text.replaceAll('Parser Error: Expected group after \\frac',
          '\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}');
    }

    // Corrigir casos específicos da imagem (x_1 e x_2)
    text = text.replaceAll('x_1 = 4 = 4 = 3', 'x_1 = \\frac{4 + 8}{4} = 3');

    text = text.replaceAll('x_2 = 4 = 4 = -1', 'x_2 = \\frac{4 - 8}{4} = -1');

    // Corrigir fórmula do discriminante
    text = text.replaceAll(
        "D = b^2 - 4ac = (-4)^2 - 4 · 2 · (-6) = 16 + 48 = 64",
        "D = b^2 - 4ac = (-4)^2 - 4 \\cdot 2 \\cdot (-6) = 16 + 48 = 64");

    // Corrigir a equação final
    text = text.replaceAll("Portanto, as raízes da equação 2x^2 − 4x − 6 = 0",
        "Portanto, as raízes da equação \$2x^2 - 4x - 6 = 0\$");

    // Corrigir problemas específicos com o Mistral
    // Substituir notação de raiz quadrada incorreta
    text = text.replaceAll('√', '\\sqrt');

    // Substituir potências com notação de superscript (²,³) por notação LaTeX
    text = text.replaceAll('²', '^{2}');
    text = text.replaceAll('³', '^{3}');

    // Corrigir potências sem chaves
    text = text.replaceAllMapped(RegExp(r'(\w+)\^(\d+)', caseSensitive: false),
        (match) => '${match.group(1)}^{${match.group(2)}}');

    // Corrigir notação de matriz
    text = text.replaceAll('\\begin{pmatrix}', '\\begin{pmatrix} ');
    text = text.replaceAll('\\end{pmatrix}', ' \\end{pmatrix}');

    // Tratar casos específicos como \(ax^{2} + bx + c = 0\)
    text = text.replaceAll(
        '\\( ax^{2} + bx + c = 0 \\)', '\$ax^{2} + bx + c = 0\$');
    text =
        text.replaceAll('\\(ax^{2} + bx + c = 0\\)', '\$ax^{2} + bx + c = 0\$');

    // Tratar caso específico de expressões com potência dentro de delimitadores
    text = text.replaceAllMapped(
        RegExp(r'\\([a-zA-Z])\^({[0-9]}|[0-9])', caseSensitive: false),
        (match) => '\$${match.group(1)}^${match.group(2)}\$');

    // Converter equação quadrática em formato LaTeX
    text = text.replaceAllMapped(
        RegExp(r'\\(\s*ax\^2\s*\+\s*bx\s*\+\s*c\s*=\s*0\s*\\)',
            caseSensitive: false),
        (match) => '\$ax^{2} + bx + c = 0\$');

    return text;
  }

  /// Método para formatar blocos de código no texto
  static Widget formatCodeBlocks(
      String text, TextStyle style, bool isDarkMode) {
    final List<Widget> widgets = [];
    final RegExp codeBlockPattern =
        RegExp(r'```(?:([\w-]+)\n)?([\s\S]*?)```', dotAll: true);
    int lastEnd = 0;

    // Processar todos os blocos de código
    for (Match match in codeBlockPattern.allMatches(text)) {
      // Adicionar texto antes do bloco de código
      if (match.start > lastEnd) {
        String textBefore = text.substring(lastEnd, match.start);
        // Aqui NÃO podemos usar buildFormattedText para evitar recursão
        // Em vez disso, processamos com um método mais simples
        if (textBefore.trim().isNotEmpty) {
          widgets.add(
            formatSimpleText(textBefore, style, isDarkMode),
          );
        }
      }

      // Detectar a linguagem (se especificada)
      String? language = match.group(1);
      String codeContent = match.group(2) ?? '';

      // Remover uma quebra de linha no início ou fim se existir
      codeContent = codeContent.trim();

      // Adicionar o bloco de código formatado
      widgets.add(
        Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF1E1E1E) : Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho com linguagem e botão de copiar
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(7),
                    topRight: Radius.circular(7),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      language ?? 'código',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: codeContent));

                          // Mostrar um feedback ao usuário usando o navigatorKey
                          if (navigatorKey.currentContext != null) {
                            ScaffoldMessenger.of(navigatorKey.currentContext!)
                                .showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Código copiado para a área de transferência'),
                                duration: Duration(seconds: 1),
                                backgroundColor: Colors.green[700],
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.copy,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12),
                child: SelectableText(
                  codeContent,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: style.fontSize,
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      lastEnd = match.end;
    }

    // Adicionar o texto restante após o último bloco de código
    if (lastEnd < text.length) {
      String textAfter = text.substring(lastEnd);
      // Novamente, usamos formatSimpleText para evitar recursão
      if (textAfter.trim().isNotEmpty) {
        widgets.add(
          formatSimpleText(textAfter, style, isDarkMode),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Formata texto simples com markdown básico (negrito, itálico, links e código inline)
  /// Este método é usado em formatCodeBlocks para evitar recursão
  static Widget formatSimpleText(
      String text, TextStyle style, bool isDarkMode) {
    if ((text.contains('|') && text.contains('\n')) ||
        (text.contains('-') && text.contains('+')) ||
        text.contains('\n- ') ||
        text.contains('\n* ') ||
        RegExp(r'\n\d+\.\s').hasMatch(text)) {
      return formatTablesAndLists(text, style, isDarkMode);
    }

    // Verificar se o texto contém cabeçalhos markdown (###, ##, #)
    if (text.contains('###') || text.contains('##') || text.contains('\n# ')) {
      return formatMarkdownHeadings(text, style, isDarkMode);
    }

    // Aqui processamos todo o texto com um algoritmo mais robusto para formatar markdown
    // sem criar recursões infinitas, usando um processador de token simples

    // Expressões regulares para formatação básica
    final RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*|__(.*?)__');
    final RegExp italicPattern = RegExp(r'\*(.*?)\*|_(.*?)_');
    final RegExp linkPattern = RegExp(r'\[(.*?)\]\((.*?)\)');
    final RegExp urlPattern = RegExp(r'(https?:\/\/[^\s]+)');
    final RegExp codePattern = RegExp(r'`([^`]+)`');

    // Lista para armazenar tokens do texto
    List<Map<String, dynamic>> tokens = [];

    // Primeiro identificamos todos os tokens de formatação
    void addFormattingTokens(RegExp pattern, String type) {
      for (Match match in pattern.allMatches(text)) {
        final Map<String, dynamic> token = {
          'start': match.start,
          'end': match.end,
          'type': type,
          'fullMatch': match.group(0) ?? '',
        };

        if (type == 'link') {
          token['content'] = match.group(1) ?? ''; // Texto do link
          token['url'] = match.group(2) ?? ''; // URL do link
        } else if (type == 'url') {
          token['content'] = match.group(0) ?? ''; // URL completa
          token['url'] = match.group(0) ?? ''; // URL é o próprio texto
        } else if (type == 'code') {
          token['content'] = match.group(1) ?? ''; // Conteúdo do código
        } else {
          token['content'] = match.group(1) ?? match.group(2) ?? '';
        }

        tokens.add(token);
      }
    }

    addFormattingTokens(boldPattern, 'bold');
    addFormattingTokens(italicPattern, 'italic');
    addFormattingTokens(linkPattern, 'link');
    addFormattingTokens(urlPattern, 'url');
    addFormattingTokens(codePattern, 'code');

    // Se não encontramos formatação, retornamos texto simples
    if (tokens.isEmpty) {
      return SelectableText(text, style: style);
    }

    // Ordenar os tokens por posição
    tokens.sort((a, b) => a['start'].compareTo(b['start']));

    // Resolver sobreposições: se dois tokens se sobrepõem, remover o menor
    for (int i = 0; i < tokens.length - 1; i++) {
      for (int j = i + 1; j < tokens.length; j++) {
        // Se o token j começa antes que o token i termine (sobreposição)
        if (tokens[j]['start'] < tokens[i]['end'] &&
            tokens[j]['start'] >= tokens[i]['start']) {
          // Marque o token mais curto para remoção
          final lenI = tokens[i]['end'] - tokens[i]['start'];
          final lenJ = tokens[j]['end'] - tokens[j]['start'];

          if (lenI < lenJ) {
            tokens[i]['remove'] = true;
          } else {
            tokens[j]['remove'] = true;
          }
        }
      }
    }

    // Remover tokens marcados para remoção
    tokens.removeWhere((token) => token['remove'] == true);

    // Processar o texto com os tokens identificados
    final List<InlineSpan> spans = [];
    int lastEnd = 0;

    for (var token in tokens) {
      // Verificar se o token atual sobrepõe outro token já processado
      if (token['start'] < lastEnd) {
        continue; // Pular este token, pois já foi processado dentro de outro
      }

      // Adicionar texto antes do token
      if (token['start'] > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, token['start']),
          style: style,
        ));
      }

      // Adicionar texto formatado
      if (token['type'] == 'bold') {
        spans.add(TextSpan(
          text: token['content'],
          style: style.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (token['type'] == 'italic') {
        spans.add(TextSpan(
          text: token['content'],
          style: style.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (token['type'] == 'link' || token['type'] == 'url') {
        spans.add(TextSpan(
          text: token['content'],
          style: style.copyWith(
            color: isDarkMode ? Colors.lightBlue : Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final urlLaunchable = Uri.parse(token['url']);
              launchUrl(
                urlLaunchable,
                mode: LaunchMode.externalApplication,
              );
            },
        ));
      } else if (token['type'] == 'code') {
        spans.add(TextSpan(
          text: token['content'],
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
            fontSize: style.fontSize,
            color: isDarkMode ? Colors.amber[300] : Colors.blue[800],
          ),
        ));
      }

      lastEnd = token['end'];
    }

    // Adicionar texto restante
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: style,
      ));
    }

    // Retornamos o texto formatado
    return SelectableText.rich(
      TextSpan(
        children: spans,
        style: style,
      ),
    );
  }

  /// Método para formatar cabeçalhos markdown (###, ##, #)
  static Widget formatMarkdownHeadings(
      String text, TextStyle style, bool isDarkMode) {
    final List<Widget> widgets = [];
    final List<String> lines = text.split('\n');

    // Expressões regulares para formatação básica
    final RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*|__(.*?)__');
    final RegExp italicPattern = RegExp(r'\*(.*?)\*|_(.*?)_');
    final RegExp linkPattern = RegExp(r'\[(.*?)\]\((.*?)\)');
    final RegExp codePattern = RegExp(r'`([^`]+)`');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      // Verificar cabeçalhos H1, H2, H3
      if (line.trim().startsWith('### ')) {
        // Cabeçalho nível 3 (H3)
        final String headingText =
            line.substring(line.indexOf('### ') + 4); // Remover "### "

        // Verificar se o título tem formatação negrito/itálico
        if (headingText.contains('**') ||
            headingText.contains('__') ||
            headingText.contains('*') ||
            headingText.contains('_')) {
          // Processar formatação dentro do título
          List<InlineSpan> spans = processInlineMarkdown(
              headingText,
              style.copyWith(
                fontSize: style.fontSize! * 1.1,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
              ),
              isDarkMode);

          widgets.add(
            Padding(
              padding: EdgeInsets.only(top: 12, bottom: 6),
              child: SelectableText.rich(
                TextSpan(children: spans),
              ),
            ),
          );
        } else {
          widgets.add(
            Padding(
              padding: EdgeInsets.only(top: 12, bottom: 6),
              child: SelectableText(
                headingText,
                style: style.copyWith(
                  fontSize: style.fontSize! * 1.1,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
                ),
              ),
            ),
          );
        }
      } else if (line.trim().startsWith('## ')) {
        // Cabeçalho nível 2 (H2)
        final String headingText =
            line.substring(line.indexOf('## ') + 3); // Remover "## "

        // Verificar se o título tem formatação negrito/itálico
        if (headingText.contains('**') ||
            headingText.contains('__') ||
            headingText.contains('*') ||
            headingText.contains('_')) {
          // Processar formatação dentro do título
          List<InlineSpan> spans = processInlineMarkdown(
              headingText,
              style.copyWith(
                fontSize: style.fontSize! * 1.25,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[100] : Colors.grey[900],
              ),
              isDarkMode);

          widgets.add(
            Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: SelectableText.rich(
                TextSpan(children: spans),
              ),
            ),
          );
        } else {
          widgets.add(
            Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: SelectableText(
                headingText,
                style: style.copyWith(
                  fontSize: style.fontSize! * 1.25,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.grey[100] : Colors.grey[900],
                ),
              ),
            ),
          );
        }
      } else if (line.trim().startsWith('# ')) {
        // Cabeçalho nível 1 (H1)
        final String headingText =
            line.substring(line.indexOf('# ') + 2); // Remover "# "

        // Verificar se o título tem formatação negrito/itálico
        if (headingText.contains('**') ||
            headingText.contains('__') ||
            headingText.contains('*') ||
            headingText.contains('_')) {
          // Processar formatação dentro do título
          List<InlineSpan> spans = processInlineMarkdown(
              headingText,
              style.copyWith(
                fontSize: style.fontSize! * 1.4,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              isDarkMode);

          widgets.add(
            Padding(
              padding: EdgeInsets.only(top: 20, bottom: 10),
              child: SelectableText.rich(
                TextSpan(children: spans),
              ),
            ),
          );
        } else {
          widgets.add(
            Padding(
              padding: EdgeInsets.only(top: 20, bottom: 10),
              child: SelectableText(
                headingText,
                style: style.copyWith(
                  fontSize: style.fontSize! * 1.4,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
          );
        }
      } else {
        // Linha normal - processar formatação de texto básico
        if (line.trim().isNotEmpty) {
          // Verificar se temos marcadores de inline como negrito, itálico, etc.
          if (line.contains('**') ||
              line.contains('__') ||
              line.contains('*') ||
              line.contains('_') ||
              line.contains('[') ||
              line.contains('`')) {
            // Processar a linha com formatação markdown
            List<InlineSpan> spans =
                processInlineMarkdown(line, style, isDarkMode);

            widgets.add(
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: SelectableText.rich(
                  TextSpan(children: spans),
                ),
              ),
            );
          } else {
            // Linha normal sem formatação markdown
            widgets.add(
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: SelectableText(line, style: style),
              ),
            );
          }
        } else {
          widgets.add(SizedBox(height: 8)); // Espaço para linha em branco
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Método auxiliar para processar formatação inline markdown
  static List<InlineSpan> processInlineMarkdown(
      String text, TextStyle style, bool isDarkMode) {
    List<InlineSpan> spans = [];

    // Expressões regulares para formatação básica
    final RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*|__(.*?)__');
    final RegExp italicPattern = RegExp(r'\*(.*?)\*|_(.*?)_');
    final RegExp linkPattern = RegExp(r'\[(.*?)\]\((.*?)\)');
    final RegExp codePattern = RegExp(r'`([^`]+)`');

    // Lista para armazenar tokens do texto
    List<Map<String, dynamic>> tokens = [];

    // Identificar todos os tokens de formatação
    void addFormattingTokens(RegExp pattern, String type) {
      for (Match match in pattern.allMatches(text)) {
        final Map<String, dynamic> token = {
          'start': match.start,
          'end': match.end,
          'type': type,
          'fullMatch': match.group(0) ?? '',
        };

        if (type == 'link') {
          token['content'] = match.group(1) ?? ''; // Texto do link
          token['url'] = match.group(2) ?? ''; // URL do link
        } else if (type == 'code') {
          token['content'] = match.group(1) ?? ''; // Conteúdo do código
        } else {
          token['content'] = match.group(1) ?? match.group(2) ?? '';
        }

        tokens.add(token);
      }
    }

    addFormattingTokens(boldPattern, 'bold');
    addFormattingTokens(italicPattern, 'italic');
    addFormattingTokens(linkPattern, 'link');
    addFormattingTokens(codePattern, 'code');

    // Se não encontramos formatação, retornar apenas o texto
    if (tokens.isEmpty) {
      spans.add(TextSpan(text: text, style: style));
      return spans;
    }

    // Ordenar os tokens por posição
    tokens.sort((a, b) => a['start'].compareTo(b['start']));

    // Resolver sobreposições: se dois tokens se sobrepõem, remover o menor
    for (int i = 0; i < tokens.length - 1; i++) {
      for (int j = i + 1; j < tokens.length; j++) {
        // Se o token j começa antes que o token i termine (sobreposição)
        if (tokens[j]['start'] < tokens[i]['end'] &&
            tokens[j]['start'] >= tokens[i]['start']) {
          // Marque o token mais curto para remoção
          final lenI = tokens[i]['end'] - tokens[i]['start'];
          final lenJ = tokens[j]['end'] - tokens[j]['start'];

          if (lenI < lenJ) {
            tokens[i]['remove'] = true;
          } else {
            tokens[j]['remove'] = true;
          }
        }
      }
    }

    // Remover tokens marcados para remoção
    tokens.removeWhere((token) => token['remove'] == true);

    // Processar o texto com os tokens identificados
    int lastEnd = 0;

    for (var token in tokens) {
      // Verificar se o token atual sobrepõe outro token já processado
      if (token['start'] < lastEnd) {
        continue; // Pular este token, pois já foi processado dentro de outro
      }

      // Adicionar texto antes do token
      if (token['start'] > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, token['start']),
          style: style,
        ));
      }

      // Adicionar texto formatado
      if (token['type'] == 'bold') {
        spans.add(TextSpan(
          text: token['content'],
          style: style.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (token['type'] == 'italic') {
        spans.add(TextSpan(
          text: token['content'],
          style: style.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (token['type'] == 'link') {
        spans.add(TextSpan(
          text: token['content'],
          style: style.copyWith(
            color: isDarkMode ? Colors.lightBlue : Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final urlLaunchable = Uri.parse(token['url']);
              launchUrl(
                urlLaunchable,
                mode: LaunchMode.externalApplication,
              );
            },
        ));
      } else if (token['type'] == 'code') {
        spans.add(TextSpan(
          text: token['content'],
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
            fontSize: style.fontSize,
            color: isDarkMode ? Colors.amber[300] : Colors.blue[800],
          ),
        ));
      }

      lastEnd = token['end'];
    }

    // Adicionar texto restante
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: style,
      ));
    }

    return spans;
  }

  /// Método auxiliar para processar fórmulas inline
  static List<InlineSpan> processarFormulasInline(String text, TextStyle style,
      RegExp inlineFormula, RegExp slashParensFormula) {
    List<InlineSpan> spans = [];

    // Combinamos todas as correspondências de todos os tipos de fórmula inline
    List<Map<String, dynamic>> allMatches = [];

    // Adicionar correspondências para $...$ e \(...\)
    void collectMatches(RegExp regExp) {
      for (Match match in regExp.allMatches(text)) {
        allMatches.add({
          'start': match.start,
          'end': match.end,
          'formula': match.group(1) ?? '',
          'fullMatch': match.group(0) ?? '',
        });
      }
    }

    collectMatches(inlineFormula);
    collectMatches(slashParensFormula);

    // Se não há correspondências, devolver uma lista vazia
    if (allMatches.isEmpty) {
      return spans;
    }

    // Ordenar por posição
    allMatches.sort((a, b) => a['start'].compareTo(b['start']));

    // Processar o texto com fórmulas
    int lastEnd = 0;

    for (var match in allMatches) {
      // Adicionar texto normal antes da fórmula
      if (match['start'] > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match['start']),
            style: style,
          ),
        );
      }

      // Tentar renderizar a fórmula
      try {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Math.tex(
              match['formula'],
              textStyle: style,
              mathStyle: MathStyle.text,
              onErrorFallback: (errMsg) {
                print('Erro ao renderizar fórmula inline: $errMsg');
                return Text(
                  match['fullMatch'],
                  style: style,
                );
              },
            ),
          ),
        );
      } catch (e) {
        print('Erro ao renderizar fórmula inline: $e');
        // Em caso de erro, mostrar o texto original
        spans.add(
          TextSpan(
            text: match['fullMatch'],
            style: style,
          ),
        );
      }

      lastEnd = match['end'];
    }

    // Adicionar texto final após a última fórmula
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: style,
        ),
      );
    }

    return spans;
  }

  /// Método auxiliar para formatar tabelas e listas
  static Widget formatTablesAndLists(
      String text, TextStyle style, bool isDarkMode) {
    final List<Widget> widgets = [];
    final lines = text.split('\n');

    // Detectar tabelas (linhas com múltiplos | caracteres)
    bool inTable = false;
    List<String> tableLines = [];

    // Detectar listas
    bool inBulletList = false;
    bool inNumberedList = false;
    List<String> listItems = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Verificar se é uma linha de tabela (contém múltiplos | e possivelmente caracteres de formatação)
      bool isTableLine = line.contains('|') && (line.split('|').length > 2);
      bool isDividerLine = line.contains('-') && line.contains('+');

      // Verificar se é um item de lista com marcador
      bool isBulletListItem = line.trim().startsWith('•') ||
          line.trim().startsWith('-') && !line.contains('|') ||
          line.trim().startsWith('*') && !line.contains('*');

      // Verificar se é um item de lista numerada (1., 2., etc.)
      bool isNumberedListItem = RegExp(r'^\s*\d+\.\s').hasMatch(line);

      if (isTableLine || isDividerLine) {
        // Finalizar qualquer lista em andamento
        if (inBulletList || inNumberedList) {
          widgets.add(buildList(listItems, inNumberedList, style, isDarkMode));
          inBulletList = false;
          inNumberedList = false;
          listItems = [];
        }

        if (!inTable) {
          inTable = true;
          tableLines = [];
        }
        tableLines.add(line);
      } else if (isBulletListItem) {
        // Finalizar tabela ou lista numerada se estava em andamento
        if (inTable) {
          widgets.add(buildTable(tableLines, style, isDarkMode));
          inTable = false;
          tableLines = [];
        } else if (inNumberedList) {
          widgets.add(buildList(listItems, true, style, isDarkMode));
          listItems = [];
        }

        inBulletList = true;
        listItems.add(line);
      } else if (isNumberedListItem) {
        // Finalizar tabela ou lista com marcadores se estava em andamento
        if (inTable) {
          widgets.add(buildTable(tableLines, style, isDarkMode));
          inTable = false;
          tableLines = [];
        } else if (inBulletList) {
          widgets.add(buildList(listItems, false, style, isDarkMode));
          listItems = [];
        }

        inNumberedList = true;
        listItems.add(line);
      } else {
        // Linha normal, finalizar qualquer estrutura especial em andamento
        if (inTable) {
          widgets.add(buildTable(tableLines, style, isDarkMode));
          inTable = false;
          tableLines = [];
        } else if (inBulletList || inNumberedList) {
          widgets.add(buildList(listItems, inNumberedList, style, isDarkMode));
          inBulletList = false;
          inNumberedList = false;
          listItems = [];
        }

        // Adicionar a linha atual (não-tabela, não-lista)
        if (line.trim().isNotEmpty) {
          widgets.add(
            Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(line, style: style),
            ),
          );
        } else {
          widgets.add(SizedBox(height: 8)); // Espaço para linha em branco
        }
      }
    }

    // Verificar se ainda há uma estrutura pendente ao final do texto
    if (inTable && tableLines.isNotEmpty) {
      widgets.add(buildTable(tableLines, style, isDarkMode));
    } else if ((inBulletList || inNumberedList) && listItems.isNotEmpty) {
      widgets.add(buildList(listItems, inNumberedList, style, isDarkMode));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Método para construir uma lista formatada
  static Widget buildList(
      List<String> items, bool isNumbered, TextStyle style, bool isDarkMode) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.asMap().entries.map((entry) {
          int index = entry.key;
          String item = entry.value;

          // Remover o prefixo do item (o marcador ou o número)
          String itemText = item.trim();
          if (isNumbered) {
            // Remover o número e o ponto
            itemText = itemText.replaceFirst(RegExp(r'^\s*\d+\.\s*'), '');
          } else {
            // Remover o marcador
            itemText = itemText.replaceFirst(RegExp(r'^\s*[•\-\*]\s*'), '');
          }

          return Padding(
            padding: EdgeInsets.only(left: 16, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isNumbered
                    ? Text('${index + 1}.',
                        style: style.copyWith(fontWeight: FontWeight.bold))
                    : Text('•',
                        style: style.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        )),
                SizedBox(width: 8),
                Expanded(
                  child: Text(itemText, style: style),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Método para construir uma tabela a partir de linhas de texto
  static Widget buildTable(
      List<String> tableLines, TextStyle style, bool isDarkMode) {
    // Processar linhas para extrair células
    List<List<String>> rows = [];

    for (String line in tableLines) {
      // Pular linhas divisórias (que contêm apenas - e +)
      if (line.trim().replaceAll('-', '').replaceAll('+', '').trim().isEmpty) {
        continue;
      }

      // Dividir a linha por | e remover espaços em branco extras
      List<String> cells = line.split('|').map((cell) => cell.trim()).toList();

      // Remover células vazias no início e fim (criadas por | no início/fim da linha)
      if (cells.first.isEmpty) cells.removeAt(0);
      if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();

      rows.add(cells);
    }

    // Calcular o número máximo de colunas
    int maxColumns = rows.fold(0, (max, row) => math.max(max, row.length));

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Table(
        border: TableBorder.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: Map.fromEntries(
          List.generate(
            maxColumns,
            (index) => MapEntry(index, FlexColumnWidth()),
          ),
        ),
        children: rows.map((cells) {
          return TableRow(
            decoration: BoxDecoration(
              color: rows.indexOf(cells) == 0
                  ? (isDarkMode ? Colors.grey[800] : Colors.grey[100])
                  : null,
            ),
            children: List.generate(maxColumns, (index) {
              // Se não houver célula para este índice, criar uma célula vazia
              if (index >= cells.length) {
                return TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('', style: style),
                  ),
                );
              }

              return TableCell(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    cells[index],
                    style: style.copyWith(
                      fontWeight: rows.indexOf(cells) == 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          );
        }).toList(),
      ),
    );
  }

  /// Método para formatar texto com marcações markdown em múltiplas linhas
  static Widget formatMarkdownText(
      String text, TextStyle style, bool isDarkMode) {
    final List<Widget> widgets = [];
    final List<String> lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      if (line.trim().isEmpty) {
        widgets.add(SizedBox(height: 8)); // Espaço para linha em branco
        continue;
      }

      // Processar formatação markdown na linha
      if (line.contains('**') ||
          line.contains('__') ||
          line.contains('*') ||
          line.contains('_') ||
          line.contains('[') ||
          line.contains('`')) {
        List<InlineSpan> spans = processInlineMarkdown(line, style, isDarkMode);

        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: SelectableText.rich(
              TextSpan(children: spans),
            ),
          ),
        );
      } else {
        // Linha sem marcação
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: SelectableText(line, style: style),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
