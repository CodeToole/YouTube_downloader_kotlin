import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
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

  // Local drag state for smooth scrubber interaction
  bool isDragging = false;
  double _dragPosition = 0.0;

  // Touch overlay visibility for video playback
  bool _showVideoControls = true;

  Player get player => widget.controller.player;
  VideoController get controller => widget.controller.videoController;

  @override
  void initState() {
    super.initState();
    _equalizerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Ensure playback begins if not already initialized for this media
    if (widget.controller.currentlyPlayingMedia?.localFilePath !=
        widget.media.localFilePath) {
      widget.controller.playMedia(widget.media);
    }
  }

  bool _isTeardownDone = false;

  void _safeTeardown() {
    if (_isTeardownDone) return;
    _isTeardownDone = true;
    widget.controller.closePlayer();
  }

  @override
  void dispose() {
    _equalizerAnimController.dispose();
    _safeTeardown();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final isVideo = media.isVideo;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        try {
          widget.controller.activePlayer?.pause();
        } catch (_) {}
        _safeTeardown();
      },
      child: StreamBuilder<Duration>(
        stream: player.stream.position,
        initialData: player.state.position,
        builder: (context, posSnapshot) {
          return StreamBuilder<Duration>(
            stream: player.stream.duration,
            initialData: player.state.duration,
            builder: (context, durSnapshot) {
              return StreamBuilder<bool>(
                stream: player.stream.playing,
                initialData: player.state.playing,
                builder: (context, playingSnapshot) {
                  final position = posSnapshot.data ?? Duration.zero;
                  final duration = durSnapshot.data ?? Duration.zero;
                  final isPlaying = playingSnapshot.data ?? false;

                  final totalMs = duration.inMilliseconds;
                  final maxVal = totalMs > 0 ? totalMs.toDouble() : 1.0;
                  final currentMs = isDragging
                      ? _dragPosition
                      : position.inMilliseconds.toDouble();
                  final sliderValue = currentMs.clamp(0.0, maxVal);

                  final displayPos = isDragging
                      ? Duration(milliseconds: _dragPosition.toInt())
                      : position;
                  final displayDur = duration;

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1A22),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
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
                          // Top drag handle & info header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isVideo
                                            ? const Color(0xFFFF0000)
                                                .withValues(alpha: 0.2)
                                            : const Color(0xFF6750A4)
                                                .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isVideo
                                                ? Icons.videocam
                                                : Icons.audiotrack,
                                            size: 14,
                                            color: isVideo
                                                ? const Color(0xFFFF4D4D)
                                                : const Color(0xFFD0BCFF),
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
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Media Stage (Responsive Video Stack / Audio Visualizer / Corrupt Notice)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: _isCorrupt
                                    ? _buildCorruptStage(media)
                                    : (isVideo
                                        ? _buildVideoStage(
                                            context: context,
                                            position: position,
                                            duration: duration,
                                            isPlaying: isPlaying,
                                          )
                                        : _buildAudioStage(media, isPlaying)),
                              ),
                            ),
                          ),

                          // Metadata
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 4),
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

                          // Synchronized Scrubber Bar & Dynamic Timestamps
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 12),
                                    activeTrackColor: const Color(0xFFD0BCFF),
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: const Color(0xFFD0BCFF),
                                  ),
                                  child: Slider(
                                    min: 0.0,
                                    max: maxVal,
                                    value: sliderValue,
                                    onChanged: (val) {
                                      setState(() {
                                        isDragging = true;
                                        _dragPosition = val;
                                      });
                                    },
                                    onChangeEnd: (val) {
                                      player.seek(Duration(
                                          milliseconds: val.toInt()));
                                      setState(() {
                                        isDragging = false;
                                      });
                                    },
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(displayPos),
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        _formatDuration(displayDur),
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
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
                                  initialValue: widget.controller.playbackSpeed,
                                  onSelected: (speed) =>
                                      widget.controller.setPlaybackSpeed(speed),
                                  itemBuilder: (ctx) => [
                                    0.5,
                                    0.75,
                                    1.0,
                                    1.25,
                                    1.5,
                                    2.0
                                  ].map((s) {
                                    return PopupMenuItem<double>(
                                      value: s,
                                      child: Text('${s}x'),
                                    );
                                  }).toList(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white24),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      '${widget.controller.playbackSpeed}x',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),

                                // Rewind -10s
                                IconButton(
                                  icon: const Icon(Icons.replay_10),
                                  iconSize: 32,
                                  onPressed: () {
                                    final newPos =
                                        position - const Duration(seconds: 10);
                                    player.seek(newPos < Duration.zero
                                        ? Duration.zero
                                        : newPos);
                                  },
                                ),

                                // Play / Pause Main Button
                                FloatingActionButton(
                                  heroTag: 'player_play_pause',
                                  backgroundColor: const Color(0xFFD0BCFF),
                                  foregroundColor: const Color(0xFF381E72),
                                  elevation: 4,
                                  onPressed: () => player.playOrPause(),
                                  child: Icon(
                                    isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    size: 32,
                                  ),
                                ),

                                // Forward +10s
                                IconButton(
                                  icon: const Icon(Icons.forward_10),
                                  iconSize: 32,
                                  onPressed: () {
                                    final newPos =
                                        position + const Duration(seconds: 10);
                                    player.seek(
                                        newPos > duration ? duration : newPos);
                                  },
                                ),

                                // Info dialog button
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'File: ${media.localFilePath.split(RegExp(r'[\\/]')).last}'),
                                            const SizedBox(height: 8),
                                            Text('Size: ${media.formattedSize}'),
                                            const SizedBox(height: 8),
                                            Text(
                                                'Format: ${media.format} (${media.quality})'),
                                            const SizedBox(height: 8),
                                            Text('Path: ${media.localFilePath}',
                                                style: const TextStyle(
                                                    fontSize: 11)),
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
                },
              );
            },
          );
        },
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

  Widget _buildCorruptStage(SavedMedia media) {
    return Container(
      color: const Color(0xFF2C243B),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.amberAccent, size: 40),
            const SizedBox(height: 8),
            const Text(
              'Corrupted / Incomplete Download',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete File', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  widget.controller.deleteMedia(media);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Responsive Video Stage with custom control buttons strictly layered on top of Video
  /// inside a Stack, wrapped in a GestureDetector(behavior: HitTestBehavior.opaque).
  Widget _buildVideoStage({
    required BuildContext context,
    required Duration position,
    required Duration duration,
    required bool isPlaying,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Native video texture surface
        Video(
          controller: controller,
          fill: Colors.black,
          controls: NoVideoControls,
        ),

        // Responsive touch overlay strictly layered on top of Video
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _showVideoControls = !_showVideoControls;
              });
            },
            child: AnimatedOpacity(
              opacity: _showVideoControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                color: Colors.black45,
                child: Stack(
                  children: [
                    // Top-right close button inside overlay
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 24),
                        tooltip: 'Close',
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),

                    // Custom control buttons: rewind, play/pause, forward
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Rewind -10s
                          IconButton(
                            icon: const Icon(Icons.replay_10,
                                color: Colors.white, size: 36),
                            tooltip: 'Rewind 10s',
                            onPressed: () {
                              final newPos =
                                  position - const Duration(seconds: 10);
                              player.seek(newPos < Duration.zero
                                  ? Duration.zero
                                  : newPos);
                            },
                          ),
                          const SizedBox(width: 24),

                          // Play / Pause toggle
                          IconButton(
                            icon: Icon(
                              isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: const Color(0xFFD0BCFF),
                              size: 56,
                            ),
                            tooltip: isPlaying ? 'Pause' : 'Play',
                            onPressed: () => player.playOrPause(),
                          ),
                          const SizedBox(width: 24),

                          // Forward +10s
                          IconButton(
                            icon: const Icon(Icons.forward_10,
                                color: Colors.white, size: 36),
                            tooltip: 'Forward 10s',
                            onPressed: () {
                              final newPos =
                                  position + const Duration(seconds: 10);
                              player.seek(
                                  newPos > duration ? duration : newPos);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Audio visualizer with thumbnail background
  Widget _buildAudioStage(SavedMedia media, bool isPlaying) {
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
                          (isPlaying ? 1.0 : 0.2);
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
