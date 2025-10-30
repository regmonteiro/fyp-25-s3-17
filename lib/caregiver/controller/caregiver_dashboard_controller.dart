// lib/caregiver/controller/caregiver_dashboard_controller.dart
import 'package:flutter/foundation.dart';

/// Controls high-level UI state for the caregiver dashboard:
/// - current bottom-tab index
/// - the selected elder UID (so Create Events can target it)
///
/// Keep data/Firestore logic in CaregiverHomeController (Home tab),
/// not here.
class CaregiverDashboardController with ChangeNotifier {
  // ---- State ----
  int _index = 0;
  String? _selectedElderId;

  // ---- Getters ----
  int get index => _index;
  String? get selectedElderId => _selectedElderId;

  /// Optional: Titles to mirror your tabs (keep in sync with the page).
  /// This lets you read a title here if you prefer (not required by your page).
  static const List<String> tabTitles = <String>[
    'Home',
    'Create Events',
    'AI Assistant',
    'Reports',
    'Account',
  ];

  String get currentTitle =>
      (index >= 0 && index < tabTitles.length) ? tabTitles[index] : 'Dashboard';

  /// Whether the FAB on the Create Events tab should show.
  bool get isFabVisible => _index == 1 && _selectedElderId != null;

  // ---- Mutators ----
  void setIndex(int i) {
    if (i == _index) return;
    _index = i;
    notifyListeners();
  }

  /// Called by Home tab when user taps a linked elder.
  /// Also jumps to the Create Events tab (to match your page behavior).
  void selectElder(String elderUid) {
    _selectedElderId = elderUid;
    _index = 1; // jump to "Create Events"
    notifyListeners();
  }

  /// Clear the selected elder (e.g., user navigates away or chooses none).
  void clearSelectedElder() {
    if (_selectedElderId == null) return;
    _selectedElderId = null;
    notifyListeners();
  }

  /// Convenience: programmatically open Create Events (keep elder if set).
  void goToCreateEvents({String? elderUid}) {
    if (elderUid != null) {
      _selectedElderId = elderUid;
    }
    _index = 1;
    notifyListeners();
  }

  /// Convenience: programmatically go home.
  void goHome() {
    if (_index == 0) return;
    _index = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    // No streams here. Just call super.
    super.dispose();
  }
}

