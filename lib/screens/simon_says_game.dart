import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;

class SimonSaysGame extends StatefulWidget {
  const SimonSaysGame({super.key});

  @override
  State<SimonSaysGame> createState() => _SimonSaysGameState();
}

class _SimonSaysGameState extends State<SimonSaysGame>
    with TickerProviderStateMixin {
  GamePhase _phase = GamePhase.ready;
  int _level = 1;
  int _score = 0;
  int _highScore = 0;
  int _lives = 3;
  
  int _sequenceLength = 3;
  double _flashDuration = 0.8;
  List<Color> _sequence = [];
  List<Color> _playerInput = [];
  int _currentFlashIndex = 0;
  bool _isShowingSequence = true;
  
  // Custom game settings
  bool _isCustomGame = false;
  int _customSequenceLength = 3;
  double _customFlashDuration = 0.8;
  
  Timer? _flashTimer;
  Timer? _pauseTimer;
  
  late AnimationController _colorFlashController;
  late AnimationController _resultController;
  late Animation<double> _colorScaleAnimation;
  
  // Color buttons - using distinct, high-contrast colors
  final List<Color> _colors = [
    const Color(0xFFFF3B30), // Bright Red
    const Color(0xFF007AFF), // Bright Blue
    const Color(0xFFFFCC00), // Bright Yellow
    const Color(0xFF34C759), // Bright Green
  ];

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _colorFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _colorScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _colorFlashController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _pauseTimer?.cancel();
    _colorFlashController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _level = prefs.getInt('simon_level') ?? 1;
      _highScore = prefs.getInt('simon_high_score') ?? 0;
      _sequenceLength = prefs.getInt('simon_length') ?? 3;
      _flashDuration = prefs.getDouble('simon_flash_duration') ?? 0.8;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('simon_level', _level);
    await prefs.setInt('simon_high_score', _highScore);
    await prefs.setInt('simon_length', _sequenceLength);
    await prefs.setDouble('simon_flash_duration', _flashDuration);
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
      _sequenceLength = _customSequenceLength;
      _flashDuration = _customFlashDuration;
    });
  }

  void _startRound() {
    _generateSequence();
    setState(() {
      _phase = GamePhase.showing;
      _currentFlashIndex = 0;
      _playerInput = [];
      _isShowingSequence = true;
    });
    _flashNextColor();
  }

  void _generateSequence() {
    final random = math.Random();
    _sequence = [];
    for (int i = 0; i < _sequenceLength; i++) {
      _sequence.add(_colors[random.nextInt(_colors.length)]);
    }
  }

  void _flashNextColor() {
    if (_currentFlashIndex >= _sequence.length) {
      // All colors flashed, move to input phase
      setState(() {
        _phase = GamePhase.guessing;
        _isShowingSequence = false;
      });
      return;
    }
    
    _colorFlashController.forward(from: 0);
    
    _flashTimer?.cancel();
    _flashTimer = Timer(Duration(milliseconds: (_flashDuration * 1000).toInt()), () {
      _colorFlashController.reverse();
      
      _pauseTimer?.cancel();
      _pauseTimer = Timer(const Duration(milliseconds: 300), () {
        setState(() {
          _currentFlashIndex++;
        });
        _flashNextColor();
      });
    });
  }

  void _onColorTap(Color color) {
    if (_phase != GamePhase.guessing) return;
    
    setState(() {
      _playerInput.add(color);
    });
    
    // Check if sequence is complete
    if (_playerInput.length == _sequence.length) {
      _checkAnswer();
    }
  }

  void _checkAnswer() {
    bool isCorrect = _playerInput.length == _sequence.length &&
        _playerInput.asMap().entries.every((entry) => entry.value == _sequence[entry.key]);
    
    setState(() {
      if (!isCorrect && !_isCustomGame) {
        _lives--;
        if (_lives <= 0) {
          _phase = GamePhase.gameOver;
        } else {
          _phase = GamePhase.incorrect;
        }
      } else {
        _phase = isCorrect ? GamePhase.correct : GamePhase.incorrect;
      }
      
      if (isCorrect) {
        _score += (_level * 25) + (_sequenceLength * 15);
        if (_score > _highScore) {
          _highScore = _score;
        }
      }
    });
    
    if (_phase == GamePhase.gameOver) return;
    
    _resultController.forward(from: 0);
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _phase != GamePhase.gameOver) {
      if (isCorrect) {
        if (!_isCustomGame) {
          _levelUp();
        } else {
          _level++;
          _sequenceLength = _customSequenceLength;
          _flashDuration = _customFlashDuration;
        }
      }
      if (mounted) _startRound();
      }
    });
  }

  void _levelUp() {
    if (_isCustomGame) return;
    
    _level++;
    
    if (_level % 2 == 0 && _sequenceLength < 10) {
      _sequenceLength++;
    }
    
    if (_level % 3 == 0 && _flashDuration > 0.4) {
      _flashDuration -= 0.1;
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
      case GamePhase.showing:
        return _buildShowingScreen();
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
                  colors: [Color(0xFFE84393), Color(0xFFFD79A8)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE84393).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.color_lens_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Simon Says',
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
                    Icons.color_lens_rounded,
                    'Watch colors flash in sequence',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.touch_app_rounded,
                    'Tap the colors in the same order',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.speed_rounded,
                    'Sequence gets longer each round',
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
                    colors: [Color(0xFFE84393), Color(0xFFFD79A8)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE84393).withOpacity(0.4),
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
        Icon(icon, color: const Color(0xFFE84393), size: 24),
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
                    'Sequence Length',
                    _customSequenceLength,
                    (val) => setState(() => _customSequenceLength = val),
                    2.0,
                    15.0,
                  ),
                  const SizedBox(height: 24),
                  _buildSettingRow(
                    'Flash Duration (seconds)',
                    _customFlashDuration,
                    (val) => setState(() => _customFlashDuration = val),
                    0.3,
                    2.0,
                    isDouble: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                  _sequenceLength = _customSequenceLength;
                  _flashDuration = _customFlashDuration;
                  _startRound();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: () {
                  _sequenceLength = _customSequenceLength;
                  _flashDuration = _customFlashDuration;
                  _startRound();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE84393), Color(0xFFFD79A8)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE84393).withOpacity(0.4),
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
              icon: const Icon(Icons.remove_circle, color: Color(0xFFE84393)),
            ),
            Expanded(
              child: Text(
                isDouble ? (value as double).toStringAsFixed(1) : value.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFFE84393),
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
              icon: const Icon(Icons.add_circle, color: Color(0xFFE84393)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShowingScreen() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE84393).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE84393).withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.visibility_rounded, color: Color(0xFFE84393), size: 20),
              const SizedBox(width: 8),
              Text(
                'Watch the sequence • ${_currentFlashIndex + 1}/$_sequenceLength',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFE84393),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: AnimatedBuilder(
              animation: _colorScaleAnimation,
              builder: (context, child) {
                final currentColor = _currentFlashIndex < _sequence.length
                    ? _sequence[_currentFlashIndex]
                    : Colors.transparent;
                return Transform.scale(
                  scale: _currentFlashIndex < _sequence.length && _colorFlashController.isAnimating
                      ? _colorScaleAnimation.value
                      : 1.0,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: currentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: currentColor.withOpacity(0.6),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuessingScreen() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE84393).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE84393).withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.touch_app_rounded, color: Color(0xFFE84393), size: 20),
              const SizedBox(width: 8),
              Text(
                'Tap colors in order • ${_playerInput.length}/$_sequenceLength',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFE84393),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.0,
              ),
              itemCount: _colors.length,
              itemBuilder: (context, index) {
                final color = _colors[index];
                final isSelected = _playerInput.contains(color) && 
                    _playerInput.indexOf(color) < _playerInput.length;
                return GestureDetector(
                  onTap: () => _onColorTap(color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.6),
                          blurRadius: 20,
                          spreadRadius: isSelected ? 5 : 0,
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 40)
                        : null,
                  ),
                );
              },
            ),
          ),
        ),
      ],
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
                gradient: LinearGradient(
                  colors: isCorrect
                      ? [const Color(0xFF00B894), const Color(0xFF55EFC4)]
                      : [const Color(0xFFFF6B6B), const Color(0xFFFF8E8E)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isCorrect ? const Color(0xFF00B894) : const Color(0xFFFF6B6B))
                        .withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                isCorrect ? Icons.check_rounded : Icons.close_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isCorrect ? 'Perfect!' : 'Try Again!',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
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
                    colors: [Color(0xFFE84393), Color(0xFFFD79A8)],
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

