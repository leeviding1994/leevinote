import 'package:flutter/material.dart';

class AlarmsScreen extends StatelessWidget {
  const AlarmsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.alarm_add, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('闹钟功能开发中...'),
        ],
      ),
    );
  }
}
