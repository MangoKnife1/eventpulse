import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import 'service_exception.dart';

/// Uploads images to Cloudinary using an *unsigned* upload preset.
/// No API secret is stored in the app. See SETUP_FIREBASE_CLOUDINARY.md.
class CloudinaryService {
  CloudinaryService._();

  static const int _maxBytes = 10 * 1024 * 1024; // Cloudinary free-plan image limit
  static final ImagePicker _picker = ImagePicker();

  static bool get isConfigured => AppConfig.cloudinaryConfigured;

  /// Lets the user pick a photo, uploads it, and returns the HTTPS URL.
  /// Returns `null` if the user cancelled the picker.
  /// Throws [ServiceException] with a readable message on failure.
  static Future<String?> pickAndUpload({
    String? folder,
    ImageSource source = ImageSource.gallery,
  }) async {
    if (!isConfigured) {
      throw const ServiceException(
        'Image upload is not set up yet. Add your Cloudinary cloud name and '
        'upload preset in lib/config/app_config.dart.',
      );
    }

    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600, // resize on device to save data
        imageQuality: 85,
      );
    } catch (_) {
      throw const ServiceException('Could not open the photo picker.');
    }
    if (picked == null) return null;

    return upload(picked, folder: folder);
  }

  static Future<String> upload(XFile file, {String? folder}) async {
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > _maxBytes) {
      throw const ServiceException('That image is too large (10 MB max).');
    }

    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/${AppConfig.cloudinaryCloudName}/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset
      ..fields['folder'] = folder ?? AppConfig.cloudinaryFolder
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name.isEmpty ? 'upload.jpg' : file.name,
        ),
      );

    try {
      final streamed = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(response.body);

      if (response.statusCode != 200) {
        final detail = (body is Map && body['error'] is Map)
            ? body['error']['message']?.toString()
            : null;
        throw ServiceException(detail ?? 'Upload failed (${response.statusCode}).');
      }

      final url = (body as Map)['secure_url'] as String?;
      if (url == null || url.isEmpty) {
        throw const ServiceException('Upload finished but no image URL was returned.');
      }
      return url;
    } on ServiceException {
      rethrow;
    } on TimeoutException {
      throw const ServiceException('Upload timed out. Check your connection and try again.');
    } catch (_) {
      throw const ServiceException('Upload failed. Check your connection and try again.');
    }
  }
}
