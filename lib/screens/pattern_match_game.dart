import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;

class PatternMatchGame extends StatefulWidget {
  const PatternMatchGame({super.key});

  @override
  State<PatternMatchGame> createState() => _PatternMatchGameState();
}

class _PatternMatchGameState extends State<PatternMatchGame>
    with TickerProviderStateMixin {
  GamePhase _phase = GamePhase.ready;
  int _level = 1;
  int _score = 0;
  int _highScore = 0;
  
  int _gridSize = 3;
  int _filledCount = 3;
  double _displayDuration = 2.5;
  
  // Custom game settings
  bool _isCustomGame = false;
  int _customGridSize = 3;
  int _customFilledCount = 3;
  double _customDisplayDuration = 2.5;
  
  List<List<bool>> _filledGrid = [];
  List<List<bool>> _selectedGrid = [];
  Set<String> _filledPositions = {};
  Set<String> _selectedPositions = {};
  bool _answerSubmitted = false;
  
  Timer? _displayTimer;
  Timer? _countdownTimer;
  double _timeRemaining = 0;
  
  late AnimationController _flashController;
  late AnimationController _resultController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);
    
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _flashAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _flashController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    _countdownTimer?.cancel();
    _flashController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _level = prefs.getInt('pattern_level') ?? 1;
      _highScore = prefs.getInt('pattern_high_score') ?? 0;
      _gridSize = prefs.getInt('pattern_grid_size') ?? 3;
      _filledCount = prefs.getInt('pattern_filled_count') ?? 3;
      _displayDuration = prefs.getDouble('pattern_duration') ?? 2.5;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pattern_level', _level);
    await prefs.setInt('pattern_high_score', _highScore);
    await prefs.setInt('pattern_grid_size', _gridSize);
    await prefs.setInt('pattern_filled_count', _filledCount);
    await prefs.setDouble('pattern_duration', _displayDuration);
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
      _gridSize = _customGridSize;
      _filledCount = _customFilledCount;
      _displayDuration = _customDisplayDuration;
    });
  }

  void _startRound() {
    _generatePattern();
    setState(() {
      _phase = GamePhase.preview;
      _selectedGrid = List.generate(_gridSize, (_) => List.generate(_gridSize, (_) => false));
      _selectedPositions.clear();
      _answerSubmitted = false; // Reset feedback flag
    });
  }

  void _startShowing() {
    setState(() {
      _phase = GamePhase.showing;
      _timeRemaining = _displayDuration;
    });
    
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
      _flashController.stop();
      setState(() {
        _phase = GamePhase.guessing;
      });
    });
  }

  void _generatePattern() {
    final random = math.Random();
    _filledGrid = List.generate(_gridSize, (_) => List.generate(_gridSize, (_) => false));
    _filledPositions.clear();
    
    // Randomly fill squares
    int filled = 0;
    while (filled < _filledCount) {
      int row = random.nextInt(_gridSize);
      int col = random.nextInt(_gridSize);
      
      if (!_filledGrid[row][col]) {
        _filledGrid[row][col] = true;
        _filledPositions.add('$row,$col');
        filled++;
      }
    }
  }

  void _onCellTapped(int row, int col) {
    if (_phase != GamePhase.guessing) return;
    
    setState(() {
      _selectedGrid[row][col] = !_selectedGrid[row][col];
      String pos = '$row,$col';
      if (_selectedGrid[row][col]) {
        _selectedPositions.add(pos);
      } else {
        _selectedPositions.remove(pos);
      }
    });
  }

  void _submitAnswer() {
    if (_phase != GamePhase.guessing) return;
    _checkAnswer();
  }

  void _checkAnswer() {
    _displayTimer?.cancel();
    _countdownTimer?.cancel();
    
    bool isCorrect = _selectedPositions.length == _filledPositions.length &&
        _selectedPositions.every((pos) => _filledPositions.contains(pos));
    
    setState(() {
      _answerSubmitted = true; // Show feedback on grid
      if (isCorrect) {
        _score += (_level * 20) + (_gridSize * _gridSize * 5);
        if (_score > _highScore) {
          _highScore = _score;
        }
        _phase = GamePhase.correct; // Move to correct phase
      } else {
        // Keep in guessing phase to show grid with feedback
        _phase = GamePhase.guessing;
      }
    });
    
    if (isCorrect) {
      // Only show result screen for correct answers
      _resultController.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!_isCustomGame) {
          _levelUp();
        } else {
          // In custom game, just increment level for display but keep settings the same
          _level++;
          // Reset to custom settings to maintain difficulty
          _gridSize = _customGridSize;
          _filledCount = _customFilledCount;
          _displayDuration = _customDisplayDuration;
        }
        _startRound();
      });
    } else {
      // Show feedback on grid for 3 seconds, then restart round
      // Phase stays as guessing so grid remains visible
      Future.delayed(const Duration(milliseconds: 3000), () {
        _startRound();
      });
    }
  }

  void _levelUp() {
    _level++;
    
    if (_level % 3 == 0 && _gridSize < 6) {
      _gridSize++;
    }
    
    if (_level % 2 == 0 && _filledCount < _gridSize * _gridSize - 2) {
      _filledCount++;
    }
    
    if (_level % 2 == 0 && _displayDuration > 1.0) {
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
                _buildStatChip(Icons.trending_up_rounded, 'Lv.$_level', const Color(0xFFE17055)),
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
      case GamePhase.preview:
        return _buildPreviewScreen();
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
                  colors: [Color(0xFFE17055), Color(0xFFFAB1A0)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE17055).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Pattern Match',
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
                    'Watch as squares flash and fill in',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.memory_rounded,
                    'Remember which squares were filled',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.touch_app_rounded,
                    'Tap the squares that were filled in',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _startGame,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE17055), Color(0xFFFAB1A0)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE17055).withOpacity(0.4),
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
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _startCustomGame,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFE17055).withOpacity(0.5)),
                    ),
                    child: Text(
                      'CUSTOM',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFFFAB1A0),
                        letterSpacing: 2,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFAB1A0), size: 24),
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
                    (val) => setState(() {
                      _customGridSize = val;
                      // Adjust filled count if needed
                      if (_customFilledCount > _customGridSize * _customGridSize - 2) {
                        _customFilledCount = (_customGridSize * _customGridSize - 2).clamp(1, 10);
                      }
                    }),
                    3.0,
                    6.0,
                  ),
                  const SizedBox(height: 24),
                  _buildSettingRow(
                    'Filled Squares',
                    _customFilledCount,
                    (val) => setState(() {
                      final maxFilled = (_customGridSize * _customGridSize - 2).clamp(1, 10);
                      _customFilledCount = (val as int).clamp(1, maxFilled);
                    }),
                    1.0,
                    (_customGridSize * _customGridSize - 2).toDouble().clamp(1.0, 10.0),
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
                  _gridSize = _customGridSize;
                  _filledCount = _customFilledCount;
                  _displayDuration = _customDisplayDuration;
                  _startRound();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: () {
                  _gridSize = _customGridSize;
                  _filledCount = _customFilledCount;
                  _displayDuration = _customDisplayDuration;
                  _startRound();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE17055), Color(0xFFFAB1A0)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE17055).withOpacity(0.4),
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
                  if (value > min) onChanged((value as double) - 0.5);
                } else {
                  if (value > min) onChanged((value as int) - 1);
                }
              },
              icon: const Icon(Icons.remove_circle, color: Color(0xFFFAB1A0)),
            ),
            Expanded(
              child: Text(
                isDouble ? (value as double).toStringAsFixed(1) : value.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFFFAB1A0),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                if (isDouble) {
                  if (value < max) onChanged((value as double) + 0.5);
                } else {
                  if (value < max) onChanged((value as int) + 1);
                }
              },
              icon: const Icon(Icons.add_circle, color: Color(0xFFFAB1A0)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewScreen() {
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
                  colors: [Color(0xFFE17055), Color(0xFFFAB1A0)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE17055).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Round ${_level > 1 ? _level : 1}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _buildPreviewRow(Icons.grid_view_rounded, 'Grid Size', '${_gridSize}x$_gridSize'),
                  const SizedBox(height: 12),
                  _buildPreviewRow(Icons.check_box_rounded, 'Filled Squares', '$_filledCount'),
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
                  _startShowing();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: _startShowing,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE17055), Color(0xFFFAB1A0)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE17055).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    'OK',
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFFAB1A0), size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: const Color(0xFFFAB1A0),
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
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE17055).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE17055).withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFFAB1A0), size: 20),
              const SizedBox(width: 8),
              Text(
                'Grid: ${_gridSize}x$_gridSize • Filled: $_filledCount',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFFAB1A0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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
                      color: _timeRemaining < 0.5 ? Colors.red : Colors.white70,
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
                    _timeRemaining < 0.5 ? Colors.red : const Color(0xFFE17055),
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: _gridSize * 70.0,
                height: _gridSize * 70.0,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridSize,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _gridSize * _gridSize,
                  itemBuilder: (context, index) {
                    final row = index ~/ _gridSize;
                    final col = index % _gridSize;
                    return _buildFilledCell(row, col, true);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilledCell(int row, int col, bool isShowing) {
    final isFilled = _filledGrid[row][col];
    
    if (isShowing) {
      // During showing phase - animate filled cells
      if (isFilled) {
        return AnimatedBuilder(
          animation: _flashAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFE17055).withOpacity(_flashAnimation.value),
                    const Color(0xFFFAB1A0).withOpacity(_flashAnimation.value),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE17055).withOpacity(_flashAnimation.value * 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            );
          },
        );
      } else {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
        );
      }
    } else {
      // During guessing phase - show selection state
      final isSelected = _selectedGrid[row][col];
      final shouldBeFilled = _filledGrid[row][col];
      
      Color cellColor;
      Color borderColor;
      double opacity;
      IconData? icon;
      
      // Only show correct/incorrect colors after submission
      if (_answerSubmitted) {
        if (isSelected && shouldBeFilled) {
          // Correct selection - green
          cellColor = const Color(0xFF00B894);
          borderColor = const Color(0xFF55EFC4);
          opacity = 0.8;
          icon = Icons.check_circle;
        } else if (isSelected && !shouldBeFilled) {
          // Wrong selection - red
          cellColor = const Color(0xFFFF6B6B);
          borderColor = const Color(0xFFFF6B6B);
          opacity = 0.6;
          icon = Icons.cancel;
        } else if (!isSelected && shouldBeFilled) {
          // Should have been selected but wasn't - show correct pattern in green (lighter)
          cellColor = const Color(0xFF00B894);
          borderColor = const Color(0xFF55EFC4);
          opacity = 0.4;
          icon = Icons.check_circle_outline;
        } else {
          // Not selected and shouldn't be - neutral
          cellColor = Colors.white;
          borderColor = Colors.white.withOpacity(0.2);
          opacity = 0.05;
        }
      } else if (isSelected) {
        // Selected but not yet submitted - show neutral selection
        cellColor = const Color(0xFFFDCB6E);
        borderColor = const Color(0xFFFDCB6E);
        opacity = 0.4;
      } else {
        cellColor = Colors.white;
        borderColor = Colors.white.withOpacity(0.2);
        opacity = 0.05;
      }
      
      return Container(
        decoration: BoxDecoration(
          color: cellColor.withOpacity(opacity),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: (isSelected || (_answerSubmitted && shouldBeFilled)) ? 3 : 1,
          ),
        ),
        child: icon != null
            ? Center(
                child: Icon(
                  icon,
                  color: borderColor,
                  size: 24,
                ),
              )
            : null,
      );
    }
  }

  Widget _buildGuessingScreen() {
    final showFeedback = _answerSubmitted;
    // Calculate correctness based on current selections
    final isCorrect = showFeedback && 
        _selectedPositions.length == _filledPositions.length &&
        _selectedPositions.every((pos) => _filledPositions.contains(pos));
    
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: showFeedback
                ? (isCorrect 
                    ? const Color(0xFF00B894).withOpacity(0.2)
                    : const Color(0xFFFF6B6B).withOpacity(0.2))
                : const Color(0xFFFDCB6E).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: showFeedback
                  ? (isCorrect 
                      ? const Color(0xFF00B894).withOpacity(0.4)
                      : const Color(0xFFFF6B6B).withOpacity(0.4))
                  : const Color(0xFFFDCB6E).withOpacity(0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                showFeedback
                    ? (isCorrect ? Icons.check_circle : Icons.cancel)
                    : Icons.lightbulb_outline_rounded,
                color: showFeedback
                    ? (isCorrect ? const Color(0xFF00B894) : const Color(0xFFFF6B6B))
                    : const Color(0xFFFDCB6E),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                showFeedback
                    ? (isCorrect 
                        ? 'Correct! Green = right, Red = wrong'
                        : 'Incorrect! Green = correct pattern, Red = wrong selections')
                    : 'Tap the squares that were filled • Selected: ${_selectedPositions.length}/$_filledCount',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: showFeedback
                      ? (isCorrect ? const Color(0xFF00B894) : const Color(0xFFFF6B6B))
                      : const Color(0xFFFDCB6E),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          showFeedback
              ? (isCorrect ? 'Perfect!' : 'Try Again!')
              : 'Which squares were filled?',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate cell size to fit within available space
              // Account for padding (24 * 2 = 48) and spacing between cells
              final availableWidth = constraints.maxWidth - 48 - (_gridSize - 1) * 4;
              final availableHeight = constraints.maxHeight - 16;
              final cellSize = ((availableWidth < availableHeight 
                  ? availableWidth 
                  : availableHeight) / _gridSize).clamp(30.0, 100.0);
              
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Container(
                    width: cellSize * _gridSize + (_gridSize - 1) * 4,
                    height: cellSize * _gridSize + (_gridSize - 1) * 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _gridSize,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: _gridSize * _gridSize,
                      itemBuilder: (context, index) {
                        final row = index ~/ _gridSize;
                        final col = index % _gridSize;
                        return GestureDetector(
                          onTap: showFeedback ? null : () => _onCellTapped(row, col),
                          child: _buildFilledCell(row, col, false),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (!showFeedback) ...[
          const SizedBox(height: 16),
          Focus(
            autofocus: true,
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
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                decoration: BoxDecoration(
                  gradient: _selectedPositions.isNotEmpty
                      ? const LinearGradient(
                          colors: [Color(0xFFE17055), Color(0xFFFAB1A0)],
                        )
                      : null,
                  color: _selectedPositions.isEmpty ? Colors.white10 : null,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: _selectedPositions.isNotEmpty
                      ? [
                          BoxShadow(
                            color: const Color(0xFFE17055).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  'SUBMIT',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: _selectedPositions.isNotEmpty ? Colors.white : Colors.white30,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
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
                color: isCorrect ? const Color(0xFF55EFC4) : const Color(0xFFFF6B6B),
              ),
            ),
            if (isCorrect) ...[
              const SizedBox(height: 8),
              Text(
                '+${(_level * 20) + (_gridSize * _gridSize * 5)} points',
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
                  _buildScoreRow('Level Reached', '$_level', const Color(0xFFE17055)),
                  const SizedBox(height: 12),
                  _buildScoreRow('High Score', '$_highScore', const Color(0xFFFAB1A0)),
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
                    colors: [Color(0xFFE17055), Color(0xFFFAB1A0)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE17055).withOpacity(0.4),
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
  preview,
  showing,
  guessing,
  correct,
  incorrect,
  gameOver,
}
