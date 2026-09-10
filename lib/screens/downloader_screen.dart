import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../controllers/media_vault_controller.dart';
import '../services/media_downloader.dart';
import '../widgets/media_player_modal.dart';

class DownloaderScreen extends StatefulWidget {
  final VoidCallback onNavigateToLibrary;

  const DownloaderScreen({super.key, required this.onNavigateToLibrary});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();

  final List<Map<String, String>> _sampleLinks = [
    {
      'title': 'Big Buck Bunny (MP4)',
      'url':
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    },
    {
      'title': 'Rick Astley (YouTube)',
      'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    },
    {
      'title': 'Elephants Dream (Direct)',
      'url':
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    },
  ];

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// Shows a native Save-As dialog on desktop platforms so the user can pick
  /// exactly where the downloaded file lands. On mobile / web the download
  /// starts immediately and the file goes to the AppData/MediaVault folder.
  Future<void> _startDownloadWithSaveDialog(
      BuildContext context, MediaVaultController controller) async {
    final media = controller.extractedMedia;
    if (media == null) return;

    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    if (!isDesktop) {
      // Mobile / web – just download directly
      controller.startDownload();
      return;
    }

    final isVideo = controller.selectedFormat.toUpperCase() == 'MP4';
    final ext = isVideo ? 'mp4' : 'mp3';
    final cleanTitle =
        media.title.replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_').trim();
    final suggestedName =
        '${cleanTitle.length > 40 ? cleanTitle.substring(0, 40) : cleanTitle}.$ext';

    final typeGroup = XTypeGroup(
      label: isVideo ? 'Video' : 'Audio',
      extensions: [ext],
    );

    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: [typeGroup],
    );

    if (location == null) {
      // User cancelled the dialog – do nothing
      return;
    }

    controller.startDownload(savePath: location.path);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MediaVaultController>();
    final isAudioFormat = controller.selectedFormat.toUpperCase() == 'MP3';
    final qualityOptions = isAudioFormat
        ? const ['Best', '320 kbps', '256 kbps', '192 kbps', '128 kbps']
        : const ['Best', '1080p', '720p', '480p', '360p'];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.play_circle_fill, color: Color(0xFFFF0000), size: 28),
            SizedBox(width: 10),
            Text(
              'Media Vault',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'View Library',
            icon: const Icon(Icons.video_library_outlined),
            onPressed: widget.onNavigateToLibrary,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // URL Input Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Download Video or Audio',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Paste any YouTube URL, Shorts, or direct media link',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlController,
                    onChanged: (val) => controller.setUrl(val),
                    decoration: InputDecoration(
                      hintText: 'https://www.youtube.com/watch?v=...',
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_urlController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _urlController.clear();
                                controller.clearUrl();
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.content_paste, size: 20),
                            tooltip: 'Paste from clipboard',
                            onPressed: () async {
                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                              if (data?.text != null) {
                                _urlController.text = data!.text!;
                                controller.setUrl(data.text!);
                              }
                            },
                          ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Sample Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Quick test:',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ..._sampleLinks.map((sample) {
                        return ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(sample['title']!, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            _urlController.text = sample['url']!;
                            controller.setUrl(sample['url']!);
                            controller.extractMedia(sample['url']!);
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Extract Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: controller.isExtracting
                          ? null
                          : () {
                              if (_urlController.text.isNotEmpty) {
                                controller.extractMedia(_urlController.text);
                              }
                            },
                      icon: controller.isExtracting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(
                        controller.isExtracting ? 'Analyzing Stream...' : 'Extract Media Info',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Extracted Media Preview & Format Card
          if (controller.extractedMedia != null) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Thumbnail and Title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 110,
                            height: 75,
                            color: Colors.black26,
                            child: controller.extractedMedia!.thumbnailUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: controller.extractedMedia!.thumbnailUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) =>
                                        const Icon(Icons.broken_image, color: Colors.grey),
                                  )
                                : const Icon(Icons.movie, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.extractedMedia!.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                controller.extractedMedia!.author,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      controller.extractedMedia!.durationFormatted,
                                      style: const TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: controller.extractedMedia!.isYouTube
                                          ? const Color(0xFFFF0000)
                                              .withValues(alpha: 0.2)
                                          : const Color(0xFF6750A4)
                                              .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      controller.extractedMedia!.sourceName ??
                                          (controller.extractedMedia!.isYouTube
                                              ? 'YouTube'
                                              : 'Direct Stream'),
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: controller.extractedMedia!.isYouTube
                                              ? const Color(0xFFFF4D4D)
                                              : const Color(0xFFD0BCFF)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // Format Selection (Video MP4 vs Audio MP3)
                    const Text(
                      'Select Format',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.videocam, size: 18),
                                  SizedBox(width: 6),
                                  Text('Video (MP4)'),
                                ],
                              ),
                            ),
                            selected: controller.selectedFormat == 'MP4',
                            onSelected: (val) {
                              if (val) controller.setFormat('MP4');
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.audiotrack, size: 18),
                                  SizedBox(width: 6),
                                  Text('Audio (MP3)'),
                                ],
                              ),
                            ),
                            selected: controller.selectedFormat == 'MP3',
                            onSelected: (val) {
                              if (val) controller.setFormat('MP3');
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Quality Selection

                    Text(
                      isAudioFormat ? 'Select Audio Quality (Bitrate)' : 'Select Video Quality',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: qualityOptions.map((q) {
                        return ChoiceChip(
                          label: Text(q),
                          selected: controller.selectedQuality == q,
                          onSelected: (val) {
                            if (val) controller.setQuality(q);
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Target Folder Selection
                    if (controller.folders.isNotEmpty) ...[
                      const Text(
                        'Save to Folder',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        initialValue: controller.selectedFolderId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Uncategorized (No Folder)'),
                          ),
                          ...controller.folders.map(
                            (f) => DropdownMenuItem<int?>(
                              value: f.id,
                              child: Row(
                                children: [
                                  Icon(Icons.folder, color: Color(f.color), size: 18),
                                  const SizedBox(width: 8),
                                  Text(f.name),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: (fId) {
                          if (fId == null) {
                            controller.setTargetFolder(null);
                          } else {
                            final f = controller.folders.firstWhere((x) => x.id == fId);
                            controller.setTargetFolder(f);
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Download / Stop Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: (controller.downloadState is DownloadStateQueued ||
                              controller.downloadState is DownloadStateProgress)
                          ? FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFBA1A1A),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => controller.cancelDownload(),
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: const Text(
                                'Stop / Cancel Download',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            )
                          : FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: isAudioFormat
                                    ? const Color(0xFF6750A4)
                                    : const Color(0xFFD0BCFF),
                                foregroundColor: isAudioFormat
                                    ? Colors.white
                                    : const Color(0xFF381E72),
                              ),
                              onPressed: () => _startDownloadWithSaveDialog(context, controller),
                              icon: Icon(isAudioFormat ? Icons.music_note : Icons.download),
                              label: Text(
                                isAudioFormat ? 'Download MP3 (Audio)' : 'Download MP4 (Video)',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Active Download Status Card
          _buildDownloadStateWidget(context, controller),
        ],
      ),
    );
  }

  Widget _buildDownloadStateWidget(BuildContext context, MediaVaultController controller) {
    final state = controller.downloadState;

    if (state is DownloadStateIdle) {
      return const SizedBox.shrink();
    }

    if (state is DownloadStateQueued) {
      final isAudioState = state.format.toUpperCase() == 'MP3';
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Color(0xFFD0BCFF)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAudioState
                                ? const Color(0xFF6750A4).withValues(alpha: 0.3)
                                : const Color(0xFFFF0000).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isAudioState ? 'MP3' : 'MP4',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isAudioState
                                  ? const Color(0xFFD0BCFF)
                                  : const Color(0xFFFF8A80),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAudioState
                              ? 'Connecting to Audio Stream (${state.quality})...'
                              : 'Connecting to Video Stream (${state.quality})...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.mediaInfo.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => controller.cancelDownload(),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is DownloadStateProgress) {
      final isAudioProgress = state.format.toUpperCase() == 'MP3';
      final percentInt = (state.progress * 100).toInt();
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isAudioProgress
                          ? const Color(0xFF6750A4).withValues(alpha: 0.3)
                          : const Color(0xFFFF0000).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isAudioProgress ? 'MP3' : 'MP4',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isAudioProgress
                            ? const Color(0xFFD0BCFF)
                            : const Color(0xFFFF8A80),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.mediaInfo.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$percentInt%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFFD0BCFF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: state.progress,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFD0BCFF)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Speed: ${state.speedFormatted}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    'ETA: ${state.etaSeconds}s remaining',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => controller.pauseDownload(),
                    icon: const Icon(Icons.pause, size: 18),
                    label: const Text('Pause'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => controller.cancelDownload(),
                    icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                    label: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (state is DownloadStateInterrupted) {
      return Card(
        color: Colors.amber.shade900.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pause_circle, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Text(
                    'Download Paused',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                state.mediaInfo.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: () => controller.resumeDownload(),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Resume Download'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => controller.cancelDownload(),
                    child: const Text('Discard', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (state is DownloadStateSuccess) {
      final saved = state.savedMedia;
      return Card(
        color: Colors.green.shade900.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.greenAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'Download Complete!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                saved.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Saved as ${saved.format} • ${saved.formattedSize}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      controller.resetDownloadState();
                      widget.onNavigateToLibrary();
                    },
                    icon: const Icon(Icons.video_library_outlined, size: 18),
                    label: const Text('Open Library'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => MediaPlayerModal(
                          media: saved,
                          controller: controller,
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Play Now'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (state is DownloadStateError) {
      return Card(
        color: Colors.red.shade900.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'Download Failed',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                state.message,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => controller.startDownload(),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
