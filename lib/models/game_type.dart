import 'package:flutter/material.dart';

enum GameType {
  missingNumber,
  sequenceRecall,
  patternMatch,
  speedNumbers,
  simonSays,
  cardMemory,
  reverseSequence,
  nBack,
  cardCounting,
  colorBlockStacking,
  cardMatching,
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
      case GameType.simonSays:
        return 'Simon Says';
      case GameType.cardMemory:
        return 'Card Memory';
      case GameType.reverseSequence:
        return 'Reverse Sequence';
      case GameType.nBack:
        return 'N-Back';
      case GameType.cardCounting:
        return 'Card Counting';
      case GameType.colorBlockStacking:
        return 'Color Stacking';
      case GameType.cardMatching:
        return 'Card Matching';
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
      case GameType.simonSays:
        return 'Watch colors flash and repeat the sequence in order.';
      case GameType.cardMemory:
        return 'Find matching pairs by remembering card positions.';
      case GameType.reverseSequence:
        return 'Remember a sequence and enter it in reverse order.';
      case GameType.nBack:
        return 'Identify if current item matches N steps back.';
      case GameType.cardCounting:
        return 'Count cards using the Hi-Lo system and track the running count.';
      case GameType.colorBlockStacking:
        return 'Memorize and rebuild vertical color stacks before they disappear.';
      case GameType.cardMatching:
        return 'Find identical pairs in a deck of 104 exact matches.';
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
      case GameType.simonSays:
        return Icons.color_lens_rounded;
      case GameType.cardMemory:
        return Icons.style_rounded;
      case GameType.reverseSequence:
        return Icons.swap_horiz_rounded;
      case GameType.nBack:
        return Icons.repeat_rounded;
      case GameType.cardCounting:
        return Icons.casino_rounded;
      case GameType.colorBlockStacking:
        return Icons.layers_rounded;
      case GameType.cardMatching:
        return Icons.dashboard_rounded;
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
      case GameType.simonSays:
        return [const Color(0xFFE84393), const Color(0xFFFD79A8)];
      case GameType.cardMemory:
        return [const Color(0xFF0984E3), const Color(0xFF74B9FF)];
      case GameType.reverseSequence:
        return [const Color(0xFFA29BFE), const Color(0xFF6C5CE7)];
      case GameType.nBack:
        return [const Color(0xFF00B894), const Color(0xFF00CEC9)];
      case GameType.cardCounting:
        return [const Color(0xFFD63031), const Color(0xFFFF7675)];
      case GameType.colorBlockStacking:
        return const [
          Color(0xFF0984E3), // Bright Blue
          Color(0xFF00CEC9), // Teal
        ];
      case GameType.cardMatching:
        return const [
          Color(0xFF6C5CE7), // Purple
          Color(0xFFA29BFE), // Light Purple
        ];
    }
  }

  bool get isAvailable {
    switch (this) {
      case GameType.missingNumber:
      case GameType.sequenceRecall:
      case GameType.patternMatch:
      case GameType.speedNumbers:
      case GameType.simonSays:
      case GameType.cardMemory:
      case GameType.reverseSequence:
      case GameType.nBack:
      case GameType.cardCounting:
      case GameType.colorBlockStacking:
      case GameType.cardMatching:
        return true;
    }
  }
}
