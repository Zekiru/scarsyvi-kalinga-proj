import 'package:flutter/material.dart';

class StudentListScreen extends StatelessWidget {
  const StudentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Roster Directory')),
      body: const Center(
        child: Text('Filter & View Students Across All Classrooms'),
      ),
    );
  }
}
