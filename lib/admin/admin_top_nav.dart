import 'package:flutter/material.dart';

class ADNavigation extends StatelessWidget {
  final String currentKey;
  final void Function(String) onNavigationChanged;

  const ADNavigation({
    Key? key,
    required this.currentKey,
    required this.onNavigationChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget item(String text, String key, IconData icon, {bool last = false}) {
      final sel = currentKey == key;
      final purple = Colors.purple.shade500;
      return Container(
        margin: EdgeInsets.only(right: last ? 16 : 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onNavigationChanged(key),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: sel
                  ? BoxDecoration(color: purple, borderRadius: BorderRadius.circular(20))
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: sel ? Colors.white : purple),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : purple,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          item('Dashboard',        'adminDashboard',      Icons.dashboard_outlined),
          item('Profile',          'adminProfile',        Icons.person_outline),
          item('Reports',          'adminReports',        Icons.assessment_outlined),
          item('Feedback',         'adminFeedback',       Icons.chat_bubble_outline),
          item('Roles',            'adminRoles',          Icons.admin_panel_settings_outlined),
          item('Safety Measures',  'adminSafetyMeasures', Icons.health_and_safety_outlined),
          item('Announcement',     'adminAnnouncement',   Icons.campaign_outlined),
          item('Manage',           'adminManage',         Icons.tune, last: true),
        ]),
      ),
    );
  }
}
