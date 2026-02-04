import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;

class SpeedNumbersGame extends StatefulWidget {
  const SpeedNumbersGame({super.key});

  @override
  State<SpeedNumbersGame> createState() => _SpeedNumbersGameState();
}

class _SpeedNumbersGameState extends State<SpeedNumbersGame>
    with TickerProviderStateMixin {
  GamePhase _phase = GamePhase.ready;
  int _level = 1;
  int _score = 0;
  int _highScore = 0;
  
  int _numberCount = 3;
  double _flashDuration = 0.8;
  double _pauseDuration = 0.3;
  
  // Custom game settings
  bool _isCustomGame = false;
  int _customNumberCount = 3;
  double _customFlashDuration = 0.8;
  double _customPauseDuration = 0.3;
  
  List<int> _numbers = [];
  int _currentFlashIndex = 0;
  List<int> _playerInput = [];
  String _inputValue = '';
  
  Timer? _flashTimer;
  Timer? _pauseTimer;
  
  late AnimationController _numberFlashController;
  late AnimationController _resultController;
  late Animation<double> _numberFadeAnimation;
  late Animation<double> _numberScaleAnimation;
  
  final FocusNode _inputFocusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _numberFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _numberFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _numberFlashController,
        curve: Curves.easeOut,
      ),
    );
    
    _numberScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _numberFlashController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _pauseTimer?.cancel();
    _numberFlashController.dispose();
    _resultController.dispose();
    _inputFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _level = prefs.getInt('speed_level') ?? 1;
      _highScore = prefs.getInt('speed_high_score') ?? 0;
      _numberCount = prefs.getInt('speed_count') ?? 3;
      _flashDuration = prefs.getDouble('speed_flash_duration') ?? 0.8;
      _pauseDuration = prefs.getDouble('speed_pause_duration') ?? 0.3;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('speed_level', _level);
    await prefs.setInt('speed_high_score', _highScore);
    await prefs.setInt('speed_count', _numberCount);
    await prefs.setDouble('speed_flash_duration', _flashDuration);
    await prefs.setDouble('speed_pause_duration', _pauseDuration);
  }

  void _startGame() {
    setState(() {
      _phase = GamePhase.ready;
      _score = 0;
      _isCustomGame = false;
    });
    _startRound();
  }

  void _startCustomGame() {
    setState(() {
      _phase = GamePhase.customSettings;
      _score = 0;
      _isCustomGame = true;
    });
  }

  void _startRound() {
    _generateNumbers();
    setState(() {
      _phase = GamePhase.showing;
      _currentFlashIndex = 0;
      _playerInput = [];
      _inputValue = '';
    });
    _textController.clear();
    _flashNextNumber();
  }

  void _generateNumbers() {
    final random = math.Random();
    _numbers = List.generate(_numberCount, (_) => random.nextInt(9) + 1);
  }

  void _flashNextNumber() {
    if (_currentFlashIndex >= _numbers.length) {
      // All numbers flashed, move to guessing phase
      setState(() {
        _phase = GamePhase.guessing;
      });
      _inputFocusNode.requestFocus();
      return;
    }
    
    _numberFlashController.forward(from: 0);
    
    _flashTimer?.cancel();
    _flashTimer = Timer(Duration(milliseconds: (_flashDuration * 1000).toInt()), () {
      _numberFlashController.reverse();
      
      _pauseTimer?.cancel();
      _pauseTimer = Timer(Duration(milliseconds: (_pauseDuration * 1000).toInt()), () {
        setState(() {
          _currentFlashIndex++;
        });
        _flashNextNumber();
      });
    });
  }

  void _onNumberInput(String value) {
    if (value.isEmpty) {
      setState(() => _inputValue = '');
      return;
    }
    
    // Parse as individual digits
    final digits = value.split('').map((d) => int.tryParse(d)).whereType<int>().toList();
    
    setState(() {
      _inputValue = value;
      _playerInput = digits;
    });
  }

  void _submitAnswer() {
    if (_inputValue.isEmpty || _playerInput.length != _numbers.length) return;
    
    _checkAnswer();
  }

  void _checkAnswer() {
    _flashTimer?.cancel();
    _pauseTimer?.cancel();
    
    bool isCorrect = _playerInput.length == _numbers.length &&
        _playerInput.asMap().entries.every((entry) => entry.value == _numbers[entry.key]);
    
    setState(() {
      _phase = isCorrect ? GamePhase.correct : GamePhase.incorrect;
      if (isCorrect) {
        _score += (_level * 25) + (_numberCount * 15);
        if (_score > _highScore) {
          _highScore = _score;
        }
      }
    });
    
    _resultController.forward(from: 0);
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (isCorrect) {
        if (!_isCustomGame) {
          _levelUp();
        } else {
          // In custom game, just increment level for display but keep settings the same
          _level++;
          // Reset to custom settings to maintain difficulty
          _numberCount = _customNumberCount;
          _flashDuration = _customFlashDuration;
          _pauseDuration = _customPauseDuration;
        }
      }
      _startRound();
    });
  }

  void _levelUp() {
    if (_isCustomGame) return; // Don't level up in custom games
    
    _level++;
    
    if (_level % 2 == 0 && _numberCount < 8) {
      _numberCount++;
    }
    
    if (_level % 3 == 0 && _flashDuration > 0.3) {
      _flashDuration -= 0.1;
    }
    
    if (_level % 4 == 0 && _pauseDuration > 0.1) {
      _pauseDuration -= 0.05;
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
              _buildHeader(),
              Expanded(child: _buildGameContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatChip(Icons.star_rounded, '$_score', const Color(0xFFFDCB6E)),
                const SizedBox(width: 12),
                _buildStatChip(Icons.trending_up_rounded, 'Lv.$_level', const Color(0xFFFDCB6E)),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(
            value,
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
                  colors: [Color(0xFFFDCB6E), Color(0xFFF9CA24)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFDCB6E).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.flash_on_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Speed Numbers',
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
                    Icons.flash_on_rounded,
                    'Numbers will flash quickly on screen',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.memory_rounded,
                    'Memorize the sequence as they appear',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.speed_rounded,
                    'Enter the complete sequence in order',
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
                    colors: [Color(0xFFFDCB6E), Color(0xFFF9CA24)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFDCB6E).withOpacity(0.4),
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
        Icon(icon, color: const Color(0xFFF9CA24), size: 24),
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
                    'Number Count',
                    _customNumberCount,
                    (val) => setState(() => _customNumberCount = val),
                    2.0,
                    10.0,
                  ),
                  const SizedBox(height: 24),
                  _buildSettingRow(
                    'Flash Duration (seconds)',
                    _customFlashDuration,
                    (val) => setState(() => _customFlashDuration = val),
                    0.2,
                    2.0,
                    isDouble: true,
                  ),
                  const SizedBox(height: 24),
                  _buildSettingRow(
                    'Pause Duration (seconds)',
                    _customPauseDuration,
                    (val) => setState(() => _customPauseDuration = val),
                    0.1,
                    1.0,
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
                  _numberCount = _customNumberCount;
                  _flashDuration = _customFlashDuration;
                  _pauseDuration = _customPauseDuration;
                  _startRound();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: () {
                  _numberCount = _customNumberCount;
                  _flashDuration = _customFlashDuration;
                  _pauseDuration = _customPauseDuration;
                  _startRound();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFDCB6E), Color(0xFFF9CA24)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFDCB6E).withOpacity(0.4),
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
              icon: const Icon(Icons.remove_circle, color: Color(0xFFFDCB6E)),
            ),
            Expanded(
              child: Text(
                isDouble ? (value as double).toStringAsFixed(1) : value.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFFFDCB6E),
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
              icon: const Icon(Icons.add_circle, color: Color(0xFFFDCB6E)),
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
            color: const Color(0xFFFDCB6E).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDCB6E).withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFF9CA24), size: 20),
              const SizedBox(width: 8),
              Text(
                'Numbers: $_numberCount • Flash: ${_flashDuration.toStringAsFixed(1)}s',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFF9CA24),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: FadeTransition(
              opacity: _numberFadeAnimation,
              child: ScaleTransition(
                scale: _numberScaleAnimation,
                child: _currentFlashIndex < _numbers.length
                    ? _buildFlashingNumber(_numbers[_currentFlashIndex])
                    : const SizedBox(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlashingNumber(int number) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFDCB6E), Color(0xFFF9CA24)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFDCB6E).withOpacity(0.5),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 80,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildGuessingScreen() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFDCB6E).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDCB6E).withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFF9CA24), size: 20),
              const SizedBox(width: 8),
              Text(
                'Enter the complete sequence in order',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFF9CA24),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'What was the sequence?',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter $_numberCount digits',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 32),
        // Input field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: TextField(
            controller: _textController,
            focusNode: _inputFocusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: InputDecoration(
              hintText: '?' * _numberCount,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 48,
                letterSpacing: 8,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFFDCB6E), width: 2),
              ),
            ),
            onChanged: _onNumberInput,
            onSubmitted: (_) => _submitAnswer(),
          ),
        ),
        const SizedBox(height: 24),
        // Submit button
        GestureDetector(
          onTap: _inputValue.length == _numberCount ? _submitAnswer : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            decoration: BoxDecoration(
              gradient: _inputValue.length == _numberCount
                  ? const LinearGradient(
                      colors: [Color(0xFFFDCB6E), Color(0xFFF9CA24)],
                    )
                  : null,
              color: _inputValue.length != _numberCount ? Colors.white10 : null,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              'SUBMIT',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: _inputValue.length == _numberCount ? Colors.white : Colors.white30,
                letterSpacing: 2,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const Spacer(),
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
              isCorrect ? 'Correct!' : 'Wrong!',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: isCorrect ? const Color(0xFF55EFC4) : const Color(0xFFFF6B6B),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sequence: ${_numbers.join(" ")}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            if (isCorrect) ...[
              const SizedBox(height: 8),
              Text(
                '+${(_level * 25) + (_numberCount * 15)} points',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFFDCB6E),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
                border: Border.all(color: Colors.white24, width: 3),
              ),
              child: const Icon(
                Icons.sports_esports_rounded,
                size: 60,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Game Over',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _buildScoreRow('Final Score', '$_score', const Color(0xFFFDCB6E)),
                  const SizedBox(height: 12),
                  _buildScoreRow('Level Reached', '$_level', const Color(0xFFFDCB6E)),
                  const SizedBox(height: 12),
                  _buildScoreRow('High Score', '$_highScore', const Color(0xFFF9CA24)),
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
                    colors: [Color(0xFFFDCB6E), Color(0xFFF9CA24)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFDCB6E).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
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
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Back to Menu',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white54,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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

