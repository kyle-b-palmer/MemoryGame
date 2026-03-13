import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;

class ReverseSequenceGame extends StatefulWidget {
  const ReverseSequenceGame({super.key});

  @override
  State<ReverseSequenceGame> createState() => _ReverseSequenceGameState();
}

class _ReverseSequenceGameState extends State<ReverseSequenceGame>
    with TickerProviderStateMixin {
  GamePhase _phase = GamePhase.ready;
  int _level = 1;
  int _score = 0;
  int _highScore = 0;
  int _lives = 3;
  
  int _sequenceLength = 3;
  double _displayDuration = 2.0;
  List<int> _sequence = [];
  List<int> _playerInput = [];
  int _currentInputIndex = 0;
  
  // Custom game settings
  bool _isCustomGame = false;
  int _customSequenceLength = 3;
  double _customDisplayDuration = 2.0;
  
  Timer? _displayTimer;
  Timer? _countdownTimer;
  double _timeRemaining = 0;
  
  late AnimationController _numberFlashController;
  late AnimationController _resultController;
  late Animation<double> _numberFadeAnimation;
  
  final List<TextEditingController> _inputControllers = [];
  final List<FocusNode> _focusNodes = [];

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
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    _countdownTimer?.cancel();
    _numberFlashController.dispose();
    _resultController.dispose();
    for (var controller in _inputControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _level = prefs.getInt('reverse_seq_level') ?? 1;
      _highScore = prefs.getInt('reverse_seq_high_score') ?? 0;
      _sequenceLength = prefs.getInt('reverse_seq_length') ?? 3;
      _displayDuration = prefs.getDouble('reverse_seq_duration') ?? 2.0;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reverse_seq_level', _level);
    await prefs.setInt('reverse_seq_high_score', _highScore);
    await prefs.setInt('reverse_seq_length', _sequenceLength);
    await prefs.setDouble('reverse_seq_duration', _displayDuration);
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
      _displayDuration = _customDisplayDuration;
    });
  }

  void _startRound() {
    _generateSequence();
    _setupInputFields();
    setState(() {
      _phase = GamePhase.nextRound;
      _playerInput = [];
      _currentInputIndex = 0;
    });
  }

  void _proceedToShowing() {
    setState(() {
      _phase = GamePhase.showing;
      _timeRemaining = _displayDuration;
    });
    
    _numberFlashController.forward(from: 0);
    
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
    
    _displayTimer?.cancel();
    _displayTimer = Timer(Duration(milliseconds: (_displayDuration * 1000).toInt()), () {
      _countdownTimer?.cancel();
      setState(() {
        _phase = GamePhase.guessing;
      });
      if (_focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  void _generateSequence() {
    final random = math.Random();
    _sequence = [];
    while (_sequence.length < _sequenceLength) {
      int num = random.nextInt(9) + 1;
      _sequence.add(num);
    }
  }

  void _setupInputFields() {
    for (var controller in _inputControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _inputControllers.clear();
    _focusNodes.clear();
    
    for (int i = 0; i < _sequenceLength; i++) {
      _inputControllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
  }

  void _onNumberInput(String value, int index) {
    if (value.isEmpty) return;
    
    final number = int.tryParse(value);
    if (number == null || number < 1 || number > 9) {
      _inputControllers[index].clear();
      return;
    }
    
    setState(() {
      if (_playerInput.length <= index) {
        _playerInput.add(number);
      } else {
        _playerInput[index] = number;
      }
      _currentInputIndex = index;
    });
    
    if (index < _sequenceLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  void _submitAnswer() {
    if (_phase != GamePhase.guessing) return;
    if (_playerInput.length != _sequenceLength) return;
    _checkAnswer();
  }

  void _checkAnswer() {
    _displayTimer?.cancel();
    _countdownTimer?.cancel();
    
    // Check if player input matches reversed sequence
    final reversedSequence = _sequence.reversed.toList();
    bool isCorrect = _playerInput.length == reversedSequence.length &&
        _playerInput.asMap().entries.every((entry) => entry.value == reversedSequence[entry.key]);
    
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
        _score += (_level * 30) + (_sequenceLength * 10);
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
            _displayDuration = _customDisplayDuration;
          }
        }
        if (mounted) _startRound();
      }
    });
  }

  void _levelUp() {
    if (_isCustomGame) return;
    
    _level++;
    
    if (_level % 2 == 0 && _sequenceLength < 8) {
      _sequenceLength++;
    }
    
    if (_level % 3 == 0 && _displayDuration > 1.0) {
      _displayDuration -= 0.2;
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
      case GamePhase.nextRound:
        return _buildNextRoundScreen();
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
                  colors: [Color(0xFFA29BFE), Color(0xFF6C5CE7)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFA29BFE).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Reverse Sequence',
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
                    'Watch the sequence of numbers appear',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.swap_horiz_rounded,
                    'Enter the sequence in REVERSE order',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.speed_rounded,
                    'Time decreases as you level up',
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
                    colors: [Color(0xFFA29BFE), Color(0xFF6C5CE7)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA29BFE).withOpacity(0.4),
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
                    10.0,
                  ),
                  const SizedBox(height: 24),
                  _buildSettingRow(
                    'Display Speed (seconds)',
                    _customDisplayDuration,
                    (val) => setState(() => _customDisplayDuration = val),
                    0.5,
                    5.0,
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
                  _displayDuration = _customDisplayDuration;
                  _startRound();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: () {
                  _sequenceLength = _customSequenceLength;
                  _displayDuration = _customDisplayDuration;
                  _startRound();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA29BFE), Color(0xFF6C5CE7)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA29BFE).withOpacity(0.4),
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
              icon: const Icon(Icons.remove_circle, color: Color(0xFFA29BFE)),
            ),
            Expanded(
              child: Text(
                isDouble ? (value as double).toStringAsFixed(1) : value.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFFA29BFE),
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
              icon: const Icon(Icons.add_circle, color: Color(0xFFA29BFE)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNextRoundScreen() {
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
                  colors: [Color(0xFFA29BFE), Color(0xFF6C5CE7)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFA29BFE).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Round $_level',
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
                  _buildPreviewRow(Icons.numbers_rounded, 'Sequence Length', '$_sequenceLength'),
                  const SizedBox(height: 12),
                  _buildPreviewRow(Icons.speed_rounded, 'Display Time', '${_displayDuration.toStringAsFixed(1)}s'),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                  _proceedToShowing();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: _proceedToShowing,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA29BFE), Color(0xFF6C5CE7)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA29BFE).withOpacity(0.4),
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

  Widget _buildPreviewRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFFA29BFE), size: 20),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFFA29BFE),
            fontWeight: FontWeight.bold,
          ),
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
            color: const Color(0xFFA29BFE).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA29BFE).withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFA29BFE), size: 20),
              const SizedBox(width: 8),
              Text(
                'Memorize the sequence • Enter in REVERSE order',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFA29BFE),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MEMORIZE!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white54,
                ),
              ),
              Text(
                '${_timeRemaining.toStringAsFixed(1)}s',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFA29BFE),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: FadeTransition(
              opacity: _numberFadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: _sequence.asMap().entries.map((entry) {
                    return _buildNumberTile(entry.value, entry.key);
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberTile(int number, int index) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFA29BFE), Color(0xFF6C5CE7)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA29BFE).withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
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
            color: const Color(0xFFA29BFE).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA29BFE).withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.swap_horiz_rounded, color: Color(0xFFA29BFE), size: 20),
              const SizedBox(width: 8),
              Text(
                'Enter the sequence in REVERSE order',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFA29BFE),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: List.generate(_sequenceLength, (index) {
            return SizedBox(
              width: 70,
              child: TextField(
                controller: _inputControllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(1),
                ],
                decoration: InputDecoration(
                  hintText: '?',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 28,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _currentInputIndex == index
                          ? const Color(0xFFA29BFE)
                          : Colors.white.withOpacity(0.2),
                      width: _currentInputIndex == index ? 2 : 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _currentInputIndex == index
                          ? const Color(0xFFA29BFE)
                          : Colors.white.withOpacity(0.2),
                      width: _currentInputIndex == index ? 2 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFA29BFE),
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) => _onNumberInput(value, index),
                onSubmitted: (_) {
                  if (_playerInput.length == _sequenceLength) {
                    _submitAnswer();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
              _submitAnswer();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            onTap: _submitAnswer,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              decoration: BoxDecoration(
                gradient: _playerInput.length == _sequenceLength
                    ? const LinearGradient(
                        colors: [Color(0xFFA29BFE), Color(0xFF6C5CE7)],
                      )
                    : null,
                color: _playerInput.length != _sequenceLength ? Colors.white10 : null,
                borderRadius: BorderRadius.circular(30),
                boxShadow: _playerInput.length == _sequenceLength
                    ? [
                        BoxShadow(
                          color: const Color(0xFFA29BFE).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                'SUBMIT',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: _playerInput.length == _sequenceLength ? Colors.white : Colors.white30,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
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
                    colors: [Color(0xFFA29BFE), Color(0xFF6C5CE7)],
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
  nextRound,
  showing,
  guessing,
  correct,
  incorrect,
  gameOver,
}

