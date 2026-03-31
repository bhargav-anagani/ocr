import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';
import 'api_service.dart';

class OcrResultModel {
  final String id;
  final String filename;
  final String fileType;
  final String extractedText;
  final double confidence;
  final int wordCount;
  final int pageCount;
  final DateTime createdAt;

  const OcrResultModel({
    required this.id,
    required this.filename,
    required this.fileType,
    required this.extractedText,
    required this.confidence,
    required this.wordCount,
    required this.pageCount,
    required this.createdAt,
  });

  factory OcrResultModel.fromJson(Map<String, dynamic> json) => OcrResultModel(
        id: json['id'] as String,
        filename: json['filename'] as String,
        fileType: json['file_type'] as String,
        extractedText: json['extracted_text'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        wordCount: json['word_count'] as int,
        pageCount: json['page_count'] as int? ?? 1,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class OcrHistoryItem {
  final String id;
  final String filename;
  final String fileType;
  final int wordCount;
  final double confidence;
  final int pageCount;
  final DateTime createdAt;
  final String preview;

  const OcrHistoryItem({
    required this.id,
    required this.filename,
    required this.fileType,
    required this.wordCount,
    required this.confidence,
    required this.pageCount,
    required this.createdAt,
    required this.preview,
  });

  factory OcrHistoryItem.fromJson(Map<String, dynamic> json) => OcrHistoryItem(
        id: json['id'] as String,
        filename: json['filename'] as String,
        fileType: json['file_type'] as String,
        wordCount: json['word_count'] as int,
        confidence: (json['confidence'] as num).toDouble(),
        pageCount: json['page_count'] as int? ?? 1,
        createdAt: DateTime.parse(json['created_at'] as String),
        preview: json['preview'] as String,
      );
}

class OcrStats {
  final int totalFiles;
  final int totalWords;
  final double avgConfidence;
  final int totalPages;

  const OcrStats({
    required this.totalFiles,
    required this.totalWords,
    required this.avgConfidence,
    required this.totalPages,
  });

  factory OcrStats.fromJson(Map<String, dynamic> json) => OcrStats(
        totalFiles: json['total_files'] as int,
        totalWords: json['total_words'] as int,
        avgConfidence: (json['avg_confidence'] as num).toDouble(),
        totalPages: json['total_pages'] as int,
      );
}

class OcrService {
  static final OcrService instance = OcrService._();
  OcrService._();

  final _api = ApiService.instance;

  Future<OcrResultModel> uploadFile({
    required List<int> fileBytes,
    required String filename,
    void Function(int, int)? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: filename,
      ),
    });

    final response = await _api.dio.post(
      AppConstants.ocrUploadEndpoint,
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
        receiveTimeout: const Duration(seconds: 120),
      ),
    );

    return OcrResultModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getHistory({int page = 1, int perPage = 10}) async {
    final response = await _api.dio.get(
      AppConstants.ocrHistoryEndpoint,
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final data = response.data as Map<String, dynamic>;
    return {
      'items': (data['items'] as List)
          .map((e) => OcrHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      'total': data['total'],
      'total_pages': data['total_pages'],
    };
  }

  Future<OcrResultModel> getResult(String id) async {
    final response = await _api.dio.get('/api/ocr/$id');
    return OcrResultModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<OcrStats> getStats() async {
    final response = await _api.dio.get(AppConstants.ocrStatsEndpoint);
    return OcrStats.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteResult(String id) async {
    await _api.dio.delete('/api/ocr/$id');
  }

  String downloadUrl(String id) =>
      '${AppConstants.baseUrl}/api/ocr/download/$id';
}
