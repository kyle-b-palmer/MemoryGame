import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;

class NBackGame extends StatefulWidget {
  const NBackGame({super.key});

  @override
  State<NBackGame> createState() => _NBackGameState();
}

class _NBackGameState extends State<NBackGame>
    with TickerProviderStateMixin {
  GamePhase _phase = GamePhase.ready;
  int _level = 1;
  int _score = 0;
  int _highScore = 0;
  int _lives = 3;
  
  int _nValue = 2; // N-back value (e.g., 2-back means check 2 positions ago)
  int _totalItems = 20;
  List<int> _sequence = [];
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAnswers = 0;
  
  bool _hasAnsweredCurrent = false;
  bool? _lastAnswerCorrect;
  
  // Custom game settings
  bool _isCustomGame = false;
  int _customNValue = 2;
  int _customTotalItems = 20;
  
  Timer? _itemTimer;
  double _itemDisplayDuration = 1.5;
  
  late AnimationController _itemFlashController;
  late AnimationController _resultController;
  late Animation<double> _itemFadeAnimation;
  late Animation<double> _itemScaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _itemFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _itemFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _itemFlashController,
        curve: Curves.easeOut,
      ),
    );
    
    _itemScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _itemFlashController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _itemTimer?.cancel();
    _itemFlashController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _level = prefs.getInt('nback_level') ?? 1;
      _highScore = prefs.getInt('nback_high_score') ?? 0;
      _nValue = prefs.getInt('nback_n_value') ?? 2;
      _totalItems = prefs.getInt('nback_total_items') ?? 20;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nback_level', _level);
    await prefs.setInt('nback_high_score', _highScore);
    await prefs.setInt('nback_n_value', _nValue);
    await prefs.setInt('nback_total_items', _totalItems);
  }

  void _startGame() {
    setState(() {
      _phase = GamePhase.ready;
      _score = 0;
      _lives = 3;
      _isCustomGame = false;
    });
    _startRound();
  }

  void _startCustomGame() {
    setState(() {
      _phase = GamePhase.customSettings;
      _score = 0;
      _isCustomGame = true;
      _nValue = _customNValue;
      _totalItems = _customTotalItems;
    });
  }

  void _startRound() {
    _generateSequence();
    setState(() {
      _phase = GamePhase.guessing;
      _currentIndex = 0;
      _correctAnswers = 0;
      _totalAnswers = 0;
      _hasAnsweredCurrent = false;
      _lastAnswerCorrect = null;
    });
    _showNextItem();
  }

  void _generateSequence() {
    final random = math.Random();
    _sequence = [];
    
    // Generate sequence with some matches N-back
    for (int i = 0; i < _totalItems; i++) {
      if (i >= _nValue && random.nextDouble() < 0.3) {
        // 30% chance to match N-back
        _sequence.add(_sequence[i - _nValue]);
      } else {
        // Random number 1-9
        _sequence.add(random.nextInt(9) + 1);
      }
    }
  }

  void _showNextItem() {
    if (_currentIndex >= _sequence.length) {
      _roundComplete();
      return;
    }
    
    setState(() {
       _hasAnsweredCurrent = false;
       _lastAnswerCorrect = null;
    });
    
    _itemFlashController.forward(from: 0);
    
    _itemTimer?.cancel();
    _itemTimer = Timer(Duration(milliseconds: (_itemDisplayDuration * 1000).toInt()), () {
      _itemFlashController.reverse();
      
      // If they missed an answer for a valid N-back position, penalize them
      if (!_hasAnsweredCurrent && _currentIndex >= _nValue && mounted) {
        // Wait indefinitely until the user presses Match or No Match
        return;
      }
      
      // If we are still in the 'freebie' zone (no previous numbers to match against)
      // just auto-advance after the timer expires
      if (mounted && _currentIndex < _sequence.length && _currentIndex < _nValue) {
         Timer(const Duration(milliseconds: 200), () {
            if (mounted && _currentIndex < _sequence.length) {
              setState(() {
                _currentIndex++;
              });
              _showNextItem();
            }
         });
      }
    });
  }

  void _onMatchPressed() {
    if (_hasAnsweredCurrent || _currentIndex < _nValue) return;
    
    final isMatch = _sequence[_currentIndex] == _sequence[_currentIndex - _nValue];
    _checkAnswer(isMatch);
  }

  void _onNoMatchPressed() {
    if (_hasAnsweredCurrent) return;
    
    if (_currentIndex < _nValue) {
      // Freebie for tapping before N items are shown
      setState(() {
         _hasAnsweredCurrent = true;
         _lastAnswerCorrect = true;
         _score += 5;
         if (_score > _highScore) {
           _highScore = _score;
         }
      });
      return;
    }
    
    final isMatch = _sequence[_currentIndex] == _sequence[_currentIndex - _nValue];
    _checkAnswer(!isMatch);
  }

  void _checkAnswer(bool isCorrect) {
    setState(() {
      _hasAnsweredCurrent = true;
      _lastAnswerCorrect = isCorrect;
      _totalAnswers++;
      if (isCorrect) {
        _correctAnswers++;
        _score += (_level * 10) + (_nValue * 5);
        if (_score > _highScore) {
          _highScore = _score;
        }
      } else if (!_isCustomGame) {
        _lives--;
        if (_lives <= 0) {
          _phase = GamePhase.gameOver;
        }
      }
    });
    
    if (_phase == GamePhase.gameOver) return;
    
    // Automatically advance to the next item after the user has answered
    Timer(const Duration(milliseconds: 600), () {
      if (mounted && _currentIndex < _sequence.length) {
        setState(() {
          _currentIndex++;
        });
        _showNextItem();
      }
    });
  }

  void _roundComplete() {
    _itemTimer?.cancel();
    
    final accuracy = _totalAnswers > 0 ? (_correctAnswers / _totalAnswers) : 0.0;
    final bonusScore = ((accuracy * 100).toInt() * 10);
    
    setState(() {
      _phase = GamePhase.correct;
      _score += bonusScore;
      if (_score > _highScore) {
        _highScore = _score;
      }
    });
    
    _resultController.forward(from: 0);
    
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!_isCustomGame) {
        _levelUp();
      } else {
        _level++;
        _nValue = _customNValue;
        _totalItems = _customTotalItems;
      }
      _startRound();
    });
  }

  void _levelUp() {
    if (_isCustomGame) return;
    
    _level++;
    
    if (_level % 3 == 0 && _nValue < 4) {
      _nValue++;
    }
    
    if (_level % 2 == 0 && _totalItems < 30) {
      _totalItems += 5;
    }
    
    if (_level % 4 == 0 && _itemDisplayDuration > 0.8) {
      _itemDisplayDuration -= 0.1;
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
      case GamePhase.guessing:
        return _buildGuessingScreen();
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
                Icons.repeat_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'N-Back',
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
                    Icons.numbers_rounded,
                    'Numbers appear one at a time',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.compare_arrows_rounded,
                    'Press MATCH if current number matches N steps back',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.close_rounded,
                    'Press NO MATCH if it doesn\'t match',
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
                    colors: [Color(0xFF00B894), Color(0xFF00CEC9)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00B894).withOpacity(0.4),
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
        Icon(icon, color: const Color(0xFF00B894), size: 24),
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
                    'N-Back Value',
                    _customNValue,
                    (val) => setState(() => _customNValue = val),
                    1.0,
                    5.0,
                  ),
                  const SizedBox(height: 24),
                  _buildSettingRow(
                    'Total Items',
                    _customTotalItems,
                    (val) => setState(() => _customTotalItems = val),
                    10.0,
                    50.0,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                  _nValue = _customNValue;
                  _totalItems = _customTotalItems;
                  _startRound();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: () {
                  _nValue = _customNValue;
                  _totalItems = _customTotalItems;
                  _startRound();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00B894), Color(0xFF00CEC9)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00B894).withOpacity(0.4),
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
                  if (value > min) onChanged((value as int) - 1);
                }
              },
              icon: const Icon(Icons.remove_circle, color: Color(0xFF00B894)),
            ),
            Expanded(
              child: Text(
                isDouble ? (value as double).toStringAsFixed(1) : value.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF00B894),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                if (isDouble) {
                  if (value < max) onChanged((value as double) + 0.1);
                } else {
                  if (value < max) onChanged((value as int) + 1);
                }
              },
              icon: const Icon(Icons.add_circle, color: Color(0xFF00B894)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGuessingScreen() {
    final currentNumber = _currentIndex < _sequence.length ? _sequence[_currentIndex] : null;
    final canMatch = _currentIndex >= _nValue;
    final previousNumber = canMatch ? _sequence[_currentIndex - _nValue] : null;
    
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF00B894).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00B894).withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Text(
                '$_nValue-Back Challenge',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF00B894),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Item ${_currentIndex + 1}/$_totalItems • Correct: $_correctAnswers/$_totalAnswers',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
              if (canMatch && previousNumber != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Does $currentNumber match $previousNumber (${_nValue} steps back)?',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: AnimatedBuilder(
              animation: _itemFadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _itemFadeAnimation.value,
                  child: Transform.scale(
                    scale: _itemScaleAnimation.value,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _hasAnsweredCurrent
                              ? (_lastAnswerCorrect == true
                                  ? const [Color(0xFF00B894), Color(0xFF55EFC4)]
                                  : const [Color(0xFFFF6B6B), Color(0xFFFF8E8E)])
                              : const [Color(0xFF0984E3), Color(0xFF74B9FF)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _hasAnsweredCurrent
                                ? (_lastAnswerCorrect == true
                                    ? const Color(0xFF00B894)
                                    : const Color(0xFFFF6B6B)).withOpacity(0.6)
                                : const Color(0xFF0984E3).withOpacity(0.6),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          currentNumber?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      _onNoMatchPressed();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: GestureDetector(
                    onTap: _onNoMatchPressed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFF6B6B)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.close_rounded, color: Color(0xFFFF6B6B), size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'NO MATCH',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFFFF6B6B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '(← Arrow)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
                      _onMatchPressed();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: GestureDetector(
                    onTap: canMatch ? _onMatchPressed : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        gradient: canMatch
                            ? const LinearGradient(
                                colors: [Color(0xFF00B894), Color(0xFF55EFC4)],
                              )
                            : null,
                        color: !canMatch ? Colors.white10 : null,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: canMatch ? const Color(0xFF00B894) : Colors.white30,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_rounded,
                            color: canMatch ? Colors.white : Colors.white30,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'MATCH',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: canMatch ? Colors.white : Colors.white30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '(→ Arrow)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultScreen(bool isCorrect) {
    final accuracy = _totalAnswers > 0 ? ((_correctAnswers / _totalAnswers) * 100).toInt() : 0;
    
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
              'Round Complete!',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Accuracy: $accuracy%',
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
                    colors: [Color(0xFF00B894), Color(0xFF00CEC9)],
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
  guessing,
  correct,
  incorrect,
  gameOver,
}

