import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

enum GameState { showing, recalling, resetting, gameOver }

class ColorBlockStackingGame extends StatefulWidget {
  const ColorBlockStackingGame({super.key});

  @override
  State<ColorBlockStackingGame> createState() => _ColorBlockStackingGameState();
}

class _ColorBlockStackingGameState extends State<ColorBlockStackingGame> with SingleTickerProviderStateMixin {
  GameState _gameState = GameState.showing;
  int _currentLevel = 3;
  int _score = 0;
  int _highScore = 0;
  int _lives = 3;
  
  final List<Color> _targetStack = [];
  final List<Color> _currentStack = [];
  
  static const List<Color> _availableColors = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.amber,
  ];
  
  Timer? _showTimer;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 500),
    );
    _startGame();
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _currentLevel = 3;
      _score = 0;
      _lives = 3;
      _gameState = GameState.showing;
      _currentStack.clear();
      _generateStack();
    });
    _startShowTimer();
  }

  void _nextLevel() {
    _showTimer?.cancel();
    setState(() {
      _currentLevel++;
      _score += 10;
      if (_score > _highScore) _highScore = _score;
      _gameState = GameState.showing;
      _currentStack.clear();
      _generateStack();
    });
    _startShowTimer();
  }

  void _generateStack() {
    final random = Random();
    _targetStack.clear();
    List<Color> pool = List.from(_availableColors);
    pool.shuffle(random);
    for (int i = 0; i < _currentLevel; i++) {
       if (pool.isNotEmpty) {
         _targetStack.add(pool.removeLast());
       } else {
         _targetStack.add(_availableColors[random.nextInt(_availableColors.length)]);
       }
    }
  }

  void _startShowTimer() {
    final showDuration = Duration(milliseconds: 1000 + (_currentLevel * 500));
    _showTimer?.cancel();
    _showTimer = Timer(showDuration, () {
      if (mounted) {
        setState(() {
          _gameState = GameState.recalling;
        });
      }
    });
  }

  void _onColorSelected(Color color) {
    if (_gameState != GameState.recalling) return;
    
    setState(() {
      _currentStack.add(color);
      
      int currentIndex = _currentStack.length - 1;
      if (_currentStack[currentIndex] != _targetStack[currentIndex]) {
        // Mistake made
        _lives--;
        _shakeController.forward(from: 0.0);
        
        if (_lives <= 0) {
           _gameOver();
        } else {
           _gameState = GameState.resetting;
           // Delay to let the shake finish and show they failed, then reset and recount
           Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                 setState(() {
                    _currentStack.clear();
                    _gameState = GameState.showing;
                 });
                 _startShowTimer();
              }
           });
        }
      } else {
        if (_currentStack.length == _targetStack.length) {
          // Delay briefly to show the final block before moving to the next level
          _gameState = GameState.showing; // Prevent interaction during delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _nextLevel();
          });
        }
      }
    });
  }
  
  void _gameOver() {
    _gameState = GameState.gameOver;
    _shakeController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Color Stacking'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () {
             _showTimer?.cancel();
             Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Restart Game',
            onPressed: () {
               _showTimer?.cancel();
               _startGame();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  reverse: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: _buildStackArea(),
                  ),
                ),
              ),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatCard('Score', _score.toString()),
          Row(
             mainAxisSize: MainAxisSize.min,
             children: List.generate(3, (index) {
                return Icon(
                   index < _lives ? Icons.favorite : Icons.favorite_border,
                   color: Colors.redAccent,
                   size: 20,
                );
             }),
          ),
          _buildStatCard('High Score', _highScore.toString()),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStackArea() {
     return AnimatedBuilder(
       animation: _shakeController,
       builder: (context, child) {
          final sineValue = sin(4 * pi * _shakeController.value);
          return Transform.translate(
             offset: Offset(sineValue * 10, 0),
             child: child,
          );
       },
       child: Column(
         mainAxisAlignment: MainAxisAlignment.end,
         children: [
           if (_gameState == GameState.showing) 
             ..._targetStack.reversed.map((c) => _buildBlock(c)).toList()
           else if (_gameState == GameState.recalling || _gameState == GameState.gameOver || _gameState == GameState.resetting)
             ...List.generate(_targetStack.length, (index) {
                int reverseIndex = _targetStack.length - 1 - index;
                if (reverseIndex < _currentStack.length) {
                   // If resetting, make the incorrect block visually distinct
                   bool isError = (_gameState == GameState.resetting || _gameState == GameState.gameOver) && 
                                  (reverseIndex == _currentStack.length - 1);
                   return _buildBlock(_currentStack[reverseIndex], isError: isError);
                } else if (_gameState == GameState.gameOver) {
                   return _buildBlock(_targetStack[reverseIndex], opacity: 0.3);
                } else {
                   return _buildEmptyBlock();
                }
             })
         ],
       ),
     );
  }

  Widget _buildBlock(Color color, {double opacity = 1.0, bool isError = false}) {
     return Container(
       width: 200,
       height: 40,
       margin: const EdgeInsets.symmetric(vertical: 2),
       decoration: BoxDecoration(
         color: isError ? Colors.redAccent : color.withOpacity(opacity),
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: isError ? Colors.white : Colors.white24, width: isError ? 4 : 2),
         boxShadow: [
           BoxShadow(
             color: isError ? Colors.redAccent.withOpacity(0.8) : color.withOpacity(opacity * 0.4),
             blurRadius: isError ? 16 : 8,
             spreadRadius: 1,
           )
         ]
       ),
     );
  }

  Widget _buildEmptyBlock() {
     return Container(
       width: 200,
       height: 40,
       margin: const EdgeInsets.symmetric(vertical: 2),
       decoration: BoxDecoration(
         color: Colors.transparent,
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: Colors.white12, width: 2, style: BorderStyle.solid),
       ),
     );
  }

  Widget _buildControls() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_gameState == GameState.gameOver) ...[
             const Text(
               'Game Over!',
               style: TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 16),
             ElevatedButton(
               style: ElevatedButton.styleFrom(
                 backgroundColor: const Color(0xFF6C5CE7),
                 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
               ),
               onPressed: () {
                  _showTimer?.cancel();
                  _startGame();
               },
               child: const Text('Play Again', style: TextStyle(fontSize: 18, color: Colors.white)),
             ),
          ] else if (_gameState == GameState.resetting) ...[
             const Text(
               'Incorrect! Resetting stack...',
               style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 16),
             const CircularProgressIndicator(color: Colors.redAccent),
             const SizedBox(height: 16),
          ] else ...[
             const Text(
               'Select colors from bottom to top',
               style: TextStyle(color: Colors.white54, fontSize: 16),
             ),
             const SizedBox(height: 16),
             Wrap(
               spacing: 12,
               runSpacing: 12,
               alignment: WrapAlignment.center,
               children: _availableColors.map((c) => _buildColorButton(c)).toList(),
             ),
          ]
        ],
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    final isEnabled = _gameState == GameState.recalling;
    return GestureDetector(
      onTap: isEnabled ? () => _onColorSelected(color) : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              if (isEnabled)
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
            ],
          ),
        ),
      ),
    );
  }
}
