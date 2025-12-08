import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/article.dart';
import '../models/vocab_entry.dart';
import '../services/tts_service.dart';
import '../services/dictionary_service.dart';
import '../services/translation_service.dart';
import '../services/vocab_storage.dart';
import '../utils/text_clean.dart';

class ArticleDetailPage extends StatefulWidget {
  final Article article;
  final TtsService ttsService;
  final DictionaryService dictionaryService;
  final TranslationService translationService;
  final VocabStorage vocabStorage;

  const ArticleDetailPage({
    super.key,
    required this.article,
    required this.ttsService,
    required this.dictionaryService,
    required this.translationService,
    required this.vocabStorage,
  });

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  late List<String> _words;
  bool _isPlayingAll = false;

  String? _articleChinese;
  bool _isTranslatingArticle = false;
  String? _articleTranslationError;

  String? _selectedWord;
  String? _phonetic;
  String? _partOfSpeech;
  String? _definition;
  String? _definitionZh;
  String? _example;
  bool _isLookingUp = false;
  String? _lookupError;

  List<VocabEntry> _savedEntries = [];
  bool _currentWordSaved = false;

  @override
  void initState() {
    super.initState();
    _words = widget.article.english
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    _loadSavedEntries();
    _loadOrTranslateArticleChinese();
  }

  void _loadSavedEntries() {
    final entries = widget.vocabStorage.loadAll();
    setState(() {
      _savedEntries = entries;
      if (_selectedWord != null) {
        _currentWordSaved = _savedEntries.any(
          (e) => cleanWord(e.word) == cleanWord(_selectedWord!),
        );
      }
    });
  }

  Future<void> _loadOrTranslateArticleChinese() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'article_${widget.article.id}_zh';

