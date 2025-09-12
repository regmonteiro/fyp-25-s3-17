import 'package:flutter/material.dart';
import '../controller/learning_page_controller.dart';

class LearningPage extends StatelessWidget {
  const LearningPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final LearningPageController controller = LearningPageController();
    return Center(
      child: Text(
        controller.greeting,
        style: const TextStyle(fontSize: 24),
      ),
    );
  }
}