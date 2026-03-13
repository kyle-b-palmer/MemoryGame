import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;

class CardMemoryGame extends StatefulWidget {
  const CardMemoryGame({super.key});

  @override
  State<CardMemoryGame> createState() => _CardMemoryGameState();
}

class _CardMemoryGameState extends State<CardMemoryGame>
    with TickerProviderStateMixin {
  GamePhase _phase = GamePhase.ready;
  int _level = 1;
  int _score = 0;
  int _highScore = 0;
  int _moves = 0;
  int _lives = 3;
  
  int _gridSize = 4; // 4x4 = 16 cards = 8 pairs
  List<int> _cardValues = [];
  List<bool> _cardFlipped = [];
  List<bool> _cardMatched = [];
  int? _firstFlippedIndex;
  int? _secondFlippedIndex;
  bool _isProcessing = false;
  
  // Custom game settings
  bool _isCustomGame = false;
  int _customGridSize = 4;
  
  Timer? _flipBackTimer;
  
  late AnimationController _resultController;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _flipBackTimer?.cancel();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _level = prefs.getInt('card_memory_level') ?? 1;
      _highScore = prefs.getInt('card_memory_high_score') ?? 0;
      _gridSize = prefs.getInt('card_memory_grid_size') ?? 4;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('card_memory_level', _level);
    await prefs.setInt('card_memory_high_score', _highScore);
    await prefs.setInt('card_memory_grid_size', _gridSize);
  }

  void _startGame() {
    setState(() {
      _phase = GamePhase.ready;
      _score = 0;
      _moves = 0;
      _lives = 3;
      _isCustomGame = false;
    });
    _startRound();
  }

  void _startCustomGame() {
    setState(() {
      _phase = GamePhase.customSettings;
      _score = 0;
      _moves = 0;
      _isCustomGame = true;
      _gridSize = _customGridSize;
    });
  }

  void _startRound() {
    _generateCards();
    setState(() {
      _phase = GamePhase.showing;
      _moves = 0;
      _firstFlippedIndex = null;
      _secondFlippedIndex = null;
      _isProcessing = false;
    });
    
    // Show all cards briefly
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _phase = GamePhase.guessing;
          _cardFlipped = List.filled(_gridSize * _gridSize, false);
        });
      }
    });
  }

  void _generateCards() {
    final random = math.Random();
    final pairCount = (_gridSize * _gridSize) ~/ 2;
    _cardValues = [];
    
    // Generate pairs
    for (int i = 0; i < pairCount; i++) {
      _cardValues.add(i);
      _cardValues.add(i);
    }
    
    // Shuffle
    _cardValues.shuffle(random);
    
    _cardFlipped = List.filled(_gridSize * _gridSize, true); // Show all initially
    _cardMatched = List.filled(_gridSize * _gridSize, false);
  }

  void _onCardTap(int index) {
    if (_isProcessing || _cardFlipped[index] || _cardMatched[index]) return;
    
    setState(() {
      _cardFlipped[index] = true;
      
      if (_firstFlippedIndex == null) {
        _firstFlippedIndex = index;
      } else if (_secondFlippedIndex == null) {
        _secondFlippedIndex = index;
        _moves++;
        _checkMatch();
      }
    });
  }

  void _checkMatch() {
    if (_firstFlippedIndex == null || _secondFlippedIndex == null) return;
    
    final firstValue = _cardValues[_firstFlippedIndex!];
    final secondValue = _cardValues[_secondFlippedIndex!];
    
    if (firstValue == secondValue) {
      // Match found
      setState(() {
        _cardMatched[_firstFlippedIndex!] = true;
        _cardMatched[_secondFlippedIndex!] = true;
        _firstFlippedIndex = null;
        _secondFlippedIndex = null;
      });
      
      // Check if all matched
      if (_cardMatched.every((matched) => matched)) {
        _roundComplete();
      }
    } else {
      // No match - flip back
      _isProcessing = true;
      _flipBackTimer?.cancel();
      _flipBackTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            if (!_isCustomGame) {
              _lives--;
              if (_lives <= 0) {
                _phase = GamePhase.gameOver;
                _isProcessing = false;
                return;
              }
            }
            _cardFlipped[_firstFlippedIndex!] = false;
            _cardFlipped[_secondFlippedIndex!] = false;
            _firstFlippedIndex = null;
            _secondFlippedIndex = null;
            _isProcessing = false;
          });
        }
      });
    }
  }

  void _roundComplete() {
    final pairCount = (_gridSize * _gridSize) ~/ 2;
    final baseScore = pairCount * 50;
    final moveBonus = (pairCount * 2 - _moves) * 10;
    final scoreGain = baseScore + moveBonus;
    
    setState(() {
      _phase = GamePhase.correct;
      _score += scoreGain;
      if (_score > _highScore) {
        _highScore = _score;
      }
    });
    
    _resultController.forward(from: 0);
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!_isCustomGame) {
        _levelUp();
      } else {
        _level++;
        _gridSize = _customGridSize;
      }
      _startRound();
    });
  }

  void _levelUp() {
    if (_isCustomGame) return;
    
    _level++;
    
    if (_level % 2 == 0 && _gridSize < 6) {
      _gridSize += 2; // Increase by 2 to keep pairs even
    }
    
    _saveProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0D1A),
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatChip(Icons.star_rounded, '$_score', const Color(0xFFFDCB6E)),
                        const SizedBox(width: 12),
                        _buildStatChip(Icons.trending_up_rounded, 'Lv.$_level', const Color(0xFF00B894)),
                        const SizedBox(width: 12),
                        _buildStatChip(Icons.swap_horiz_rounded, '$_moves', const Color(0xFF0984E3)),
                        if (!_isCustomGame) ...[
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(3, (index) => Icon(
                              index < _lives ? Icons.favorite : Icons.favorite_border,
                              color: Colors.redAccent,
                              size: 20,
                            )),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(child: _buildGameContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent() {
    switch (_phase) {
      case GamePhase.ready:
        return _buildReadyScreen();
      case GamePhase.customSettings:
        return _buildCustomSettingsScreen();
      case GamePhase.showing:
      case GamePhase.guessing:
        return _buildGameScreen();
      case GamePhase.correct:
        return _buildResultScreen(true);
      case GamePhase.incorrect:
        return _buildResultScreen(false);
      case GamePhase.gameOver:
        return _buildGameOverScreen();
    }
  }

  Widget _buildReadyScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0984E3), Color(0xFF74B9FF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0984E3).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.style_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Card Memory',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _buildInstructionRow(
                    Icons.visibility_rounded,
                    'Cards are shown briefly at the start',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.touch_app_rounded,
                    'Flip two cards to find matching pairs',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.star_rounded,
                    'Fewer moves = higher score',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _startGame,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0984E3), Color(0xFF74B9FF)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0984E3).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  'START GAME',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _startCustomGame,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Text(
                  'CUSTOM GAME',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF0984E3), size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomSettingsScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Custom Game Settings',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _buildSettingRow(
                    'Grid Size',
                    _customGridSize,
                    (val) => setState(() => _customGridSize = val),
                    4.0,
                    8.0,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${(_customGridSize * _customGridSize) ~/ 2} pairs',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                  _gridSize = _customGridSize;
                  _startRound();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: () {
                  _gridSize = _customGridSize;
                  _startRound();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0984E3), Color(0xFF74B9FF)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0984E3).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    'START',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, dynamic value, Function(dynamic) onChanged, double min, double max, {bool isDouble = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: () {
                if (isDouble) {
                  if (value > min) onChanged((value as double) - 0.1);
                } else {
                  if (value > min) onChanged((value as int) - 2);
                }
              },
              icon: const Icon(Icons.remove_circle, color: Color(0xFF0984E3)),
            ),
            Expanded(
              child: Text(
                isDouble ? (value as double).toStringAsFixed(1) : value.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF0984E3),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                if (isDouble) {
                  if (value < max) onChanged((value as double) + 0.1);
                } else {
                  if (value < max) onChanged((value as int) + 2);
                }
              },
              icon: const Icon(Icons.add_circle, color: Color(0xFF0984E3)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGameScreen() {
    return Column(
      children: [
        if (_phase == GamePhase.showing)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0984E3).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0984E3).withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.visibility_rounded, color: Color(0xFF0984E3), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Memorize the cards!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF0984E3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate card size to fit within available space
              // Account for padding (16 * 2 = 32) and spacing between cards
              final availableWidth = constraints.maxWidth - 32 - (_gridSize - 1) * 8;
              final availableHeight = constraints.maxHeight - 16;
              final cardSize = ((availableWidth < availableHeight 
                  ? availableWidth 
                  : availableHeight) / _gridSize).clamp(40.0, 120.0);
              
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: SizedBox(
                    width: cardSize * _gridSize + (_gridSize - 1) * 8,
                    height: cardSize * _gridSize + (_gridSize - 1) * 8,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _gridSize,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _gridSize * _gridSize,
                      itemBuilder: (context, index) {
                        return SizedBox(
                          width: cardSize,
                          height: cardSize,
                          child: _buildCard(index),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCard(int index) {
    final isFlipped = _cardFlipped[index];
    final isMatched = _cardMatched[index];
    final value = _cardValues[index];
    
    return GestureDetector(
      onTap: () => _onCardTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isMatched
              ? const Color(0xFF00B894).withOpacity(0.3)
              : isFlipped
                  ? const Color(0xFF0984E3)
                  : const Color(0xFF74B9FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMatched
                ? const Color(0xFF00B894)
                : isFlipped
                    ? Colors.white.withOpacity(0.5)
                    : Colors.white.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Center(
          child: isFlipped || _phase == GamePhase.showing
              ? Text(
                  '${value + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : const Icon(
                  Icons.help_outline_rounded,
                  color: Colors.white70,
                  size: 32,
                ),
        ),
      ),
    );
  }

  Widget _buildResultScreen(bool isCorrect) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00B894), Color(0xFF55EFC4)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00B894).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Perfect!',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Moves: $_moves',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.sentiment_dissatisfied_rounded,
              size: 80,
              color: Colors.white54,
            ),
            const SizedBox(height: 24),
            Text(
              'Game Over',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Final Score: $_score',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _startGame,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0984E3), Color(0xFF74B9FF)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'PLAY AGAIN',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum GamePhase {
  ready,
  customSettings,
  showing,
  guessing,
  correct,
  incorrect,
  gameOver,
}

