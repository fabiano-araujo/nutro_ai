import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../image_upload.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../models/study_item.dart';
import '../theme/app_theme.dart';
import '../widgets/response_display.dart';
import 'document_scan_screen.dart';
import '../i18n/app_localizations_extension.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import '../widgets/credit_indicator.dart';
import 'image_edit_screen.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({Key? key}) : super(key: key);

  @override
  _CameraScanScreenState createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen>
    with WidgetsBindingObserver {
  String _selectedScanMode = 'ai_macros'; // 'ai_macros', 'barcode'
  bool _flashEnabled = false;
  Uint8List? _capturedImage;
  String _selectedLanguage = 'en'; // Idioma padrão para tradução (ex: inglês)

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCameraError = false; // Nova variável para controlar erros de câmera

  // Adicionar variáveis para timeout
  Timer? _initTimeoutTimer;
  static const int _cameraInitTimeoutSeconds =
      15; // Tempo máximo para inicialização
  bool _isInitializing = false;
  DateTime? _initStartTime; // Registrar quando começou a inicialização

  // PageController para centralização automática dos itens
  late PageController _pageController;

  // Lista de todos os modos disponíveis
  final List<Map<String, dynamic>> _scanModes = [
    {
      'id': 'ai_macros',
      'label': 'Macros com IA',
      'color': AppTheme.primaryColor,
      'icon': Icons.restaurant_menu,
    },
    {
      'id': 'barcode',
      'label': 'Código de Barras',
      'color': Color(0xFF21AAFF),
      'icon': Icons.qr_code_scanner,
    },
  ];

  // Largura estimada para cada item (não usado mais diretamente, mas mantido para referência)
  final double _itemWidth = 120.0;
  final double _itemSpacing = 40.0;

  // Lista de idiomas suportados para tradução
  final Map<String, String> _supportedLanguages = {
    'en': 'Inglês',
    'es': 'Espanhol',
    'pt': 'Português',
    // Adicione mais idiomas aqui conforme necessário
  };

  // Adicionando variáveis para controle de estado
  bool _isMinimized = false;
  bool _isResuming = false;
  int _resumeAttempts = 0;

  @override
  void initState() {
    super.initState();
    // Registrar observador para ciclo de vida do widget
    WidgetsBinding.instance.addObserver(this);
    // Inicializa a câmera
    _logInfo('initState: Inicializando câmera pela primeira vez');
    _initializeCamera();

    // Inicializa o PageController na página correspondente ao modo selecionado
    int initialIndex =
        _scanModes.indexWhere((mode) => mode['id'] == _selectedScanMode);
    if (initialIndex < 0) initialIndex = 0; // default para 'ai_macros' (índice 0)

    _pageController = PageController(
      initialPage: initialIndex,
      viewportFraction: 0.5, // Aumentado para dar mais espaço aos textos
    );

    // Adicionar verificação de sanidade para câmera presa em loading
    _setupSanityCheck();
  }

  @override
  void dispose() {
    _pageController.dispose();

    // Cancelar timer de timeout se existir
    _cancelInitTimeoutTimer();

    // Remover observador
    WidgetsBinding.instance.removeObserver(this);
    // Liberar recursos da câmera
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _logInfo('Mudança de estado do ciclo de vida: $state');

    // Garanta que não haja operações concorrentes
    if (_isResuming) {
      _logInfo('Já está retomando, ignorando nova mudança de estado');
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        _logInfo('App retomado: tentando restaurar a câmera');
        if (_isMinimized) {
          _isMinimized = false;
          _isResuming = true;
          _resumeAttempts = 0;

          // Aguardar um pouco antes de tentar reinicializar a câmera
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted && !_isCameraInitialized) {
              _logInfo('Tentando reinicializar câmera após delay');
              _tryRestoreCamera();
            } else {
              _logInfo('Camera já inicializada ou widget desmontado');
              _isResuming = false;
            }
          });
        } else {
          _logInfo('Não foi minimizado, nada a fazer');
          _isResuming = false;
        }
        break;

      case AppLifecycleState.inactive:
        _logInfo('App inativo: liberando câmera');
        _cleanupCamera('inactive');
        break;

      case AppLifecycleState.paused:
        _logInfo('App pausado: liberando câmera');
        _isMinimized = true;
        _cleanupCamera('paused');
        break;

      case AppLifecycleState.detached:
        _logInfo('App desanexado: liberando câmera');
        _cleanupCamera('detached');
        break;

      case AppLifecycleState.hidden:
        _logInfo('App oculto: liberando câmera');
        _cleanupCamera('hidden');
        break;
    }
  }

  // Método para log de informações
  void _logInfo(String message) {
    print('[CAMERA_DEBUG] INFO: $message');
  }

  // Método para log de erros
  void _logError(String message, [dynamic error]) {
    print('[CAMERA_DEBUG] ERRO: $message ${error != null ? '- $error' : ''}');
    // Marcar que houve um erro na câmera
    if (mounted && !_isCameraError) {
      setState(() {
        _isCameraError = true;
      });
    }
  }

  // Método para tentar restaurar a câmera com lógica de retry
  Future<void> _tryRestoreCamera() async {
    if (!mounted || _isCameraInitialized) {
      _isResuming = false;
      return;
    }

    _resumeAttempts++;
    _logInfo('Tentativa $_resumeAttempts de restaurar a câmera');

    // Configurar timeout para restauração da câmera
    _setupInitTimeoutTimer();
    setState(() {
      _isInitializing = true;
    });

    try {
      // Se já existe um controlador, descarte-o primeiro
      if (_cameraController != null) {
        _logInfo('Descartando controlador existente antes de restaurar');
        _disposeCamera();
      }

      // Obter lista de câmeras disponíveis
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        _logError('Nenhuma câmera disponível');
        if (mounted) {
          setState(() {
            _isCameraError = true;
            _isInitializing = false;
          });
          _showErrorSnackBar('Nenhuma câmera disponível');
        }
        _isResuming = false;
        _cancelInitTimeoutTimer();
        return;
      }

      // Inicializar a câmera traseira (normalmente a primeira)
      await _initCameraController(_cameras[0]);
      _isResuming = false;
      _isInitializing = false;
      _cancelInitTimeoutTimer();
      _logInfo('Câmera restaurada com sucesso');
    } catch (e) {
      _logError('Erro ao restaurar a câmera', e);
      _cancelInitTimeoutTimer();

      // Tentar novamente se ainda não atingiu o limite de tentativas
      if (_resumeAttempts < 3 && mounted) {
        _logInfo('Agendando nova tentativa em ${_resumeAttempts * 500}ms');
        Future.delayed(Duration(milliseconds: _resumeAttempts * 500), () {
          if (mounted && !_isCameraInitialized) {
            _tryRestoreCamera();
          } else {
            _isResuming = false;
          }
        });
      } else {
        _logInfo('Número máximo de tentativas atingido');
        _isResuming = false;
        if (mounted) {
          setState(() {
            _isCameraError = true;
            _isInitializing = false;
          });
          _showErrorSnackBar(
              'Falha ao inicializar a câmera após várias tentativas');
        }
      }
    }
  }

  // Método unificado para limpeza da câmera
  void _cleanupCamera(String reason) {
    _logInfo('Limpando recursos da câmera (razão: $reason)');

    if (_cameraController == null) {
      _logInfo('Controlador já é nulo, nada a limpar');
      return;
    }

    try {
      final controller = _cameraController;

      // Verificação adicional antes de liberar recursos
      if (controller != null && controller.value.isInitialized) {
        // Capturar a referência e definir _cameraController como nulo ANTES
        // de tentar descartar o controlador, evitando condições de corrida
        _logInfo('Marcando câmera como não inicializada');
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
            _cameraController = null; // Definir como nulo ANTES da liberação
          });
        } else {
          _isCameraInitialized = false;
          _cameraController = null;
        }

        // Agora liberamos o controlador de forma segura
        _logInfo('Liberando controlador com segurança');
        controller.dispose().then((_) {
          _logInfo('Controlador liberado com sucesso');
        }).catchError((e) {
          _logError('Erro ao liberar controlador, mas foi tratado', e);
        });
      } else {
        _logInfo('Controlador não inicializado, apenas limpando referências');
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
            _cameraController = null;
          });
        } else {
          _isCameraInitialized = false;
          _cameraController = null;
        }
      }
    } catch (e) {
      _logError('Erro ao liberar recursos da câmera', e);
      // Garantir que as referências sejam limpas mesmo em caso de erro
      _isCameraInitialized = false;
      _cameraController = null;
    }
  }

  void _disposeCamera() {
    _cleanupCamera('dispose_called');
  }

  // Método para cancelar o timer de timeout
  void _cancelInitTimeoutTimer() {
    if (_initTimeoutTimer != null) {
      _initTimeoutTimer!.cancel();
      _initTimeoutTimer = null;
    }
  }

  // Método para configurar o timer de timeout
  void _setupInitTimeoutTimer() {
    _cancelInitTimeoutTimer(); // Cancelar timer existente se houver

    // Registrar o tempo de início da inicialização
    _initStartTime = DateTime.now();

    _initTimeoutTimer = Timer(Duration(seconds: _cameraInitTimeoutSeconds), () {
      _logError('Timeout geral na inicialização da câmera');

      if (mounted && !_isCameraError && _isInitializing) {
        setState(() {
          _isCameraError = true;
          _isInitializing = false;
        });

        // Limpar recursos da câmera em caso de timeout
        _cleanupCamera('init_timeout');

        // Exibir mensagem ao usuário
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr.translate('camera_timeout') ??
                  'Tempo esgotado ao inicializar a câmera. Tente novamente.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  Future<void> _initializeCamera() async {
    _logInfo('Iniciando processo de inicialização da câmera');

    if (!mounted) {
      _logInfo('Widget desmontado, cancelando inicialização');
      return;
    }

    // Marca que a inicialização está em andamento
    setState(() {
      _isInitializing = true;
    });

    // Configurar timer de timeout para todo o processo
    _setupInitTimeoutTimer();

    // Reseta o estado de erro
    if (_isCameraError && mounted) {
      setState(() {
        _isCameraError = false;
      });
    }

    try {
      // Se já existe um controlador, descarte-o primeiro
      if (_cameraController != null) {
        _logInfo('Controlador já existe, descartando primeiro');
        _disposeCamera();
      }

      _logInfo('Buscando câmeras disponíveis');
      // Obter lista de câmeras disponíveis
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        _logError('Nenhuma câmera disponível');
        if (mounted) {
          setState(() {
            _isCameraError = true;
            _isInitializing = false;
          });
          _cancelInitTimeoutTimer();
          _showErrorSnackBar(context.tr.translate('no_cameras_available') ??
              'Nenhuma câmera disponível');
        }
        return;
      }

      _logInfo('Câmeras encontradas: ${_cameras.length}');
      // Inicializar a câmera traseira (normalmente a primeira)
      await _initCameraController(_cameras[0]);

      // Cancelar timer de timeout após inicialização bem-sucedida
      _cancelInitTimeoutTimer();
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      _logError('Erro ao inicializar câmera', e);
      _cancelInitTimeoutTimer();

      if (mounted) {
        setState(() {
          _isCameraError = true;
          _isInitializing = false;
        });
        _showErrorSnackBar(
            '${context.tr.translate('camera_initialization_error') ?? 'Erro ao inicializar câmera'}: $e');
      }
    }
  }

  Future<void> _initCameraController(CameraDescription camera) async {
    _logInfo('Criando controlador para câmera: ${camera.name}');

    if (!mounted) {
      _logInfo('Widget desmontado, cancelando inicialização do controlador');
      return;
    }

    // Criar novo controller
    final CameraController controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _logInfo('Controlador criado, iniciando inicialização');
    _cameraController = controller;

    try {
      _logInfo('Inicializando controlador com timeout de 10 segundos');
      // Inicializar o controller
      await controller.initialize().timeout(Duration(seconds: 10),
          onTimeout: () {
        _logError('Timeout ao inicializar a câmera');
        throw TimeoutException('Tempo esgotado ao inicializar a câmera');
      });

      if (!mounted || controller != _cameraController) {
        _logInfo(
            'Widget desmontado ou controlador alterado durante inicialização');
        await controller.dispose();
        return;
      }

      _logInfo('Controlador inicializado, configurando flash');
      // Atualizar flash se necessário
      if (controller.value.isInitialized) {
        await controller
            .setFlashMode(_flashEnabled ? FlashMode.torch : FlashMode.off);
        _logInfo(
            'Flash configurado: ${_flashEnabled ? 'ativado' : 'desativado'}');
      }

      if (mounted) {
        _logInfo('Atualizando estado: câmera inicializada com sucesso');
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      _logError('Erro ao inicializar o controlador da câmera', e);

      if (mounted && controller == _cameraController) {
        _logInfo('Limpando referência do controlador após falha');
        _cameraController = null;
        setState(() {
          _isCameraInitialized = false;
          _isCameraError = true; // Marcar explicitamente como erro
        });
      }

      _logInfo('Tentando liberar controlador que falhou');
      try {
        await controller.dispose();
      } catch (disposeError) {
        _logError('Erro ao liberar controlador com falha', disposeError);
      }

      if (mounted) {
        _showErrorSnackBar(
          '${context.tr.translate('camera_initialization_error') ?? 'Erro ao inicializar câmera'}: $e',
        );
      }

      rethrow;
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showErrorSnackBar(
          context.tr.translate('camera_not_ready') ?? 'Câmera não está pronta');
      return;
    }

    try {
      // Definir as dimensões do retângulo de corte
      final Size screenSize = MediaQuery.of(context).size;
      final double padding = 16.0;
      final double rectWidth = screenSize.width - (padding * 2);
      final double rectHeight = 180.0;

      // Calcular a posição vertical do retângulo para centralizá-lo mais para cima
      final double appBarHeight = AppBar().preferredSize.height;
      final double statusBarHeight = MediaQuery.of(context).padding.top;
      final double buttonsAreaHeight =
          180.0; // Altura estimada da área inferior
      final double availableHeight = screenSize.height -
          appBarHeight -
          statusBarHeight -
          buttonsAreaHeight;
      // Posicionar mais para cima, usando 0.25 em vez de 0.3 da altura disponível
      final double topOffset =
          appBarHeight + statusBarHeight + (availableHeight * 0.25);

      final Rect cutOutRect = Rect.fromLTWH(
          padding, topOffset, rectWidth, rectHeight); // Usar LTWH para precisão

      // Capturar imagem
      final XFile photo = await _cameraController!.takePicture();
      final Uint8List imageBytes = await photo.readAsBytes();

      setState(() {
        _capturedImage = imageBytes;
      });

      // Navegar para a tela de edição de imagem
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditScreen(
            image: _capturedImage!,
            initialCropRect: cutOutRect,
            scanMode: _selectedScanMode,
          ),
        ),
      ).then((_) {
        // Quando voltar à tela da câmera, reinicializá-la
        if (mounted) {
          _initializeCamera();
        }
      });
    } catch (e) {
      _showErrorSnackBar(
          '${context.tr.translate('failed_to_capture_image') ?? 'Falha ao capturar imagem'}: $e');
    }
  }

  void _openGallery() async {
    try {
      final imageBytes = await ImageUploadHelper.pickImageFromGallery();
      if (imageBytes != null) {
        final Size screenSize = MediaQuery.of(context).size;
        final double padding = 16.0;
        final double rectWidth = screenSize.width - (padding * 2);
        final double rectHeight = 180.0;

        // Calcular a posição vertical do retângulo
        final double appBarHeight = AppBar().preferredSize.height;
        final double statusBarHeight = MediaQuery.of(context).padding.top;
        final double buttonsAreaHeight = 180.0;
        final double availableHeight = screenSize.height -
            appBarHeight -
            statusBarHeight -
            buttonsAreaHeight;
        // Centralizar verticalmente na área disponível
        final double topOffset =
            appBarHeight + statusBarHeight + (availableHeight * 0.4);

        final Rect cutOutRect = Rect.fromLTWH(padding, topOffset, rectWidth,
            rectHeight); // Usar LTWH para precisão

        setState(() {
          _capturedImage = imageBytes;
        });

        // Navegar para a tela de edição de imagem
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageEditScreen(
              image: _capturedImage!,
              initialCropRect: cutOutRect,
              scanMode: _selectedScanMode,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('${context.tr.translate('failed_to_pick_image')}: $e');
    }
  }

  void _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _flashEnabled = !_flashEnabled;
    });

    try {
      await _cameraController!
          .setFlashMode(_flashEnabled ? FlashMode.torch : FlashMode.off);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_flashEnabled
              ? context.tr.translate('flash_enabled')
              : context.tr.translate('flash_disabled')),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      _showErrorSnackBar(
          '${context.tr.translate('flash_toggle_error') ?? 'Erro ao alternar flash'}: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
    print('[CAMERA_ERROR] $message');
  }

  // Método para centralizar o item selecionado
  void _scrollToSelectedItem({bool animate = true}) {
    // Encontrar o índice do modo selecionado
    final int selectedIndex =
        _scanModes.indexWhere((m) => m['id'] == _selectedScanMode);
    if (selectedIndex < 0) return;

    // Animar a mudança de página
    if (animate) {
      _pageController.animateToPage(
        selectedIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController.jumpToPage(selectedIndex);
    }
  }

  // Método chamado quando uma nova página é selecionada no PageView
  void _onPageChanged(int pageIndex) {
    if (pageIndex >= 0 && pageIndex < _scanModes.length) {
      final String newMode = _scanModes[pageIndex]['id'];
      if (_selectedScanMode != newMode) {
        setState(() {
          _selectedScanMode = newMode;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Definir as dimensões do retângulo de corte
    final Size screenSize = MediaQuery.of(context).size;
    final double padding = 16.0;
    final double rectWidth = screenSize.width - (padding * 2);
    final double rectHeight = 180.0;

    // Calcular a posição vertical do retângulo para centralizá-lo mais para cima
    final double appBarHeight = AppBar().preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double buttonsAreaHeight = 180.0; // Altura estimada da área inferior
    final double availableHeight =
        screenSize.height - appBarHeight - statusBarHeight - buttonsAreaHeight;
    // Posicionar mais para cima, usando 0.25 em vez de 0.3 da altura disponível
    final double topOffset =
        appBarHeight + statusBarHeight + (availableHeight * 0.25);

    final Rect cutOutRect = Rect.fromLTWH(
        padding, topOffset, rectWidth, rectHeight); // Usar LTWH para precisão

    // Texto da dica baseado no modo
    String hintText = '';
    switch (_selectedScanMode) {
      case 'ai_macros':
        hintText = context.tr.translate('ai_macros_hint') ??
            'Tire uma foto do seu alimento para calcular macros';
        break;
      case 'barcode':
        hintText = context.tr.translate('barcode_hint') ??
            'Escaneie o código de barras do produto';
        break;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar:
          true, // Permite que o corpo se estenda atrás do AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // AppBar totalmente transparente
        elevation: 0,
        title: Text(context.tr.translate('scan'),
            style: TextStyle(color: Colors.white)),
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CreditIndicator(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Verifica se temos um erro de câmera para mostrar a tela de erro
          if (_isCameraError)
            _buildErrorScreen(context)
          else if (_isCameraInitialized &&
              _cameraController != null &&
              _cameraController!.value.isInitialized)
            // Visualização da câmera
            Container(
              width: double.infinity,
              height: double.infinity,
              child: CameraPreview(_cameraController!),
            )
          else
            // Tela de carregamento melhorada
            _buildLoadingScreen(context),

          // Só mostra o recorte e os controles se não houver erro de câmera
          if (!_isCameraError) ...[
            // Overlay translúcido com recorte retangular
            Positioned.fill(
              child: CustomPaint(
                painter: OverlayPainter(
                  cutOutRect: cutOutRect,
                  borderRadius: 12.0,
                ),
              ),
            ),

            // Mensagem informativa acima do retângulo
            Positioned(
              top: cutOutRect.top - 60,
              left: padding,
              right: padding,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getModeHintText(),
                  style: TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Bottom controls overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 10,
                    top: 10,
                    left: 0,
                    right: 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scan mode options com PageView para centralização automática
                    Container(
                      height:
                          50, // Reduzido para acomodar menos padding vertical
                      width: double.infinity,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _scanModes.length,
                        onPageChanged: _onPageChanged,
                        physics: BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final mode = _scanModes[index];
                          return Center(
                            child: _buildScanOptionTextOnly(
                              mode['id'],
                              context.tr.translate(mode['id']) ?? mode['label'],
                              mode['color'],
                            ),
                          );
                        },
                      ),
                    ),

                    SizedBox(height: 20),

                    // Capture, gallery and flash buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Gallery button (left) - sem contorno
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(Icons.photo_library_outlined,
                                color: Colors.white),
                            onPressed: _openGallery,
                          ),
                        ),

                        // Botão de captura grande com a cor e ícone do modo selecionado
                        GestureDetector(
                          onTap: _isCameraInitialized ? _captureImage : null,
                          child: Container(
                            width: 85,
                            height: 85,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 75,
                                height: 75,
                                decoration: BoxDecoration(
                                  color: _getModeColor(_selectedScanMode),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getModeIcon(_selectedScanMode),
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Flash button (right) - sem contorno
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _flashEnabled
                                ? Colors.yellow.withOpacity(0.3)
                                : Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              _flashEnabled ? Icons.flash_on : Icons.flash_off,
                              color: Colors.white,
                            ),
                            onPressed:
                                _isCameraInitialized ? _toggleFlash : null,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Widget para exibir a tela de erro
  Widget _buildErrorScreen(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 80,
            ),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                context.tr.translate('camera_error_message') ??
                    'Não foi possível inicializar a câmera',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                _isInitializing
                    ? (context.tr.translate('camera_timeout_description') ??
                        'A câmera está demorando muito para responder. Você pode tentar novamente ou usar a galeria.')
                    : (context.tr.translate('camera_error_description') ??
                        'Verifique as permissões de câmera do aplicativo ou tente novamente'),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                // Reset estado de initializing se estiver true
                if (_isInitializing) {
                  setState(() {
                    _isInitializing = false;
                  });
                }
                _initializeCamera();
              },
              icon: Icon(Icons.refresh),
              label: Text(
                context.tr.translate('try_again') ?? 'Tentar novamente',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 20),
            TextButton(
              onPressed: _openGallery,
              child: Text(
                context.tr.translate('use_gallery') ?? 'Usar galeria',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget para exibir uma tela de carregamento melhorada
  Widget _buildLoadingScreen(BuildContext context) {
    // Verificar se a inicialização está demorando mais de 5 segundos
    bool isLongLoading = false;
    if (_isInitializing && _initStartTime != null) {
      isLongLoading = DateTime.now().difference(_initStartTime!).inSeconds > 5;
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 3,
            ),
            if (_isInitializing) ...[
              // Mostrar sempre mensagens se estiver inicializando
              SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  context.tr.translate('camera_initializing') ??
                      'Inicializando câmera...',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
              if (isLongLoading) ...[
                SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    context.tr.translate('camera_wait_message') ??
                        'Isso pode levar alguns segundos',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 24),
                TextButton.icon(
                  onPressed: _openGallery,
                  icon: Icon(Icons.photo_library, color: Colors.white70),
                  label: Text(
                    context.tr.translate('use_gallery_instead') ??
                        'Usar galeria em vez disso',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // Método para obter a cor com base no modo selecionado
  Color _getModeColor(String mode) {
    final modeData = _scanModes.firstWhere(
      (element) => element['id'] == mode,
      orElse: () => _scanModes[1], // Default para 'general'
    );

    return modeData['color'];
  }

  // Método para obter o ícone com base no modo selecionado
  IconData _getModeIcon(String mode) {
    final modeData = _scanModes.firstWhere(
      (element) => element['id'] == mode,
      orElse: () => _scanModes[1], // Default para 'general'
    );

    return modeData['icon'];
  }

  // Novo método para criar opção de scan apenas com texto
  Widget _buildScanOptionTextOnly(String mode, String label, Color color) {
    final isSelected = _selectedScanMode == mode;

    return GestureDetector(
      onTap: () {
        if (_selectedScanMode != mode) {
          setState(() {
            _selectedScanMode = mode;
          });

          // Centralizar o item selecionado quando clicado
          _scrollToSelectedItem();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 14),
        width: 140, // Largura fixa mas suficiente para todos os textos
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }

  // O método original não será mais usado para renderizar na tela, mas mantemos
  // por ser usado em outras partes do código
  Widget _buildScanOption(
      String mode, String label, IconData icon, Color color) {
    final isSelected = _selectedScanMode == mode;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedScanMode = mode;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? color : Colors.white.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? color : Colors.white,
              size: 24,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? color : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Método para obter o texto da dica baseado no modo
  String _getModeHintText() {
    switch (_selectedScanMode) {
      case 'ai_macros':
        return context.tr.translate('ai_macros_hint') ??
            'Tire uma foto do seu alimento para calcular macros';
      case 'barcode':
        return context.tr.translate('barcode_hint') ??
            'Escaneie o código de barras do produto';
      default:
        return '';
    }
  }

  String _getTranslateHintShort(BuildContext context) {
    // Método para garantir que sempre teremos um texto para "translate_hint_short"
    // baseado no idioma atual
    String? translatedText = context.tr.translate('translate_hint_short');

    if (translatedText != null && translatedText != 'translate_hint_short') {
      return translatedText;
    }

    // Fallback para idiomas específicos se a tradução não for encontrada
    Locale currentLocale = Localizations.localeOf(context);
    String languageCode = currentLocale.languageCode;

    switch (languageCode) {
      case 'pt':
        return 'Traduzir para';
      case 'es':
        return 'Traducir a';
      case 'fr':
        return 'Traduire en';
      case 'de':
        return 'Übersetzen in';
      case 'it':
        return 'Traduci in';
      default:
        return 'Translate to';
    }
  }

  // Verificação periódica do estado da câmera
  void _setupSanityCheck() {
    Future.delayed(Duration(seconds: 20), () {
      if (mounted &&
          _isInitializing &&
          !_isCameraInitialized &&
          !_isCameraError) {
        _logError('Verificação de sanidade: Câmera presa em inicialização');

        // Cancelar qualquer timer de timeout existente
        _cancelInitTimeoutTimer();

        // Forçar o estado de erro
        setState(() {
          _isCameraError = true;
          _isInitializing = false;
        });

        // Limpar recursos
        _cleanupCamera('sanity_check_failure');

        // Exibir mensagem
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr.translate('camera_stuck') ??
                'A câmera parece estar presa. Por favor, tente novamente.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }
}

// Classe para desenhar o overlay translúcido
class OverlayPainter extends CustomPainter {
  final Rect cutOutRect;
  final double borderRadius;

  OverlayPainter({
    required this.cutOutRect,
    this.borderRadius = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Método alternativo para criar o efeito de corte
    // Primeiro, criamos um path para o retângulo com bordas arredondadas
    final Path cutOutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          cutOutRect,
          Radius.circular(borderRadius),
        ),
      );

    // Em seguida, criamos um path para a tela inteira
    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      // Removemos o recorte do path de fundo usando a operação de diferença
      ..fillType = PathFillType.evenOdd
      ..addPath(cutOutPath, Offset.zero);

    // Desenhar o overlay translúcido com base no path resultante, mais claro
    canvas.drawPath(
      backgroundPath,
      Paint()
        ..color = Colors.black
            .withOpacity(0.35) // Opacidade reduzida para ficar mais claro
        ..style = PaintingStyle.fill,
    );

    // Desenhar borda ao redor do recorte com bordas arredondadas
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        cutOutRect,
        Radius.circular(borderRadius),
      ),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
