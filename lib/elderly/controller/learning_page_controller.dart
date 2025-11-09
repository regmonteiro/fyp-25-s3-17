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
  Map<String, int> _idIndex = const {}; // id -> index
  LearningResourceMini? _selected;
  String _error = '';

  UnmodifiableListView<LearningResourceMini> get resources =>
      UnmodifiableListView(_resources);

  LearningResourceMini? get selectedResource => _selected;
  bool get hasSelection => _selected != null;
  String get errorMessage => _error;
  int get length => _resources.length;

  LearningResourceMini? getById(String id) {
    final i = _idIndex[id];
    if (i == null) return null;
    return _resources[i];
  }

  void setResources(List<LearningResourceMini> newList) {
    _resources = List<LearningResourceMini>.from(newList);
    _idIndex = {
      for (var i = 0; i < _resources.length; i++) _resources[i].id: i,
    };

    if (_selected != null && !_idIndex.containsKey(_selected!.id)) {
      _selected = null;
    }
    _error = '';
  }


  bool selectResource(String id) {
    final i = _idIndex[id];
    if (i != null) {
      _selected = _resources[i];
      _error = '';
      return true;
    } else {
      _error = 'Resource not found.';
      _selected = null;
      return false;
    }
  }

  void upsertResource(LearningResourceMini r) {
    final i = _idIndex[r.id];
    if (i == null) {
      _resources = List.of(_resources)..add(r);
    } else {
      final copy = List.of(_resources);
      copy[i] = r;
      _resources = copy;
    }
    // rebuild index
    _idIndex = {for (var i = 0; i < _resources.length; i++) _resources[i].id: i};

    // keep selection consistent
    if (_selected != null) {
      if (!_idIndex.containsKey(_selected!.id)) _selected = null;
    }
  }
  bool removeResource(String id) {
    final i = _idIndex[id];
    if (i == null) return false;
    final copy = List.of(_resources)..removeAt(i);
    _resources = copy;
    _idIndex = {for (var j = 0; j < _resources.length; j++) _resources[j].id: j};
    if (_selected?.id == id) _selected = null;
    return true;
  }

  void clearSelection() {
    _selected = null;
    _error = '';
  }

  void setError(String message) {
    _error = message;
  }

  void clearError() {
    _error = '';
  }
}
