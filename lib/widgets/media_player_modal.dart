import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/saved_media.dart';
import '../controllers/media_vault_controller.dart';

class MediaPlayerModal extends StatefulWidget {
  final SavedMedia media;
  final MediaVaultController controller;

  const MediaPlayerModal({
    super.key,
    required this.media,
    required this.controller,
  });

  @override
  State<MediaPlayerModal> createState() => _MediaPlayerModalState();
}

class _MediaPlayerModalState extends State<MediaPlayerModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _equalizerAnimController;

  @override
  void initState() {
    super.initState();
    _equalizerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _equalizerAnimController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final media = widget.media;
    final isVideo = media.isVideo;

    final pos = c.playbackPosition;
    final dur = c.playbackDuration;
    final progressFraction = dur.inMilliseconds > 0
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A22),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top drag handle & close
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isVideo
                              ? const Color(0xFFFF0000).withValues(alpha: 0.2)
                              : const Color(0xFF6750A4).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isVideo ? Icons.videocam : Icons.audiotrack,
                              size: 14,
                              color: isVideo ? const Color(0xFFFF4D4D) : const Color(0xFFD0BCFF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              media.format,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isVideo
                                    ? const Color(0xFFFF4D4D)
                                    : const Color(0xFFD0BCFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        media.quality,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      c.closePlayer();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // Media Stage (Real Video / Audio Visualizer or Corrupt Notice)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _isCorrupt
                      ? _buildCorruptStage(c, media)
                      : (isVideo
                          ? _buildVideoStage(c)
                          : _buildAudioStage(c, media)),
                ),
              ),
            ),

            // Metadata
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Column(
                children: [
                  Text(
                    media.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    media.author,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),

            // Seek Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: const Color(0xFFD0BCFF),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: const Color(0xFFD0BCFF),
                    ),
                    child: Slider(
                      value: progressFraction,
                      onChanged: (val) {
                        final targetMs = (val * dur.inMilliseconds).toInt();
                        c.seekTo(Duration(milliseconds: targetMs));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(pos),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          _formatDuration(dur),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Control Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Playback speed button
                  PopupMenuButton<double>(
                    tooltip: 'Speed',
                    initialValue: c.playbackSpeed,
                    onSelected: (speed) => c.setPlaybackSpeed(speed),
                    itemBuilder: (ctx) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                      return PopupMenuItem<double>(
                        value: s,
                        child: Text('${s}x'),
                      );
                    }).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${c.playbackSpeed}x',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // -10s
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    iconSize: 32,
                    onPressed: () => c.skipSeconds(-10),
                  ),

                  // Play / Pause Main Button
                  FloatingActionButton(
                    heroTag: 'player_play_pause',
                    backgroundColor: const Color(0xFFD0BCFF),
                    foregroundColor: const Color(0xFF381E72),
                    elevation: 4,
                    onPressed: () => c.togglePlayPause(),
                    child: Icon(
                      c.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 32,
                    ),
                  ),

                  // +10s
                  IconButton(
                    icon: const Icon(Icons.forward_10),
                    iconSize: 32,
                    onPressed: () => c.skipSeconds(10),
                  ),

                  // Info
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    tooltip: 'File Details',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Media Details'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('File: ${media.localFilePath.split(RegExp(r'[\\/]')).last}'),
                              const SizedBox(height: 8),
                              Text('Size: ${media.formattedSize}'),
                              const SizedBox(height: 8),
                              Text('Format: ${media.format} (${media.quality})'),
                              const SizedBox(height: 8),
                              Text('Path: ${media.localFilePath}', style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isCorrupt {
    try {
      final f = File(widget.media.localFilePath);
      return !f.existsSync() || f.lengthSync() < 1024;
    } catch (_) {
      return true;
    }
  }

  Widget _buildCorruptStage(MediaVaultController c, SavedMedia media) {
    return Container(
      color: const Color(0xFF2C243B),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.amberAccent, size: 40),
            const SizedBox(height: 8),
            const Text(
              'Corrupted / Incomplete Download',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'File size is only ${media.formattedSize}. It was downloaded before the fix and cannot be played.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            if (media.id != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete File', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  c.deleteMedia(media);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Real video playback using media_kit's Video widget
  Widget _buildVideoStage(MediaVaultController c) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Real video surface
        Video(
          controller: c.videoController,
          fill: Colors.black,
        ),
        // Tap to toggle play/pause
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => c.togglePlayPause(),
            child: AnimatedOpacity(
              opacity: c.isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black38,
                child: const Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 64,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Audio visualizer with thumbnail background
  Widget _buildAudioStage(MediaVaultController c, SavedMedia media) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail background
        if (media.thumbnailUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: media.thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(color: Colors.black26),
            errorWidget: (_, _, _) => Container(color: Colors.black38),
          )
        else
          Container(color: const Color(0xFF2C243B)),

        // Dark overlay gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),

        // Animated equalizer bars
        Center(
          child: AnimatedBuilder(
            animation: _equalizerAnimController,
            builder: (context, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(12, (index) {
                  final waveHeight = 15 +
                      (sin((index * 0.5) +
                                  (_equalizerAnimController.value * pi * 2)) *
                              25 +
                          25) *
                          (c.isPlaying ? 1.0 : 0.2);
                  return Container(
                    width: 4,
                    height: waveHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0BCFF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}
