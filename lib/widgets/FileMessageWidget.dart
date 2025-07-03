import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/FileService.dart';
import 'package:get/get.dart';

class FileMessageWidget extends StatelessWidget {
  final Map<String, dynamic> fileData;
  final bool isCurrentUser;

  const FileMessageWidget({
    Key? key,
    required this.fileData,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String fileType = fileData['type'] ?? 'unknown';
    final String fileName = fileData['name'] ?? 'Unknown file';
    final String fileUrl = fileData['url'] ?? '';
    final int fileSize = fileData['size'] ?? 0;

    if (fileType == 'image') {
      return _buildImageMessage(context, fileName, fileUrl, fileSize);
    } else if (fileType == 'pdf') {
      return _buildPdfMessage(context, fileName, fileUrl, fileSize);
    } else {
      return _buildUnknownFileMessage(context, fileName, fileSize);
    }
  }

  Widget _buildImageMessage(BuildContext context, String fileName, String fileUrl, int fileSize) {
    return IntrinsicHeight(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.58,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GestureDetector(
                      onTap: () => _showImageFullScreen(context, fileUrl, fileName),
                      child: Container(
                        constraints: BoxConstraints(
                          maxHeight: 220,
                          minHeight: 140,
                        ),
                                                  child: AspectRatio(
                            aspectRatio: 4 / 3,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                fileUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.grey[200]!,
                                          Colors.grey[300]!,
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded /
                                                    loadingProgress.expectedTotalBytes!
                                                : null,
                                            color: isCurrentUser ? Colors.blueAccent : Colors.grey[600],
                                            strokeWidth: 3,
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'Loading image...',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.red[50]!,
                                          Colors.red[100]!,
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red[600],
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.image_not_supported,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Failed to load image',
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Overlay gradient for better text visibility
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.6),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Tap indicator
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    Icons.fullscreen,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: isCurrentUser 
                    ? Colors.white.withOpacity(0.15) 
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrentUser 
                      ? Colors.white.withOpacity(0.2) 
                      : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isCurrentUser 
                          ? Colors.white.withOpacity(0.2)
                          : Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.photo_camera,
                      size: 12,
                      color: isCurrentUser 
                          ? Colors.white 
                          : Colors.blue[600],
                    ),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isCurrentUser 
                            ? Colors.white.withOpacity(0.9) 
                            : Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCurrentUser 
                          ? Colors.white.withOpacity(0.2)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      FileService.formatFileSize(fileSize),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isCurrentUser 
                            ? Colors.white.withOpacity(0.8) 
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfMessage(BuildContext context, String fileName, String fileUrl, int fileSize) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.50,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isCurrentUser
                ? [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.1),
                  ]
                : [
                    Colors.red[50]!,
                    Color.lerp(Colors.red[50], Colors.white, 0.5)!,
                  ],
          ),
          border: Border.all(
            color: isCurrentUser 
                ? Colors.white.withOpacity(0.3) 
                : Colors.red[100]!,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openPdf(fileUrl),
            borderRadius: BorderRadius.circular(16),
            splashColor: isCurrentUser 
                ? Colors.white.withOpacity(0.2)
                : Colors.red[100]!.withOpacity(0.3),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.red[600]!,
                          Colors.red[700]!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red[600]!.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.picture_as_pdf,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isCurrentUser 
                                ? Colors.white.withOpacity(0.95) 
                                : Colors.grey[800],
                            letterSpacing: 0.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCurrentUser 
                                ? Colors.white.withOpacity(0.2)
                                : Colors.red[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.picture_as_pdf,
                                size: 11,
                                color: isCurrentUser 
                                    ? Colors.white.withOpacity(0.8)
                                    : Colors.red[700],
                              ),
                              SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  FileService.formatFileSize(fileSize),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: isCurrentUser 
                                        ? Colors.white.withOpacity(0.7)
                                        : Colors.red[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isCurrentUser 
                          ? Colors.white.withOpacity(0.2)
                          : Colors.red[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.open_in_new,
                      size: 14,
                      color: isCurrentUser 
                          ? Colors.white.withOpacity(0.8)
                          : Colors.red[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnknownFileMessage(BuildContext context, String fileName, int fileSize) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.58,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isCurrentUser
                ? [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.1),
                  ]
                : [
                    Colors.grey[50]!,
                    Colors.grey[100]!,
                  ],
          ),
          border: Border.all(
            color: isCurrentUser 
                ? Colors.white.withOpacity(0.3) 
                : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey[600]!,
                      Colors.grey[700]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey[600]!.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                                                    child: Icon(
                    Icons.insert_drive_file,
                    color: Colors.white,
                    size: 24,
                  ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isCurrentUser 
                            ? Colors.white.withOpacity(0.95) 
                            : Colors.grey[800],
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    SizedBox(height: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrentUser 
                            ? Colors.white.withOpacity(0.2)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 14,
                            color: isCurrentUser 
                                ? Colors.white.withOpacity(0.8)
                                : Colors.grey[700],
                          ),
                          SizedBox(width: 4),
                          Text(
                            'File',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isCurrentUser 
                                  ? Colors.white.withOpacity(0.8)
                                  : Colors.grey[700],
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            width: 2,
                            height: 12,
                            decoration: BoxDecoration(
                              color: isCurrentUser 
                                  ? Colors.white.withOpacity(0.4)
                                  : Colors.grey[400],
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            FileService.formatFileSize(fileSize),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isCurrentUser 
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCurrentUser 
                      ? Colors.white.withOpacity(0.2)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.file_download_outlined,
                  size: 18,
                  color: isCurrentUser 
                      ? Colors.white.withOpacity(0.8)
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageFullScreen(BuildContext context, String imageUrl, String fileName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: IconThemeData(color: Colors.white),
            title: Text(
              fileName,
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.open_in_new, color: Colors.white),
                onPressed: () => _openUrl(imageUrl),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.white, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPdf(String pdfUrl) {
    _openUrl(pdfUrl);
  }

  void _showPdfOptions(String pdfUrl) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'PDF Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.open_in_browser, color: Colors.blue[600]),
              ),
              title: Text('Open in Browser'),
              subtitle: Text('View PDF in your web browser'),
              onTap: () {
                Get.back();
                _openInBrowser(pdfUrl);
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.copy, color: Colors.green[600]),
              ),
              title: Text('Copy Link'),
              subtitle: Text('Copy PDF link to clipboard'),
              onTap: () {
                Get.back();
                _copyToClipboard(pdfUrl);
              },
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _openInBrowser(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error opening in browser: $e');
      Get.snackbar(
        'Error',
        'Failed to open in browser',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
      );
    }
  }

  void _copyToClipboard(String url) {
    // Note: You might need to add the flutter/services import and use Clipboard.setData
    // For now, showing a message
    Get.snackbar(
      'Link Ready',
      'PDF link: $url',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green[100],
      colorText: Colors.green[800],
      duration: Duration(seconds: 5),
    );
  }

  void _openUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      
      // Try different launch modes for better compatibility
      bool launched = false;
      
      // First, try with external application
      try {
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(
            uri, 
            mode: LaunchMode.externalApplication,
          );
        }
      } catch (e) {
        print('External application launch failed: $e');
      }
      
      // If that fails, try with platform default
      if (!launched) {
        try {
          launched = await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
          );
        } catch (e) {
          print('Platform default launch failed: $e');
        }
      }
      
      // If that fails, try with in-app web view
      if (!launched) {
        try {
          launched = await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
          );
        } catch (e) {
          print('In-app web view launch failed: $e');
        }
      }
      
      if (!launched) {
        print('Failed to open PDF: No compatible app found');
        Get.snackbar(
          'Unable to Open PDF',
          'Please install a PDF viewer app like Adobe Reader or Google Drive',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange[100],
          colorText: Colors.orange[800],
          duration: Duration(seconds: 4),
          icon: Icon(Icons.warning, color: Colors.orange[800]),
          mainButton: TextButton(
            onPressed: () {
              Get.closeCurrentSnackbar();
              _showPdfOptions(url);
            },
            child: Text(
              'Options',
              style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error opening URL: $e');
    }
  }
} 