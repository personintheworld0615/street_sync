import 'package:flutter/material.dart';

class CommunityReportScreen extends StatefulWidget {
  const CommunityReportScreen({super.key});

  @override
  State<CommunityReportScreen> createState() => _CommunityReportScreenState();
}

class _CommunityReportScreenState extends State<CommunityReportScreen> {
  String? _selectedCategory;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Community Report', 
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                )
              ),
            SizedBox(height: 2),
            Text('Capture and report issues as you walk', style: TextStyle(fontSize: 15)),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 76, 175, 80),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  height: 270,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.add_a_photo_outlined,
                            size: 40,
                            color: Colors.blue,
                          ),
                          onPressed: () {
                            // Handle photo capture button press
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Take a photo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text (
                        'Tap to capture or upload',
                        style : TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: const Text (
                          '----------or----------',
                        ),
                      ),
                      Row (
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.file_upload_outlined,
                              size: 30,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              // Handle file upload button press
                            },
                          ),
                          const Text(
                            'Upload from library',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ),
                ),
                Container (
                  height: 150,
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text (
                        'Issue Category',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      Row (
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                // Handle tap on Road Damage category
                                setState(() {
                                  _selectedCategory = 'Road Damage';
                                });
                              },
                              child: Container(
                                height: 50,
                                margin: const EdgeInsets.only(top: 10, right: 5),
                                decoration: BoxDecoration(
                                  color: _selectedCategory == 'Road Damage' ? const Color.fromARGB(255, 255, 236, 236) : Colors.white,
                                  border: Border.all(color: _selectedCategory == 'Road Damage' ? Colors.red : Colors.white, width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Text('Road Damage'),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                // Handle tap on Public Works category
                                setState(() {
                                  _selectedCategory = 'Public Works';
                                });
                              },
                              child: Container(
                                height: 50,
                                margin: const EdgeInsets.only(top: 10, right: 5),
                                decoration: BoxDecoration(
                                  color: _selectedCategory == 'Public Works' ? const Color.fromARGB(255, 255, 242, 221) : Colors.white,
                                  border: Border.all(color: _selectedCategory == 'Public Works' ? Colors.orange : Colors.white, width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Text('Public Works'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row (
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                // Handle tap on Environmental category
                                setState(() {
                                  _selectedCategory = 'Environmental';
                                });
                              },
                              child: Container(
                                height: 50,
                                margin: const EdgeInsets.only(top: 10, right: 5),
                                decoration: BoxDecoration(
                                  color: _selectedCategory == 'Environmental' ? const Color.fromARGB(255, 212, 255, 214) : Colors.white,
                                  border: Border.all(color: _selectedCategory == 'Environmental' ? Colors.green : Colors.white, width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Text('Environmental'),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                // Handle tap on Accessibility category
                                setState(() {
                                  _selectedCategory = 'Accessibility';
                                });
                              },
                              child: Container(
                                height: 50,
                                margin: const EdgeInsets.only(top: 10, right: 5),
                                decoration: BoxDecoration(
                                  color: _selectedCategory == 'Accessibility' ? const Color.fromARGB(255, 250, 223, 255) : Colors.white,
                                  border: Border.all(color: _selectedCategory == 'Accessibility' ? Colors.purple : Colors.white, width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Text('Accessibility'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container (
                  height: 200,
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text (
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        height: 150,
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: TextField(
                            maxLines: null,
                            expands: true,
                            decoration: InputDecoration(
                              hintText: 'Describe the issue...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container (
                  height: 50,
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 20),
                  child: ElevatedButton(
                    onPressed: () {
                      // Handle submit button press
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 76, 175, 80),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Submit Report',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  )
                )
              ],
            ),
          ),
      ),
    );
  }
}