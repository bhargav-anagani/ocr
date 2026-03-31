import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ocr_service.dart';

enum OcrStatus { idle, uploading, success, error }

class OcrState {
  final OcrStatus status;
  final OcrResultModel? result;
  final String? errorMessage;
  final double uploadProgress;
  final List<OcrHistoryItem> historyItems;
  final int historyTotal;
  final int historyPage;
  final OcrStats? stats;
  final bool historyLoading;

  const OcrState({
    this.status = OcrStatus.idle,
    this.result,
    this.errorMessage,
    this.uploadProgress = 0,
    this.historyItems = const [],
    this.historyTotal = 0,
    this.historyPage = 1,
    this.stats,
    this.historyLoading = false,
  });

  OcrState copyWith({
    OcrStatus? status,
    OcrResultModel? result,
    String? errorMessage,
    double? uploadProgress,
    List<OcrHistoryItem>? historyItems,
    int? historyTotal,
    int? historyPage,
    OcrStats? stats,
    bool? historyLoading,
  }) =>
      OcrState(
        status: status ?? this.status,
        result: result ?? this.result,
        errorMessage: errorMessage,
        uploadProgress: uploadProgress ?? this.uploadProgress,
        historyItems: historyItems ?? this.historyItems,
        historyTotal: historyTotal ?? this.historyTotal,
        historyPage: historyPage ?? this.historyPage,
        stats: stats ?? this.stats,
        historyLoading: historyLoading ?? this.historyLoading,
      );
}

class OcrNotifier extends StateNotifier<OcrState> {
  OcrNotifier() : super(const OcrState());

  final _ocrService = OcrService.instance;

  Future<void> uploadFile({
    required List<int> fileBytes,
    required String filename,
  }) async {
    state = state.copyWith(
      status: OcrStatus.uploading,
      uploadProgress: 0,
      errorMessage: null,
    );
    try {
      final result = await _ocrService.uploadFile(
        fileBytes: fileBytes,
        filename: filename,
        onSendProgress: (sent, total) {
          if (total > 0) {
            state = state.copyWith(uploadProgress: sent / total);
          }
        },
      );
      state = state.copyWith(
        status: OcrStatus.success,
        result: result,
        uploadProgress: 1.0,
      );
      // Refresh stats and history
      await loadStats();
    } catch (e) {
      state = state.copyWith(
        status: OcrStatus.error,
        errorMessage: 'OCR processing failed: ${e.toString()}',
      );
    }
  }

  Future<void> loadHistory({int page = 1}) async {
    state = state.copyWith(historyLoading: true, errorMessage: null);
    try {
      final data = await _ocrService.getHistory(page: page);
      final items = data['items'] as List<OcrHistoryItem>;
      state = state.copyWith(
        historyItems: page == 1 ? items : [...state.historyItems, ...items],
        historyTotal: data['total'] as int,
        historyPage: page,
        historyLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        historyLoading: false,
        errorMessage: 'Failed to load history.',
      );
    }
  }

  Future<void> loadStats() async {
    try {
      final stats = await _ocrService.getStats();
      state = state.copyWith(stats: stats);
    } catch (_) {}
  }

  Future<void> deleteResult(String id) async {
    try {
      await _ocrService.deleteResult(id);
      state = state.copyWith(
        historyItems: state.historyItems.where((e) => e.id != id).toList(),
        historyTotal: state.historyTotal - 1,
      );
      await loadStats();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to delete.');
    }
  }

  void resetUpload() {
    state = state.copyWith(
      status: OcrStatus.idle,
      result: null,
      uploadProgress: 0,
      errorMessage: null,
    );
  }
}

final ocrProvider = StateNotifierProvider<OcrNotifier, OcrState>(
  (ref) => OcrNotifier(),
);
