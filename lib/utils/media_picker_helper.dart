import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class MediaPickerHelper {
  static final ImagePicker _imagePicker = ImagePicker();
  static const int maxUploadImageDimension = 1600;
  static const int targetMaxUploadImageBytes = 2 * 1024 * 1024;
  static const int _initialJpegQuality = 82;
  static const int _minJpegQuality = 68;

  /// Seleciona uma imagem da galeria ou câmera.
  /// Retorna os bytes da imagem ou null se a seleção for cancelada ou falhar.
  static Future<Uint8List?> pickImage(
      ImageSource source, BuildContext context) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: maxUploadImageDimension.toDouble(),
        maxHeight: maxUploadImageDimension.toDouble(),
        imageQuality: 80, // Qualidade um pouco melhor
      );

      if (pickedFile != null) {
        // Ler a imagem como bytes
        final bytes = await pickedFile.readAsBytes();
        final uploadBytes = optimizeImageForUpload(bytes);
        print('📸 MediaPickerHelper - Imagem selecionada: ${pickedFile.path}');
        print(
            '📸 MediaPickerHelper - Imagem otimizada: ${bytes.length} -> ${uploadBytes.length} bytes');
        return uploadBytes;
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

  static Uint8List optimizeImageForUpload(Uint8List bytes) {
    if (bytes.isEmpty) {
      return bytes;
    }

    try {
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        return bytes;
      }

      final longestSide = math.max(decodedImage.width, decodedImage.height);
      final shouldResize = longestSide > maxUploadImageDimension;
      final uploadImage = shouldResize
          ? img.copyResize(
              decodedImage,
              width: decodedImage.width >= decodedImage.height
                  ? maxUploadImageDimension
                  : null,
              height: decodedImage.height > decodedImage.width
                  ? maxUploadImageDimension
                  : null,
              interpolation: img.Interpolation.average,
            )
          : decodedImage;

      var quality = _initialJpegQuality;
      var encoded = Uint8List.fromList(
        img.encodeJpg(uploadImage, quality: quality),
      );

      while (encoded.length > targetMaxUploadImageBytes &&
          quality > _minJpegQuality) {
        quality -= 7;
        encoded = Uint8List.fromList(
          img.encodeJpg(uploadImage, quality: quality),
        );
      }

      if (encoded.length >= bytes.length &&
          bytes.length <= targetMaxUploadImageBytes) {
        return bytes;
      }

      return encoded;
    } catch (e) {
      print('❌ MediaPickerHelper - Erro ao otimizar imagem: $e');
      return bytes;
    }
  }
}
