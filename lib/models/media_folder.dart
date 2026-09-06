class MediaFolder {
  final int? id;
  final String name;
  final int color;
  final String iconName;
  final String description;

  MediaFolder({
    this.id,
    required this.name,
    this.color = 0xFF6750A4,
    this.iconName = 'folder',
    this.description = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'iconName': iconName,
        'description': description,
      };

  factory MediaFolder.fromMap(Map<String, dynamic> map) => MediaFolder(
        id: map['id'],
        name: map['name'] ?? '',
        color: map['color'] ?? 0xFF6750A4,
        iconName: map['iconName'] ?? 'folder',
        description: map['description'] ?? '',
      );

  MediaFolder copyWith({
    int? id,
    String? name,
    int? color,
    String? iconName,
    String? description,
  }) =>
      MediaFolder(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
        iconName: iconName ?? this.iconName,
        description: description ?? this.description,
      );
}
