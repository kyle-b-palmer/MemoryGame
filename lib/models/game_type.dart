import 'package:flutter/material.dart';

enum GameType {
  missingNumber,
  sequenceRecall,
  patternMatch,
  speedNumbers,
}

extension GameTypeExtension on GameType {
  String get title {
    switch (this) {
      case GameType.missingNumber:
        return 'Missing Number';
      case GameType.sequenceRecall:
        return 'Sequence Recall';
      case GameType.patternMatch:
        return 'Pattern Match';
      case GameType.speedNumbers:
        return 'Speed Numbers';
    }
  }

  String get description {
    switch (this) {
      case GameType.missingNumber:
        return 'Spot the missing number in a sequence before time runs out!';
      case GameType.sequenceRecall:
        return 'Remember and reproduce number sequences in order.';
      case GameType.patternMatch:
        return 'Identify matching patterns in a grid of symbols.';
      case GameType.speedNumbers:
        return 'Memorize numbers that flash on screen as fast as possible.';
    }
  }

  IconData get icon {
    switch (this) {
      case GameType.missingNumber:
        return Icons.question_mark_rounded;
      case GameType.sequenceRecall:
        return Icons.format_list_numbered_rounded;
      case GameType.patternMatch:
        return Icons.grid_view_rounded;
      case GameType.speedNumbers:
        return Icons.flash_on_rounded;
    }
  }

  List<Color> get gradientColors {
    switch (this) {
      case GameType.missingNumber:
        return [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)];
      case GameType.sequenceRecall:
        return [const Color(0xFF00B894), const Color(0xFF55EFC4)];
      case GameType.patternMatch:
        return [const Color(0xFFE17055), const Color(0xFFFAB1A0)];
      case GameType.speedNumbers:
        return [const Color(0xFFFDCB6E), const Color(0xFFF9CA24)];
    }
  }

  bool get isAvailable {
    switch (this) {
      case GameType.missingNumber:
      case GameType.sequenceRecall:
      case GameType.patternMatch:
      case GameType.speedNumbers:
        return true;
    }
  }
}

