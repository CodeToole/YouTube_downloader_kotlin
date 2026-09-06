import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controllers/media_vault_controller.dart';
import '../models/saved_media.dart';
import '../models/media_folder.dart';
import '../widgets/folder_dialogs.dart';
import '../widgets/playlist_dialogs.dart';
import '../widgets/media_player_modal.dart';

class LibraryScreen extends StatefulWidget {
  final VoidCallback onNavigateToDownloader;

  const LibraryScreen({super.key, required this.onNavigateToDownloader});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MediaVaultController>();
    final mediaList = controller.libraryMedia;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'New Folder',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => FolderDialogs.showCreateOrEditFolder(context, controller),
          ),
          PopupMenuButton<String>(
            tooltip: 'Sort by',
            icon: const Icon(Icons.sort),
            initialValue: controller.librarySortBy,
            onSelected: (val) => controller.setLibrarySortBy(val),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'DATE_DESC', child: Text('Newest First')),
              const PopupMenuItem(value: 'TITLE_ASC', child: Text('Title (A-Z)')),
              const PopupMenuItem(value: 'SIZE_DESC', child: Text('Largest File Size')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => controller.setLibrarySearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Search by title or author...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          controller.setLibrarySearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Filter Chips (Media Type & Folders)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                // Type filters
                ChoiceChip(
                  label: const Text('All Media'),
                  selected: controller.libraryMediaType == 'ALL',
                  onSelected: (val) {
                    if (val) controller.setLibraryMediaType('ALL');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.videocam, size: 16),
                  label: const Text('Videos'),
                  selected: controller.libraryMediaType == 'VIDEOS',
                  onSelected: (val) {
                    if (val) controller.setLibraryMediaType('VIDEOS');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.audiotrack, size: 16),
                  label: const Text('Audio'),
                  selected: controller.libraryMediaType == 'AUDIO',
                  onSelected: (val) {
                    if (val) controller.setLibraryMediaType('AUDIO');
                  },
                ),
                const SizedBox(width: 16),
                const VerticalDivider(width: 1),
                const SizedBox(width: 16),

                // Folder filters
                ChoiceChip(
                  label: const Text('All Folders'),
                  selected: controller.libraryFolderFilter == null,
                  onSelected: (val) {
                    if (val) controller.setLibraryFolderFilter(null);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.folder_off_outlined, size: 16),
                  label: const Text('Uncategorized'),
                  selected: controller.libraryFolderFilter == -1,
                  onSelected: (val) {
                    if (val) controller.setLibraryFolderFilter(-1);
                  },
                ),
                const SizedBox(width: 8),
                ...controller.folders.map((f) {
                  final isSelected = controller.libraryFolderFilter == f.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InputChip(
                      avatar: Icon(Icons.folder, color: Color(f.color), size: 16),
                      label: Text(f.name),
                      selected: isSelected,
                      onSelected: (val) {
                        controller.setLibraryFolderFilter(val ? f.id : null);
                      },
                      onDeleted: () => _confirmDeleteFolder(context, controller, f),
                      deleteIcon: const Icon(Icons.more_vert, size: 16),
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Media List
          Expanded(
            child: mediaList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'No media found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Downloaded videos and audio will appear here',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: widget.onNavigateToDownloader,
                          icon: const Icon(Icons.download),
                          label: const Text('Download Media'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: mediaList.length,
                    itemBuilder: (context, index) {
                      final media = mediaList[index];
                      return _buildMediaCard(context, controller, media);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaCard(
    BuildContext context,
    MediaVaultController controller,
    SavedMedia media,
  ) {
    final dateStr = DateFormat('MMM d, yyyy')
        .format(DateTime.fromMillisecondsSinceEpoch(media.downloadDate));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail with duration tag
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 100,
                      height: 70,
                      color: Colors.black26,
                      child: media.thumbnailUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: media.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Icon(
                                media.isVideo ? Icons.videocam : Icons.audiotrack,
                                color: Colors.grey,
                              ),
                            )
                          : Icon(
                              media.isVideo ? Icons.videocam : Icons.audiotrack,
                              color: Colors.grey,
                            ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        media.formattedDuration,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Title and metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      media.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: media.isVideo
                                ? const Color(0xFFFF0000).withValues(alpha: 0.15)
                                : const Color(0xFF6750A4).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            media.format,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: media.isVideo
                                  ? const Color(0xFFFF4D4D)
                                  : const Color(0xFFD0BCFF),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            media.formattedSize,
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),
                        if (media.fileSizeBytes < 1024)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 10, color: Colors.amberAccent),
                                SizedBox(width: 2),
                                Text(
                                  'CORRUPT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amberAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (media.folderName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.folder, size: 10, color: Color(0xFFD0BCFF)),
                                const SizedBox(width: 3),
                                Text(
                                  media.folderName!,
                                  style: const TextStyle(
                                      fontSize: 10, color: Color(0xFFD0BCFF)),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (action) {
                  switch (action) {
                    case 'play':
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
                      break;
                    case 'move':
                      FolderDialogs.showMoveToFolderSheet(context, controller, media);
                      break;
                    case 'playlist':
                      PlaylistDialogs.showAddToPlaylistSheet(context, controller, media);
                      break;
                    case 'rename':
                      _showRenameDialog(context, controller, media);
                      break;
                    case 'delete':
                      _confirmDeleteMedia(context, controller, media);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'play',
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow, size: 18),
                        SizedBox(width: 10),
                        Text('Play Now'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'move',
                    child: Row(
                      children: [
                        Icon(Icons.drive_file_move_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Move to Folder'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'playlist',
                    child: Row(
                      children: [
                        Icon(Icons.playlist_add, size: 18),
                        SizedBox(width: 10),
                        Text('Add to Playlist'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    MediaVaultController controller,
    SavedMedia media,
  ) {
    final textController = TextEditingController(text: media.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Media'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty) {
                controller.renameMedia(media, newName);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMedia(
    BuildContext context,
    MediaVaultController controller,
    SavedMedia media,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text('Are you sure you want to delete "${media.title}" from storage?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              controller.deleteMedia(media);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFolder(
    BuildContext context,
    MediaVaultController controller,
    MediaFolder folder,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Folder Name & Color'),
              onTap: () {
                Navigator.pop(ctx);
                FolderDialogs.showCreateOrEditFolder(context, controller, folder: folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete Folder (Keep files)',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                controller.deleteFolder(folder.id!, deleteFiles: false);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
