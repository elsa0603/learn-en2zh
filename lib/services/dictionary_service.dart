import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/text_clean.dart';

class DictionaryEntry {
  final String word;
  final String? phonetic;
  final String? partOfSpeech;
  final String definition;
  final String? example;

  DictionaryEntry({
    required this.word,
    this.phonetic,
    this.partOfSpeech,
    required this.definition,
    this.example,
  });
}

class DictionaryService {
  Future<DictionaryEntry?> lookup(String rawWord) async {
    final word = cleanWord(rawWord);
    if (word.isEmpty) return null;

    final url =
        Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$word');

    try {
      final res = await http.get(url);
      if (res.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(res.body);
      if (data is! List || data.isEmpty || data[0] is! Map) {
        return null;
      }

      final first = data[0] as Map<String, dynamic>;

      String? phonetic;
      if (first['phonetic'] is String) {
        phonetic = first['phonetic'] as String;
      } else if (first['phonetics'] is List &&
          (first['phonetics'] as List).isNotEmpty) {
        final p0 = (first['phonetics'] as List).first;
        if (p0 is Map && p0['text'] is String) {
          phonetic = p0['text'] as String;
        }
      }

      String? partOfSpeech;
      String? definition;
      String? example;

      if (first['meanings'] is List && (first['meanings'] as List).isNotEmpty) {
        final m0 = (first['meanings'] as List).first;
        if (m0 is Map) {
          if (m0['partOfSpeech'] is String) {
            partOfSpeech = m0['partOfSpeech'] as String;
          }
          if (m0['definitions'] is List &&
              (m0['definitions'] as List).isNotEmpty) {
            final d0 = (m0['definitions'] as List).first;
            if (d0 is Map) {
              if (d0['definition'] is String) {
                definition = d0['definition'] as String;
              }
              if (d0['example'] is String) {
                example = d0['example'] as String;
              }
            }
          }
        }
      }

      if (definition == null || definition.isEmpty) {
        return null;
      }

      return DictionaryEntry(
        word: word,
        phonetic: phonetic,
        partOfSpeech: partOfSpeech,
        definition: definition,
        example: example,
      );
    } catch (_) {
      return null;
    }
  }
}
