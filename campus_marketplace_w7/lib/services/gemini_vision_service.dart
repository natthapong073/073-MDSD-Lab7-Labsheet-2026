import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/listing_draft.dart';

class GeminiVisionService {
  static const _model = 'gemini-3.5-flash-lite';
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  Future<ListingDraft> analyzeProductImage(File imageFile, {required String prompt}) async {
    if (_apiKey.isEmpty) {
      throw Exception('ไม่พบ GEMINI_API_KEY กรุณารันด้วย --dart-define');
    }

    final uri = Uri.parse('$_baseUrl?key=$_apiKey');

    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);

    final requestBody = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {
              "inline_data": {
                "mime_type": "image/jpeg",
                "data": base64Image
              }
            }
          ]
        }
      ],
      "generationConfig": {
        "responseMimeType": "application/json",
        "responseSchema": {
          "type": "OBJECT",
          "properties": {
            "title": {"type": "STRING"},
            "category": {"type": "STRING"},
            "description": {"type": "STRING"}
          },
          "required": ["title", "category", "description"]
        }
      }
    });

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // ตรวจสอบกรณีที่ candidates ว่างเปล่า (ถูกบล็อก)
        if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
          throw Exception('AI ไม่สามารถวิเคราะห์ภาพนี้ได้ อาจเข้าข่ายเนื้อหาที่ไม่เหมาะสม ลองใช้ภาพอื่น');
        }

        final candidate = data['candidates'][0];
        
        // ตรวจสอบกรณี finishReason เป็น SAFETY
        if (candidate['finishReason'] == 'SAFETY') {
          throw Exception('เนื้อหาที่วิเคราะห์เข้าข่ายไม่ปลอดภัยตามนโยบายของ Gemini กรุณาใช้ภาพอื่น');
        }

        final textResponse = candidate['content']['parts'][0]['text'];
        final jsonDraft = jsonDecode(textResponse);
        
        return ListingDraft.fromJson(jsonDraft);
      } else {
        throw Exception('การวิเคราะห์ผิดพลาด: ${response.statusCode}');
      }
    } catch (e) {
      // ส่งผ่าน Error ที่ดักไว้ให้ UI แสดงผล
      throw Exception('$e');
    }
  }
}