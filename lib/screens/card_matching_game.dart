import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;

enum MatchPhase {
  setting,
  memorizing,
  playing,
  gameOver
}

class CardMatchingGame extends StatefulWidget {
  const CardMatchingGame({super.key});

  @override
  State<CardMatchingGame> createState() => _CardMatchingGameState();
}

class _CardMatchingGameState extends State<CardMatchingGame> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  MatchPhase _phase = MatchPhase.setting;
  
  // Game Configuration
  bool _isCustomGame = false;
  int _targetCardCount = 8;
  int _customCardCount = 8;
  int _level = 1;
  int _score = 0;
  int _highScore = 0;
  int _lives = 3;
  
  // Decks & Board
  final List<String> _cardValues = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
  final List<String> _suits = ['♠', '♥', '♦', '♣'];
  
  // List of active cards on the board
  List<String> _boardCards = [];
  List<bool> _isFlipped = [];
  List<bool> _isMatched = [];
  
  // Interaction State
  int? _firstSelectedIndex;
  bool _isEvaluating = false;
  
  // Animation / Timer
  Timer? _evalTimer;
  Timer? _memorizationTimer;
  late AnimationController _cardFlashController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cardFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadProgress();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _evalTimer?.cancel();
    _memorizationTimer?.cancel();
    _cardFlashController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveProgress();
    }
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _level = prefs.getInt('matching_level') ?? 1;
      _highScore = prefs.getInt('matching_high_score') ?? 0;
      
      final savedPhase = prefs.getInt('matching_phase');
      if (savedPhase != null && savedPhase != MatchPhase.gameOver.index && savedPhase != MatchPhase.setting.index) {
         _phase = MatchPhase.values[savedPhase];
         _score = prefs.getInt('matching_score') ?? 0;
         _lives = prefs.getInt('matching_lives') ?? 3;
         _isCustomGame = prefs.getBool('matching_is_custom') ?? false;
         _targetCardCount = prefs.getInt('matching_target_count') ?? 8;
         
         _boardCards = prefs.getStringList('matching_board_cards') ?? [];
         _isFlipped = (prefs.getStringList('matching_is_flipped') ?? []).map((e) => e == 'true').toList();
         _isMatched = (prefs.getStringList('matching_is_matched') ?? []).map((e) => e == 'true').toList();
      }
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('matching_level', _level);
    await prefs.setInt('matching_high_score', _highScore);
    
    if (_phase == MatchPhase.setting || _phase == MatchPhase.gameOver) {
       await prefs.remove('matching_phase');
    } else {
       await prefs.setInt('matching_phase', _phase.index);
       await prefs.setInt('matching_score', _score);
       await prefs.setInt('matching_lives', _lives);
       await prefs.setBool('matching_is_custom', _isCustomGame);
       await prefs.setInt('matching_target_count', _targetCardCount);
       
       await prefs.setStringList('matching_board_cards', _boardCards);
       await prefs.setStringList('matching_is_flipped', _isFlipped.map((e) => e.toString()).toList());
       await prefs.setStringList('matching_is_matched', _isMatched.map((e) => e.toString()).toList());
    }
  }

  void _clearActiveState() {
     _evalTimer?.cancel();
     _memorizationTimer?.cancel();
     SharedPreferences.getInstance().then((prefs) {
        prefs.remove('matching_phase');
     });
  }

  void _startGame() {
    _clearActiveState();
    setState(() {
      _isCustomGame = false;
      _level = 1;
      _score = 0;
      _targetCardCount = 8;
    });
    _dealBoard();
  }

  void _startCustomGame() {
    _clearActiveState();
    setState(() {
      _isCustomGame = true;
      _score = 0;
      _targetCardCount = _customCardCount;
    });
    _dealBoard();
  }

  void _dealBoard() {
     setState(() {
       _phase = MatchPhase.memorizing;
       _firstSelectedIndex = null;
       _isEvaluating = false;
       _lives = 3;
     });
     
     // Generate unique pool
     _boardCards.clear();
     List<String> deckKeys = [];
     for (String suit in _suits) {
        for (String value in _cardValues) {
           deckKeys.add('$value$suit');
        }
     }
     deckKeys.shuffle(math.Random());
     
     // Pick N pairs uniquely
     int numPairs = _targetCardCount ~/ 2;
     for (int i = 0; i < numPairs; i++) {
        _boardCards.add(deckKeys[i]); // Twin A
        _boardCards.add(deckKeys[i]); // Twin B (exact match)
     }
     
     _boardCards.shuffle(math.Random());
     _isFlipped = List.generate(_targetCardCount, (_) => true); // Flip entirely face up initially
     _isMatched = List.generate(_targetCardCount, (_) => false);
     
     _saveProgress();

     _memorizationTimer = Timer(const Duration(milliseconds: 3000), () {
        if (!mounted) return;
        setState(() {
           // Turn them all blankly down
           _isFlipped = List.generate(_targetCardCount, (_) => false);
           _phase = MatchPhase.playing;
        });
        _saveProgress();
     });
  }

  void _handleCardTap(int index) {
      if (_phase != MatchPhase.playing || _isEvaluating || _isFlipped[index] || _isMatched[index]) return;

      setState(() {
         _isFlipped[index] = true;
      });

      if (_firstSelectedIndex == null) {
         // This is the first flip of a pair attempt
         _firstSelectedIndex = index;
      } else {
         // This is the second flip
         _isEvaluating = true;
         int first = _firstSelectedIndex!;
         int second = index;
         
         if (_boardCards[first] == _boardCards[second]) {
            // MATCH!
            _score += 10;
            _isMatched[first] = true;
            _isMatched[second] = true;
            _firstSelectedIndex = null;
            _isEvaluating = false;
            _checkLevelCompletion();
         } else {
            // NO MATCH
            _score = math.max(0, _score - 2);
            _lives--;
            
            _evalTimer = Timer(const Duration(milliseconds: 1000), () {
               if (!mounted) return;
               setState(() {
                  _isFlipped[first] = false;
                  _isFlipped[second] = false;
                  _firstSelectedIndex = null;
                  _isEvaluating = false;
                  if (_lives <= 0) {
                     _phase = MatchPhase.gameOver;
                     if (_score > _highScore) _highScore = _score;
                  }
               });
               if (_lives <= 0) _saveProgress();
            });
         }
      }
  }

  void _checkLevelCompletion() {
      if (_isMatched.every((matched) => matched)) {
          // Completed the board
          if (_score > _highScore) _highScore = _score;
          
          if (_isCustomGame) {
             _phase = MatchPhase.gameOver;
          } else {
             // Standard Progression
             _level++;
             _targetCardCount = math.min(52, _targetCardCount + 2); // Cap at 52 (26 distinct pairs)
             _dealBoard();
          }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E272E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Card Matching', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Restart Game',
            onPressed: () {
               _clearActiveState();
               setState(() {
                 _phase = MatchPhase.setting;
               });
            },
          ),
          Center(
             child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Row(
                       mainAxisSize: MainAxisSize.min,
                       children: List.generate(3, (index) {
                          return Icon(
                             index < _lives ? Icons.favorite : Icons.favorite_border,
                             color: Colors.redAccent,
                             size: 16,
                          );
                       }),
                    ),
                    const SizedBox(width: 12),
                    Text('Lv.$_level', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00B894))),
                    const SizedBox(width: 12),
                    Text('Score: $_score', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFDCB6E))),
                  ],
                ),
             ),
          )
        ],
      ),
      body: SafeArea(
        child: _buildPhaseContent(),
      ),
    );
  }

  Widget _buildPhaseContent() {
     switch (_phase) {
        case MatchPhase.setting:
           return _buildSettingScreen();
        case MatchPhase.gameOver:
           return _buildGameOverScreen();
        case MatchPhase.memorizing:
        case MatchPhase.playing:
           return _buildGridScreen();
     }
  }

  Widget _buildSettingScreen() {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               const Icon(Icons.dashboard, size: 80, color: Color(0xFF0984E3)),
               const SizedBox(height: 24),
               const Text("Memory Card Match", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
               const SizedBox(height: 16),
               const Text("Find matching pairs. Exact value and suit required.", style: TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
               const SizedBox(height: 48),
               
               // Standard Mode
               ElevatedButton(
                  style: ElevatedButton.styleFrom(
                     backgroundColor: const Color(0xFF0984E3),
                     padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                  ),
                  onPressed: _startGame,
                  child: const Text("STANDARD MODE", style: TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.bold)),
               ),
               const SizedBox(height: 12),
               const Text("Start at 8 cards, escalating up to 52.", style: TextStyle(color: Colors.white54, fontSize: 12)),
               
               const SizedBox(height: 48),
               
               // Custom Mode
               Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                     color: Colors.white.withOpacity(0.05),
                     borderRadius: BorderRadius.circular(16)
                  ),
                  child: Column(
                     children: [
                        const Text("CUSTOM MATCH", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const SizedBox(height: 16),
                        Row(
                           children: [
                              const Text("Cards:", style: TextStyle(color: Colors.white70)),
                              Expanded(
                                 child: Slider(
                                    value: _customCardCount.toDouble(),
                                    min: 4,
                                    max: 52,
                                    divisions: 24, // Ensures steps of 2
                                    activeColor: const Color(0xFFFDCB6E),
                                    inactiveColor: Colors.white24,
                                    label: "$_customCardCount Cards",
                                    onChanged: (val) {
                                       setState(() { _customCardCount = val.toInt(); });
                                    },
                                 ),
                              ),
                              Text("$_customCardCount", style: const TextStyle(color: const Color(0xFFFDCB6E), fontWeight: FontWeight.bold)),
                           ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                           style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFDCB6E)),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                           ),
                           onPressed: _startCustomGame,
                           child: const Text("PLAY CUSTOM", style: TextStyle(color: Color(0xFFFDCB6E), letterSpacing: 2, fontWeight: FontWeight.bold)),
                        )
                     ],
                  ),
               )
            ],
          ),
        ),
      );
  }

  Widget _buildGridScreen() {
      return LayoutBuilder(
         builder: (context, constraints) {
            double bestCardWidth = 0;
            int bestCols = 1;
            int bestRows = 1;
            
            for (int cols = 1; cols <= _targetCardCount; cols++) {
               int rows = (_targetCardCount / cols).ceil();
               double cardWidth = ((constraints.maxWidth - 16) - (cols - 1) * 8) / cols;
               double cardHeight = ((constraints.maxHeight - 16) - (rows - 1) * 8) / rows;
               
               double actualWidth = math.min(cardWidth, cardHeight * 0.7).floorToDouble();
               
               if (actualWidth > bestCardWidth) {
                  bestCardWidth = actualWidth;
                  bestCols = cols;
                  bestRows = rows;
               }
            }
            
            double gridWidth = bestCols * bestCardWidth + (bestCols - 1) * 8;
            double gridHeight = bestRows * (bestCardWidth / 0.7) + (bestRows - 1) * 8;
            
            return Center(
               child: SizedBox(
                  width: gridWidth,
                  height: gridHeight,
                  child: GridView.builder(
                     physics: const NeverScrollableScrollPhysics(),
                     padding: EdgeInsets.zero,
                     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: bestCols,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8
                     ),
                     itemCount: _targetCardCount,
                     itemBuilder: (context, index) {
                        return _buildInteractiveCard(index);
                     },
                  ),
               ),
            );
         }
      );
  }

  Widget _buildInteractiveCard(int index) {
     return LayoutBuilder(
        builder: (context, constraints) {
           double cardHeight = constraints.maxHeight;
           double fMed = math.max(8.0, cardHeight * 0.12);
           double fSml = math.max(6.0, cardHeight * 0.10);
           double fLrg = math.max(16.0, cardHeight * 0.35);
           
           bool isFaceUp = _isFlipped[index];
           bool isMatch = _isMatched[index];
           
           if (!isFaceUp) {
              return GestureDetector(
                 onTap: () => _handleCardTap(index),
                 child: Container(
                    decoration: BoxDecoration(
                       color: const Color(0xFF0984E3),
                       borderRadius: BorderRadius.circular(8),
                       border: Border.all(color: Colors.white54, width: 2),
                       image: const DecorationImage(
                          image: NetworkImage('https://www.transparenttextures.com/patterns/cubes.png'),
                          repeat: ImageRepeat.repeat,
                          opacity: 0.2
                       ),
                       boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(2,2))
                       ]
                    ),
                    child: Center(
                       child: Icon(Icons.ac_unit, color: Colors.white24, size: fLrg),
                    ),
                 ),
              );
           }
           
           String card = _boardCards[index];
           final valStr = card.replaceAll(RegExp(r'[♠♥♦♣]'), '');
           final suit = card.replaceAll(RegExp(r'[0-9JQKA]'), '');
           final isRed = suit == '♥' || suit == '♦';
           
           return Container(
               decoration: BoxDecoration(
                  color: isMatch ? const Color(0xFFDFF9EE) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isMatch ? const Color(0xFF00B894) : Colors.black26, width: isMatch ? 2 : 1),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2,2))]
               ),
               child: Stack(
                  children: [
                     Positioned(
                        top: 4, left: 4,
                        child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                              Text(valStr, style: TextStyle(color: isRed ? Colors.red : Colors.black, fontSize: fMed, fontWeight: FontWeight.bold, height: 1)),
                              Text(suit, style: TextStyle(color: isRed ? Colors.red : Colors.black, fontSize: fSml, height: 1)),
                           ],
                        )
                     ),
                     Positioned(
                        bottom: 4, right: 4,
                        child: RotatedBox(
                           quarterTurns: 2,
                           child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                 Text(valStr, style: TextStyle(color: isRed ? Colors.red : Colors.black, fontSize: fMed, fontWeight: FontWeight.bold, height: 1)),
                                 Text(suit, style: TextStyle(color: isRed ? Colors.red : Colors.black, fontSize: fSml, height: 1)),
                              ],
                           ),
                        )
                     ),
                     Center(
                        child: Text(suit, style: TextStyle(color: isRed ? Colors.red : Colors.black, fontSize: fLrg)),
                     ),
                     if (isMatch)
                        Container(
                           decoration: BoxDecoration(
                              color: const Color(0xFF00B894).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8)
                           ),
                        )
                  ],
               ),
           );
        }
     );
  }

  Widget _buildGameOverScreen() {
      bool isWin = _lives > 0;
      
      return Center(
         child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Icon(isWin ? Icons.star_rounded : Icons.heart_broken_rounded, color: isWin ? const Color(0xFFFDCB6E) : Colors.redAccent, size: 100),
               const SizedBox(height: 24),
               Text(isWin ? "GRID COMPLETE!" : "GAME OVER", style: TextStyle(color: isWin ? Colors.white : Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
               const SizedBox(height: 8),
               Text("Final Score: $_score", style: const TextStyle(color: Color(0xFFFDCB6E), fontSize: 24)),
               const SizedBox(height: 48),
               ElevatedButton(
                  style: ElevatedButton.styleFrom(
                     backgroundColor: const Color(0xFF0984E3),
                     padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                  ),
                  onPressed: () {
                     _clearActiveState();
                     setState(() {
                       _phase = MatchPhase.setting;
                     });
                  },
                  child: const Text("BACK TO MENU", style: TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.bold)),
               )
            ],
         ),
      );
  }
}
