import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cross_file/cross_file.dart';

class ImageEncryptionService {
  // Maximum size in bytes (5MB)
  static const int MAX_IMAGE_SIZE = 5 * 1024 * 1024;
  
  // Check if image is within size limit
  static Future<bool> isImageSizeValid(File file) async {
    final fileSize = await file.length();
    return fileSize <= MAX_IMAGE_SIZE;
  }
  
  // Compress image to target size
  static Future<File?> compressImage(File file) async {
    try {
      final String dir = file.parent.path;
      final String targetPath = '$dir/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileSize = await file.length();
      
      if (fileSize <= MAX_IMAGE_SIZE) {
        // No need to compress if already under limit
        return file;
      }
      
      // Calculate quality based on file size
      // Lower quality for larger files
      int quality = (MAX_IMAGE_SIZE / fileSize * 100).round();
      quality = quality.clamp(50, 85); // Don't go below 50% or above 85%
      
      // Compress the image
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.path, 
        targetPath,
        quality: quality,
        minWidth: 1000, // Reasonable width for profile pictures
        minHeight: 1000,
      );
      
      if (compressedFile == null) {
        print('Failed to compress image');
        return null;
      }
      
      // Convert XFile to File
      final File resultFile = File(compressedFile.path);
      
      // Check if compressed enough
      if (await resultFile.length() > MAX_IMAGE_SIZE) {
        print('Image still too large after compression');
        return null;
      }
      
      print('Compressed image from ${fileSize} to ${await resultFile.length()} bytes');
      return resultFile;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }
  
  // Convert image file to Base64 string with size validation and compression
  static Future<String> imageToBase64String(File file, {Function(double)? onProgress}) async {
    try {
      onProgress?.call(0.1); // Start progress
      
      // Check size first
      final isValid = await isImageSizeValid(file);
      if (!isValid) {
        print('Original image too large, attempting compression');
        final compressedFile = await compressImage(file);
        if (compressedFile == null) {
          throw Exception('Image too large (>5MB) even after compression');
        }
        file = compressedFile;
      }
      
      onProgress?.call(0.3); // After size check/compression
      
      // Read the image file as bytes
      final Uint8List bytes = await file.readAsBytes();
      onProgress?.call(0.6); // After reading bytes
      
      // Convert to base64 string
      final String base64Image = base64Encode(bytes);
      onProgress?.call(0.9); // After encoding
      
      print('Image converted to Base64 string successfully (${base64Image.length} chars)');
      onProgress?.call(1.0); // Complete
      
      return base64Image;
    } catch (e) {
      print('Error converting image to Base64: $e');
      throw e;
    }
  }
  
  // Convert Base64 string back to image bytes
  static Uint8List? base64StringToImage(String base64String) {
    try {
      if (base64String.isEmpty) {
        return null;
      }
      
      // Decode Base64 string to bytes
      final Uint8List imageBytes = base64Decode(base64String);
      print('Base64 string converted to image bytes successfully');
      
      return imageBytes;
    } catch (e) {
      print('Error converting Base64 to image: $e');
      return null;
    }
  }
  
  // Check if a string is a valid Base64 image
  static bool isValidBase64Image(String str) {
    if (str.isEmpty) return false;
    
    try {
      // Check if it's valid Base64
      base64Decode(str);
      // A very basic check - real images will be much longer
      return str.length > 100;
    } catch (e) {
      return false;
    }
  }
} 