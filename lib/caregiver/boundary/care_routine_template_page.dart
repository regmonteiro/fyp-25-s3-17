// lib/ui/care_routine_template_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/care_routine_template_entity.dart';
import '../../services/care_routine_template_service.dart';
import '../../assistant_chat.dart';

class CareRoutineTemplatePage extends StatefulWidget {
  const CareRoutineTemplatePage({super.key});

  @override
  State<CareRoutineTemplatePage> createState() => _CareRoutineTemplatePageState();
}

class _CareRoutineTemplatePageState extends State<CareRoutineTemplatePage> {
  final _svc = CareRoutineTemplateService();

  String _currentStep = 'templates';
  bool _loading = true;
  String _error = '';
  String _success = '';

  String _currentUserType = 'elderly';
  List<CareRoutineTemplateEntity> _templates = [];
  List<Map<String, dynamic>> _assigned = [];
  List<Map<String, dynamic>> _linkedUsers = [];

  CareRoutineTemplateEntity? _deleteConfirm;
  Map<String, dynamic>? _unassignConfirm;

  Map<String, dynamic>? _selectedUser; // {id, name, ...}
  CareRoutineTemplateEntity? _selectedTemplate;

  // new template form
  final _tplNameCtrl = TextEditingController();
  final _tplDescCtrl = TextEditingController();
  final List<CareRoutineItem> _newItems = [];

  StreamSubscription? _tplSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _tplNameCtrl.dispose();
    _tplDescCtrl.dispose();
    _tplSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      setState(() {
        _loading = true;
        _error = '';
        _success = '';
      });

      _currentUserType = await _svc.getCurrentUserType();

      await _loadLinkedUsers();
      await _loadTemplates();
      await _loadAssigned();

