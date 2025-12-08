import 'package:flutter/material.dart';

import 'models/article.dart';
import 'pages/article_list_page.dart';
import 'pages/vocab_list_page.dart';
import 'pages/article_detail_page.dart';

import 'services/article_repository.dart';
import 'services/tts_service.dart';
import 'services/dictionary_service.dart';
import 'services/translation_service.dart';
import 'services/vocab_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 生字本：從 local storage 載入
  final vocabStorage = VocabStorage();
  await vocabStorage.load();

  runApp(MyApp(vocabStorage: vocabStorage));
}

class MyApp extends StatelessWidget {
  final VocabStorage vocabStorage;

  const MyApp({super.key, required this.vocabStorage});

  // 🔗 你的 GitHub Raw 文章 JSON 位置
  static const String articlesUrl =
      'https://raw.githubusercontent.com/elsa0603/learn-en2zh-data/refs/heads/main/articles.json';

  @override
  Widget build(BuildContext context) {
    // 各種 service 在這裡建立一次，整個 app 共用
    final articleRepository = ArticleRepository(articlesUrl);
    final dictionaryService = DictionaryService();
    final translationService =
        TranslationService('AIzaSyBnGr3UOEFpQsIcBFWsYKEexEk9suFCUYU');
    final ttsService = TtsService('AIzaSyBnGr3UOEFpQsIcBFWsYKEexEk9suFCUYU');

    return MaterialApp(
      title: 'Bilingual Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),

      // 首頁：文章列表
      home: ArticleListPage(
        articleRepository: articleRepository,
        ttsService: ttsService,
        vocabStorage: vocabStorage,
        dictionaryService: dictionaryService,
        translationService: translationService,
      ),

      // 固定路由
      routes: {
        '/vocab': (_) => VocabListPage(
              vocabStorage: vocabStorage,
              ttsService: ttsService,
            ),
      },

      // 動態路由（文章詳情頁）
      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          final article = settings.arguments as Article;
          return MaterialPageRoute(
            builder: (_) => ArticleDetailPage(
              article: article,
              ttsService: ttsService,
              dictionaryService: dictionaryService,
              translationService: translationService,
              vocabStorage: vocabStorage,
            ),
          );
        }
        return null;
      },
    );
  }
}
