import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import 'controller/health_records_controller.dart';
import 'health_upload_page.dart';
import '../caregiver/boundary/caregiver_home_page.dart';

class CaregiverHealthUploadPage extends StatefulWidget {
  final UserProfile caregiver;
  const CaregiverHealthUploadPage({super.key, required this.caregiver});

  @override
  State<CaregiverHealthUploadPage> createState() => _CaregiverHealthUploadPageState();
}

class _CaregiverHealthUploadPageState extends State<CaregiverHealthUploadPage> {
  bool _loading = true;
  String? _selectedElderUid;
  List<_ElderOpt> _options = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final me = widget.caregiver;
    final doc = await FirebaseFirestore.instance.collection('Account').doc(me.uid).get();
    final data = doc.data() ?? {};

    List<String> _asStringList(Object? raw) {
      if (raw is List) {
        return raw.map((e) => e is String ? e.trim() : e?.toString() ?? '')
                  .where((s) => s.isNotEmpty).toList();
      }
      return const [];
    }

    final ids = <String>{
      ..._asStringList(data['elderlyIds']),
      if ((data['elderlyId'] as String?)?.isNotEmpty == true) (data['elderlyId'] as String),
      ..._asStringList(data['linkedElderlyIds']),
    }.toList();

    // Resolve simple display names for dropdown
    final opts = <_ElderOpt>[];
    for (final id in ids) {
      final ed = await FirebaseFirestore.instance.collection('Account').doc(id).get();
      final m = ed.data() ?? {};
      final safe = (m['safeDisplayName'] ?? m['displayName'])?.toString().trim() ?? '';
      final first = (m['firstname'] ?? m['firstname'])?.toString().trim() ?? '';
      final last  = (m['lastname']  ?? m['lastname']) ?.toString().trim() ?? '';
      final full  = [first, last].where((s) => s.isNotEmpty).join(' ').trim();
      final email = (m['email'] ?? '').toString();
      final name  = safe.isNotEmpty ? safe : (full.isNotEmpty ? full : (email.isNotEmpty ? email : id));
      opts.add(_ElderOpt(uid: id, label: name));
    }

    setState(() {
      _options = opts;
      _selectedElderUid = opts.isNotEmpty ? opts.first.uid : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_selectedElderUid == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Upload Health Records'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => CaregiverHomePage(userProfile: widget.caregiver)),
              );
            },
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No linked elderly profiles found.\nLink an elderly to upload health records for them.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final controller = HealthRecordsController(elderlyId: _selectedElderUid!);

    return ChangeNotifierProvider.value(
      value: controller,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Upload Health Records'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => CaregiverHomePage(userProfile: widget.caregiver)),
              );
            },
          ),
          actions: [
            if (_options.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedElderUid,
                    items: _options.map((o) =>
                      DropdownMenuItem<String>(value: o.uid, child: Text(o.label))
                    ).toList(),
                    onChanged: (v) {
                      if (v == null || v == _selectedElderUid) return;
                      setState(() => _selectedElderUid = v);
                    },
                  ),
                ),
              ),
          ],
        ),
        body: const HealthUploadPage(),
      ),
    );
  }
}

class _ElderOpt {
  final String uid;
  final String label;
  _ElderOpt({required this.uid, required this.label});
}