    final cached = prefs.getString(key);
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _articleChinese = cached;
        _isTranslatingArticle = false;
        _articleTranslationError = null;
      });
      return;
    }

    setState(() {
      _isTranslatingArticle = true;
      _articleTranslationError = null;
    });

    final zh =
        await widget.translationService.translateToZhTw(widget.article.english);

    if (!mounted) return;

    if (zh == null || zh.isEmpty) {
      setState(() {
        _isTranslatingArticle = false;
        _articleTranslationError = '翻譯文章內容時發生問題。';
      });
      return;
    }

    await prefs.setString(key, zh);

    setState(() {
      _articleChinese = zh;
      _isTranslatingArticle = false;
      _articleTranslationError = null;
    });
  }

  Future<void> _playEnglish() async {
    setState(() => _isPlayingAll = true);
    await widget.ttsService.speak(widget.article.english);
    if (mounted) {
      setState(() => _isPlayingAll = false);
    }
  }

  Future<void> _onWordTap(String rawWord) async {
    final word = cleanWord(rawWord);
    if (word.isEmpty) return;

    setState(() {
      _selectedWord = word;
      _phonetic = null;
      _partOfSpeech = null;
      _definition = null;
      _definitionZh = null;
      _example = null;
      _lookupError = null;
      _isLookingUp = true;
      _currentWordSaved = _savedEntries.any(
        (e) => cleanWord(e.word) == word,
      );
    });

    await widget.ttsService.speak(word);

    final entry = await widget.dictionaryService.lookup(word);

    if (!mounted) return;

    if (entry == null) {
      setState(() {
        _isLookingUp = false;
        _lookupError = '查不到「$word」的字典解釋。';
      });
      return;
    }

    setState(() {
      _phonetic = entry.phonetic;
      _partOfSpeech = entry.partOfSpeech;
      _definition = entry.definition;
      _example = entry.example;
      _isLookingUp = false;
      _currentWordSaved = _savedEntries.any(
        (e) => cleanWord(e.word) == word,
      );
    });

    if (entry.definition.isNotEmpty) {
      final zh =
          await widget.translationService.translateToZhTw(entry.definition);

      if (!mounted) return;

      setState(() {
        _definitionZh = zh;
      });
    }
  }

  Future<void> _addCurrentWordToVocab() async {
    if (_selectedWord == null) return;

    final entry = VocabEntry(
      word: _selectedWord!,
      phonetic: _phonetic,
      partOfSpeech: _partOfSpeech,
      definition: _definition,
      example: _example,
      definitionZh: _definitionZh,
    );

    await widget.vocabStorage.addOrUpdate(entry);
    _loadSavedEntries();
    setState(() {
      _currentWordSaved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cardRadius = BorderRadius.circular(16);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.article.title),
        actions: [
          IconButton(
            icon: Icon(_isPlayingAll ? Icons.stop : Icons.volume_up),
            tooltip: '朗讀全文',
            onPressed: _isPlayingAll ? null : _playEnglish,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 英文區
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.8),
                borderRadius: cardRadius,
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _words.map((w) {
                  final clean = cleanWord(w);
                  final isSelected = _selectedWord != null &&
                      clean.isNotEmpty &&
                      clean == cleanWord(_selectedWord!);

                  return GestureDetector(
                    onTap: () => _onWordTap(w),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: isSelected
                          ? BoxDecoration(
                              color:
                                  theme.colorScheme.primary.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                            )
                          : null,
                      child: Text(
                        w,
                        style: textTheme.bodyLarge?.copyWith(
                          fontSize: 20,
                          height: 1.5,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // 中文區
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.8),
                borderRadius: cardRadius,
              ),
              child: Builder(
                builder: (context) {
                  if (_articleChinese != null && _articleChinese!.isNotEmpty) {
                    return Text(
                      _articleChinese!,
                      style: textTheme.bodyLarge?.copyWith(
                        fontSize: 20,
                        height: 1.5,
                        color: Colors.grey[800],
                      ),
                    );
                  }

                  if (_isTranslatingArticle) {
                    return Text(
                      '正在為這篇文章產生中文翻譯…',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    );
                  }

                  if (_articleTranslationError != null) {
                    return Text(
                      _articleTranslationError!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.red[700],
                      ),
                    );
                  }

                  return Text(
                    '尚未取得中文翻譯。',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            Text(
              '單字區',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 170),
              decoration: BoxDecoration(
                borderRadius: cardRadius,
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.4),
                  width: 1.2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _buildWordPanel(textTheme),
            ),

            const SizedBox(height: 24),

            if (_savedEntries.isNotEmpty) ...[
              Text(
                '已收藏的生字卡',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _savedEntries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final v = _savedEntries[index];
                    return _VocabCard(entry: v);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWordPanel(TextTheme textTheme) {
    if (_selectedWord == null) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          '（點上面的英文單字，這裡會顯示單字、音標、詞性、英英解釋與中文翻譯，並可加入生字本）',
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      );
    }

    if (_isLookingUp) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          '查詢「$_selectedWord」中…',
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      );
    }

    if (_lookupError != null) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          _lookupError!,
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.red[700],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _selectedWord ?? '',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (_phonetic != null && _phonetic!.isNotEmpty)
                Text(
                  _phonetic!,
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (_partOfSpeech != null && _partOfSpeech!.isNotEmpty)
            Text(
              _partOfSpeech!,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 6),
          if (_definition != null)
            Text(
              _definition!,
              style: textTheme.bodyMedium,
            ),
          if (_definitionZh != null && _definitionZh!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _definitionZh!,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.teal[800],
              ),
            ),
          ],
          if (_example != null && _example!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Example:',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _example!,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.grey[800],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _currentWordSaved ? null : _addCurrentWordToVocab,
              icon: Icon(_currentWordSaved ? Icons.check : Icons.bookmark_add),
              label: Text(_currentWordSaved ? '已加入生字本' : '加入生字本'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VocabCard extends StatelessWidget {
  final VocabEntry entry;

  const _VocabCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.word,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (entry.phonetic != null && entry.phonetic!.isNotEmpty)
            Text(
              entry.phonetic!,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey[700],
              ),
            ),
          if (entry.partOfSpeech != null && entry.partOfSpeech!.isNotEmpty)
            Text(
              entry.partOfSpeech!,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 6),
          if (entry.definition != null)
            Expanded(
              child: Text(
                entry.definition!,
                style: textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
