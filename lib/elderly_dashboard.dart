import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ElderlyDashboard extends StatefulWidget {
  const ElderlyDashboard({super.key});

  @override
  State<ElderlyDashboard> createState() => _ElderlyDashboardState();
}

class _ElderlyDashboardState extends State<ElderlyDashboard> {
  String userName = "";
  List<Map<String, dynamic>> eventReminders = [];

  @override
  void initState() {
    super.initState();
    fetchUserName();
    fetchEventReminders();
  }

  Future<void> fetchUserName() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        setState(() {
          userName = "${doc['firstName']} ${doc['lastName']}";
        });
      }
    } catch (e) {
      setState(() {
        userName = "User";
      });
    }
  }

  Future<void> fetchEventReminders() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: uid)
          .get();

      setState(() {
        eventReminders = querySnapshot.docs
            .map((doc) => {
                  "title": doc['title'],
                  "date": doc['date'],
                  "time": doc['time'],
                })
            .toList();
      });
    } catch (e) {
      print("Error fetching events: $e");
    }
  }

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // You can navigate to other pages here (Profile, Events, Social)
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Elderly Dashboard")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Assistant Greeting
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  "Hello $userName! How can I assist you today?",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Event Reminders
            const Text("Event Reminders",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            eventReminders.isEmpty
                ? const Text("No upcoming events.")
                : Column(
                    children: eventReminders.map((event) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.event),
                          title: Text(event["title"]),
                          subtitle: Text("${event["date"]} • ${event["time"]}"),
                        ),
                      );
                    }).toList(),
                  ),

            const SizedBox(height: 16),

            // Chatbot UI
            const Text("AI Assistant Chat",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text("Chatbot conversation area..."),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: "Type your message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: "Events"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Social"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

