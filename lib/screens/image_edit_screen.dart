import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../screens/document_scan_screen.dart';
import '../i18n/app_localizations_extension.dart';
import '../theme/app_theme.dart';
import 'dart:convert';
import '../screens/ai_tutor_screen.dart';

class ImageEditScreen extends StatefulWidget {
  final Uint8List image;
  final Rect initialCropRect;
  final String scanMode;

  const ImageEditScreen({
    Key? key,
    required this.image,
    required this.initialCropRect,
    required this.scanMode,
  }) : super(key: key);

  @override
  _ImageEditScreenState createState() => _ImageEditScreenState();
}

class _ImageEditScreenState extends State<ImageEditScreen> {
  late ui.Image _uiImage;
  bool _isImageLoaded = false;
  int _rotationDegrees = 0;
  bool _isProcessing = false;
  Rect _cropRect = Rect.zero;

  // Modo de edição sempre ativo
  final bool _isEditModeEnabled = true;

  // Para permitir arrastar os cantos ou mover o retângulo
  double? _startDragX; // Ponto X inicial do toque para mover o retângulo
  double? _startDragY; // Ponto Y inicial do toque para mover o retângulo
  int _activeCorner = -1; // Índice do canto ativo (0-3) ou -1 se nenhum

  final double _cornerHandleSize = 50.0; // Tamanho da área de toque nos cantos
  final double _minCropSize = 50.0; // Tamanho mínimo do retângulo de corte

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromList(widget.image, (ui.Image img) {
      completer.complete(img);
    });

    _uiImage = await completer.future;

    // Ajustar o retângulo de corte para corresponder exatamente ao retângulo usado na tela CameraScanScreen
    // A posição inicial vem como parâmetro, mas podemos ajustá-la para ficar consistente
    _cropRect = widget.initialCropRect;

    // Ajustar a posição Y baseado no mesmo cálculo da CameraScanScreen, se necessário
    final Size screenSize = MediaQuery.of(context).size;
    final double appBarHeight = AppBar().preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double buttonsAreaHeight = 180.0;
    final double availableHeight =
        screenSize.height - appBarHeight - statusBarHeight - buttonsAreaHeight;
    final double idealTopOffset =
        appBarHeight + statusBarHeight + (availableHeight * 0.25);

    // Se a posição Y estiver muito diferente do ideal, ajustamos
    if ((_cropRect.top - idealTopOffset).abs() > 20) {
      // Ajustar mantendo a largura e altura originais
      _cropRect = Rect.fromLTWH(
          _cropRect.left, idealTopOffset, _cropRect.width, _cropRect.height);
    }

