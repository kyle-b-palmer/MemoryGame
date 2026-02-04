import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;

class MissingNumberGame extends StatefulWidget {
  const MissingNumberGame({super.key});

  @override
  State<MissingNumberGame> createState() => _MissingNumberGameState();
}

class _MissingNumberGameState extends State<MissingNumberGame>
    with TickerProviderStateMixin {
  // Game state
  GamePhase _phase = GamePhase.ready;
  int _level = 1;
  int _score = 0;
  int _highScore = 0;
  int _consecutiveFailures = 0;
  
  // Number display settings
  int _totalNumbers = 5;
  int _missingCount = 1;
  double _displayDuration = 3.0;
  
  // Current round data
  List<int> _displayedNumbers = [];
  List<int> _missingNumbers = [];
  List<int> _playerGuesses = [];
  String _inputValue = '';
  
  // Timers and controllers
  Timer? _displayTimer;
  Timer? _countdownTimer;
  double _timeRemaining = 0;
  
  // Animation controllers
  late AnimationController _numberFlashController;
  late AnimationController _resultController;
  late Animation<double> _numberFadeAnimation;
  late Animation<double> _numberScaleAnimation;
  
  // Focus node for input
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
    
    _numberScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _numberFlashController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    _countdownTimer?.cancel();
    _numberFlashController.dispose();
    _resultController.dispose();
    _inputFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _level = prefs.getInt('saved_level') ?? 1;
      _highScore = prefs.getInt('high_score') ?? 0;
      _totalNumbers = prefs.getInt('total_numbers') ?? 5;
      _missingCount = prefs.getInt('missing_count') ?? 1;
      _displayDuration = prefs.getDouble('display_duration') ?? 3.0;
    });
    _applyDifficultySettings();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('saved_level', _level);
    await prefs.setInt('high_score', _highScore);
    await prefs.setInt('total_numbers', _totalNumbers);
    await prefs.setInt('missing_count', _missingCount);
    await prefs.setDouble('display_duration', _displayDuration);
  }

  void _applyDifficultySettings() {
    // Ensure difficulty settings are valid based on level
    if (_totalNumbers < 5) _totalNumbers = 5;
    if (_missingCount < 1) _missingCount = 1;
    if (_displayDuration < 1.0) _displayDuration = 1.0;
    if (_displayDuration > 3.0) _displayDuration = 3.0;
  }

  void _startGame() {
    setState(() {
      _phase = GamePhase.ready;
      _score = 0;
      _consecutiveFailures = 0;
    });
    _startRound();
  }

  void _startRound() {
    _generateNumbers();
    setState(() {
      _phase = GamePhase.showing;
      _timeRemaining = _displayDuration;
      _playerGuesses = [];
      _inputValue = '';
    });
    _textController.clear();
    
    _numberFlashController.forward(from: 0);
    
    // Countdown timer
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _timeRemaining -= 0.05;
        if (_timeRemaining <= 0) {
          _timeRemaining = 0;
          timer.cancel();
        }
      });
    });
    
    // Display timer
    _displayTimer?.cancel();
    _displayTimer = Timer(Duration(milliseconds: (_displayDuration * 1000).toInt()), () {
      _countdownTimer?.cancel();
      setState(() {
        _phase = GamePhase.guessing;
      });
      _inputFocusNode.requestFocus();
    });
  }

  void _generateNumbers() {
    final random = math.Random();
    
    // Generate sequence from 1 to totalNumbers
    List<int> fullSequence = List.generate(_totalNumbers, (i) => i + 1);
    
    // Pick random numbers to hide
    fullSequence.shuffle(random);
    _missingNumbers = fullSequence.take(_missingCount).toList();
    _missingNumbers.sort();
    
    // Create displayed numbers (full sequence minus missing)
    _displayedNumbers = List.generate(_totalNumbers, (i) => i + 1)
      ..removeWhere((n) => _missingNumbers.contains(n));
  }

  void _submitGuess() {
    if (_inputValue.isEmpty) return;
    
    final guess = int.tryParse(_inputValue);
    if (guess == null) {
      _textController.clear();
      setState(() => _inputValue = '');
      return;
    }
    
    setState(() {
      if (!_playerGuesses.contains(guess)) {
        _playerGuesses.add(guess);
      }
      _inputValue = '';
    });
    _textController.clear();
    
    // Check if all guesses have been made
    if (_playerGuesses.length >= _missingCount) {
      _checkAnswer();
    }
  }

  void _checkAnswer() {
    _displayTimer?.cancel();
    _countdownTimer?.cancel();
    
    // Sort both lists for comparison
    final sortedGuesses = List<int>.from(_playerGuesses)..sort();
    final sortedMissing = List<int>.from(_missingNumbers)..sort();
    
    bool isCorrect = sortedGuesses.length == sortedMissing.length &&
        sortedGuesses.every((g) => sortedMissing.contains(g));
    
    setState(() {
      _phase = isCorrect ? GamePhase.correct : GamePhase.incorrect;
      if (isCorrect) {
        _score += (_level * 10) + (_displayDuration * 5).toInt();
        if (_score > _highScore) {
          _highScore = _score;
        }
        _consecutiveFailures = 0; // Reset failures on success
      } else {
        _consecutiveFailures++;
        // If failed twice in a row, reduce difficulty
        if (_consecutiveFailures >= 2) {
          _reduceDifficulty();
          _consecutiveFailures = 0; // Reset after reducing difficulty
        }
      }
    });
    
    _resultController.forward(from: 0);
    
    // Move to next round
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (isCorrect) {
        _levelUp();
      }
      _startRound();
    });
  }

  void _levelUp() {
    _level++;
    
    // Increase difficulty every few levels
    if (_level % 3 == 0 && _totalNumbers < 15) {
      _totalNumbers++;
    }
    
    if (_level % 5 == 0 && _missingCount < 3) {
      _missingCount++;
    }
    
    // Decrease display time (minimum 1 second)
    if (_level % 2 == 0 && _displayDuration > 1.0) {
      _displayDuration -= 0.2;
    }
    
    _saveProgress();
  }

  void _reduceDifficulty() {
    // Reduce total numbers (minimum 5)
    if (_totalNumbers > 5) {
      _totalNumbers--;
    }
    
    // Reduce missing count (minimum 1)
    if (_missingCount > 1) {
      _missingCount--;
    }
    
    // Increase display time (maximum 3.0 seconds)
    if (_displayDuration < 3.0) {
      _displayDuration += 0.2;
    }
    
    // Reduce level if possible (minimum 1)
    if (_level > 1) {
      _level--;
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
              Expanded(
                child: _buildGameContent(),
              ),
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
                _buildStatChip(Icons.trending_up_rounded, 'Lv.$_level', const Color(0xFF6C5CE7)),
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
                  colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.question_mark_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Missing Number',
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
                    'Watch the sequence of numbers flash on screen',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.search_rounded,
                    'Find the missing number(s) in the sequence',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.speed_rounded,
                    'Be quick! Time decreases as you level up',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_level > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.4)),
                ),
                child: Text(
                  'Resuming from Level $_level',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFA29BFE),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _startGame,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C5CE7).withOpacity(0.4),
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
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFA29BFE), size: 24),
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

  Widget _buildShowingScreen() {
    return Column(
      children: [
        // Info bar showing total numbers expected
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF6C5CE7).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFA29BFE), size: 20),
              const SizedBox(width: 8),
              Text(
                'Sequence: 1 to $_totalNumbers • Find $_missingCount missing',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFA29BFE),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Timer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MEMORIZE!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white54,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    '${_timeRemaining.toStringAsFixed(1)}s',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _timeRemaining < 1 ? Colors.red : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _timeRemaining / _displayDuration,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(
                    _timeRemaining < 1 ? Colors.red : const Color(0xFF6C5CE7),
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        // Numbers display
        Expanded(
          child: Center(
            child: FadeTransition(
              opacity: _numberFadeAnimation,
              child: ScaleTransition(
                scale: _numberScaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: _displayedNumbers.map((number) {
                      return _buildNumberTile(number);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberTile(int number, {bool isGuess = false, bool isCorrect = false}) {
    Color bgColor;
    Color textColor;
    Color borderColor;
    
    if (isGuess) {
      if (isCorrect) {
        bgColor = const Color(0xFF00B894).withOpacity(0.2);
        textColor = const Color(0xFF55EFC4);
        borderColor = const Color(0xFF00B894);
      } else {
        bgColor = const Color(0xFFFF6B6B).withOpacity(0.2);
        textColor = const Color(0xFFFF6B6B);
        borderColor = const Color(0xFFFF6B6B);
      }
    } else {
      bgColor = const Color(0xFF6C5CE7).withOpacity(0.15);
      textColor = Colors.white;
      borderColor = const Color(0xFF6C5CE7).withOpacity(0.5);
    }
    
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            color: textColor,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildGuessingScreen() {
    return Column(
      children: [
        // Info bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFDCB6E).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDCB6E).withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFDCB6E), size: 20),
              const SizedBox(width: 8),
              Text(
                'Sequence was 1 to $_totalNumbers • Enter $_missingCount missing number${_missingCount > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFFDCB6E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Question prompt
        Text(
          'What ${_missingCount > 1 ? 'are' : 'is'} the missing number${_missingCount > 1 ? 's' : ''}?',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_playerGuesses.length}/$_missingCount entered',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 24),
        // Current guesses
        if (_playerGuesses.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _playerGuesses.map((guess) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6C5CE7)),
                ),
                child: Text(
                  '$guess',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
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
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              hintText: '?',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 32,
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
                borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 2),
              ),
            ),
            onChanged: (value) {
              setState(() => _inputValue = value);
            },
            onSubmitted: (_) => _submitGuess(),
          ),
        ),
        const SizedBox(height: 24),
        // Submit button
        GestureDetector(
          onTap: _inputValue.isNotEmpty ? _submitGuess : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            decoration: BoxDecoration(
              gradient: _inputValue.isNotEmpty
                  ? const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                    )
                  : null,
              color: _inputValue.isEmpty ? Colors.white10 : null,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              _playerGuesses.length < _missingCount - 1 ? 'ADD NUMBER' : 'SUBMIT',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: _inputValue.isNotEmpty ? Colors.white : Colors.white30,
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
          return Transform.scale(
            scale: value,
            child: child,
          );
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
              'Missing: ${_missingNumbers.join(", ")}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            if (isCorrect) ...[
              const SizedBox(height: 8),
              Text(
                '+${(_level * 10) + (_displayDuration * 5).toInt()} points',
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
                  _buildScoreRow('Level Reached', '$_level', const Color(0xFF6C5CE7)),
                  const SizedBox(height: 12),
                  _buildScoreRow('High Score', '$_highScore', const Color(0xFF55EFC4)),
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
                    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C5CE7).withOpacity(0.4),
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
  showing,
  guessing,
  correct,
  incorrect,
  gameOver,
}

