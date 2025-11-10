import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import 'admin_shell.dart';

class AdminSafetyMeasuresPage extends StatefulWidget {
  final UserProfile userProfile;
  const AdminSafetyMeasuresPage({super.key, required this.userProfile});

  @override
  State<AdminSafetyMeasuresPage> createState() => _AdminSafetyMeasuresState();
}

class _AdminSafetyMeasuresState extends State<AdminSafetyMeasuresPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _createdByController = TextEditingController();
  final _maxResponseLengthController = TextEditingController(text: '500');
  final _prohibitedWordsController = TextEditingController();

  // State
  bool _isLoading = false;
  String _successMessage = '';
  String _errorMessage = '';
  final List<SafetyMeasure> _safetyMeasuresList = [];

  @override
  void initState() {
    super.initState();
    // Prefill createdBy from user profile (or fallback)
    _createdByController.text =
        (widget.userProfile.email ?? 'admin@example.com').replaceAll('.', '_');
    _loadSafetyDataWithFallback();
  }

  Future<void> _loadSafetyDataWithFallback() async {
    setState(() => _isLoading = true);
    try {
      final querySnapshot =
          await _firestore.collection('SafetyMeasures').limit(50).get();

      _safetyMeasuresList.clear();
      int loaded = 0;
      for (final doc in querySnapshot.docs) {
        final s = _parseSafetyMeasureDocument(doc);
        if (s != null) {
          s.id = doc.id;
          _safetyMeasuresList.add(s);
          loaded++;
        }
      }
      if (loaded == 0) _loadSampleSafetyData();
      if (mounted) setState(() {});
    } catch (e) {
      _showError('Failed to load safety measures: $e');
      _loadSampleSafetyData();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  SafetyMeasure? _parseSafetyMeasureDocument(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();
      if (data == null) return null;

      final title = data['title'] as String?;
      final description = data['description'] as String?;
      final createdBy = data['createdBy'] as String?;
      final createdAt = data['createdAt'] as String?;
      final lastUpdatedAt = data['lastUpdatedAt'] as String?;
      final parameters = data['parameters'] as Map<String, dynamic>?;
      final prohibited = data['prohibitedWords'] as List<dynamic>?;

      if (title == null || description == null || createdBy == null) return null;

      return SafetyMeasure(
        title: title,
        description: description,
        createdBy: createdBy,
        createdAt: _parseISODate(createdAt),
        lastUpdatedAt: _parseISODate(lastUpdatedAt),
        parameters: parameters ?? {},
        prohibitedWords: (prohibited ?? []).cast<String>(),
      );
    } catch (_) {
      return null;
    }
  }

  DateTime _parseISODate(String? s) {
    if (s == null) return DateTime.now();
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }

  void _loadSampleSafetyData() {
    _safetyMeasuresList
      ..clear()
      ..addAll([
        SafetyMeasure(
          id: 'sample_1',
          title: 'Appropriate Language Use',
          description:
              'Ensure AI responses avoid offensive or harmful language. Maintain respectful and polite tone.',
          createdBy: 'admin@example.com',
          createdAt: DateTime.now(),
          lastUpdatedAt: DateTime.now(),
          parameters: {
            'enforcePoliteness': true,
            'flagSuspiciousContent': true,
            'maxResponseLength': 500,
          },
          prohibitedWords: ['offensive_word1', 'offensive_word2', 'bad_language'],
        ),
        SafetyMeasure(
          id: 'sample_2',
          title: 'Content Moderation',
          description:
              'Filter out inappropriate content and ensure responses are family-friendly.',
          createdBy: 'moderator@example.com',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          lastUpdatedAt: DateTime.now(),
          parameters: {
            'enforcePoliteness': true,
            'flagSuspiciousContent': false,
            'maxResponseLength': 300,
          },
          prohibitedWords: ['hate_speech', 'discrimination'],
        ),
        SafetyMeasure(
          id: 'sample_3',
          title: 'Security Guidelines',
          description: 'Prevent security threats and malicious content in AI responses.',
          createdBy: 'security@example.com',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          lastUpdatedAt: DateTime.now(),
          parameters: {
            'enforcePoliteness': false,
            'flagSuspiciousContent': true,
            'maxResponseLength': 1000,
          },
          prohibitedWords: ['spam', 'phishing', 'malware'],
        ),
      ]);

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loaded sample safety measures for testing')),
    );
    _showError('Using sample data. Check Firestore connection and security rules.');
  }

  void _handleSaveSafetyMeasure() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final createdBy = _createdByController.text.trim();
    final maxLenStr = _maxResponseLengthController.text.trim();
    final prohibitedWords = _prohibitedWordsController.text.trim();

    _hideMessages();

    if (title.isEmpty) return _showError('Title is required.');
    if (description.isEmpty) return _showError('Description is required.');
    if (createdBy.isEmpty) return _showError('Created By is required.');
    if (maxLenStr.isEmpty) return _showError('Max Response Length is required.');

    final maxLen = int.tryParse(maxLenStr);
    if (maxLen == null || maxLen <= 0) {
      return _showError('Max Response Length must be a valid positive number.');
    }

    _saveSafetyMeasure(title, description, createdBy, maxLen, prohibitedWords);
  }

  Future<void> _saveSafetyMeasure(
    String title,
    String description,
    String createdBy,
    int maxResponseLength,
    String prohibitedWords,
  ) async {
    setState(() => _isLoading = true);
    try {
      final prohibited = <String>[];
      if (prohibitedWords.isNotEmpty) {
        for (final w in prohibitedWords.split(RegExp(r'[,\n]'))) {
          final t = w.trim();
          if (t.isNotEmpty) prohibited.add(t);
        }
      }

      final now = DateTime.now().toUtc();
      String two(int n) => (n >= 10) ? '$n' : '0$n';
      final iso = '${now.year}-${two(now.month)}-${two(now.day)}'
          'T${two(now.hour)}:${two(now.minute)}:${two(now.second)}Z';

      final data = <String, dynamic>{
        'title': title,
        'description': description,
        'createdBy': createdBy.replaceAll('.', '_'),
        'createdAt': iso,
        'lastUpdatedAt': iso,
        'parameters': {
          'enforcePoliteness': true,
          'flagSuspiciousContent': true,
          'maxResponseLength': maxResponseLength,
        },
        'prohibitedWords': prohibited,
      };

      await _firestore.collection('SafetyMeasures').add(data);

      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSuccess('Safety measure saved successfully!');
      _clearForm();
      _loadSafetyDataWithFallback();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Failed to save safety measure: $e');
    }
  }

  void _showSuccess(String m) {
    if (!mounted) return;
    setState(() {
      _successMessage = m;
      _errorMessage = '';
    });
  }

  void _showError(String m) {
    if (!mounted) return;
    setState(() {
      _errorMessage = m;
      _successMessage = '';
    });
  }

  void _hideMessages() {
    if (!mounted) return;
    setState(() {
      _errorMessage = '';
      _successMessage = '';
    });
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _prohibitedWordsController.clear();
    _maxResponseLengthController.text = '500';
  }

  String _two(int n) => (n >= 10) ? '$n' : '0$n';

  String _formatDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${_two(d.day)} ${months[d.month - 1]} ${d.year}, '
           '${_two(d.hour)}:${_two(d.minute)}';
    }

  String _renderParameters(Map<String, dynamic> p) {
    if (p.isEmpty) return 'No parameters set';
    final ep = (p['enforcePoliteness'] as bool?) ?? false;
    final fs = (p['flagSuspiciousContent'] as bool?) ?? false;
    final mr = (p['maxResponseLength'] as int?) ?? 500;
    return 'Parameters:\n'
        '• Enforce Politeness: ${ep ? '✅ Yes' : '❌ No'}\n'
        '• Flag Suspicious Content: ${fs ? '✅ Yes' : '❌ No'}\n'
        '• Max Response Length: $mr characters';
  }

  String _renderProhibitedWords(List<String> w) {
    if (w.isEmpty) return 'No prohibited words set';
    return 'Prohibited Words (${w.length}):\n${w.map((e) => '• $e').join('\n')}';
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF003366)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF003366)),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      style: const TextStyle(fontSize: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Safety Measures',
      currentKey: 'adminSafetyMeasures',
      profile: widget.userProfile,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create or Edit Safety Measures',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 24),

              _textField(controller: _titleController, hint: 'Title'),
              const SizedBox(height: 16),

              _textField(controller: _descriptionController, hint: 'Description', maxLines: 5),
              const SizedBox(height: 16),

              _textField(
                controller: _createdByController,
                hint: 'Created By (email)',
                type: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              _textField(
                controller: _maxResponseLengthController,
                hint: 'Max Response Length',
                type: TextInputType.number,
              ),
              const SizedBox(height: 16),

              _textField(
                controller: _prohibitedWordsController,
                hint: 'Prohibited Words (comma separated)',
                maxLines: 5,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleSaveSafetyMeasure,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007BFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  elevation: 4,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Safety Measures',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 16),

              if (_isLoading) const Center(child: CircularProgressIndicator()),

              if (_successMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _successMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.green, fontSize: 16),
                  ),
                ),

              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),

              const SizedBox(height: 24),

              Text(
                'Existing Safety Guidelines (${_safetyMeasuresList.length})',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004080),
                ),
              ),
              const SizedBox(height: 16),

              if (_safetyMeasuresList.isEmpty)
                const Text(
                  'No safety measures found. Create your first safety measure above.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF666666),
                  ),
                  textAlign: TextAlign.center,
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _safetyMeasuresList.length,
                  itemBuilder: (context, idx) {
                    final s = _safetyMeasuresList[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              s.description,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _renderParameters(s.parameters),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _renderProhibitedWords(s.prohibitedWords),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'By: ${s.createdBy.replaceAll('_', '.')} | Updated: ${_formatDate(s.lastUpdatedAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _createdByController.dispose();
    _maxResponseLengthController.dispose();
    _prohibitedWordsController.dispose();
    super.dispose();
  }
}

class SafetyMeasure {
  String? id;
  final String title;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final Map<String, dynamic> parameters;
  final List<String> prohibitedWords;

  SafetyMeasure({
    this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.parameters,
    required this.prohibitedWords,
  });
}
