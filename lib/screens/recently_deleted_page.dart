import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class RecentlyDeletedPage extends StatelessWidget {
  const RecentlyDeletedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently Deleted'),
        backgroundColor: AppColors.primaryCyan,
      ),
      body: const Center(
        child: Text(
          'Recently Deleted Items will appear here',
          style: TextStyle(color: AppColors.white, fontSize: 18),
        ),
      ),
    );
  }
}
