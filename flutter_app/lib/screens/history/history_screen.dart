import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/ocr_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ocrProvider.notifier).loadHistory();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ocrState = ref.watch(ocrProvider);

    final filtered = ocrState.historyItems
        .where((h) => h.filename.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            h.preview.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search files...',
                hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(context, ocrState, filtered),
    );
  }

  Widget _buildBody(BuildContext context, OcrState ocrState, List filtered) {
    if (ocrState.historyLoading && ocrState.historyItems.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: AppTheme.darkCard,
          highlightColor: AppTheme.darkBorder,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, color: AppTheme.textSecondary, size: 56),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No files in history' : 'No results for "$_searchQuery"',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () => ref.read(ocrProvider.notifier).loadHistory(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index] as dynamic;
          return _HistoryCard(item: item, index: index)
              .animate()
              .fadeIn(delay: Duration(milliseconds: index * 50))
              .slideX(begin: 0.05, end: 0);
        },
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  final dynamic item;
  final int index;
  const _HistoryCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isImage = item.fileType != 'PDF';
    final icon = isImage ? Icons.image_outlined : Icons.picture_as_pdf_rounded;
    final color = isImage ? AppTheme.secondary : AppTheme.accent;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: AppTheme.accent),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.darkCard,
            title: const Text('Delete?', style: TextStyle(color: Colors.white)),
            content: Text('Remove "${item.filename}" from history?',
                style: TextStyle(color: AppTheme.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete', style: TextStyle(color: AppTheme.accent))),
            ],
          ),
        );
      },
      onDismissed: (_) => ref.read(ocrProvider.notifier).deleteResult(item.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(item.filename,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3),
              Text(item.preview,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Text('${item.wordCount} words',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                const SizedBox(width: 8),
                Text('•',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                const SizedBox(width: 8),
                Text(DateFormat('MMM d, yyyy').format(item.createdAt),
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              ]),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _confidenceColor(item.confidence).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${item.confidence.toInt()}%',
                style: TextStyle(
                    color: _confidenceColor(item.confidence),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          onTap: () => context.push('/result/${item.id}'),
        ),
      ),
    );
  }

  Color _confidenceColor(double c) {
    if (c >= 80) return AppTheme.secondary;
    if (c >= 60) return AppTheme.warning;
    return AppTheme.accent;
  }
}