    _tplSub = _svc.subscribeToUserTemplates().listen((maps) {
  setState(() => _templates = maps
      .map((m) => CareRoutineTemplateEntity.fromFirestore(m['id'] as String, m))
      .toList());
});

    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadLinkedUsers() async {
    try {
      final users = await _svc.getLinkedElderlyUsers();
      setState(() => _linkedUsers = users);
      if (_currentUserType == 'elderly' && users.isNotEmpty) {
        _selectedUser = users.first; // self
      }
      if (users.isEmpty && _currentUserType == 'caregiver') {
        setState(() => _error = 'No elderly users are linked to your account. Please link an elderly user first.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final maps = await _svc.getUserCareRoutineTemplates();
setState(() => _templates = maps
    .map((m) => CareRoutineTemplateEntity.fromFirestore(m['id'] as String, m))
    .toList());

    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _loadAssigned() async {
    try {
      final items = <Map<String, dynamic>>[];
      if (_currentUserType == 'caregiver') {
        for (final u in _linkedUsers) {
          final arr = await _svc.getAssignedRoutines(u['id'].toString());
          items.addAll(arr.map((e) => {...e, 'elderlyUser': u}));
        }
      } else {
        final id = await _svc.getLinkedElderlyId();
        final arr = await _svc.getAssignedRoutines(id);
        items.addAll(arr.map((e) => {
              ...e,
              'elderlyUser': {'id': id, 'name': 'Me', 'relationship': 'Self'}
            }));
      }
      setState(() => _assigned = items);
    } catch (e) {
      // keep silence; can show toast if needed
    }
  }

  void _addItem(String type) {
    setState(() {
      _newItems.add(CareRoutineItem(type: type, time: '', title: ''));
    });
  }

  void _updateItem(int i, {String? time, String? title, String? desc}) {
    final old = _newItems[i];
    setState(() {
      _newItems[i] = CareRoutineItem(
        type: old.type,
        time: time ?? old.time,
        title: title ?? old.title,
        description: desc ?? old.description,
      );
    });
  }

  void _removeItem(int i) {
    setState(() => _newItems.removeAt(i));
  }

  Future<void> _createTemplate() async {
    try {
      setState(() {
        _loading = true;
        _error = '';
        _success = '';
      });

      final entity = CareRoutineTemplateEntity(
        name: _tplNameCtrl.text.trim(),
        description: _tplDescCtrl.text.trim(),
        items: _newItems,
        createdBy: FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '',
        createdAtIso: DateTime.now().toIso8601String(),
      );

      final errors = entity.validate();
      if (errors.isNotEmpty) {
        throw StateError(errors.join(', '));
      }

      await _svc.createCareRoutineTemplate(entity.toFirestore());


      setState(() {
        _tplNameCtrl.clear();
        _tplDescCtrl.clear();
        _newItems.clear();
        _success = 'Routine template created successfully!';
        _currentStep = 'templates';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete(CareRoutineTemplateEntity tpl) async {
    try {
      final assigned = await _svc.isTemplateAssigned(tpl.id!);
      if (assigned) {
        setState(() => _error = 'Cannot delete "${tpl.name}" because it is currently assigned. Please unassign it first.');
        return;
      }
      setState(() => _deleteConfirm = tpl);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

 Future<void> _deleteTemplateNow() async {
  final tpl = _deleteConfirm;
  if (tpl == null) return;
  try {
    setState(() {
      _loading = true;
      _error = '';
      _success = '';
    });

    // ⬇️ Use the Firestore service method name
    await _svc.deleteCareRoutineTemplate(tpl.id!);

    await _loadTemplates();
    setState(() {
      _success = 'Routine template "${tpl.name}" deleted successfully!';
      _deleteConfirm = null;
    });
  } catch (e) {
    setState(() => _error = e.toString());
  } finally {
    setState(() => _loading = false);
  }
}


  Future<void> _assignSelected() async {
    try {
      setState(() {
        _loading = true;
        _error = '';
        _success = '';
      });
      if (_selectedUser == null || _selectedTemplate == null) {
        throw StateError('Please select both a user and a template');
      }
      await _svc.assignRoutineToElderly(
        _selectedUser!['id'].toString(),
        _selectedTemplate!.id!,
      );
      final msg = _currentUserType == 'elderly'
          ? 'Routine "${_selectedTemplate!.name}" has been assigned to your schedule!'
          : 'Routine "${_selectedTemplate!.name}" has been assigned to ${_selectedUser!['name']}!';
      setState(() {
        _success = msg;
        _currentStep = 'templates';
        _selectedUser = null;
        _selectedTemplate = null;
      });
      await _loadAssigned();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _unassignNow() async {
    final a = _unassignConfirm;
    if (a == null) return;
    try {
      setState(() {
        _loading = true;
        _error = '';
        _success = '';
      });
      await _svc.removeAssignedRoutine(a['elderlyId'].toString(), a['templateId'].toString());
      setState(() {
        _success = 'Routine "${a['templateData']['name']}" has been unassigned!';
        _unassignConfirm = null;
      });
      await _loadAssigned();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---------------- UI helpers ----------------
  IconData _iconFor(String type) {
    switch (type) {
      case 'medication':
        return Icons.medication;
      case 'meal':
        return Icons.restaurant;
      case 'rest':
        return Icons.nightlight_round;
      case 'entertainment':
        return Icons.favorite;
      default:
        return Icons.access_time;
    }
  }

  Color _chipColor(BuildContext context, String type) {
    switch (type) {
      case 'medication':
        return Colors.red.withOpacity(0.1);
      case 'meal':
        return Colors.orange.withOpacity(0.1);
      case 'rest':
        return Colors.blueGrey.withOpacity(0.1);
      case 'entertainment':
        return Colors.purple.withOpacity(0.1);
      default:
        return Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4);
    }
  }

  Widget _stepButton(String key, String label) {
    final active = _currentStep == key;
    return ElevatedButton(
      onPressed: () => setState(() => _currentStep = key),
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? Theme.of(context).colorScheme.primary : null,
        foregroundColor: active ? Colors.white : null,
      ),
      child: Text(label),
    );
  }

  void _autoAssignToSelfIfElderlyAndTemplatePicked(CareRoutineTemplateEntity tpl) async {
    setState(() => _selectedTemplate = tpl);
    if (_currentUserType == 'elderly') {
      if (_selectedUser == null) {
        final users = await _svc.getLinkedElderlyUsers();
        if (users.isNotEmpty) _selectedUser = users.first;
      }
      await _assignSelected();
    } else {
      setState(() => _currentStep = 'assign');
    }
  }

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    final isElderly = _currentUserType == 'elderly';
    final isCaregiver = _currentUserType == 'caregiver';

    if (_loading && _templates.isEmpty && _linkedUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading care routines...'),
          ],
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
  backgroundColor: Colors.deepPurple,
  onPressed: () {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'guest@allcare.ai';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssistantChat(userEmail: email),
      ),
    );
  },
  child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
),

      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.access_time),
            const SizedBox(width: 8),
            Text(isElderly ? 'My Daily Routine' : 'Care Routine Management'),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              children: [
                _stepButton('templates', isElderly ? 'My Templates' : 'Routine Templates'),
                _stepButton('create', 'Create New'),
                if (isCaregiver) _stepButton('assign', 'Assign Routine'),
                _stepButton('assigned', isElderly ? 'My Schedule' : 'Assigned Routines'),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (_error.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error)),
                  ],
                ),
              ),
            if (_success.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_success)),
                  ],
                ),
              ),
            Expanded(
              child: _buildStep(isElderly: isElderly, isCaregiver: isCaregiver),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({required bool isElderly, required bool isCaregiver}) {
    switch (_currentStep) {
      case 'create':
        return _buildCreateView();
      case 'assign':
        if (!isCaregiver) return _buildEmpty('Assignment available for caregivers only.');
        return _buildAssignView();
      case 'assigned':
        return _buildAssignedView(isElderly: isElderly);
      case 'templates':
      default:
        return _buildTemplatesView(isElderly: isElderly);
    }
  }

  Widget _buildEmpty(String msg) => Center(child: Text(msg));

  // -------- Templates View --------
  Widget _buildTemplatesView({required bool isElderly}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(isElderly ? 'My Routine Templates' : 'Routine Templates',
                style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => setState(() => _currentStep = 'create'),
              icon: const Icon(Icons.add),
              label: const Text('Create New Template'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_templates.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                Text(isElderly ? 'No Templates Created Yet' : 'No Templates Yet',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  isElderly
                      ? 'Create your first routine template to organize your daily schedule'
                      : 'Create your first care routine template to get started',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => setState(() => _currentStep = 'create'),
                  child: const Text('Create Your First Template'),
                ),
              ],
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: _templates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final t = _templates[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.name, style: Theme.of(context).textTheme.titleMedium),
                                  if (t.description.isNotEmpty)
                                    Text(t.description, style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete template',
                              onPressed: () => _confirmDelete(t),
                              icon: const Icon(Icons.delete, color: Colors.red),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${t.items.length} activities', style: const TextStyle(color: Colors.blue)),
                        const SizedBox(height: 6),
                        for (final item in t.items.take(3))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: _chipColor(context, item.type),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(_iconFor(item.type), size: 16),
                                ),
                                const SizedBox(width: 8),
                                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Text(item.time, style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        if (t.items.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('+${t.items.length - 3} more activities',
                                style: const TextStyle(color: Colors.grey)),
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            onPressed: () => _autoAssignToSelfIfElderlyAndTemplatePicked(t),
                            child: Text(isElderly ? 'Add to My Schedule' : 'Assign Routine'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // Delete dialog
        if (_deleteConfirm != null)
          _ConfirmBar(
            icon: Icons.warning_amber_rounded,
            color: Colors.red,
            title: 'Delete Routine Template',
            message:
                'Are you sure you want to delete the routine template "${_deleteConfirm!.name}"? This action cannot be undone.',
            onCancel: () => setState(() => _deleteConfirm = null),
            onConfirm: _deleteTemplateNow,
            confirmText: 'Delete Template',
          ),
      ],
    );
  }

  // -------- Create Template View --------
  Widget _buildCreateView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create New Routine Template', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _tplNameCtrl,
            decoration: const InputDecoration(labelText: 'Template Name', hintText: 'e.g., Morning Routine'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tplDescCtrl,
            decoration: const InputDecoration(labelText: 'Description (Optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Text('Add Activities', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () => _addItem('medication'),
                child: const Text('Medication'),
              ),
              FilledButton.tonal(
                onPressed: () => _addItem('meal'),
                child: const Text('Meal'),
              ),
              FilledButton.tonal(
                onPressed: () => _addItem('rest'),
                child: const Text('Rest/Activity'),
              ),
              FilledButton.tonal(
                onPressed: () => _addItem('entertainment'),
                child: const Text('Entertainment'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _newItems.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_iconFor(_newItems[i].type)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        runSpacing: 8,
                        spacing: 8,
                        children: [
                          SizedBox(
                            width: 120,
                            child: TextField(
                              decoration: const InputDecoration(labelText: 'Time (HH:MM)'),
                              onChanged: (v) => _updateItem(i, time: v),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              decoration: const InputDecoration(labelText: 'Title'),
                              onChanged: (v) => _updateItem(i, title: v),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: TextField(
                              decoration: const InputDecoration(labelText: 'Description'),
                              onChanged: (v) => _updateItem(i, desc: v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeItem(i),
                      icon: const Icon(Icons.close, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStep = 'templates'),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _loading ? null : _createTemplate,
                icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
                label: Text(_loading ? 'Creating...' : 'Create Routine'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------- Assign View (caregiver only) --------
  Widget _buildAssignView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assign Routine to User', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text('Select Linked User', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_linkedUsers.isEmpty)
            _EmptyBox(
              icon: Icons.person,
              title: 'No Linked Users',
              subtitle: 'You need to be linked to an elderly user to assign routines.',
              actionText: 'Retry Loading Users',
              onAction: _loadLinkedUsers,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _linkedUsers.map((u) {
                final selected = _selectedUser?['id'] == u['id'];
                return ChoiceChip(
                  label: Text('${u['name']}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedUser = u),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          if (_selectedUser != null && _templates.isNotEmpty) ...[
            Text('Select Routine Template', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _templates.map((t) {
                final selected = _selectedTemplate?.id == t.id;
                return ChoiceChip(
                  label: Text('${t.name} (${t.items.length})'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedTemplate = t),
                );
              }).toList(),
            ),
          ],
          if (_selectedUser != null && _templates.isEmpty)
            _EmptyBox(
              icon: Icons.access_time,
              title: 'No Templates Available',
              subtitle: 'Create a routine template first before assigning.',
              actionText: 'Create Template',
              onAction: () => setState(() => _currentStep = 'create'),
            ),
          const SizedBox(height: 16),
          if (_selectedUser != null && _selectedTemplate != null)
            Card(
              child: ListTile(
                title: const Text('Assignment Confirmation'),
                subtitle: Text(
                  'You are about to assign "${_selectedTemplate!.name}" to ${_selectedUser!['name']}. '
                  'This routine contains ${_selectedTemplate!.items.length} activities.',
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStep = 'templates'),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: (_selectedUser == null || _selectedTemplate == null || _loading) ? null : _assignSelected,
                child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Confirm Assignment'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------- Assigned View --------
  Widget _buildAssignedView({required bool isElderly}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(isElderly ? 'My Daily Schedule' : 'Assigned Routines',
                style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            OutlinedButton(onPressed: _loadAssigned, child: const Text('Refresh')),
          ],
        ),
        const SizedBox(height: 12),
        if (_assigned.isEmpty)
          _EmptyBox(
            icon: Icons.group,
            title: isElderly ? 'No Routines Scheduled' : 'No Assigned Routines',
            subtitle: isElderly
                ? 'Assign routines to your schedule to see them here'
                : 'Assign routines to elderly users to see them here',
            actionText: isElderly ? 'Add Routine to Schedule' : 'Assign Routine',
            onAction: () => setState(() => _currentStep = isElderly ? 'templates' : 'assign'),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: _assigned.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final a = _assigned[i];
                final tpl = Map<String, dynamic>.from(a['templateData'] as Map);
                final items = List<Map<String, dynamic>>.from(tpl['items'] as List);
                final elderlyUser = Map<String, dynamic>.from(a['elderlyUser'] as Map? ?? {});
                final assignedOn = DateTime.tryParse(a['assignedAt']?.toString() ?? '');

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${tpl['name']}', style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 2),
                                  Text(
                                    isElderly
                                        ? 'Assigned on: ${assignedOn == null ? '-' : _fmtDate(assignedOn)}'
                                        : 'Assigned to: ${elderlyUser['name'] ?? '-'} • '
                                          'Assigned on: ${assignedOn == null ? '-' : _fmtDate(assignedOn)}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const Chip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, size: 14),
                                  SizedBox(width: 4),
                                  Text('Active'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final it in items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: _chipStaticColor(context, (it['type'] ?? '').toString()),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(_staticIconFor((it['type'] ?? '').toString()), size: 16, color: Colors.black87),
                                ),
                                const SizedBox(width: 6),
                                Text((it['time'] ?? '').toString(), style: const TextStyle(color: Colors.grey)),
                                const SizedBox(width: 8),
                                Text((it['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                                if ((it['description'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text('- ${(it['description'] ?? '').toString()}', style: const TextStyle(color: Colors.grey)),
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => _unassignConfirm = a),
                            icon: const Icon(Icons.group_remove),
                            label: Text(isElderly ? 'Remove from Schedule' : 'Unassign Routine'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        if (_unassignConfirm != null)
          _ConfirmBar(
            icon: Icons.warning_amber_rounded,
            color: Colors.orange,
            title: 'Unassign Routine',
            message:
                'Are you sure you want to unassign the routine "${_unassignConfirm!['templateData']['name']}"?',
            onCancel: () => setState(() => _unassignConfirm = null),
            onConfirm: _unassignNow,
            confirmText: 'Unassign Routine',
          ),
      ],
    );
  }

  static String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static IconData _staticIconFor(String type) {
    switch (type) {
      case 'medication':
        return Icons.medication;
      case 'meal':
        return Icons.restaurant;
      case 'rest':
        return Icons.nightlight_round;
      case 'entertainment':
        return Icons.favorite;
      default:
        return Icons.access_time;
    }
  }

  static Color _chipStaticColor(BuildContext context, String type) {
    switch (type) {
      case 'medication':
        return Colors.red.withOpacity(0.1);
      case 'meal':
        return Colors.orange.withOpacity(0.1);
      case 'rest':
        return Colors.blueGrey.withOpacity(0.1);
      case 'entertainment':
        return Colors.purple.withOpacity(0.1);
      default:
        return Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4);
    }
  }
}

// ---------- small UI helpers ----------
class _ConfirmBar extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String confirmText;

  const _ConfirmBar({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.onCancel,
    required this.onConfirm,
    required this.confirmText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.08),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: Text(message)),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  onPressed: onConfirm,
                  child: Text(confirmText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionText;
  final VoidCallback onAction;

  const _EmptyBox({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: onAction, child: Text(actionText)),
            ],
          ),
        ),
      ),
    );
  }
}
