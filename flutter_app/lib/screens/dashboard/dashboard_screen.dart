import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ocr_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ocrProvider.notifier).loadStats();
      ref.read(ocrProvider.notifier).loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final ocrState = ref.watch(ocrProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            backgroundColor: AppTheme.darkSurface,
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, ${user?.name.split(' ').first ?? 'User'} 👋',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('OcrVision Dashboard',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stats cards
                _StatsSection(ocrState: ocrState).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 24),

                // Quick Actions
                Text('Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white, fontSize: 18)),
                const SizedBox(height: 12),
                _QuickActions().animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 28),

                // Recent History
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Files',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white, fontSize: 18)),
                    TextButton(
                      onPressed: () => context.push('/history'),
                      child: const Text('See all',
                          style: TextStyle(color: AppTheme.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _RecentHistory(ocrState: ocrState).animate().fadeIn(delay: 300.ms),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/upload'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_rounded),
        label: const Text('Upload File', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final OcrState ocrState;
  const _StatsSection({required this.ocrState});

  @override
  Widget build(BuildContext context) {
    final stats = ocrState.stats;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          label: 'Files Processed',
          value: stats?.totalFiles.toString() ?? '—',
          icon: Icons.insert_drive_file_outlined,
          gradient: AppTheme.primaryGradient,
        ),
        _StatCard(
          label: 'Words Extracted',
          value: stats != null
              ? _formatNum(stats.totalWords)
              : '—',
          icon: Icons.text_fields_rounded,
          gradient: AppTheme.successGradient,
        ),
        _StatCard(
          label: 'Avg Confidence',
          value: stats != null ? '${stats.avgConfidence.toStringAsFixed(1)}%' : '—',
          icon: Icons.insights_rounded,
          gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        _StatCard(
          label: 'Pages Scanned',
          value: stats?.totalPages.toString() ?? '—',
          icon: Icons.auto_stories_outlined,
          gradient: const LinearGradient(
              colors: [Color(0xFFB721FF), Color(0xFF21D4FD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
      ],
    );
  }

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Gradient gradient;

  const _StatCard({required this.label, required this.value, required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.upload_file_rounded,
            title: 'Upload Image',
            subtitle: 'JPG, PNG, BMP',
            color: AppTheme.primary,
            onTap: () => context.push('/upload'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.picture_as_pdf_rounded,
            title: 'Scan PDF',
            subtitle: 'Multi-page support',
            color: AppTheme.secondary,
            onTap: () => context.push('/upload'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.history_rounded,
            title: 'History',
            subtitle: 'View all files',
            color: const Color(0xFFFF6B6B),
            onTap: () => context.push('/history'),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _RecentHistory extends StatelessWidget {
  final OcrState ocrState;
  const _RecentHistory({required this.ocrState});

  @override
  Widget build(BuildContext context) {
    if (ocrState.historyLoading && ocrState.historyItems.isEmpty) {
      return Column(
        children: List.generate(
          3,
          (_) => Shimmer.fromColors(
            baseColor: AppTheme.darkCard,
            highlightColor: AppTheme.darkBorder,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 70,
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }

    if (ocrState.historyItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, color: AppTheme.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text('No files processed yet',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            Text('Upload an image or PDF to get started',
                style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.7), fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      children: ocrState.historyItems.take(5).map((item) {
        final icon = item.fileType == 'PDF' ? Icons.picture_as_pdf_rounded : Icons.image_outlined;
        final color = item.fileType == 'PDF' ? AppTheme.accent : AppTheme.secondary;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(item.filename,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
                '${item.wordCount} words • ${DateFormat('MMM d').format(item.createdAt)}',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
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
        );
      }).toList(),
    );
  }

  Color _confidenceColor(double c) {
    if (c >= 80) return AppTheme.secondary;
    if (c >= 60) return AppTheme.warning;
    return AppTheme.accent;
  }
}
