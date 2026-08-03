import 'dart:convert';
import 'package:http/http.dart' as http;

class DeepSeekService {
  final String apiKey;
  final String baseUrl;

  DeepSeekService({
    required this.apiKey,
    this.baseUrl = 'https://api.deepseek.com/chat/completions',
  });

  /// Parse raw SMS text with DeepSeek API as fallback if local parsing is incomplete.
  Future<Map<String, String>?> parseSmsFallback(String smsText) async {
    if (apiKey.isEmpty || apiKey == 'YOUR_DEEPSEEK_API_KEY') {
      print('DeepSeek API Key not configured.');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': [
            {
              'role': 'system',
              'content': 'You are an SMS parser assistant for Indian banking and UPI messages. '
                  'Extract the merchant name and financial category from the raw SMS. '
                  'Respond STRICTLY in JSON format without markdown code blocks: '
                  '{"merchant_name": "clean string", "category": "category string"}'
            },
            {
              'role': 'user',
              'content': 'Extract merchant name and category from this SMS: "$smsText"'
            }
          ],
          'temperature': 0.1,
          'response_format': {'type': 'json_object'}
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content != null) {
          final Map<String, dynamic> parsedJson = jsonDecode(content.trim());
          return {
            'merchant_name': parsedJson['merchant_name']?.toString() ?? 'Unknown Merchant',
            'category': parsedJson['category']?.toString() ?? 'General',
          };
        }
      } else {
        print('DeepSeek API HTTP error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('DeepSeek Service Exception: $e');
    }
    return null;
  }
}