    setState(() {
      _isImageLoaded = true;
    });
    print('[INIT] Imagem carregada: ${_uiImage.width}x${_uiImage.height}');
    print('[INIT] Retângulo inicial: $_cropRect');
  }

  // Rotacionar a imagem
  void _rotateImage() {
    setState(() {
      _rotationDegrees = (_rotationDegrees + 90) % 360;
      // TODO: Ajustar _cropRect se a rotação alterar as proporções visíveis?
      // Por enquanto, apenas rotaciona a imagem, o corte é relativo à imagem rotacionada.
    });
    print('[ACTION] Imagem rotacionada para $_rotationDegrees graus');
  }

  // Processar e cortar a imagem
  Future<void> _processImage() async {
    if (!_isImageLoaded) return;

    print('[PROCESS] Iniciando processamento...');
    setState(() {
      _isProcessing = true;
    });

    try {
      img.Image? originalImage = img.decodeImage(widget.image);
      if (originalImage == null) {
        throw Exception('Não foi possível decodificar a imagem');
      }

      img.Image rotatedImage = originalImage;
      if (_rotationDegrees > 0) {
        print('[PROCESS] Rotacionando imagem em $_rotationDegrees graus');
        for (int i = 0; i < _rotationDegrees ~/ 90; i++) {
          rotatedImage = img.copyRotate(rotatedImage, angle: 90);
        }
      }

      final Rect displayRect = _calculateDisplayRect(Size(
        _rotationDegrees == 90 || _rotationDegrees == 270
            ? _uiImage.height.toDouble()
            : _uiImage.width.toDouble(),
        _rotationDegrees == 90 || _rotationDegrees == 270
            ? _uiImage.width.toDouble()
            : _uiImage.height.toDouble(),
      ));

      print('[PROCESS] Área de Display Calculada: $displayRect');
      print('[PROCESS] Retângulo de Corte (Coords Tela): $_cropRect');

      // Converter coordenadas do recorte na tela para coordenadas na imagem rotacionada
      // Garantir que as coordenadas estejam dentro dos limites da área de display
      final double relativeCropX =
          (_cropRect.left - displayRect.left).clamp(0.0, displayRect.width);
      final double relativeCropY =
          (_cropRect.top - displayRect.top).clamp(0.0, displayRect.height);
      final double relativeCropWidth =
          _cropRect.width.clamp(0.0, displayRect.width - relativeCropX);
      final double relativeCropHeight =
          _cropRect.height.clamp(0.0, displayRect.height - relativeCropY);

      final double cropStartX =
          (relativeCropX / displayRect.width) * rotatedImage.width;
      final double cropStartY =
          (relativeCropY / displayRect.height) * rotatedImage.height;
      final double cropWidth =
          (relativeCropWidth / displayRect.width) * rotatedImage.width;
      final double cropHeight =
          (relativeCropHeight / displayRect.height) * rotatedImage.height;

      print(
          '[PROCESS] Coords Corte (Relativo Imagem): X=$cropStartX, Y=$cropStartY, W=$cropWidth, H=$cropHeight');

      img.Image croppedImage = img.copyCrop(
        rotatedImage,
        x: cropStartX.round().clamp(0, rotatedImage.width - 1),
        y: cropStartY.round().clamp(0, rotatedImage.height - 1),
        width:
            cropWidth.round().clamp(1, rotatedImage.width - cropStartX.round()),
        height: cropHeight
            .round()
            .clamp(1, rotatedImage.height - cropStartY.round()),
      );

      print(
          '[PROCESS] Imagem cortada: ${croppedImage.width}x${croppedImage.height}');

      Uint8List processedImage =
          Uint8List.fromList(img.encodeJpg(croppedImage, quality: 90));

      if (mounted) {
        // Enviar diretamente para o AI Tutor
        _sendToAITutor(processedImage);
      }
    } catch (e, stacktrace) {
      print('[PROCESS] Erro: $e\n$stacktrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erro ao processar imagem: $e'),
            backgroundColor: Colors.red),
      );
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Novo método para enviar para AITutorScreen
  void _sendToAITutor(Uint8List processedImage) async {
    print('[PROCESS] Navegando para AITutorScreen');

    // Converter a imagem para base64 para incluir no JSON
    final String base64Image = base64Encode(processedImage);

    // Definir título com base no modo de escaneamento
    String toolTitle = 'Digitalização';
    String toolType = 'scan';

    switch (widget.scanMode) {
      case 'math':
        toolTitle = 'Matemática';
        toolType = 'math';
        break;
      case 'translate':
        toolTitle = 'Tradução';
        toolType = 'translate';
        break;
      case 'physics':
        toolTitle = 'Física';
        toolType = 'physics';
        break;
      case 'chemistry':
        toolTitle = 'Química';
        toolType = 'chemistry';
        break;
      case 'history':
        toolTitle = 'História';
        toolType = 'history';
        break;
      default:
        toolTitle = 'Digitalização';
        toolType = 'scan';
    }

    // Criar dados da ferramenta para passar ao AI Tutor
    final Map<String, dynamic> toolData = {
      'toolName': 'Camera Scan',
      'toolTab': toolTitle,
      'sourceType': 'camera',
      'scanMode': widget.scanMode,
      'imageData': base64Image,
      'userInput': 'Análise de imagem: $toolTitle',
      'fullPrompt':
          'Analise esta imagem capturada com a câmera no modo "$toolTitle" e forneça uma resposta detalhada.',
      'hasImage': true,
    };

    // Converter para JSON
    final String jsonData = jsonEncode(toolData);

    // Navegar para o AI Tutor com os dados
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AITutorScreen(initialPrompt: jsonData),
      ),
    );
  }

  // Calcula o retângulo onde a imagem é efetivamente desenhada na tela
  Rect _calculateDisplayRect(Size imageDisplaySize) {
    final Size screenSize = MediaQuery.of(context).size;

    // Altura do navbar padrão do Flutter
    final double navBarHeight = 56.0 +
        MediaQuery.of(context)
            .padding
            .bottom; // Altura do navbar + padding inferior (para iPhones com notch)

    // Altura disponível excluindo o navbar
    final double availableHeight = screenSize.height - navBarHeight;

    // Calcular valores para ocupar a tela inteira, menos o navbar
    final double screenRatio = screenSize.width / availableHeight;
    final double imageRatio = imageDisplaySize.width / imageDisplaySize.height;

    double displayWidth, displayHeight;

    // Assegurar que a imagem cubra toda a largura da tela e altura disponível até o navbar
    if (screenRatio > imageRatio) {
      // Tela mais larga que a imagem - ajustar largura e deixar altura adequada à proporção
      displayWidth = screenSize.width;
      displayHeight = displayWidth / imageRatio;

      // Se a altura calculada for menor que a altura disponível, ajustar para preencher todo o espaço
      if (displayHeight < availableHeight) {
        displayHeight = availableHeight;
        displayWidth = displayHeight * imageRatio;
      }
    } else {
      // Tela mais alta que a imagem - ajustar para altura disponível
      displayHeight = availableHeight;
      displayWidth = displayHeight * imageRatio;

      // Se a largura calculada for menor que a largura da tela, ajustar para preencher toda a largura
      if (displayWidth < screenSize.width) {
        displayWidth = screenSize.width;
        displayHeight = displayWidth / imageRatio;
      }
    }

    // Centralizar a imagem horizontalmente
    final double left = (screenSize.width - displayWidth) / 2;
    // Posicionar no topo, garantindo que o bottom fique no limite do navbar
    final double top = 0;

    return Rect.fromLTWH(left, top, displayWidth, availableHeight);
  }

  // --- Manipuladores de Gestos --- //

  void _handlePanStart(DragStartDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localPosition =
        renderBox.globalToLocal(details.globalPosition);
    print(
        '\n[PAN_START] Toque em $localPosition (Global: ${details.globalPosition})');
    print('[PAN_START] Retângulo atual: $_cropRect');

    _activeCorner = -1;
    _startDragX = null;
    _startDragY = null;

    // Coordenadas dos cantos na tela
    final Offset tl = _cropRect.topLeft;
    final Offset tr = _cropRect.topRight;
    final Offset bl = _cropRect.bottomLeft;
    final Offset br = _cropRect.bottomRight;

    // Criar retângulos de toque maiores ao redor dos cantos
    final Rect tlRect = Rect.fromCenter(
        center: tl, width: _cornerHandleSize, height: _cornerHandleSize);
    final Rect trRect = Rect.fromCenter(
        center: tr, width: _cornerHandleSize, height: _cornerHandleSize);
    final Rect blRect = Rect.fromCenter(
        center: bl, width: _cornerHandleSize, height: _cornerHandleSize);
    final Rect brRect = Rect.fromCenter(
        center: br, width: _cornerHandleSize, height: _cornerHandleSize);

    print('[PAN_START] Área de toque TL: $tlRect');
    print('[PAN_START] Área de toque TR: $trRect');
    print('[PAN_START] Área de toque BL: $blRect');
    print('[PAN_START] Área de toque BR: $brRect');

    if (tlRect.contains(localPosition)) {
      _activeCorner = 0;
      print('[PAN_START] CANTO ATIVO: 0 (Superior Esquerdo)');
      HapticFeedback.mediumImpact();
    } else if (trRect.contains(localPosition)) {
      _activeCorner = 1;
      print('[PAN_START] CANTO ATIVO: 1 (Superior Direito)');
      HapticFeedback.mediumImpact();
    } else if (blRect.contains(localPosition)) {
      _activeCorner = 2;
      print('[PAN_START] CANTO ATIVO: 2 (Inferior Esquerdo)');
      HapticFeedback.mediumImpact();
    } else if (brRect.contains(localPosition)) {
      _activeCorner = 3;
      print('[PAN_START] CANTO ATIVO: 3 (Inferior Direito)');
      HapticFeedback.mediumImpact();
    } else if (_cropRect.contains(localPosition)) {
      // Iniciar arraste do retângulo inteiro
      _startDragX = localPosition.dx - _cropRect.left;
      _startDragY = localPosition.dy - _cropRect.top;
      print(
          '[PAN_START] MOVENDO RETÂNGULO: Offset inicial ($_startDragX, $_startDragY)');
    } else {
      print('[PAN_START] Toque fora das áreas ativas.');
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_activeCorner < 0 && _startDragX == null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localPosition =
        renderBox.globalToLocal(details.globalPosition);

    // Calcular limites da área de display da imagem
    final Rect displayRect = _calculateDisplayRect(Size(
      _rotationDegrees == 90 || _rotationDegrees == 270
          ? _uiImage.height.toDouble()
          : _uiImage.width.toDouble(),
      _rotationDegrees == 90 || _rotationDegrees == 270
          ? _uiImage.width.toDouble()
          : _uiImage.height.toDouble(),
    ));
    print('[PAN_UPDATE] Posição local: $localPosition');

    setState(() {
      Rect newRect = _cropRect;

      if (_activeCorner >= 0) {
        // Redimensionar pelos cantos
        print('[PAN_UPDATE] Redimensionando pelo canto $_activeCorner');
        double newLeft = newRect.left;
        double newTop = newRect.top;
        double newRight = newRect.right;
        double newBottom = newRect.bottom;

        // Clampar a posição do toque para dentro dos limites do displayRect
        final clampedX =
            localPosition.dx.clamp(displayRect.left, displayRect.right);
        final clampedY =
            localPosition.dy.clamp(displayRect.top, displayRect.bottom);

        switch (_activeCorner) {
          case 0: // Superior Esquerdo
            newLeft = clampedX;
            newTop = clampedY;
            break;
          case 1: // Superior Direito
            newRight = clampedX;
            newTop = clampedY;
            break;
          case 2: // Inferior Esquerdo
            newLeft = clampedX;
            newBottom = clampedY;
            break;
          case 3: // Inferior Direito
            newRight = clampedX;
            newBottom = clampedY;
            break;
        }

        // Garantir que left < right e top < bottom, e tamanho mínimo
        if (newRight - newLeft >= _minCropSize &&
            newBottom - newTop >= _minCropSize) {
          newRect = Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
          print('[PAN_UPDATE] Novo retângulo (redimensionado): $newRect');
          _cropRect = newRect;
        } else {
          print(
              '[PAN_UPDATE] Redimensionamento inválido (tamanho mínimo ou coords invertidas)');
        }
      } else if (_startDragX != null && _startDragY != null) {
        // Mover o retângulo inteiro
        print('[PAN_UPDATE] Movendo retângulo inteiro');
        double newLeft = localPosition.dx - _startDragX!;
        double newTop = localPosition.dy - _startDragY!;

        // Manter o retângulo dentro dos limites
        newLeft = newLeft.clamp(
            displayRect.left, displayRect.right - _cropRect.width);
        newTop = newTop.clamp(
            displayRect.top, displayRect.bottom - _cropRect.height);

        newRect =
            Rect.fromLTWH(newLeft, newTop, _cropRect.width, _cropRect.height);
        print('[PAN_UPDATE] Novo retângulo (movido): $newRect');
        _cropRect = newRect;
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    print('\n[PAN_END] Finalizando gesto');
    print('[PAN_END] Estado final do retângulo: $_cropRect');
    _activeCorner = -1;
    _startDragX = null;
    _startDragY = null;
  }

  // --- Build Method --- //

  @override
  Widget build(BuildContext context) {
    final double borderRadius = 12.0;
    final Size screenSize = MediaQuery.of(context).size;
    print('\n[BUILD] Reconstruindo widget...');

    Rect? displayRect; // Retângulo onde a imagem é desenhada
    Size?
        imageDisplaySize; // Tamanho da imagem como exibida (considerando rotação)

    if (_isImageLoaded) {
      imageDisplaySize = _rotationDegrees == 90 || _rotationDegrees == 270
          ? Size(_uiImage.height.toDouble(), _uiImage.width.toDouble())
          : Size(_uiImage.width.toDouble(), _uiImage.height.toDouble());
      displayRect = _calculateDisplayRect(imageDisplaySize);
      print('[BUILD] Área de Display da Imagem Calculada: $displayRect');
      print('[BUILD] Retângulo de Corte Atual: $_cropRect');
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          context.tr.translate('editarImagem') ?? 'Editar Imagem',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _isImageLoaded && displayRect != null && imageDisplaySize != null
          ? Stack(
              children: [
                // 1. Imagem (Fundo)
                Positioned.fromRect(
                  rect: displayRect,
                  child: Transform.rotate(
                    angle: _rotationDegrees * (math.pi / 180),
                    child: CustomPaint(
                      painter: ImagePainter(_uiImage),
                      size: imageDisplaySize,
                    ),
                  ),
                ),

                // 2. GestureDetector e Overlay de Corte (sobre a imagem)
                Positioned.fromRect(
                  rect: displayRect, // Posiciona sobre a área da imagem
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque, // Captura toques na área
                    onPanStart: _handlePanStart,
                    onPanUpdate: _handlePanUpdate,
                    onPanEnd: _handlePanEnd,
                    child: CustomPaint(
                      painter: CropOverlayPainter(
                        cropRect: Rect.fromLTRB(
                          _cropRect.left - displayRect.left,
                          _cropRect.top - displayRect.top,
                          _cropRect.right - displayRect.left,
                          _cropRect.bottom - displayRect.top,
                        ),
                        borderRadius: borderRadius,
                      ),
                      size: displayRect.size,
                    ),
                  ),
                ),

                // Adicionar texto explicativo acima da área de seleção
                Positioned(
                  top: _cropRect.top - 60,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Selecione apenas uma pergunta",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // 3. Botões de Controle (Base) - sem gradiente, cor uniforme
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom + 20,
                        top: 20,
                        left: 20,
                        right: 20),
                    decoration: BoxDecoration(
                      color: Colors.black
                          .withOpacity(0.5), // Cor uniforme em vez de gradiente
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Botão Rotação
                        _buildControlButton(
                          icon: Icons.rotate_right,
                          onPressed: _rotateImage,
                        ),

                        // Botão Confirmar
                        _buildConfirmButton(),

                        // Espaço vazio para manter o layout balanceado
                        SizedBox(width: 60),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
    );
  }

  Widget _buildControlButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 28),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 5, spreadRadius: 1)
        ],
      ),
      child: _isProcessing
          ? Center(
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 3))
          : IconButton(
              icon: Icon(Icons.check, color: Colors.white, size: 35),
              onPressed: _processImage,
            ),
    );
  }
}

// --- Painters --- //

// Painter para desenhar a imagem
class ImagePainter extends CustomPainter {
  final ui.Image image;

  ImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant ImagePainter oldDelegate) {
    return image != oldDelegate.image;
  }
}

// Painter para desenhar o overlay de corte
class CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final double borderRadius;
  final bool editMode;

  CropOverlayPainter({
    required this.cropRect,
    this.borderRadius = 12.0,
    this.editMode = true, // Sempre em modo de edição
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Overlay mais claro fora do retângulo de corte
    final Paint backgroundPaint = Paint()
      ..color = Colors.black
          .withOpacity(0.35) // Opacidade reduzida para ficar mais claro
      ..style = PaintingStyle.fill;

    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
          RRect.fromRectAndRadius(cropRect, Radius.circular(borderRadius)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, backgroundPaint);

    // Desenhar borda do recorte em branco
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(
        RRect.fromRectAndRadius(cropRect, Radius.circular(borderRadius)),
        borderPaint);
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) {
    return cropRect != oldDelegate.cropRect ||
        borderRadius != oldDelegate.borderRadius;
  }
}
