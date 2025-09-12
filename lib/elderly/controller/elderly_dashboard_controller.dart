class ElderlyDashboardController {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void onItemTapped(int index) {
    _selectedIndex = index;
    // Notify listeners to rebuild the UI, if using a state management solution.
    // For this simple example, the StatefulWidget will handle the setState.
  }
}