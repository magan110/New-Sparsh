import 'dart:convert';
import 'package:http/http.dart' as http;

/// Singleton class for handling all API calls.
/// Call ApiService.instance.method() to use.
class ApiService {
  ApiService._privateConstructor();

  static final ApiService instance = ApiService._privateConstructor();

  final String _baseUrl = 'https://qa.birlawhite.com:55232/api';

  Future<Map<String, dynamic>> scanToken(String tokenNum) async {
    final url = Uri.parse('$_baseUrl/TokenScan/scan');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tokenNum': tokenNum}),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'body': response.body};
      } else {
        return {'success': false, 'body': response.body};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> validateTokenPin(String tokenNum, String pin) async {
    final url = Uri.parse('$_baseUrl/TokenValidate/validate');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "tokenNum": tokenNum,
          "tokenCvv": pin,
        }),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'body': response.body};
      } else {
        return {'success': false, 'body': response.body};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fetchFailedTokenInfo(String tokenNum) async {
    final url = Uri.parse('$_baseUrl/TokenScan/failedInfo');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tokenNum': tokenNum}),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'body': response.body};
      } else {
        return {'success': false, 'body': response.body};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}