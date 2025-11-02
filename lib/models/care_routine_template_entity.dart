class CareRoutineItem {
  final String type;
  final String time;
  final String title;
  final String? description;

  CareRoutineItem({
    required this.type,
    required this.time,
    required this.title,
    this.description,
  });

  factory CareRoutineItem.fromMap(Map<String, dynamic> m) => CareRoutineItem(
    type: (m['type'] ?? '').toString(),
    time: (m['time'] ?? '').toString(),
    title: (m['title'] ?? '').toString(),
    description: (m['description'] ?? '').toString().isEmpty ? null : m['description'].toString(),
  );

  Map<String, dynamic> toMap() => {
    'type': type,
    'time': time,
    'title': title,
    if (description != null && description!.isNotEmpty) 'description': description,
  };
}

class CareRoutineTemplateEntity {
  final String? id;
  final String name;
  final String description;
  final List<CareRoutineItem> items;
  final String createdBy;
  final String createdAtIso;

  CareRoutineTemplateEntity({
    this.id,
    required this.name,
    required this.description,
    required this.items,
    required this.createdBy,
    required this.createdAtIso,
  });

  factory CareRoutineTemplateEntity.fromFirestore(String id, Map<String, dynamic> data) {
    final list = (data['items'] as List? ?? const []);
    return CareRoutineTemplateEntity(
      id: id,
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      items: list.map((e) => CareRoutineItem.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAtIso: (data['createdAt'] ?? data['createdAtIso'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'items': items.map((i) => i.toMap()).toList(),
    'createdBy': createdBy,
    'createdAt': createdAtIso,
    'lastUpdatedAt': DateTime.now().toIso8601String(),
  };

  List<String> validate() {
    final errs = <String>[];
    if (name.trim().isEmpty) errs.add('Template name is required');
    if (items.isEmpty) errs.add('Please add at least one activity to the template');
    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      if (it.time.trim().isEmpty) errs.add('Activity ${i + 1}: Time is required');
      if (it.title.trim().isEmpty) errs.add('Activity ${i + 1}: Title is required');
    }
    return errs;
  }
}
