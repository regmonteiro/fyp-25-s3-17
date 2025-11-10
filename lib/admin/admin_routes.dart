import 'package:flutter/material.dart';
import '../models/user_profile.dart';

import 'admin_dashboard.dart';              // class AdminDashboard
import 'admin_profile_page.dart';           // class AdminProfilePage
import 'admin_report_page.dart';            // class AdminReportsPage
import 'manage_feedback.dart';              // class AdminFeedbackPage
import 'admin_roles.dart';                  // class AdminRolesPage
import 'admin_safety_measures_page.dart';         // class AdminSafetyMeasuresPage
import 'manage_announcement_page.dart';     // class AdminAnnouncementPage
import 'admin_manage_page.dart';                  // class AdminManagePage
import 'admin_manage_activities_page.dart';
import 'manage_medical_page.dart';
import 'manage_membership.dart';
import 'manage_service_page.dart';

typedef AdminPageBuilder = Widget Function(BuildContext, UserProfile);

final Map<String, AdminPageBuilder> kAdminPages = {
  'adminDashboard'      : (ctx, p) => AdminDashboard(userProfile: p),
  'adminManageActivites' : (ctx, p) => AdminManageActivitiesPage(userProfile: p),
  'adminProfile'        : (ctx, p) => AdminProfilePage(userProfile: p),
  'adminReports'        : (ctx, p) => AdminReportsPage(userProfile: p),
  'adminFeedback'       : (ctx, p) => AdminFeedbackPage(userProfile: p),
  'adminRoles'          : (ctx, p) => AdminRolesPage(userProfile: p),
  'adminSafetyMeasures' : (ctx, p) => AdminSafetyMeasuresPage(userProfile: p),
  'adminAnnouncement'   : (ctx, p) => AdminAnnouncementPage(userProfile: p),
  'adminManage'         : (ctx, p) => AdminManagePage(),
  'adminManageMedical' : (ctx, p) => AdminManageMedical(),
  'adminManageMembership' : (ctx,p) => AdminManageMembership(),
  'adminManageService'  : (ctx,p) => AdminManageService(),
};

void navigateAdmin(BuildContext context, String key, UserProfile profile) {
  final builder = kAdminPages[key];
  if (builder == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unknown admin page: $key')));
    return;
  }
  Navigator.of(context).pushReplacement(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => builder(context, profile),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 180),
    ),
  );
}
