import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  double _textScale = 1.0; // 100%
  double get textScale => _textScale;

  void setTextScale(double value) {
    if (value <= 0) return;
    _textScale = value;
    notifyListeners();
  }
}
