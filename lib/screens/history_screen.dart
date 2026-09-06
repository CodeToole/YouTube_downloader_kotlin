import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controllers/media_vault_controller.dart';
import '../models/download_history_record.dart';

class HistoryScreen extends StatelessWidget {
  final VoidCallback onNavigateToDownloader;

  const HistoryScreen({super.key, required this.onNavigateToDownloader});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MediaVaultController>();
    final historyList = controller.historyList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download History', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (historyList.isNotEmpty)
            IconButton(
              tooltip: 'Clear History',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClearHistory(context, controller),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: controller.historyStatusFilter == null,
                  onSelected: (val) {
                    if (val) controller.setHistoryFilter(null);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.check_circle, size: 16, color: Colors.greenAccent),
                  label: const Text('Completed'),
                  selected:
                      controller.historyStatusFilter == DownloadHistoryStatus.completed,
                  onSelected: (val) {
                    controller.setHistoryFilter(
                        val ? DownloadHistoryStatus.completed : null);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
                  label: const Text('Failed'),
                  selected:
                      controller.historyStatusFilter == DownloadHistoryStatus.failed,
                  onSelected: (val) {
                    controller.setHistoryFilter(
                        val ? DownloadHistoryStatus.failed : null);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.pause_circle_outline,
                      size: 16, color: Colors.amberAccent),
                  label: const Text('Interrupted'),
                  selected:
                      controller.historyStatusFilter == DownloadHistoryStatus.interrupted,
                  onSelected: (val) {
                    controller.setHistoryFilter(
                        val ? DownloadHistoryStatus.interrupted : null);
                  },
                ),
              ],
            ),
          ),

          // History List
          Expanded(
            child: historyList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'No history records',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Downloads activity will be recorded here',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: historyList.length,
                    itemBuilder: (context, index) {
                      final item = historyList[index];
                      return _buildHistoryCard(context, controller, item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    MediaVaultController controller,
    DownloadHistoryRecord record,
  ) {
    final dateStr = DateFormat('MMM d, h:mm a')
        .format(DateTime.fromMillisecondsSinceEpoch(record.timestamp));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Icon Circle
            CircleAvatar(
              backgroundColor: _getStatusBg(record.status),
              child: Icon(_getStatusIcon(record.status), color: _getStatusFg(record.status), size: 20),
            ),
            const SizedBox(width: 12),

            // Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.author,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusBg(record.status),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          record.status.nameUpper,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getStatusFg(record.status),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${record.format} • ${record.quality}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          record.formattedSize,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (record.errorMessage != null && record.errorMessage!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      record.errorMessage!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            Column(
              children: [
                if (record.status != DownloadHistoryStatus.completed)
                  IconButton(
                    icon: const Icon(Icons.replay, size: 20),
                    tooltip: 'Retry Download',
                    onPressed: () {
                      controller.retryDownloadFromHistory(record);
                      onNavigateToDownloader();
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                  tooltip: 'Delete Log',
                  onPressed: () {
                    if (record.id != null) {
                      controller.deleteHistoryRecord(record.id!);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusBg(DownloadHistoryStatus status) {
    switch (status) {
      case DownloadHistoryStatus.completed:
        return Colors.green.withValues(alpha: 0.2);
      case DownloadHistoryStatus.failed:
        return Colors.red.withValues(alpha: 0.2);
      case DownloadHistoryStatus.interrupted:
        return Colors.amber.withValues(alpha: 0.2);
      case DownloadHistoryStatus.downloading:
        return Colors.blue.withValues(alpha: 0.2);
    }
  }

  Color _getStatusFg(DownloadHistoryStatus status) {
    switch (status) {
      case DownloadHistoryStatus.completed:
        return Colors.greenAccent;
      case DownloadHistoryStatus.failed:
        return Colors.redAccent;
      case DownloadHistoryStatus.interrupted:
        return Colors.amberAccent;
      case DownloadHistoryStatus.downloading:
        return Colors.lightBlueAccent;
    }
  }

  IconData _getStatusIcon(DownloadHistoryStatus status) {
    switch (status) {
      case DownloadHistoryStatus.completed:
        return Icons.check;
      case DownloadHistoryStatus.failed:
        return Icons.close;
      case DownloadHistoryStatus.interrupted:
        return Icons.pause;
      case DownloadHistoryStatus.downloading:
        return Icons.downloading;
    }
  }

  void _confirmClearHistory(BuildContext context, MediaVaultController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text('This will delete all download logs. Downloaded files remain safe in your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              controller.clearAllHistory();
              Navigator.pop(ctx);
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
