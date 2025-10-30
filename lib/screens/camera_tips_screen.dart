import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CameraTipsScreen extends StatelessWidget {
  const CameraTipsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Botão de fechar
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 28,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Conteúdo principal
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Ilustração
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFF8E1),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Frame de captura roxo
                          CustomPaint(
                            size: Size(200, 200),
                            painter: _FramePainter(),
                          ),
                          // Emoji de comida (prato de salada)
                          Center(
                            child: Text(
                              '🥗',
                              style: TextStyle(fontSize: 100),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 40),

                    // Título
                    Text(
                      'Algumas dicas rápidas',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 32),

                    // Lista de dicas
                    _buildTipCard(
                      icon: Icons.crop_free,
                      text: 'Enquadre toda a refeição',
                      iconColor: AppTheme.primaryColor,
                      isDarkMode: isDarkMode,
                    ),
                    SizedBox(height: 16),
                    _buildTipCard(
                      icon: Icons.remove_red_eye_outlined,
                      text: 'Mostre cada item nitidamente',
                      iconColor: Color(0xFF7C4DFF),
                      isDarkMode: isDarkMode,
                    ),
                    SizedBox(height: 16),
                    _buildTipCard(
                      icon: Icons.lightbulb_outline,
                      text: 'Garanta uma boa iluminação',
                      iconColor: Color(0xFFFFA726),
                      isDarkMode: isDarkMode,
                    ),

                    Spacer(),
                  ],
                ),
              ),
            ),

            // Botão de ação
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Começar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard({
    required IconData icon,
    required String text,
    required Color iconColor,
    required bool isDarkMode,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF2A2A2A) : Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.grey.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Painter para desenhar o frame de captura roxo
class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFF9C27B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final cornerLength = 40.0;
    final radius = 12.0;

    // Canto superior esquerdo
    canvas.drawLine(
      Offset(0, cornerLength),
      Offset(0, radius),
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(0, 0, radius * 2, radius * 2),
      3.14,
      1.57,
      false,
      paint,
    );
    canvas.drawLine(
      Offset(radius, 0),
      Offset(cornerLength, 0),
      paint,
    );

    // Canto superior direito
    canvas.drawLine(
      Offset(size.width - cornerLength, 0),
      Offset(size.width - radius, 0),
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(size.width - radius * 2, 0, radius * 2, radius * 2),
      4.71,
      1.57,
      false,
      paint,
    );
    canvas.drawLine(
      Offset(size.width, radius),
      Offset(size.width, cornerLength),
      paint,
    );

    // Canto inferior esquerdo
    canvas.drawLine(
      Offset(0, size.height - cornerLength),
      Offset(0, size.height - radius),
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(0, size.height - radius * 2, radius * 2, radius * 2),
      1.57,
      1.57,
      false,
      paint,
    );
    canvas.drawLine(
      Offset(radius, size.height),
      Offset(cornerLength, size.height),
      paint,
    );

    // Canto inferior direito
    canvas.drawLine(
      Offset(size.width - cornerLength, size.height),
      Offset(size.width - radius, size.height),
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(
          size.width - radius * 2, size.height - radius * 2, radius * 2, radius * 2),
      0,
      1.57,
      false,
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height - radius),
      Offset(size.width, size.height - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
