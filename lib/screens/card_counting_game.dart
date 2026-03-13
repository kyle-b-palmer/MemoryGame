import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;
import 'blackjack_counting_game.dart';

class CardCountingGame extends StatefulWidget {
  const CardCountingGame({super.key});

  @override
  State<CardCountingGame> createState() => _CardCountingGameState();
}

class _CardCountingGameState extends State<CardCountingGame>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  GamePhase _phase = GamePhase.ready;
  int _level = 1;
  int _score = 0;
  int _highScore = 0;
  
  int _cardCount = 10;
  double _displayDuration = 2.0;
  List<String> _cards = [];
  int _currentCardIndex = 0;
  int _correctCount = 0;
  
  // Custom game settings
  bool _isCustomGame = false;
  int _customCardCount = 10;
  double _customDisplayDuration = 2.0;
  
  Timer? _displayTimer;
  Timer? _countdownTimer;
  double _timeRemaining = 0;
  
  late AnimationController _cardFlashController;
  late AnimationController _resultController;
  late Animation<double> _cardFadeAnimation;
  late Animation<double> _cardScaleAnimation;
  
  final FocusNode _inputFocusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  String _inputValue = '';

  // Card values for counting
  final List<String> _cardValues = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
  final List<String> _suits = ['♠', '♥', '♦', '♣'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProgress();
    _cardFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _cardFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardFlashController,
        curve: Curves.easeOut,
      ),
    );
    
    _cardScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardFlashController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _displayTimer?.cancel();
    _countdownTimer?.cancel();
    _cardFlashController.dispose();
    _resultController.dispose();
    _inputFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveActiveState();
    }
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _level = prefs.getInt('card_counting_level') ?? 1;
      _highScore = prefs.getInt('card_counting_high_score') ?? 0;
      _cardCount = prefs.getInt('card_counting_count') ?? 10;
      _displayDuration = prefs.getDouble('card_counting_duration') ?? 2.0;

      // Try to load active state
      final savedPhaseIndex = prefs.getInt('card_counting_saved_phase');
      if (savedPhaseIndex != null) {
        final savedPhase = GamePhase.values[savedPhaseIndex];
        // Only restore if not finished or at ready screen
        if (savedPhase != GamePhase.ready && savedPhase != GamePhase.gameOver && savedPhase != GamePhase.customSettings) {
          _phase = savedPhase;
          _score = prefs.getInt('card_counting_saved_score') ?? 0;
          _cards = prefs.getStringList('card_counting_saved_cards') ?? [];
          _currentCardIndex = prefs.getInt('card_counting_saved_card_index') ?? 0;
          _correctCount = prefs.getInt('card_counting_saved_correct_count') ?? 0;
          _isCustomGame = prefs.getBool('card_counting_saved_is_custom') ?? false;

          if (_phase == GamePhase.showing && _cards.isNotEmpty) {
             _timeRemaining = _displayDuration * _cardCount;
             _showNextCard();
          } else if (_phase == GamePhase.guessing) {
             _inputFocusNode.requestFocus();
          }
        }
      }
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('card_counting_level', _level);
    await prefs.setInt('card_counting_high_score', _highScore);
    await prefs.setInt('card_counting_count', _cardCount);
    await prefs.setDouble('card_counting_duration', _displayDuration);
  }

  Future<void> _saveActiveState() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (_phase == GamePhase.ready || _phase == GamePhase.gameOver || _phase == GamePhase.customSettings) {
      // Clear active state if we are out of game
      await prefs.remove('card_counting_saved_phase');
      return;
    }

    await prefs.setInt('card_counting_saved_phase', _phase.index);
    await prefs.setInt('card_counting_saved_score', _score);
    await prefs.setStringList('card_counting_saved_cards', _cards);
    await prefs.setInt('card_counting_saved_card_index', _currentCardIndex);
    await prefs.setInt('card_counting_saved_correct_count', _correctCount);
    await prefs.setBool('card_counting_saved_is_custom', _isCustomGame);
  }

  void _startGame() {
    _clearActiveState();
    setState(() {
      _phase = GamePhase.ready;
      _score = 0;
      _isCustomGame = false;
    });
    _startRound();
  }

  void _startCustomGame() {
    _clearActiveState();
    setState(() {
      _phase = GamePhase.customSettings;
      _score = 0;
      _isCustomGame = true;
      _cardCount = _customCardCount;
      _displayDuration = _customDisplayDuration;
    });
  }

  void _startBlackjackSimulator() {
    // Navigate completely to a new dedicated screen for Blackjack simulation to not pollute this simple state
    Navigator.of(context).push(
       MaterialPageRoute(builder: (context) => const BlackjackCountingGame())
    );
  }

  Future<void> _clearActiveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('card_counting_saved_phase');
  }

  void _startRound() {
    setState(() {
      _phase = GamePhase.roundStarting;
    });
    _saveActiveState();
  }

  void _beginShowingCards() {
    _generateCards();
    setState(() {
      _phase = GamePhase.showing;
      _currentCardIndex = 0;
      _timeRemaining = _displayDuration * _cardCount;
      _inputValue = '';
    });
    _textController.clear();
    _saveActiveState();
    _showNextCard();
  }

  void _generateCards() {
    final random = math.Random();
    _cards = [];
    _correctCount = 0;
    
    for (int i = 0; i < _cardCount; i++) {
      final value = _cardValues[random.nextInt(_cardValues.length)];
      final suit = _suits[random.nextInt(_suits.length)];
      _cards.add('$value$suit');
      
      // Calculate count value
      if (['2', '3', '4', '5', '6'].contains(value)) {
        _correctCount += 1;
      } else if (['10', 'J', 'Q', 'K', 'A'].contains(value)) {
        _correctCount -= 1;
      }
      // 7, 8, 9 are 0, so no change
    }
  }

  void _showNextCard() {
    if (_currentCardIndex >= _cards.length) {
      // All cards shown, move to input phase
      setState(() {
        _phase = GamePhase.guessing;
      });
      _saveActiveState();
      _inputFocusNode.requestFocus();
      return;
    }
    
    _cardFlashController.forward(from: 0);
    
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _timeRemaining -= 0.05;
        if (_timeRemaining <= 0) {
          _timeRemaining = 0;
        }
      });
    });
    
    _displayTimer?.cancel();
    _displayTimer = Timer(Duration(milliseconds: (_displayDuration * 1000).toInt()), () {
      _cardFlashController.reverse();
      
      Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _currentCardIndex++;
          });
          _saveActiveState();
          _showNextCard();
        }
      });
    });
  }

  int _getCardCountValue(String card) {
    final value = card.replaceAll(RegExp(r'[♠♥♦♣]'), '');
    if (['2', '3', '4', '5', '6'].contains(value)) {
      return 1;
    } else if (['10', 'J', 'Q', 'K', 'A'].contains(value)) {
      return -1;
    }
    return 0; // 7, 8, 9
  }

  void _submitAnswer() {
    if (_phase != GamePhase.guessing) return;
    if (_inputValue.isEmpty) return;
    
    final guess = int.tryParse(_inputValue);
    if (guess == null) {
      _textController.clear();
      setState(() => _inputValue = '');
      return;
    }
    
    _checkAnswer(guess);
  }

  void _checkAnswer(int guess) {
    _displayTimer?.cancel();
    _countdownTimer?.cancel();
    
    final isCorrect = guess == _correctCount;
    
    setState(() {
      _phase = isCorrect ? GamePhase.correct : GamePhase.incorrect;
      if (isCorrect) {
        _score += (_level * 30) + (_cardCount * 10);
        if (_score > _highScore) {
          _highScore = _score;
        }
      }
    });
    
    _resultController.forward(from: 0);
    
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (isCorrect) {
        if (!_isCustomGame) {
          _levelUp();
        } else {
          _level++;
          _cardCount = _customCardCount;
          _displayDuration = _customDisplayDuration;
        }
      } else {
        _clearActiveState();
      }
      if (isCorrect) {
         _startRound();
      }
    });
  }

  void _levelUp() {
    if (_isCustomGame) return;
    
    _level++;
    
    if (_level % 2 == 0 && _cardCount < 20) {
      _cardCount += 2;
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
                      ],
                    ),
                    if (_phase != GamePhase.ready && _phase != GamePhase.customSettings)
                      IconButton(
                        onPressed: () {
                           _clearActiveState();
                           _displayTimer?.cancel();
                           _countdownTimer?.cancel();
                           _cardFlashController.stop();
                           setState(() {
                             _phase = GamePhase.ready;
                             _score = 0;
                             _level = 1;
                             _cardCount = 10;
                             _displayDuration = 2.0;
                           });
                           _saveProgress();
                        },
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        tooltip: 'Restart Game',
                      )
                    else
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
      case GamePhase.roundStarting:
        return _buildRoundStartingScreen();
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
                  colors: [Color(0xFFD63031), Color(0xFFFF7675)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD63031).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.casino_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Card Counting',
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
                    Icons.credit_card_rounded,
                    'Watch cards appear one at a time',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.calculate_rounded,
                    '2-6 = +1, 7-9 = 0, 10/J/Q/K/A = -1',
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.numbers_rounded,
                    'Enter the total running count at the end',
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
                    colors: [Color(0xFFD63031), Color(0xFFFF7675)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD63031).withOpacity(0.4),
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
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _startBlackjackSimulator,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                  boxShadow: [
                     BoxShadow(
                        color: Colors.amber.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4)
                     )
                  ]
                ),
                child: Text(
                  'BLACKJACK SIMULATOR',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
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
        Icon(icon, color: const Color(0xFFD63031), size: 24),
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
                    'Number of Cards',
                    _customCardCount,
                    (val) => setState(() => _customCardCount = val),
                    5.0,
                    30.0,
                  ),
                  const SizedBox(height: 24),
                  _buildSettingRow(
                    'Display Duration (seconds)',
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
                  _cardCount = _customCardCount;
                  _displayDuration = _customDisplayDuration;
                  _startRound();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: () {
                  _cardCount = _customCardCount;
                  _displayDuration = _customDisplayDuration;
                  _startRound();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD63031), Color(0xFFFF7675)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD63031).withOpacity(0.4),
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
              icon: const Icon(Icons.remove_circle, color: Color(0xFFD63031)),
            ),
            Expanded(
              child: Text(
                isDouble ? (value as double).toStringAsFixed(1) : value.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFFD63031),
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
              icon: const Icon(Icons.add_circle, color: Color(0xFFD63031)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoundStartingScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFD63031).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD63031).withOpacity(0.3), width: 2),
              ),
              child: const Icon(
                Icons.credit_card_rounded,
                color: Color(0xFFD63031),
                size: 64,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Round $_level',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_none_rounded, color: Colors.white70, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    '$_cardCount Cards',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: _beginShowingCards,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD63031), Color(0xFFFF7675)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD63031).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  'DEAL',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                _clearActiveState();
                setState(() {
                  _phase = GamePhase.ready;
                });
              },
              child: const Text(
                'QUIT TO MENU',
                style: TextStyle(
                  color: Colors.white54,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowingScreen() {
    final currentCard = _currentCardIndex < _cards.length ? _cards[_currentCardIndex] : '';
    final cardValue = currentCard.replaceAll(RegExp(r'[♠♥♦♣]'), '');
    final suit = currentCard.replaceAll(RegExp(r'[0-9JQKA]'), '');
    final isRed = suit == '♥' || suit == '♦';
    
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFD63031).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD63031).withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.credit_card_rounded, color: Color(0xFFD63031), size: 20),
              const SizedBox(width: 8),
              Text(
                'Card ${_currentCardIndex + 1}/$_cardCount',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFD63031),
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
              final maxWidth = constraints.maxWidth * 0.7;
              final maxHeight = constraints.maxHeight * 0.8;
              final cardWidth = (maxWidth < 200 ? maxWidth : 200.0).clamp(120.0, 200.0);
              final cardHeight = (cardWidth * 1.4).clamp(168.0, 280.0);
              
              return Center(
                child: AnimatedBuilder(
                  animation: _cardFadeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _cardFadeAnimation.value,
                      child: Transform.scale(
                        scale: _cardScaleAnimation.value,
                        child: Container(
                          width: cardWidth,
                          height: cardHeight,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isRed ? const Color(0xFFD63031) : Colors.black,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                      child: Stack(
                        children: [
                          // Top-left corner
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cardValue,
                                  style: TextStyle(
                                    color: isRed ? const Color(0xFFD63031) : Colors.black,
                                    fontSize: (cardWidth * 0.14).clamp(20.0, 28.0),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  suit,
                                  style: TextStyle(
                                    color: isRed ? const Color(0xFFD63031) : Colors.black,
                                    fontSize: (cardWidth * 0.14).clamp(20.0, 28.0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Center suit
                          Center(
                            child: Text(
                              suit,
                              style: TextStyle(
                                color: isRed ? const Color(0xFFD63031) : Colors.black,
                                fontSize: (cardWidth * 0.36).clamp(48.0, 72.0),
                              ),
                            ),
                          ),
                          // Bottom-right corner (rotated)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Transform.rotate(
                              angle: 3.14159, // 180 degrees
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    cardValue,
                                    style: TextStyle(
                                      color: isRed ? const Color(0xFFD63031) : Colors.black,
                                      fontSize: (cardWidth * 0.14).clamp(20.0, 28.0),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    suit,
                                    style: TextStyle(
                                      color: isRed ? const Color(0xFFD63031) : Colors.black,
                                      fontSize: (cardWidth * 0.14).clamp(20.0, 28.0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
            },
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
            color: const Color(0xFFD63031).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD63031).withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calculate_rounded, color: Color(0xFFD63031), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'What is the total running count?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFD63031),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '2-6 = +1, 7-9 = 0, 10/J/Q/K/A = -1',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: TextField(
            controller: _textController,
            focusNode: _inputFocusNode,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*')),
            ],
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 48,
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
                borderSide: const BorderSide(color: Color(0xFFD63031), width: 2),
              ),
            ),
            onChanged: (value) {
              setState(() => _inputValue = value);
            },
            onSubmitted: (_) => _submitAnswer(),
          ),
        ),
        const SizedBox(height: 32),
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
                gradient: _inputValue.isNotEmpty
                    ? const LinearGradient(
                        colors: [Color(0xFFD63031), Color(0xFFFF7675)],
                      )
                    : null,
                color: _inputValue.isEmpty ? Colors.white10 : null,
                borderRadius: BorderRadius.circular(30),
                boxShadow: _inputValue.isNotEmpty
                    ? [
                        BoxShadow(
                          color: const Color(0xFFD63031).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                'SUBMIT',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: _inputValue.isNotEmpty ? Colors.white : Colors.white30,
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
            if (!isCorrect) ...[
              const SizedBox(height: 8),
              Text(
                'Correct count: $_correctCount',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
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
                    colors: [Color(0xFFD63031), Color(0xFFFF7675)],
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
  roundStarting,
  showing,
  guessing,
  correct,
  incorrect,
  gameOver,
}
