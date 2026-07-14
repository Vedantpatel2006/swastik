import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'background_processor.dart';

/// Background task for uploading files to Firebase Storage
class FileUploadTask extends BackgroundTask {
  final File file;
  final String uploadPath;
  final Map<String, String>? metadata;
  final Function(String downloadUrl)? onSuccess;
  final Function(dynamic error)? onFailure;

  FileUploadTask({
    required super.id,
    required this.file,
    required this.uploadPath,
    this.metadata,
    this.onSuccess,
    this.onFailure,
  }) : super(name: 'Uploading ${file.path.split('/').last}');

  @override
  Future<void> execute() async {
    try {
      final backgroundProcessor = BackgroundProcessor();

      // Initialize progress
      backgroundProcessor.updateTaskProgress(id, 0.0);

      // Create storage reference
      final ref = FirebaseStorage.instance.ref().child(uploadPath);

      // Set metadata if provided
      SettableMetadata? settableMetadata;
      if (metadata != null) {
        settableMetadata = SettableMetadata(
          customMetadata: metadata,
          contentType: _getContentType(file.path),
        );
      }

      // Start upload
      final uploadTask = settableMetadata != null
          ? ref.putFile(file, settableMetadata)
          : ref.putFile(file);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          backgroundProcessor.updateTaskProgress(id, progress);
        }
      });

      // Wait for completion
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Complete
      backgroundProcessor.updateTaskProgress(id, 1.0);
      onSuccess?.call(downloadUrl);
    } catch (error) {
      onFailure?.call(error);
      rethrow;
    }
  }

  @override
  void onError(dynamic error) {
    super.onError(error);
    onFailure?.call(error);
  }

  String? _getContentType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      default:
        return null;
    }
  }
}

/// Background task for batch file uploads
class BatchFileUploadTask extends BackgroundTask {
  final List<File> files;
  final String basePath;
  final Map<String, String>? metadata;
  final Function(List<String> downloadUrls)? onSuccess;
  final Function(dynamic error)? onFailure;

  BatchFileUploadTask({
    required super.id,
    required this.files,
    required this.basePath,
    this.metadata,
    this.onSuccess,
    this.onFailure,
  }) : super(name: 'Uploading ${files.length} files');

  @override
  Future<void> execute() async {
    try {
      final backgroundProcessor = BackgroundProcessor();
      final List<String> downloadUrls = [];

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final fileName = file.path.split('/').last;
        final uploadPath = '$basePath/$fileName';

        // Update progress based on current file
        final baseProgress = i / files.length;
        backgroundProcessor.updateTaskProgress(id, baseProgress);

        // Upload file
        final ref = FirebaseStorage.instance.ref().child(uploadPath);

        SettableMetadata? settableMetadata;
        if (metadata != null) {
          settableMetadata = SettableMetadata(
            customMetadata: metadata,
            contentType: _getContentType(file.path),
          );
        }

        final uploadTask = settableMetadata != null
            ? ref.putFile(file, settableMetadata)
            : ref.putFile(file);

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        downloadUrls.add(downloadUrl);

        // Update progress for completed file
        backgroundProcessor.updateTaskProgress(id, (i + 1) / files.length);
      }

      onSuccess?.call(downloadUrls);
    } catch (error) {
      onFailure?.call(error);
      rethrow;
    }
  }

  @override
  void onError(dynamic error) {
    super.onError(error);
    onFailure?.call(error);
  }

  String? _getContentType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      default:
        return null;
    }
  }
}
