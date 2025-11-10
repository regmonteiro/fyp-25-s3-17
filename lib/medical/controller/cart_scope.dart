import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'cart_controller.dart';

class EnsureCartProvider extends StatelessWidget {
  final Widget child;
  const EnsureCartProvider({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    CartController? existing;
    try {
      existing = Provider.of<CartController>(context, listen: false);
    } catch (_) {
      existing = null;
    }
    if (existing != null) return child;

    return ChangeNotifierProvider<CartController>(
      create: (_) => CartController(),
      child: child,
    );
  }
}
