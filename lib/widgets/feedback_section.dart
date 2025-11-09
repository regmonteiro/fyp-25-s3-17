import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/feedback_model.dart';
import '../services/feedback_service.dart';

class FeedbackSection extends StatefulWidget {
  const FeedbackSection({super.key});

  @override
  State<FeedbackSection> createState() => _FeedbackSectionState();
}

class _FeedbackSectionState extends State<FeedbackSection> {
  final _svc = FeedbackService();

  // carousel
  int _index = 0;

  // form state
  bool _showForm = false;
  bool _submitting = false;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  String _initialsFromEmail(String email) {
    if (email.isEmpty) return '?';
    final namePart = email.split('@').first;
    final parts = namePart.split(RegExp(r'[.\-_]')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return namePart[0].toUpperCase();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _next(List<FeedbackModel> list) {
    setState(() {
      _index = (_index + 3 >= list.length) ? 0 : _index + 3;
    });
  }

  void _prev(List<FeedbackModel> list) {
    setState(() {
      _index = (_index - 3 < 0) ? (list.length <= 3 ? 0 : list.length - 3) : _index - 3;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await _svc.addFeedback(
        userName: _nameCtrl.text,
        userEmail: _emailCtrl.text,
        rating: _rating,
        comment: _commentCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback!')),
      );
      setState(() {
        _showForm = false;
        _rating = 0;
      });
      _nameCtrl.clear();
      _emailCtrl.clear();
      _commentCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting feedback: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xffeef1ff),
      padding: const EdgeInsets.symmetric(vertical: 32),
      width: double.infinity,
      child: StreamBuilder<List<FeedbackModel>>(
        stream: _svc.streamAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ));
          }
          final list = snap.data ?? <FeedbackModel>[];

          return Column(
            children: [
              const Text(
                'What Our Users Say',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xff2d2d5a)),
              ),
              const SizedBox(height: 20),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: Text(
                    'No feedback yet. Be the first to share your experience!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        final three = list.skip(_index).take(3).toList();
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: three.map((fb) => _FeedbackCard(
                            initials: _initialsFromEmail(fb.userEmail),
                            nameOrEmail: fb.userName.isNotEmpty ? fb.userName : fb.userEmail,
                            comment: fb.comment,
                            rating: fb.rating,
                          )).toList(),
                        );
                      },
                    ),
                    if (list.length > 3) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _roundBtn(icon: Icons.chevron_left, onPressed: () => _prev(list)),
                          const SizedBox(width: 12),
                          _roundBtn(icon: Icons.chevron_right, onPressed: () => _next(list)),
                        ],
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => setState(() => _showForm = true),
                child: const Text('Share Feedback'),
              ),
              const SizedBox(height: 8),
              if (_showForm) _formDialog(context),
            ],
          );
        },
      ),
    );
  }

  Widget _roundBtn({required IconData icon, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xff7877ed), width: 2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xff7877ed)),
      ),
    );
  }

  Widget _formDialog(BuildContext ctx) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Stack(
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: Text('Share Feedback',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => setState(() => _showForm = false),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
                  return ok ? null : 'Enter a valid email';
                },
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    const Text('Your Rating'),
                    Wrap(
                      spacing: 6,
                      children: List.generate(5, (i) {
                        final star = i + 1;
                        final selected = star <= _rating;
                        return InkWell(
                          onTap: () => setState(() => _rating = star),
                          child: Icon(
                            Icons.star,
                            size: 28,
                            color: selected ? const Color(0xffffc107) : const Color(0xffe2e2f0),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _commentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your Feedback',
                  border: OutlineInputBorder(),
                ),
                minLines: 3,
                maxLines: 6,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: Text(_submitting ? 'Submitting…' : 'Submit Feedback'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => setState(() => _showForm = false),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final String initials;
  final String nameOrEmail;
  final String comment;
  final int rating;

  const _FeedbackCard({
    required this.initials,
    required this.nameOrEmail,
    required this.comment,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 330,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xff7877ed), Color(0xff5a59d3)]),
              ),
              child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(nameOrEmail, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xff2d2d5a))),
            ),
          ]),
          const SizedBox(height: 12),
          Text(comment, style: const TextStyle(color: Colors.black87, height: 1.4)),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (i) {
              final filled = i < rating;
              return Icon(filled ? Icons.star : Icons.star_border,
                  size: 20, color: const Color(0xffffc107));
            }),
          ),
        ],
      ),
    );
  }
}
