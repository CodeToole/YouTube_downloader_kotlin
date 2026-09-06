import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../controllers/media_vault_controller.dart';
import '../models/batch_download_item.dart';

class BatchDownloaderScreen extends StatefulWidget {
  final VoidCallback onNavigateToLibrary;

  const BatchDownloaderScreen({super.key, required this.onNavigateToLibrary});

  @override
  State<BatchDownloaderScreen> createState() => _BatchDownloaderScreenState();
}

class _BatchDownloaderScreenState extends State<BatchDownloaderScreen> {
  final TextEditingController _batchInputController = TextEditingController();

  @override
  void dispose() {
    _batchInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MediaVaultController>();
    final items = controller.batchItems;
    final selectedCount = items.where((e) => e.isSelected).length;
    final completedCount = items.where((e) => e.status == BatchItemStatus.completed).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Downloader', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (items.isNotEmpty) ...[
            IconButton(
              tooltip: 'Clear completed',
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: () => controller.clearCompletedBatchItems(),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Input section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Multi-URL Batch Download',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Paste multiple YouTube or media links (one per line)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _batchInputController,
                      maxLines: 3,
                      onChanged: (val) => controller.setBatchInput(val),
                      decoration: InputDecoration(
                        hintText: 'https://www.youtube.com/watch?v=...\nhttps://youtu.be/...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            controller.loadSampleBatch();
                            _batchInputController.text = controller.batchInputText;
                          },
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('Load Sample Batch'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: controller.isBatchParsing
                              ? null
                              : () {
                                  controller.parseBatchUrls();
                                  _batchInputController.clear();
                                },
                          icon: controller.isBatchParsing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.playlist_add, size: 18),
                          label: const Text('Add to Queue'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Control Bar
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  Checkbox(
                    value: selectedCount == items.length && items.isNotEmpty,
                    tristate: selectedCount > 0 && selectedCount < items.length,
                    onChanged: (val) {
                      controller.selectAllBatchItems(val == true);
                    },
                  ),
                  Text(
                    'Selected ($selectedCount/${items.length}) • Done: $completedCount',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const Spacer(),
                  if (controller.isBatchDownloading)
                    FilledButton.tonalIcon(
                      onPressed: () => controller.pauseBatchDownload(),
                      icon: const Icon(Icons.pause, size: 18),
                      label: const Text('Pause All'),
                    )
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD0BCFF),
                        foregroundColor: const Color(0xFF381E72),
                      ),
                      onPressed: selectedCount == 0 ? null : () => controller.startBatchDownload(),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download Selected'),
                    ),
                ],
              ),
            ),

          // Items List
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.queue_play_next, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'No batch items in queue',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Paste URLs above or tap "Load Sample Batch"',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildBatchItemCard(context, controller, item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchItemCard(
    BuildContext context,
    MediaVaultController controller,
    BatchDownloadItem item,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: item.isSelected,
                  onChanged: (_) => controller.toggleItemSelection(item.id),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 70,
                    height: 50,
                    color: Colors.black26,
                    child: item.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                const Icon(Icons.movie, size: 24, color: Colors.grey),
                          )
                        : const Icon(Icons.movie, size: 24, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.author,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      _buildStatusBadge(item),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  onPressed: () => controller.removeBatchItem(item.id),
                ),
              ],
            ),
            if (item.status == BatchItemStatus.downloading) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.progress > 0 ? item.progress : null,
                  minHeight: 5,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFD0BCFF)),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.speedFormatted,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    '${(item.progress * 100).toInt()}% • ETA ${item.etaSeconds}s',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BatchDownloadItem item) {
    Color bg;
    Color fg;
    IconData icon;

    switch (item.status) {
      case BatchItemStatus.queued:
        bg = Colors.white12;
        fg = Colors.white70;
        icon = Icons.hourglass_empty;
        break;
      case BatchItemStatus.extracting:
        bg = Colors.blue.withValues(alpha: 0.2);
        fg = Colors.lightBlueAccent;
        icon = Icons.sync;
        break;
      case BatchItemStatus.ready:
        bg = Colors.purple.withValues(alpha: 0.2);
        fg = const Color(0xFFD0BCFF);
        icon = Icons.check;
        break;
      case BatchItemStatus.downloading:
        bg = Colors.amber.withValues(alpha: 0.2);
        fg = Colors.amberAccent;
        icon = Icons.downloading;
        break;
      case BatchItemStatus.paused:
        bg = Colors.orange.withValues(alpha: 0.2);
        fg = Colors.orangeAccent;
        icon = Icons.pause;
        break;
      case BatchItemStatus.completed:
        bg = Colors.green.withValues(alpha: 0.2);
        fg = Colors.greenAccent;
        icon = Icons.check_circle;
        break;
      case BatchItemStatus.failed:
        bg = Colors.red.withValues(alpha: 0.2);
        fg = Colors.redAccent;
        icon = Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            item.status.displayName,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }
}
