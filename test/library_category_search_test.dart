import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doujin_audio/core/media/audio_detail.dart';
import 'package:doujin_audio/core/widgets/search_highlight.dart';
import 'package:doujin_audio/features/library/domain/audio_library_category.dart';
import 'package:doujin_audio/features/library/presentation/library_tab.dart';

void main() {
  group('SearchHighlightScope.withTerms', () {
    testWidgets('provides custom terms list to descendant SearchHighlightedText', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SearchHighlightScope.withTerms(
              terms: ['alpha', 'beta'],
              child: SearchHighlightedText(
                text: 'alpha test beta',
                style: TextStyle(),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(RichText), findsOneWidget);
      final richText = tester.widget<RichText>(find.byType(RichText));
      final textSpan = richText.text as TextSpan;
      expect(textSpan.children, isNotNull);
      expect(textSpan.children!.length, greaterThan(1));
    });
  });

  group('Category entry search filtering logic', () {
    final entry1 = _createEntry(
      title: 'Work Alpha',
      path: '/path/1',
      tags: ['ASMR', 'Relaxation'],
      voiceActors: ['VoiceA'],
      circleName: 'CircleOne',
    );
    final entry2 = _createEntry(
      title: 'Work Beta',
      path: '/path/2',
      tags: ['Sleep', 'ASMR'],
      voiceActors: ['VoiceB'],
      circleName: 'CircleTwo',
    );

    test('Single-value and multi-value term matching on entries', () {
      final terms1 = entry1.normalizedTermsForCategory(
        AudioLibraryCategoryType.tags,
      );
      expect(terms1.contains('asmr'), isTrue);
      expect(terms1.contains('relaxation'), isTrue);

      final terms2 = entry2.normalizedTermsForCategory(
        AudioLibraryCategoryType.tags,
      );
      expect(terms2.contains('asmr'), isTrue);
      expect(terms2.contains('sleep'), isTrue);
    });

    test('Simultaneous AND condition matching between text query and element search', () {
      final entries = [entry1, entry2];

      List<AudioLibraryCategoryEntry> filter({
        required List<String> queryTerms,
        required List<String> normalizedSelectedTerms,
        required List<String> termKeywords,
      }) {
        final hasTextQuery = queryTerms.isNotEmpty;
        final hasElementQuery =
            normalizedSelectedTerms.isNotEmpty || termKeywords.isNotEmpty;

        return entries.where((entry) {
          final entryTerms = entry.normalizedTermsForCategory(
            AudioLibraryCategoryType.tags,
          );
          final matchesSelected = normalizedSelectedTerms.every(
            entryTerms.contains,
          );
          final matchesTermKeywords = termKeywords.every(
            (keyword) => entryTerms.any((term) => term.contains(keyword)),
          );
          final matchesElement =
              hasElementQuery && matchesSelected && matchesTermKeywords;
          final matchesText =
              hasTextQuery && queryTerms.every(entry.searchableText.contains);

          if (hasTextQuery && hasElementQuery) {
            return matchesText && matchesElement;
          } else if (hasTextQuery) {
            return matchesText;
          } else if (hasElementQuery) {
            return matchesElement;
          }
          return true;
        }).toList();
      }

      // Only text search ('alpha') matches entry1
      final textOnly = filter(
        queryTerms: ['alpha'],
        normalizedSelectedTerms: [],
        termKeywords: [],
      );
      expect(textOnly.map((e) => e.title), ['Work Alpha']);

      // Only element search ('asmr') matches both entry1 and entry2
      final elementOnly = filter(
        queryTerms: [],
        normalizedSelectedTerms: ['asmr'],
        termKeywords: [],
      );
      expect(elementOnly.map((e) => e.title), ['Work Alpha', 'Work Beta']);

      // Both active: text search 'alpha' AND element search 'asmr' -> matches ONLY entry1!
      final bothActiveMatch = filter(
        queryTerms: ['alpha'],
        normalizedSelectedTerms: ['asmr'],
        termKeywords: [],
      );
      expect(bothActiveMatch.map((e) => e.title), ['Work Alpha']);

      // Both active: text search 'beta' AND element search 'relaxation' -> matches NONE because entry2 has 'beta' but no 'relaxation', entry1 has 'relaxation' but no 'beta'
      final bothActiveNoMatch = filter(
        queryTerms: ['beta'],
        normalizedSelectedTerms: ['relaxation'],
        termKeywords: [],
      );
      expect(bothActiveNoMatch, isEmpty);
    });
  });

  group('LibraryCategoryTermBox styling', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
    });

    testWidgets(
      'displays capsule style when collapsed and transitions to card style when expanded',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LibraryCategoryTermBox(
                categoryType: AudioLibraryCategoryType.tags,
                collapseOnMount: true,
                terms: const ['tag1', 'tag2'],
                selectedTerms: const {},
                emptyText: 'No tags',
                clearLabel: 'Clear',
                searchHintText: 'Search tags...',
                searchQuery: '',
                onSearchQueryChanged: (_) {},
                onToggle: (_) {},
                onClear: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Collapsed: Container has capsule border radius
        final containerFinder = find.byType(AnimatedContainer);
        expect(containerFinder, findsOneWidget);
        final container = tester.widget<AnimatedContainer>(containerFinder);
        final decoration = container.decoration as BoxDecoration;
        expect(
          decoration.borderRadius,
          BorderRadius.circular(LibraryCategoryTermBox.capsuleRadius),
        );

        // AnimatedSize alignment is Alignment.topCenter (anchors search row to prevent flickering other rows)
        final animatedSizeFinder = find.byType(AnimatedSize);
        expect(animatedSizeFinder, findsOneWidget);
        final animatedSize = tester.widget<AnimatedSize>(animatedSizeFinder);
        expect(animatedSize.alignment, Alignment.topCenter);

        // Collapsed: TextField has capsule border radius
        final textFieldFinder = find.byType(TextField);
        expect(textFieldFinder, findsOneWidget);
        final textField = tester.widget<TextField>(textFieldFinder);
        final border =
            textField.decoration!.enabledBorder as OutlineInputBorder;
        expect(border.borderRadius, BorderRadius.circular(999));

        // Collapsed: ActionChip has StadiumBorder
        final actionChipFinder = find.byType(ActionChip);
        expect(actionChipFinder, findsOneWidget);
        final actionChip = tester.widget<ActionChip>(actionChipFinder);
        expect(actionChip.shape, const StadiumBorder());

        // Tap ActionChip to expand
        await tester.tap(actionChipFinder);
        await tester.pumpAndSettle();

        // Expanded: Container border radius matches capsule border radius
        final expandedContainer = tester.widget<AnimatedContainer>(
          containerFinder,
        );
        final expandedDecoration =
            expandedContainer.decoration as BoxDecoration;
        expect(
          expandedDecoration.borderRadius,
          BorderRadius.circular(LibraryCategoryTermBox.capsuleRadius),
        );

        // Expanded: TextField retains capsule border radius
        final expandedTextField = tester.widget<TextField>(textFieldFinder);
        final expandedBorder =
            expandedTextField.decoration!.enabledBorder as OutlineInputBorder;
        expect(expandedBorder.borderRadius, BorderRadius.circular(999));

        // Expanded: ActionChip has StadiumBorder
        final expandedActionChip = tester.widget<ActionChip>(actionChipFinder);
        expect(expandedActionChip.shape, const StadiumBorder());

        // Expanded: FilterChip elements have StadiumBorder (capsule style)
        final filterChipFinder = find.byType(FilterChip);
        expect(filterChipFinder, findsNWidgets(2));
        final filterChip = tester.widget<FilterChip>(filterChipFinder.first);
        expect(filterChip.shape, const StadiumBorder());

        // Tap ActionChip to collapse again
        await tester.tap(actionChipFinder);
        await tester.pumpAndSettle();

        // Back to capsule
        final reCollapsedContainer = tester.widget<AnimatedContainer>(
          containerFinder,
        );
        final reCollapsedDecoration =
            reCollapsedContainer.decoration as BoxDecoration;
        expect(
          reCollapsedDecoration.borderRadius,
          BorderRadius.circular(LibraryCategoryTermBox.capsuleRadius),
        );
      },
    );
  });
}

AudioLibraryCategoryEntry _createEntry({
  required String title,
  required String path,
  required List<String> tags,
  required List<String> voiceActors,
  required String circleName,
}) {
  final target = AudioDetailTarget.singleAudioFile(path);
  return AudioLibraryCategoryEntry(
    target: target,
    title: title,
    path: path,
    isFolder: false,
    detail: AudioDetail(
      target: target,
      rjCode: '',
      workTitle: title,
      circleName: circleName,
      voiceActors: voiceActors,
      tags: tags,
    ),
    tracks: const [],
  );
}
