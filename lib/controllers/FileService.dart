import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

class FileService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Pick and upload image
  Future<Map<String, dynamic>?> pickAndUploadImage({
    required String chatId,
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );

      if (pickedFile == null) return null;

      // Compress the image
      final File originalFile = File(pickedFile.path);
      final String fileName = path.basename(pickedFile.path);
      final String fileExtension = path.extension(fileName).toLowerCase();

      Uint8List? compressedData;
      if (fileExtension == '.jpg' || fileExtension == '.jpeg' || fileExtension == '.png') {
        compressedData = await FlutterImageCompress.compressWithFile(
          originalFile.path,
          quality: 70,
          minWidth: 800,
          minHeight: 600,
        );
      }

      final Uint8List fileData = compressedData ?? await originalFile.readAsBytes();
      final int fileSizeInBytes = fileData.length;
      final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      // Check file size limit (10MB)
      if (fileSizeInMB > 10) {
        throw Exception('File size exceeds 10MB limit');
      }

      // Upload to Firebase Storage
      final String uploadPath = 'chat_files/$chatId/images/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final Reference ref = _storage.ref().child(uploadPath);
      
      final UploadTask uploadTask = ref.putData(
        fileData,
        SettableMetadata(
          contentType: _getContentType(fileExtension),
          customMetadata: {
            'uploadedBy': currentUserId,
            'chatId': chatId,
            'originalName': fileName,
            'fileType': 'image',
          },
        ),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return {
        'url': downloadUrl,
        'name': fileName,
        'size': fileSizeInBytes,
        'type': 'image',
        'uploadPath': uploadPath,
      };
    } catch (e) {
      print('Error picking and uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  // Pick and upload PDF
  Future<Map<String, dynamic>?> pickAndUploadPDF({
    required String chatId,
  }) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return null;

      final PlatformFile file = result.files.first;
      final String fileName = file.name;
      final int fileSizeInBytes = file.size;
      final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      // Check file size limit (25MB for PDFs)
      if (fileSizeInMB > 25) {
        throw Exception('PDF file size exceeds 25MB limit');
      }

      Uint8List? fileData;
      if (file.bytes != null) {
        fileData = file.bytes!;
      } else if (file.path != null) {
        fileData = await File(file.path!).readAsBytes();
      } else {
        throw Exception('Unable to read file data');
      }

      // Upload to Firebase Storage
      final String uploadPath = 'chat_files/$chatId/pdfs/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final Reference ref = _storage.ref().child(uploadPath);
      
      final UploadTask uploadTask = ref.putData(
        fileData,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'uploadedBy': currentUserId,
            'chatId': chatId,
            'originalName': fileName,
            'fileType': 'pdf',
          },
        ),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return {
        'url': downloadUrl,
        'name': fileName,
        'size': fileSizeInBytes,
        'type': 'pdf',
        'uploadPath': uploadPath,
      };
    } catch (e) {
      print('Error picking and uploading PDF: $e');
      throw Exception('Failed to upload PDF: $e');
    }
  }

  // Delete file from Firebase Storage
  Future<void> deleteFile(String uploadPath) async {
    try {
      await _storage.ref().child(uploadPath).delete();
    } catch (e) {
      print('Error deleting file: $e');
      // Don't throw error as file might already be deleted
    }
  }

  // Get file content type based on extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  // Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
} 