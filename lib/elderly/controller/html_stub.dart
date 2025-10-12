// html_stub.dart
// Non-web stub so code compiles on mobile/desktop.

class _NoopDoc {
  dynamic querySelector(String _) => null;
  dynamic get body => null;
}

class _NoopElement {
  void setAttribute(String _, String __) {}
  void addEventListener(String _, void Function(dynamic) __) {}
}

class _NoopBody {
  void append(dynamic _) {}
}

class _NoopInput {
  String? value;
  void dispatchEvent(dynamic _) {}
}

class _NoopButton {
  void click() {}
}

final document = _NoopDoc();

class DivElement extends _NoopElement {
  final style = _Style();
}

class Element extends _NoopElement {
  Element.tag(String _);
}

class ScriptElement extends _NoopElement {
  late String src;
  late bool async;
}

class InputElement extends _NoopInput {}
class ButtonElement extends _NoopButton {}

class Event {
  Event(String type, {bool? bubbles});
}

class _Style {
  String? width;
  String? height;
}
