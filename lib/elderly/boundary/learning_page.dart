import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controller/learning_page_controller.dart';
import '../boundary/learning_reward_history.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({Key? key}) : super(key: key);

  @override
  _LearningPageState createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  final LearningPageController _controller = LearningPageController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allLearningTopics = [];
  List<Map<String, dynamic>> _filteredLearningTopics = [];
  List<Map<String, dynamic>> _allActivities = [];
  List<Map<String, dynamic>> _filteredActivities = [];

  @override
  void initState() {
    super.initState();
    _controller.fetchLearningData().then((data) {
      setState(() {
        // Corrected casting to resolve the type error
        _allLearningTopics = (data['learningTopics'] as List<dynamic>).map((item) => item as Map<String, dynamic>).toList();
        _filteredLearningTopics = List.from(_allLearningTopics);
        _allActivities = (data['activities'] as List<dynamic>).map((item) => item as Map<String, dynamic>).toList();
        _filteredActivities = List.from(_allActivities);
      });
    });
    _searchController.addListener(_filterContent);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterContent);
    _searchController.dispose();
    super.dispose();
  }

  void _filterContent() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredLearningTopics = _allLearningTopics.where((topic) {
        return topic['title'].toLowerCase().contains(query) ||
            topic['description'].toLowerCase().contains(query) ||
            (topic['tags'] as List).any((tag) => tag.toLowerCase().contains(query));
      }).toList();

      _filteredActivities = _allActivities.where((activity) {
        return activity['title'].toLowerCase().contains(query) ||
            activity['description'].toLowerCase().contains(query) ||
            (activity['tags'] as List).any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search learning or activities...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionTitle(context, 'Learning Resources Library'),
            _buildLearningTopicsSection(),
            _buildSectionTitle(context, 'Activities on AllCare Platform'),
            _buildActivitiesSection(),
            const SizedBox(height: 16),
            _buildSectionTitle(context, 'Connect with the Community'),
            _buildConnectSection(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Text('My Learning', style: TextStyle(color: Colors.white, fontSize: 20)),
                IconButton(
                  icon: const Icon(Icons.notifications_none, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPointsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsSection(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _controller.getRewardPointsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildPointsCard(0, 0);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final int currentPoints = data['currentPoints'] ?? 0;
        final int totalEarned = data['totalEarned'] ?? 0;

        return _buildPointsCard(currentPoints, totalEarned);
      },
    );
  }

  Widget _buildPointsCard(int currentPoints, int totalEarned) {
    final bool isRedeemable = currentPoints >= 50;
    final int voucherValue = (currentPoints ~/ 50) * 5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Reward Points', style: TextStyle(color: Colors.grey)),
                  Text(
                    '$currentPoints Points',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (isRedeemable)
                ElevatedButton(
                  onPressed: () => _showRedeemDialog(context, voucherValue),
                  child: const Text('Redeem'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Points Earned: $totalEarned'),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LearningRewardHistoryPage()),
                  );
                },
                child: const Text('Redemption History >'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRedeemDialog(BuildContext context, int voucherValue) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Redeem your voucher!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You have $voucherValue points. This is redeemable for a \$$voucherValue Hao Mart voucher.'),
              const SizedBox(height: 10),
              const Text('Terms & Conditions:'),
              const Text('- Vouchers are valid for 30 days after redemption.'),
              const Text('- Vouchers can be used at any Hao Mart outlet.'),
              const Text('- Vouchers can be used for any purchases.'),
              const SizedBox(height: 10),
              const Text('Do you want to redeem now?'),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Redeem'),
              onPressed: () {
                _controller.redeemVoucher(voucherValue).then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Voucher redeemed successfully!')),
                  );
                }).catchError((error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to redeem voucher: $error')),
                  );
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLearningTopicsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: _filteredLearningTopics.isEmpty
          ? const Center(child: Text('No learning topics found.'))
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: _filteredLearningTopics.length,
              itemBuilder: (context, index) {
                final topic = _filteredLearningTopics[index];
                return _buildLearningCard(topic);
              },
            ),
    );
  }

  Widget _buildLearningCard(Map<String, dynamic> topic) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: InkWell(
        onTap: () {
          _controller.completeLearningTopic(topic['title']);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Completed "${topic['title']}" and earned 2 points!')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic['title'],
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  topic['description'],
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 4,
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (topic['tags'] as List).map((tag) => Chip(label: Text(tag))).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivitiesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: _filteredActivities.isEmpty
          ? const Center(child: Text('No activities found.'))
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: _filteredActivities.length,
              itemBuilder: (context, index) {
                final activity = _filteredActivities[index];
                return _buildActivityCard(activity);
              },
            ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _controller.completeActivity(activity['title']);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registered for "${activity['title']}" and earned 10 points!')),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              activity['image_url'],
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity['description'],
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (activity['tags'] as List).map((tag) => Chip(label: Text(tag))).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConnectSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, 'Connect with other Elderlies'),
          const SizedBox(height: 8),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                // Navigate to a community page or chat
                print('Connecting with community...');
              },
              icon: const Icon(Icons.people_alt),
              label: const Text('Find your community'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}