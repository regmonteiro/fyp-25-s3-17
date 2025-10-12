// Web impl that calls the real platformViewRegistry.
import 'dart:ui' as ui;

typedef ViewFactory = dynamic Function(int);

// ignore: undefined_prefixed_name
void registerViewFactory(String viewType, ViewFactory factory) {
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(viewType, factory);
}
