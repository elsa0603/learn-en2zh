import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/article_repository.dart';
import '../services/tts_service.dart';
import '../services/vocab_storage.dart';
import '../services/dictionary_service.dart';
import '../services/translation_service.dart';

class ArticleListPage extends StatefulWidget {
  final ArticleRepository articleRepository;
  final TtsService ttsService;
  final VocabStorage vocabStorage;
  final DictionaryService dictionaryService;
  final TranslationService translationService;

  const ArticleListPage({
    super.key,
    required this.articleRepository,
    required this.ttsService,
    required this.vocabStorage,
    required this.dictionaryService,
    required this.translationService,
  });

  @override
  State<ArticleListPage> createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  late Future<List<Article>> _articlesFuture;

  String? _selectedLevel;
  String? _selectedCategory;

  static const List<String> _levelOptions = ['全部', '初級', '中級'];
  static const List<String> _categoryOptions = ['全部', '旅遊', '飲食', '生活', '知識'];

  @override
  void initState() {
    super.initState();
    _articlesFuture = widget.articleRepository.fetchArticles();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('English Reader'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            tooltip: '生字本',
            onPressed: () {
              Navigator.pushNamed(context, '/vocab');
            },
          ),
        ],
      ),
      body: Container(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        child: FutureBuilder<List<Article>>(
          future: _articlesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('載入文章失敗：${snapshot.error}'),
              );
            }

            final articles = snapshot.data ?? [];
            if (articles.isEmpty) {
              return const Center(child: Text('目前沒有任何文章'));
            }

            final filtered = articles.where((a) {
              final matchLevel = _selectedLevel == null ||
                  (a.level != null && a.level == _selectedLevel);
              final matchCategory = _selectedCategory == null ||
                  (a.category != null && a.category == _selectedCategory);
              return matchLevel && matchCategory;
            }).toList();

            final displayList = filtered.isEmpty ? articles : filtered;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Choose a story to read',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 難度
                  Row(
                    children: [
                      const Text('難度：', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          children: _levelOptions.map((label) {
                            final value = label == '全部' ? null : label;
                            final selected = _selectedLevel == value;
                            return ChoiceChip(
                              label: Text(label),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  _selectedLevel = value;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 主題
                  Row(
                    children: [
                      const Text('主題：', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          children: _categoryOptions.map((label) {
                            final value = label == '全部' ? null : label;
                            final selected = _selectedCategory == value;
                            return ChoiceChip(
                              label: Text(label),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  _selectedCategory = value;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Grid 文章列表
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = 1;
                        if (constraints.maxWidth >= 1000) {
                          crossAxisCount = 3;
                        } else if (constraints.maxWidth >= 650) {
                          crossAxisCount = 2;
                        }

                        return GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 4 / 3,
                          ),
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            final article = displayList[index];
                            return _ArticleCard(
                              article: article,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/detail',
                                  arguments: article,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;

  const _ArticleCard({
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial =
        article.title.isNotEmpty ? article.title[0].toUpperCase() : '?';

    String? tag;
    if (article.level != null && article.category != null) {
      tag = '${article.level} · ${article.category}';
    } else if (article.level != null) {
      tag = article.level;
    } else if (article.category != null) {
      tag = article.category;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    article.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (tag != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // 內文 preview
            Expanded(
              child: Text(
                article.english,
                style: const TextStyle(fontSize: 14, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Read more',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
