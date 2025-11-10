// lib/admin/admin_manage_page.dart
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import 'admin_shell.dart';
import 'admin_navigation.dart';
import 'admin_routes.dart';

class AdminManagePage extends StatefulWidget {
  final UserProfile? userProfile; // keep compatible with your map

  const AdminManagePage({super.key, this.userProfile});

  @override
  State<AdminManagePage> createState() => _AdminManagePageState();
}

class _AdminManagePageState extends State<AdminManagePage> {
  UserProfile get _profile =>
      widget.userProfile ??
      UserProfile.empty(); // ensure you have a .empty() or adapt accordingly

  void _go(String key) => navigateAdmin(context, key, _profile);

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Manage',
      currentKey: 'adminManage',
      profile: _profile,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final spacing = 16.0;

          Widget card({
            required String title,
            required String subtitle,
            required IconData icon,
            required VoidCallback onTap,
            Color color = const Color(0xFF6A1B9A), // purple 800-ish
          }) {
            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  height: 140,
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, size: 28, color: color),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.black54),
                    ],
                  ),
                ),
              ),
            );
          }

          final grid = GridView.count(
            crossAxisCount: isWide ? 2 : 1,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: isWide ? 2.8 : 2.6,
            shrinkWrap: true,
            children: [
              card(
                title: 'Activities',
                subtitle: 'Create, edit, and review community activities',
                icon: Icons.event_note_outlined,
                onTap: () => _go('adminManageActivites'), // note: your key spelling
                color: Colors.indigo,
              ),
              card(
                title: 'Medical Products',
                subtitle: 'Manage catalogue, orders, and analytics',
                icon: Icons.local_hospital_outlined,
                onTap: () => _go('adminManageMedical'),
                color: Colors.teal,
              ),
              card(
                title: 'Membership',
                subtitle: 'Plans, approvals, and member records',
                icon: Icons.group_outlined,
                onTap: () => _go('adminManageMembership'),
                color: Colors.blue,
              ),
              card(
                title: 'Services',
                subtitle: 'Service listings & bookings (coming soon)',
                icon: Icons.handyman_outlined,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Services management coming soon')),
                  );
                },
                color: Colors.deepOrange,
              ),
            ],
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What would you like to manage?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Jump into a module below to configure data and workflows.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 20),
                  grid,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
