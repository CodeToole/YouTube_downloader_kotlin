import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../models/saved_media.dart';
import '../controllers/media_vault_controller.dart';

class PlaylistDialogs {
  static const List<int> playlistColors = [
    0xFFD0BCFF, // Light Purple
    0xFFFF8A80, // Light Coral
    0xFFFFD180, // Light Amber
    0xFFA7FFEB, // Light Teal
    0xFF80D8FF, // Light Blue
    0xFFEA80FC, // Light Pink
    0xFFCCFF90, // Light Lime
  ];

  static void showCreatePlaylistDialog(
    BuildContext context,
    MediaVaultController controller, {
    Playlist? playlistToEdit,
  }) {
    final nameController = TextEditingController(text: playlistToEdit?.name ?? '');
    final descController = TextEditingController(text: playlistToEdit?.description ?? '');
    int selectedColor = playlistToEdit?.iconColor ?? playlistColors.first;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(playlistToEdit == null ? 'New Playlist' : 'Edit Playlist'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Playlist Name',
                        hintText: 'e.g. Chill Mix, Workout Beats',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.playlist_add),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Playlist Accent Color',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: playlistColors.map((color) {
                        final isSelected = selectedColor == color;
                        return GestureDetector(
                          onTap: () => setState(() => selectedColor = color),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(color),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Color(color).withValues(alpha: 0.5),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.black87, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      if (playlistToEdit == null) {
                        controller.createPlaylist(
                          name: name,
                          description: descController.text.trim(),
                          color: selectedColor,
                        );
                      } else {
                        controller.updatePlaylist(
                          playlistToEdit.copyWith(
                            name: name,
                            description: descController.text.trim(),
                            iconColor: selectedColor,
                          ),
                        );
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(playlistToEdit == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void showAddToPlaylistSheet(
    BuildContext context,
    MediaVaultController controller,
    SavedMedia media,
  ) {
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Add to Playlist: "${media.title}"',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'New Playlist',
                      onPressed: () {
                        Navigator.pop(ctx);
                        showCreatePlaylistDialog(context, controller);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              if (controller.playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No playlists created yet.\nTap + to create one!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...controller.playlists.map((p) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(p.iconColor),
                      child: const Icon(Icons.playlist_play, color: Colors.black87),
                    ),
                    title: Text(p.name),
                    subtitle: Text('${p.itemCount} items'),
                    onTap: () {
                      if (p.id != null && media.id != null) {
                        controller.addMediaToPlaylist(p.id!, media.id!);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added to "${p.name}"'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                      Navigator.pop(ctx);
                    },
                  );
                }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
