import 'saved_media.dart';

class Playlist {
  final int? id;
  final String name;
  final String description;
  final int iconColor;
  final int itemCount;

  Playlist({
    this.id,
    required this.name,
    this.description = '',
    this.iconColor = 0xFFD0BCFF,
    this.itemCount = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'iconColor': iconColor,
      };

  factory Playlist.fromMap(Map<String, dynamic> map, {int itemCount = 0}) =>
      Playlist(
        id: map['id'],
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        iconColor: map['iconColor'] ?? 0xFFD0BCFF,
        itemCount: itemCount,
      );

  Playlist copyWith({
    int? id,
    String? name,
    String? description,
    int? iconColor,
    int? itemCount,
  }) =>
      Playlist(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        iconColor: iconColor ?? this.iconColor,
        itemCount: itemCount ?? this.itemCount,
      );
}

class PlaylistItem {
  final int playlistId;
  final int mediaId;
  final int orderIndex;
  final SavedMedia? media;

  PlaylistItem({
    required this.playlistId,
    required this.mediaId,
    required this.orderIndex,
    this.media,
  });

  Map<String, dynamic> toMap() => {
        'playlistId': playlistId,
        'mediaId': mediaId,
        'orderIndex': orderIndex,
      };

  factory PlaylistItem.fromMap(Map<String, dynamic> map, {SavedMedia? media}) =>
      PlaylistItem(
        playlistId: map['playlistId'],
        mediaId: map['mediaId'],
        orderIndex: map['orderIndex'] ?? 0,
        media: media,
      );
}
