import 'package:flutter/material.dart';
import '../models/media_folder.dart';
import '../models/saved_media.dart';
import '../controllers/media_vault_controller.dart';

class FolderDialogs {
  static const List<int> folderColors = [
    0xFF6750A4, // Purple
    0xFFB3261E, // Red
    0xFFE06D10, // Orange
    0xFF1B873F, // Green
    0xFF00668B, // Blue
    0xFF8E44AD, // Deep Purple
    0xFFC2185B, // Pink
    0xFF00796B, // Teal
  ];

  static void showCreateOrEditFolder(
    BuildContext context,
    MediaVaultController controller, {
    MediaFolder? folder,
  }) {
    final nameController = TextEditingController(text: folder?.name ?? '');
    final descController = TextEditingController(text: folder?.description ?? '');
    int selectedColor = folder?.color ?? folderColors.first;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(folder == null ? 'New Folder' : 'Edit Folder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Folder Name',
                        hintText: 'e.g. Music Videos, Podcasts',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.folder_outlined),
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
                      'Folder Color',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: folderColors.map((color) {
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
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
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
                      if (folder == null) {
                        controller.createFolder(
                          name: name,
                          color: selectedColor,
                          description: descController.text.trim(),
                        );
                      } else {
                        controller.updateFolder(
                          folder.copyWith(
                            name: name,
                            color: selectedColor,
                            description: descController.text.trim(),
                          ),
                        );
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(folder == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void showMoveToFolderSheet(
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
                child: Text(
                  'Move "${media.title}" to Folder',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('Uncategorized (No Folder)'),
                trailing: media.folderId == null
                    ? const Icon(Icons.check, color: Colors.purpleAccent)
                    : null,
                onTap: () {
                  controller.moveMediaToFolder(media, null);
                  Navigator.pop(ctx);
                },
              ),
              ...controller.folders.map((f) {
                final isSelected = media.folderId == f.id;
                return ListTile(
                  leading: Icon(Icons.folder, color: Color(f.color)),
                  title: Text(f.name),
                  subtitle: f.description.isNotEmpty ? Text(f.description) : null,
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.purpleAccent)
                      : null,
                  onTap: () {
                    controller.moveMediaToFolder(media, f);
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
