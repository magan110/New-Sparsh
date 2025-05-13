import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'token_summary.dart';

class TokenDetailsPage extends StatefulWidget {
  final String activeTab;
  final List<String>? tokens;

  const TokenDetailsPage({super.key, this.activeTab = 'Details', this.tokens});

  @override
  State<TokenDetailsPage> createState() => _TokenDetailsPageState();
}

class _TokenDetailsPageState extends State<TokenDetailsPage> {
  late Future<List<Map<String, dynamic>>> tokenDataFuture;
  late List<String> tokens;

  @override
  void initState() {
    super.initState();
    tokens = widget.tokens ?? ['08WX1NDVTPKB', '15TY8BGFWCNH', 'XTR9PU5RXT00'];
    tokenDataFuture = fetchTokenData();
  }

  Future<List<Map<String, dynamic>>> fetchTokenData() async {
    final url = Uri.parse('https://qa.birlawhite.com:55232/api/TokenScan/scan');
    List<Map<String, dynamic>> tokenResults = [];

    for (String token in tokens) {
      try {
        final response = await http.post(url, body: {'token': token});
        final data = jsonDecode(response.body);

        final isValid = data['success'] == true || data['isValid'] == true;

        tokenResults.add({
          'token': token,
          'isValid': isValid,
          'id': isValid ? (data['id']?.toString() ?? '') : '',
          'date': isValid ? (data['date']?.toString() ?? '') : '',
          'value': isValid ? (data['value']?.toString() ?? '') : '',
          'handling': isValid ? (data['handling']?.toString() ?? '') : '',
          'pin': isValid ? (data['pin']?.toString() ?? '') : '',
        });
      } catch (_) {
        tokenResults.add({'token': token, 'isValid': false});
      }
    }
    return tokenResults;
  }

  void _navigateToTab(String tab) {
    if (tab == 'Details') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => TokenDetailsPage(activeTab: 'Details', tokens: tokens),
        ),
      );
    } else if (tab == 'Summary') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => TokenSummaryScreen(activeTab: 'Summary', tokens: tokens),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Token Details'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildTopNav(context, widget.activeTab),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: tokenDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text("Error fetching tokens: ${snapshot.error}"),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No token data found."));
                }
                final tokens = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: tokens.length,
                  itemBuilder: (context, index) {
                    final token = tokens[index];
                    return _buildTokenCard(token);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNav(BuildContext context, String activeTab) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(
              context,
              'Details',
              activeTab == 'Details',
              () => _navigateToTab('Details'),
            ),
            _navItem(
              context,
              'Summary',
              activeTab == 'Summary',
              () => _navigateToTab('Summary'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          onTap();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isActive
                  ? const Color.fromRGBO(0, 112, 183, 1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildTokenCard(Map<String, dynamic> tokenData) {
    final isValid = tokenData['isValid'] == true;
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.0),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 6.0,
            ),
            decoration: BoxDecoration(
              color: isValid ? Colors.blue : Colors.red,
              borderRadius: BorderRadius.circular(5.0),
            ),
            child: Text(
              tokenData['token'] ?? '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10.0),
            color: Colors.white,
            child:
                isValid
                    ? _buildValidDetails(tokenData)
                    : _buildErrorCard(tokenData['token']),
          ),
        ],
      ),
    );
  }

  Widget _buildValidDetails(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data['id'] != null && data['id'] != '')
          Text(
            data['id'],
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        if (data['date'] != null && data['date'] != '')
          Text(
            'Valid Upto - ${data['date']}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        if (data['value'] != null && data['value'] != '')
          Text(
            'Value To Pay - ${data['value']}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (data['handling'] != null && data['handling'] != '')
              Text(
                'Handling - ${data['handling']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            Row(
              children: [
                if (data['pin'] != null && data['pin'] != '') ...[
                  const Text('PIN', style: TextStyle(color: Colors.grey)),
                  const SizedBox(width: 5),
                  Container(
                    width: 50,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                    child: Text(
                      data['pin'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('Accepted', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildErrorCard(String token) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Error - $token',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const Text(
          'Please check with IT or Company Officer',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('Rejected', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
