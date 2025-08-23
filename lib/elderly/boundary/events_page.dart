import 'package:flutter/material.dart';
import '../controller/events_controller.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final EventsController controller = EventsController();
    return Center(
      child: Text(
        controller.greeting,
        style: const TextStyle(fontSize: 24),
      ),
    );
  }
}