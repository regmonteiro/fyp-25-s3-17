import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'controller/health_records_controller.dart';

class HealthUploadPage extends StatefulWidget {
  const HealthUploadPage({Key? key}) : super(key: key);

  @override
  State<HealthUploadPage> createState() => _HealthUploadPageState();
}

class _HealthUploadPageState extends State<HealthUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _recordType = 'Lab Results';
  DateTime _docDate = DateTime.now();

  final List<File> _files = [];
  bool _uploading = false;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null) return;

    final pickedPaths = result.paths.whereType<String>().toList();
    final pickedFiles = pickedPaths.map((p) => File(p)).toList();

    setState(() {
      _files.addAll(pickedFiles);
      if (_files.length > 10) {
        _files.removeRange(10, _files.length);
      }
    });
  }

  Future<void> _takePhoto() async {
    // Note: on web, dart:io File isn’t available; this flow targets mobile
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera capture is not supported in web for this upload flow.')),
      );
      return;
    }
    final XFile? shot = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85, // a bit of compression
      maxWidth: 2000,   // keep file size reasonable
    );
    if (shot == null) return;

    setState(() {
      _files.add(File(shot.path));
      if (_files.length > 10) {
        _files.removeRange(10, _files.length);
      }
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _docDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _docDate = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or capture at least one file.')),
      );
      return;
    }

    setState(() => _uploading = true);
    final controller = context.read<HealthRecordsController>();

    try {
      final ok = await controller.uploadRecords(
        recordName: _nameCtrl.text.trim(),
        recordType: _recordType,
        documentDate: _docDate,
        files: _files, // stays as List<File>
      );

      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload successful')),
        );
        setState(() {
          _files.clear();
          _nameCtrl.clear();
          _recordType = 'Lab Results';
          _docDate = DateTime.now();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: _uploading,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Record name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a record name' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _recordType,
                decoration: const InputDecoration(
                  labelText: 'Record type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Lab Results', child: Text('Lab Results')),
                  DropdownMenuItem(value: 'Radiology', child: Text('Radiology')),
                  DropdownMenuItem(value: 'Immunisations', child: Text('Immunisations')),
                  DropdownMenuItem(value: 'Consultation Documents', child: Text('Consultation Documents')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _recordType = v ?? 'Lab Results'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Document date'),
                subtitle: Text(
                  '${_docDate.year}-${_docDate.month.toString().padLeft(2, '0')}-${_docDate.day.toString().padLeft(2, '0')}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.date_range),
                  onPressed: _pickDate,
                ),
              ),
              const SizedBox(height: 8),

              if (_files.isNotEmpty)
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: _files
                          .asMap()
                          .entries
                          .map((e) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.insert_drive_file),
                                title: Text(e.value.path.split('/').last),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () => setState(() => _files.removeAt(e.key)),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),

              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Select files'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Take photo'),
                  ),
                  const SizedBox(width: 12),
                  if (_uploading) const SizedBox(height: 24, width: 24, child: CircularProgressIndicator()),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _submit,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Upload'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
