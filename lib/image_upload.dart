import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Helper class for handling image uploads
class ImageUploadHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Pick an image from the gallery
  /// Returns the File object of the selected image, or null if cancelled
  static Future<Uint8List?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Compress image to reduce size
      );

      if (image != null) {
        return await image.readAsBytes();
      }
      return null;
    } catch (e) {
      print('Error picking image from gallery: \$e');
      return null;
    }
  }

  /// Capture an image using the camera
  /// Returns the File object of the captured image, or null if cancelled
  static Future<Uint8List?> captureImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // Compress image to reduce size
      );

      if (image != null) {
        return await image.readAsBytes();
      }
      return null;
    } catch (e) {
      print('Error capturing image: \$e');
      return null;
    }
  }

  /// Example usage of how to handle the returned File
  static Future<void> handleImageSelection({required bool fromCamera}) async {
    Uint8List? imageFile =
        fromCamera ? await captureImage() : await pickImageFromGallery();

    if (imageFile != null) {
      // Do something with the image file
      // For example, upload to server or display in UI
      print('Image selected');
    }
  }
}
