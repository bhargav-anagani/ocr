import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/ocr_provider.dart';
import '../../services/ocr_service.dart';

final _resultProvider = FutureProvider.family<OcrResultModel, String>((ref, id) {
  return OcrService.instance.getResult(id);
});

class ResultScreen extends ConsumerStatefulWidget {
  final String resultId;
  const ResultScreen({super.key, required this.resultId});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  late TextEditingController _textCtrl;
  bool _isEditing = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: _textCtrl.text));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _downloadTxt() async {
    final url = Uri.parse(OcrService.instance.downloadUrl(widget.resultId));
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultAsync = ref.watch(_resultProvider(widget.resultId));

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            ref.read(ocrProvider.notifier).resetUpload();
            context.pop();
          },
        ),
        title: const Text('OCR Result'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_outlined,
                color: _isEditing ? AppTheme.secondary : Colors.white),
            onPressed: () => setState(() => _isEditing = !_isEditing),
            tooltip: _isEditing ? 'Done editing' : 'Edit text',
          ),
          IconButton(
            icon: Icon(_copied ? Icons.check : Icons.copy_outlined,
                color: _copied ? AppTheme.secondary : Colors.white),
            onPressed: _copyText,
            tooltip: 'Copy text',
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            onPressed: _downloadTxt,
            tooltip: 'Download TXT',
          ),
        ],
      ),
      body: resultAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.accent, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load result', style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
        data: (result) {
          if (_textCtrl.text.isEmpty) {
            _textCtrl.text = result.extractedText;
          }
          return _ResultBody(
            result: result,
            textCtrl: _textCtrl,
            isEditing: _isEditing,
            onDownload: _downloadTxt,
            onCopy: _copyText,
            copied: _copied,
          );
        },
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  final OcrResultModel result;
  final TextEditingController textCtrl;
  final bool isEditing;
  final VoidCallback onDownload;
  final VoidCallback onCopy;
  final bool copied;

  const _ResultBody({
    required this.result,
    required this.textCtrl,
    required this.isEditing,
    required this.onDownload,
    required this.onCopy,
    required this.copied,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Metadata chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(icon: Icons.insert_drive_file_outlined,
                  label: result.fileType, color: AppTheme.primary),
              _MetaChip(icon: Icons.text_fields_rounded,
                  label: '${result.wordCount} words', color: AppTheme.secondary),
              _MetaChip(icon: Icons.insights_rounded,
                  label: '${result.confidence.toInt()}% confidence',
                  color: result.confidence >= 80
                      ? AppTheme.secondary
                      : result.confidence >= 60
                          ? AppTheme.warning
                          : AppTheme.accent),
              _MetaChip(icon: Icons.calendar_today_outlined,
                  label: DateFormat('MMM d, yyyy').format(result.createdAt),
                  color: AppTheme.textSecondary),
              if (result.pageCount > 1)
                _MetaChip(icon: Icons.auto_stories_outlined,
                    label: '${result.pageCount} pages', color: AppTheme.warning),
            ],
          ).animate().fadeIn(),
          const SizedBox(height: 20),

          // Text area
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEditing ? AppTheme.primary : AppTheme.darkBorder,
                width: isEditing ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBorder.withOpacity(0.5),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.article_outlined, color: AppTheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? 'Editing — changes are local only' : 'Extracted Text',
                        style: TextStyle(
                            color: isEditing ? AppTheme.warning : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      if (copied)
                        const Text('Copied!',
                            style: TextStyle(color: AppTheme.secondary, fontSize: 12)),
                    ],
                  ),
                ),

                // Text field
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: textCtrl,
                    maxLines: null,
                    readOnly: !isEditing,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.6),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: copied ? AppTheme.secondary : AppTheme.primary,
                    side: BorderSide(
                        color: copied ? AppTheme.secondary : AppTheme.primary),
                  ),
                  icon: Icon(copied ? Icons.check : Icons.copy_all_rounded, size: 18),
                  label: Text(copied ? 'Copied!' : 'Copy All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download TXT'),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 150.ms),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
