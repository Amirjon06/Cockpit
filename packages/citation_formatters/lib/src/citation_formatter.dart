enum CitationStyle {
  mla('MLA'),
  apa('APA'),
  chicago('Chicago'),
  ieee('IEEE'),
  harvard('Harvard');

  const CitationStyle(this.label);

  final String label;
}

class CitationSource {
  const CitationSource({
    required this.id,
    required this.title,
    this.author,
    this.publisher,
    this.year,
    this.url,
    this.accessDate,
  });

  final String id;
  final String title;
  final String? author;
  final String? publisher;
  final String? year;
  final String? url;
  final String? accessDate;

  factory CitationSource.fromJson(Map<String, dynamic> json) {
    return CitationSource(
      id: json['id']?.toString() ?? '',
      title: (json['title'] ?? json['Title'])?.toString() ?? 'Untitled Source',
      author: (json['author'] ?? json['Author'])?.toString(),
      publisher: json['publisher']?.toString(),
      year: (json['year'] ?? json['publishedYear'])?.toString(),
      url: (json['url'] ?? json['website_URL'])?.toString(),
      accessDate: json['accessDate']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (author != null) 'author': author,
    if (publisher != null) 'publisher': publisher,
    if (year != null) 'year': year,
    if (url != null) 'url': url,
    if (accessDate != null) 'accessDate': accessDate,
  };
}

extension CitationStyleX on CitationStyle {
  static CitationStyle fromLabel(String? value) {
    final normalized = value?.trim().toLowerCase();
    return CitationStyle.values.firstWhere(
      (style) => style.label.toLowerCase() == normalized,
      orElse: () => CitationStyle.apa,
    );
  }
}

class CitationFormatter {
  const CitationFormatter();

  String bibliographyTitle(CitationStyle style) {
    return switch (style) {
      CitationStyle.mla => 'Works Cited',
      CitationStyle.chicago => 'Bibliography',
      CitationStyle.harvard => 'Reference List',
      CitationStyle.apa || CitationStyle.ieee => 'References',
    };
  }

  String inlineCitation(
    CitationSource source,
    CitationStyle style, {
    int? index,
  }) {
    final surname = _surname(source.author);
    final year = _year(source.year);

    return switch (style) {
      CitationStyle.mla => '($surname)',
      CitationStyle.apa => '($surname, $year)',
      CitationStyle.chicago => '($surname $year)',
      CitationStyle.ieee => '[${index ?? 1}]',
      CitationStyle.harvard => '($surname, $year)',
    };
  }

  String bibliographyEntry(
    CitationSource source,
    CitationStyle style, {
    int? index,
  }) {
    final author = _clean(source.author, fallback: 'Unknown');
    final surname = _surname(source.author);
    final publisher = _clean(source.publisher, fallback: 'Unknown Publisher');
    final year = _year(source.year);
    final title = _clean(source.title, fallback: 'Untitled Source');
    final url = _clean(source.url);

    return switch (style) {
      CitationStyle.mla =>
        '$author. "$title." $publisher, ${_period(year)}'
            '${url.isEmpty ? '' : ' $url.'}',
      CitationStyle.apa =>
        '$surname. ($year). $title. $publisher.'
            '${url.isEmpty ? '' : ' $url'}',
      CitationStyle.chicago =>
        '$author. "$title." $publisher, ${_period(year)}'
            '${url.isEmpty ? '' : ' $url.'}',
      CitationStyle.ieee =>
        '[${index ?? 1}] $author, "$title," $publisher, ${_period(year)}'
            '${url.isEmpty ? '' : ' [Online]. Available: $url'}',
      CitationStyle.harvard =>
        '$surname, ${_period(year)} $title. $publisher.'
            '${url.isEmpty ? '' : ' Available at: $url'}',
    };
  }

  List<String> bibliography(List<CitationSource> sources, CitationStyle style) {
    final seen = <String>{};
    final uniqueSources = sources
        .where((source) {
          final identity = source.id.trim().isNotEmpty
              ? 'id:${source.id.trim().toLowerCase()}'
              : 'source:${source.title.trim().toLowerCase()}|${_clean(source.url).toLowerCase()}';
          return seen.add(identity);
        })
        .toList(growable: false);
    final entries = <String>[
      for (var i = 0; i < uniqueSources.length; i++)
        bibliographyEntry(uniqueSources[i], style, index: i + 1),
    ];

    if (style != CitationStyle.ieee) {
      entries.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    return entries;
  }

  String _surname(String? value) {
    final author = _clean(value);
    if (author.isEmpty) return 'Unknown';
    final firstAuthor = author
        .split(RegExp(r';|\s+and\s+|&', caseSensitive: false))
        .first
        .trim();
    if (firstAuthor.contains(',')) return firstAuthor.split(',').first.trim();
    final parts = firstAuthor.split(RegExp(r'\s+'));
    return parts.isEmpty ? 'Unknown' : parts.last;
  }

  String _year(String? value) {
    final match = RegExp(r'\d{4}').firstMatch(value ?? '');
    return match?.group(0) ?? 'n.d.';
  }

  String _period(String value) => value.endsWith('.') ? value : '$value.';

  String _clean(String? value, {String fallback = ''}) {
    final cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? fallback : cleaned;
  }
}
