import 'package:citation_formatters/citation_formatters.dart';
import 'package:test/test.dart';

void main() {
  const formatter = CitationFormatter();
  const source = CitationSource(
    id: 'source-1',
    title: 'Evidence Based Learning',
    author: 'Alex Rivera',
    publisher: 'Academic Press',
    year: 'Published in 2026',
    url: 'https://example.edu/evidence',
  );

  test('matches the official in-text templates for all five styles', () {
    expect(
      formatter.inlineCitation(source, CitationStyle.apa),
      '(Rivera, 2026)',
    );
    expect(formatter.inlineCitation(source, CitationStyle.mla), '(Rivera)');
    expect(
      formatter.inlineCitation(source, CitationStyle.chicago),
      '(Rivera 2026)',
    );
    expect(
      formatter.inlineCitation(source, CitationStyle.ieee, index: 3),
      '[3]',
    );
    expect(
      formatter.inlineCitation(source, CitationStyle.harvard),
      '(Rivera, 2026)',
    );
  });

  test('matches the official reference templates and section titles', () {
    expect(
      formatter.bibliographyEntry(source, CitationStyle.apa),
      'Rivera. (2026). Evidence Based Learning. Academic Press. '
      'https://example.edu/evidence',
    );
    expect(
      formatter.bibliographyEntry(source, CitationStyle.ieee, index: 2),
      '[2] Alex Rivera, "Evidence Based Learning," Academic Press, 2026. '
      '[Online]. Available: https://example.edu/evidence',
    );
    expect(formatter.bibliographyTitle(CitationStyle.mla), 'Works Cited');
    expect(formatter.bibliographyTitle(CitationStyle.chicago), 'Bibliography');
    expect(
      formatter.bibliographyTitle(CitationStyle.harvard),
      'Reference List',
    );
  });

  test('normalizes reference aliases and missing metadata', () {
    final parsed = CitationSource.fromJson({
      'id': 'legacy',
      'Title': 'Legacy source',
      'Author': 'Chen, Morgan',
      'publishedYear': 'Spring 2024',
      'website_URL': 'https://example.edu/legacy',
    });
    const missing = CitationSource(id: 'missing', title: 'No metadata');

    expect(parsed.title, 'Legacy source');
    expect(parsed.year, 'Spring 2024');
    expect(formatter.inlineCitation(parsed, CitationStyle.apa), '(Chen, 2024)');
    expect(
      formatter.inlineCitation(missing, CitationStyle.apa),
      '(Unknown, n.d.)',
    );
    expect(
      formatter.bibliographyEntry(missing, CitationStyle.mla),
      'Unknown. "No metadata." Unknown Publisher, n.d.',
    );
  });

  test('deduplicates references and preserves IEEE source order', () {
    const second = CitationSource(
      id: 'source-2',
      title: 'Another source',
      author: 'Bailey, Sam',
      year: '2025',
    );

    final apa = formatter.bibliography([
      source,
      second,
      source,
    ], CitationStyle.apa);
    final ieee = formatter.bibliography([
      source,
      second,
      source,
    ], CitationStyle.ieee);

    expect(apa, hasLength(2));
    expect(apa.first, startsWith('Bailey'));
    expect(ieee, hasLength(2));
    expect(ieee.first, startsWith('[1] Alex Rivera'));
    expect(ieee.last, startsWith('[2] Bailey, Sam'));
  });
}
