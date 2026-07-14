class OfflineTempleService {
  Future<void> initialize() async {
    // Initialize the service
  }

  Future<List<Map<String, dynamic>>> searchTemples(String query) async {
    // Mock search - return empty list for now
    return [];
  }

  Future<SyncResult> syncTemples() async {
    // Mock sync
    return SyncResult(success: true, message: 'Sync completed');
  }

  Future<DeleteResult> deleteTemple({
    required String templeId,
    Function(double)? onProgress,
    Function(String)? onStatusUpdate,
  }) async {
    // Mock delete
    return DeleteResult(
      isSuccess: true,
      message: 'Temple deleted successfully',
    );
  }
}

class SyncResult {
  final bool success;
  final String message;

  SyncResult({required this.success, required this.message});
}

class DeleteResult {
  final bool isSuccess;
  final String? error;
  final String message;

  DeleteResult({required this.isSuccess, this.error, required this.message});
}
