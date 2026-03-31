import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/ocr_provider.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  String? _selectedFileName;
  List<int>? _selectedFileBytes;
  bool _isDragging = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'tiff', 'webp', 'pdf'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _selectedFileName = file.name;
        _selectedFileBytes = file.bytes?.toList();
      });
    }
  }

  Future<void> _processFile() async {
    if (_selectedFileBytes == null || _selectedFileName == null) return;

    await ref.read(ocrProvider.notifier).uploadFile(
          fileBytes: _selectedFileBytes!,
          filename: _selectedFileName!,
        );

    final state = ref.read(ocrProvider);
    if (state.status == OcrStatus.success && state.result != null) {
      if (mounted) {
        context.push('/result/${state.result!.id}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocrState = ref.watch(ocrProvider);
    final isUploading = ocrState.status == OcrStatus.uploading;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Upload & Process'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drop zone
              GestureDetector(
                onTap: isUploading ? null : _pickFile,
                child: AnimatedContainer(
                  duration: AppConstants.shortAnim,
                  height: 200,
                  decoration: BoxDecoration(
                    color: _isDragging
                        ? AppTheme.primary.withOpacity(0.12)
                        : AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isDragging
                          ? AppTheme.primary
                          : (_selectedFileName != null
                              ? AppTheme.secondary
                              : AppTheme.darkBorder),
                      width: _isDragging ? 2 : 1.5,
                      style: _selectedFileName != null
                          ? BorderStyle.solid
                          : BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_selectedFileName == null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cloud_upload_outlined,
                              color: AppTheme.primary, size: 40),
                        ),
                        const SizedBox(height: 16),
                        const Text('Tap to browse files',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('Supports JPG, PNG, BMP, TIFF, WEBP, PDF',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                      ] else ...[
                        Icon(
                          _selectedFileName!.toLowerCase().endsWith('.pdf')
                              ? Icons.picture_as_pdf_rounded
                              : Icons.image_rounded,
                          color: AppTheme.secondary,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(_selectedFileName!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text(
                          '${(_selectedFileBytes!.length / 1024).toStringAsFixed(1)} KB selected',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: isUploading ? null : _pickFile,
                          child: const Text('Change file',
                              style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                        ),
                      ],
                    ],
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 0.1, end: 0),

              const SizedBox(height: 20),

              // Supported formats
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.supportedFormats.map((fmt) {
                  return Chip(
                    label: Text(fmt,
                        style: const TextStyle(
                            color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    side: const BorderSide(color: AppTheme.primary, width: 0.5),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 28),

              // Upload progress
              if (isUploading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Processing OCR...',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        Text('${(ocrState.uploadProgress * 100).toInt()}%',
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearPercentIndicator(
                      lineHeight: 8,
                      percent: ocrState.uploadProgress.clamp(0.0, 1.0),
                      backgroundColor: AppTheme.darkCard,
                      progressColor: AppTheme.primary,
                      barRadius: const Radius.circular(4),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Preprocessing with OpenCV → Running Tesseract OCR...',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Error message
              if (ocrState.errorMessage != null && ocrState.status == OcrStatus.error) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(ocrState.errorMessage!,
                            style: const TextStyle(color: AppTheme.accent, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Process button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_selectedFileBytes == null || isUploading) ? null : _processFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    disabledBackgroundColor: AppTheme.darkCard,
                  ),
                  icon: isUploading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.auto_fix_high_rounded),
                  label: Text(
                    isUploading ? 'Processing...' : 'Extract Text',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ).animate().fadeIn(delay: 150.ms),

              const SizedBox(height: 40),

              // Tips section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.tips_and_updates_outlined, color: AppTheme.primary, size: 18),
                      SizedBox(width: 8),
                      Text('Tips for best results',
                          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 12),
                    ...[
                      '📸 Use well-lit, high-resolution images',
                      '📄 Ensure text is horizontal and clearly visible',
                      '🖨️ For documents, scan at 300 DPI or higher',
                      '📋 Avoid shadows or glare on the document',
                    ].map((tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(tip,
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                        )),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
        ),
      ),
    );
  }
}
