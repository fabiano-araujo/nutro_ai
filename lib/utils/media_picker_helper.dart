import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MediaPickerHelper {
  static final ImagePicker _imagePicker = ImagePicker();

  /// Seleciona uma imagem da galeria ou câmera.
  /// Retorna os bytes da imagem ou null se a seleção for cancelada ou falhar.
  static Future<Uint8List?> pickImage(
      ImageSource source, BuildContext context) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80, // Qualidade um pouco melhor
      );

      if (pickedFile != null) {
        // Ler a imagem como bytes
        final bytes = await pickedFile.readAsBytes();
        print('📸 MediaPickerHelper - Imagem selecionada: ${pickedFile.path}');
        return bytes;
      } else {
        print('📸 MediaPickerHelper - Seleção de imagem cancelada.');
        return null;
      }
    } catch (e) {
      print('❌ MediaPickerHelper - Erro ao selecionar imagem: $e');
      // Mostra uma mensagem de erro para o usuário
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao selecionar imagem: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }
}
