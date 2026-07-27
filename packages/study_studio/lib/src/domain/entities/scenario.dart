/// An application scenario (Screen 10 — Scenario Mode).
///
/// A realistic situation the learner must reason through — clues to investigate,
/// candidate first actions (one correct), and the AI's reasoning. Generated from
/// the studio's material by the backend.
class Scenario {
  const Scenario({
    required this.id,
    required this.studioId,
    required this.title,
    required this.problem,
    required this.question,
    required this.correctOptionId,
    this.difficulty = 3,
    this.estimatedMinutes = 6,
    this.skills = const [],
    this.aiNote = '',
    this.clues = const [],
    this.options = const [],
    this.reasoning = '',
    this.outcomeLabel = '',
    this.relatedTopics = const [],
  });

  final String id;
  final String studioId;
  final String title;

  /// 1-5. Rendered as Beginner / Intermediate / Advanced.
  final int difficulty;
  final int estimatedMinutes;
  final List<String> skills;
  final String aiNote;

  /// The situation to diagnose (may span a few lines).
  final String problem;

  /// What the learner must determine.
  final String question;

  final List<ScenarioClue> clues;
  final List<ScenarioOption> options;
  final String correctOptionId;

  /// The AI's explanation once the best action is chosen.
  final String reasoning;

  /// Short outcome label, e.g. "Likely issue: Layer 3 (Network)".
  final String outcomeLabel;
  final List<String> relatedTopics;

  String get difficultyLabel => switch (difficulty) {
        <= 2 => 'Beginner',
        3 => 'Intermediate',
        _ => 'Advanced',
      };

  bool isCorrect(String optionId) => optionId == correctOptionId;
}

/// One investigation clue — inspecting it reveals [detail].
class ScenarioClue {
  const ScenarioClue({
    required this.id,
    required this.label,
    required this.detail,
  });

  final String id;
  final String label;
  final String detail;
}

/// One candidate first action.
class ScenarioOption {
  const ScenarioOption({required this.id, required this.label});

  final String id;
  final String label;
}
