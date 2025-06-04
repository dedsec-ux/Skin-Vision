import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../controllers/ImageEncryptionService.dart';

class EncryptedImage extends StatefulWidget {
  final String base64String;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BoxFit? fit;

  const EncryptedImage({
    Key? key,
    required this.base64String,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  _EncryptedImageState createState() => _EncryptedImageState();
}

class _EncryptedImageState extends State<EncryptedImage> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(EncryptedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64String != widget.base64String) {
      _loadImage();
    }
  }

  void _loadImage() {
    if (widget.base64String.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Convert from Base64 string to image bytes
      final decryptedBytes = ImageEncryptionService.base64StringToImage(widget.base64String);
      
      if (mounted) {
        setState(() {
          _imageBytes = decryptedBytes;
          _isLoading = false;
          _hasError = decryptedBytes == null;
        });
      }
    } catch (e) {
      print('Error loading Base64 image: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ?? Center(
        child: SizedBox(
          width: widget.width != null ? widget.width! * 0.5 : 30,
          height: widget.height != null ? widget.height! * 0.5 : 30,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
          ),
        ),
      );
    }

    if (_hasError || _imageBytes == null) {
      return widget.errorWidget ?? Icon(
        Icons.image_not_supported,
        size: widget.width != null ? widget.width! * 0.5 : 30,
        color: Colors.grey,
      );
    }

    return Image.memory(
      _imageBytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
    );
  }
} 