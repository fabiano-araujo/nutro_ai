import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import '../i18n/app_localizations_extension.dart';

class ImageViewerScreen extends StatelessWidget {
  final Uint8List imageBytes;

  const ImageViewerScreen({Key? key, required this.imageBytes})
      : super(key: key);

  Future<void> _download(BuildContext context) async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(context.tr.translate('gallery_permission_denied')),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      await Gal.putImageBytes(
        imageBytes,
        name: 'nutro_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr.translate('image_saved_gallery')),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on GalException catch (e) {
      debugPrint('Erro ao salvar imagem na galeria: ${e.type.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr.translate('image_save_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro inesperado ao salvar imagem: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr.translate('image_save_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white, size: 26),
            tooltip: context.tr.translate('save_to_gallery'),
            onPressed: () => _download(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: Center(
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
