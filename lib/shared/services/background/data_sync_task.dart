import 'package:cloud_firestore/cloud_firestore.dart';
import 'background_processor.dart';

/// Background task for synchronizing data with Firestore
class DataSyncTask extends BackgroundTask {
  final String collection;
  final Map<String, dynamic> data;
  final String? documentId;
  final DataSyncOperation operation;
  final Function(String documentId)? onSuccess;
  final Function(dynamic error)? onFailure;

  DataSyncTask({
    required super.id,
    required this.collection,
    required this.data,
    this.documentId,
    required this.operation,
    this.onSuccess,
    this.onFailure,
  }) : super(name: '${operation.name} data in $collection');

  @override
  Future<void> execute() async {
    try {
      final backgroundProcessor = BackgroundProcessor();
      final firestore = FirebaseFirestore.instance;

      // Initialize progress
      backgroundProcessor.updateTaskProgress(id, 0.1);

      String resultDocumentId;

      switch (operation) {
        case DataSyncOperation.create:
          backgroundProcessor.updateTaskProgress(id, 0.3);
          final docRef = await firestore.collection(collection).add(data);
          resultDocumentId = docRef.id;
          break;

        case DataSyncOperation.update:
          if (documentId == null) {
            throw ArgumentError('Document ID is required for update operation');
          }
          backgroundProcessor.updateTaskProgress(id, 0.3);
          await firestore.collection(collection).doc(documentId).update(data);
          resultDocumentId = documentId!;
          break;

        case DataSyncOperation.upsert:
          if (documentId == null) {
            throw ArgumentError('Document ID is required for upsert operation');
          }
          backgroundProcessor.updateTaskProgress(id, 0.3);
          await firestore
              .collection(collection)
              .doc(documentId)
              .set(data, SetOptions(merge: true));
          resultDocumentId = documentId!;
          break;

        case DataSyncOperation.delete:
          if (documentId == null) {
            throw ArgumentError('Document ID is required for delete operation');
          }
          backgroundProcessor.updateTaskProgress(id, 0.3);
          await firestore.collection(collection).doc(documentId).delete();
          resultDocumentId = documentId!;
          break;
      }

      // Complete
      backgroundProcessor.updateTaskProgress(id, 1.0);
      onSuccess?.call(resultDocumentId);
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
}

/// Background task for batch data synchronization
class BatchDataSyncTask extends BackgroundTask {
  final String collection;
  final List<BatchDataOperation> operations;
  final Function(List<String> documentIds)? onSuccess;
  final Function(dynamic error)? onFailure;

  BatchDataSyncTask({
    required super.id,
    required this.collection,
    required this.operations,
    this.onSuccess,
    this.onFailure,
  }) : super(name: 'Batch sync ${operations.length} operations');

  @override
  Future<void> execute() async {
    try {
      final backgroundProcessor = BackgroundProcessor();
      final firestore = FirebaseFirestore.instance;
      final List<String> resultDocumentIds = [];

      for (int i = 0; i < operations.length; i++) {
        final operation = operations[i];

        // Update progress based on current operation
        final baseProgress = i / operations.length;
        backgroundProcessor.updateTaskProgress(id, baseProgress);

        String resultDocumentId;

        switch (operation.type) {
          case DataSyncOperation.create:
            final docRef = await firestore
                .collection(collection)
                .add(operation.data);
            resultDocumentId = docRef.id;
            break;

          case DataSyncOperation.update:
            if (operation.documentId == null) {
              throw ArgumentError(
                'Document ID is required for update operation at index $i',
              );
            }
            await firestore
                .collection(collection)
                .doc(operation.documentId)
                .update(operation.data);
            resultDocumentId = operation.documentId!;
            break;

          case DataSyncOperation.upsert:
            if (operation.documentId == null) {
              throw ArgumentError(
                'Document ID is required for upsert operation at index $i',
              );
            }
            await firestore
                .collection(collection)
                .doc(operation.documentId)
                .set(operation.data, SetOptions(merge: true));
            resultDocumentId = operation.documentId!;
            break;

          case DataSyncOperation.delete:
            if (operation.documentId == null) {
              throw ArgumentError(
                'Document ID is required for delete operation at index $i',
              );
            }
            await firestore
                .collection(collection)
                .doc(operation.documentId)
                .delete();
            resultDocumentId = operation.documentId!;
            break;
        }

        resultDocumentIds.add(resultDocumentId);

        // Update progress for completed operation
        backgroundProcessor.updateTaskProgress(id, (i + 1) / operations.length);
      }

      onSuccess?.call(resultDocumentIds);
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
}

/// Represents a single data operation in a batch
class BatchDataOperation {
  final DataSyncOperation type;
  final Map<String, dynamic> data;
  final String? documentId;

  BatchDataOperation({required this.type, required this.data, this.documentId});

  factory BatchDataOperation.create(Map<String, dynamic> data) {
    return BatchDataOperation(type: DataSyncOperation.create, data: data);
  }

  factory BatchDataOperation.update(
    String documentId,
    Map<String, dynamic> data,
  ) {
    return BatchDataOperation(
      type: DataSyncOperation.update,
      data: data,
      documentId: documentId,
    );
  }

  factory BatchDataOperation.upsert(
    String documentId,
    Map<String, dynamic> data,
  ) {
    return BatchDataOperation(
      type: DataSyncOperation.upsert,
      data: data,
      documentId: documentId,
    );
  }

  factory BatchDataOperation.delete(String documentId) {
    return BatchDataOperation(
      type: DataSyncOperation.delete,
      data: {},
      documentId: documentId,
    );
  }
}

/// Types of data synchronization operations
enum DataSyncOperation { create, update, upsert, delete }
