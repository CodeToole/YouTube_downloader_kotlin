import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../controllers/media_vault_controller.dart';
import '../models/playlist.dart';
import '../widgets/playlist_dialogs.dart';
import '../widgets/media_player_modal.dart';

class PlaylistsScreen extends StatelessWidget {
  final VoidCallback onNavigateToLibrary;

  const PlaylistsScreen({super.key, required this.onNavigateToLibrary});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MediaVaultController>();

    if (controller.selectedPlaylist != null) {
      return _buildPlaylistDetailView(context, controller, controller.selectedPlaylist!);
    }

    return _buildPlaylistsListView(context, controller);
  }

  Widget _buildPlaylistsListView(BuildContext context, MediaVaultController controller) {
    final playlists = controller.playlists;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists & Mixes', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'New Playlist',
            icon: const Icon(Icons.playlist_add),
            onPressed: () => PlaylistDialogs.showCreatePlaylistDialog(context, controller),
          ),
        ],
      ),
      body: playlists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.playlist_play, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'No playlists yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Organize your favorite audio and video mixes',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () =>
                        PlaylistDialogs.showCreatePlaylistDialog(context, controller),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Playlist'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(playlist.iconColor),
                      child: const Icon(Icons.queue_music, color: Colors.black87),
                    ),
                    title: Text(
                      playlist.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (playlist.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            playlist.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          '${playlist.itemCount} ${playlist.itemCount == 1 ? "track" : "tracks"}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'rename') {
                          PlaylistDialogs.showCreatePlaylistDialog(
                            context,
                            controller,
                            playlistToEdit: playlist,
                          );
                        } else if (action == 'delete') {
                          _confirmDeletePlaylist(context, controller, playlist);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'rename', child: Text('Edit / Rename')),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                    onTap: () => controller.selectPlaylist(playlist),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPlaylistDetailView(
    BuildContext context,
    MediaVaultController controller,
    Playlist playlist,
  ) {
    final mediaList = controller.selectedPlaylistMedia;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => controller.selectPlaylist(null),
        ),
        title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Add items from library',
            icon: const Icon(Icons.add),
            onPressed: () => _showAddItemsFromLibraryDialog(context, controller, playlist),
          ),
        ],
      ),
      body: Column(
        children: [
          // Playlist Header Banner
          Container(
            padding: const EdgeInsets.all(20),
            color: Color(playlist.iconColor).withValues(alpha: 0.15),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Color(playlist.iconColor),
                  child: const Icon(Icons.playlist_play, size: 36, color: Colors.black87),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (playlist.description.isNotEmpty)
                        Text(
                          playlist.description,
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${mediaList.length} items',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (mediaList.isNotEmpty)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD0BCFF),
                      foregroundColor: const Color(0xFF381E72),
                    ),
                    onPressed: () {
                      controller.playMedia(mediaList.first);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => MediaPlayerModal(
                          media: mediaList.first,
                          controller: controller,
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play All'),
                  ),
              ],
            ),
          ),

          // Items list
          Expanded(
            child: mediaList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.library_music_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'This playlist is empty',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _showAddItemsFromLibraryDialog(context, controller, playlist),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Media Items'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: mediaList.length,
                    itemBuilder: (context, index) {
                      final media = mediaList[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 60,
                              height: 45,
                              color: Colors.black26,
                              child: media.thumbnailUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: media.thumbnailUrl,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      media.isVideo ? Icons.videocam : Icons.audiotrack,
                                      color: Colors.grey,
                                    ),
                            ),
                          ),
                          title: Text(
                            media.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${media.author} • ${media.formattedDuration}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.redAccent, size: 20),
                            tooltip: 'Remove from playlist',
                            onPressed: () {
                              if (playlist.id != null && media.id != null) {
                                controller.removeMediaFromPlaylist(playlist.id!, media.id!);
                              }
                            },
                          ),
                          onTap: () {
                            controller.playMedia(media);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => MediaPlayerModal(
                                media: media,
                                controller: controller,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddItemsFromLibraryDialog(
    BuildContext context,
    MediaVaultController controller,
    Playlist playlist,
  ) {
    final allLibrary = controller.libraryMedia;
    final currentIds = controller.selectedPlaylistMedia.map((m) => m.id).toSet();
    final available = allLibrary.where((m) => !currentIds.contains(m.id)).toList();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Add to "${playlist.name}"',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              if (available.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text('All library items are already in this playlist!'),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final item = available[index];
                      return ListTile(
                        leading: Icon(item.isVideo ? Icons.videocam : Icons.audiotrack),
                        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(item.author),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () {
                          if (playlist.id != null && item.id != null) {
                            controller.addMediaToPlaylist(playlist.id!, item.id!);
                          }
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeletePlaylist(
    BuildContext context,
    MediaVaultController controller,
    Playlist playlist,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Playlist?'),
        content: Text('Delete "${playlist.name}"? Media files will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              if (playlist.id != null) {
                controller.deletePlaylist(playlist.id!);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
