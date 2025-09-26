import 'dart:collection';

class LearningResourceMini {
  final String id;
  final String title;
  final String description;
  final String category;
  final String? url;

  const LearningResourceMini({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.url,
  });
}

class ViewLearningResourceController {
  List<LearningResourceMini> _resources = const [];
  LearningResourceMini? _selected;
  String _error = '';

  UnmodifiableListView<LearningResourceMini> get resources =>
      UnmodifiableListView(_resources);

  LearningResourceMini? get selectedResource => _selected;
  String get errorMessage => _error;

  void setResources(List<LearningResourceMini> newList) {
    _resources = List<LearningResourceMini>.from(newList);
    // clear selection if it no longer exists
    if (_selected != null && !_resources.any((r) => r.id == _selected!.id)) {
      _selected = null;
    }
    _error = '';
  }

  void selectResource(String id) {
    final idx = _resources.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _selected = _resources[idx];
      _error = '';
    } else {
      _error = 'Resource not found.';
    }
  }

  void clearSelection() {
    _selected = null;
    _error = '';
  }
}