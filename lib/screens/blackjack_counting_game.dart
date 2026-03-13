import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;

enum BlackjackPhase {
  betting, // Not really betting, just waiting to deal
  dealing,
  playing,
  askingCount,
  result,
  shuffleNotify
}

class BlackjackCountingGame extends StatefulWidget {
  const BlackjackCountingGame({super.key});

  @override
  State<BlackjackCountingGame> createState() => _BlackjackCountingGameState();
}

class _BlackjackCountingGameState extends State<BlackjackCountingGame> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  BlackjackPhase _phase = BlackjackPhase.betting;
  
  // Shoe of 6 decks
  List<String> _shoe = [];
  int _runningCount = 0;
  
  // Table Setup: 5 players
  List<List<String>> _playerHands = List.generate(5, (_) => []);
  List<String> _dealerHand = [];
  
  bool _isDealerHiddenCardRevealed = false;
  
  // Card Definitions
  final List<String> _cardValues = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
  final List<String> _suits = ['♠', '♥', '♦', '♣'];
  
  // Animation/Input
  final FocusNode _inputFocusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  String _inputValue = '';
  
  int _score = 0;
  int _roundsPlayed = 0;
  
  // Dealing Speeds (ms delay between dealing)
  double _dealDelayMs = 400.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveState();
    }
  }

  Future<void> _loadState() async {
     final prefs = await SharedPreferences.getInstance();
     setState(() {
       _shoe = prefs.getStringList('blackjack_shoe') ?? [];
       _runningCount = prefs.getInt('blackjack_count') ?? 0;
       _score = prefs.getInt('blackjack_score') ?? 0;
       _roundsPlayed = prefs.getInt('blackjack_rounds') ?? 0;
       _dealDelayMs = prefs.getDouble('blackjack_deal_delay') ?? 400.0;
       
       if (_shoe.isEmpty) {
          _generateShoe();
       } else {
          // Attempt to load partial phase if they force killed app mid-hand
          final savedPhase = prefs.getInt('blackjack_phase');
          if (savedPhase != null && savedPhase != BlackjackPhase.betting.index && savedPhase != BlackjackPhase.shuffleNotify.index) {
             _phase = BlackjackPhase.values[savedPhase];
             _isDealerHiddenCardRevealed = prefs.getBool('blackjack_dealer_revealed') ?? false;
             
             // deserialize hands
             _dealerHand = prefs.getStringList('blackjack_dealer_hand') ?? [];
             for (int i = 0; i < 5; i++) {
                _playerHands[i] = prefs.getStringList('blackjack_p${i}_hand') ?? [];
             }
             
             if (_phase == BlackjackPhase.askingCount) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  FocusScope.of(context).requestFocus(_inputFocusNode);
                });
             }
          }
       }
     });
  }

  Future<void> _saveState() async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.setStringList('blackjack_shoe', _shoe);
     await prefs.setInt('blackjack_count', _runningCount);
     await prefs.setInt('blackjack_score', _score);
     await prefs.setInt('blackjack_rounds', _roundsPlayed);
     await prefs.setDouble('blackjack_deal_delay', _dealDelayMs);
     
     await prefs.setInt('blackjack_phase', _phase.index);
     await prefs.setBool('blackjack_dealer_revealed', _isDealerHiddenCardRevealed);
     await prefs.setStringList('blackjack_dealer_hand', _dealerHand);
     for (int i = 0; i < 5; i++) {
        await prefs.setStringList('blackjack_p${i}_hand', _playerHands[i]);
     }
  }
  
  Future<void> _clearActiveHandState() async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.remove('blackjack_phase');
  }

  void _generateShoe() {
    _shoe.clear();
    _runningCount = 0;
    
    // 6 decks
    for (int i = 0; i < 6; i++) {
      for (String suit in _suits) {
        for (String value in _cardValues) {
          _shoe.add('$value$suit');
        }
      }
    }
    _shoe.shuffle(math.Random());
  }
  
  void _updateCount(String card) {
    final value = card.replaceAll(RegExp(r'[♠♥♦♣]'), '');
    if (['2', '3', '4', '5', '6'].contains(value)) {
      _runningCount += 1; // standard Hi-Lo
    } else if (['10', 'J', 'Q', 'K', 'A'].contains(value)) {
      _runningCount -= 1;
    }
  }

  // Value calculation for Blackjack Basic Rules
  int _calculateHandValue(List<String> hand, {bool stopAtFirst = false}) {
     int sum = 0;
     int aces = 0;
     
     for (int i = 0; i < hand.length; i++) {
        if (stopAtFirst && i > 0) break; // Used for evaluating dealer upcard only
        
        final card = hand[i];
        final valStr = card.replaceAll(RegExp(r'[♠♥♦♣]'), '');
        
        if (['J', 'Q', 'K'].contains(valStr)) {
           sum += 10;
        } else if (valStr == 'A') {
           aces += 1;
           sum += 11;
        } else {
           sum += int.parse(valStr);
        }
     }
     
     while (sum > 21 && aces > 0) {
        sum -= 10;
        aces -= 1;
     }
     
     return sum;
  }

  void _dealHand() async {
    if (_shoe.length < 30) {
       // Not enough cards for a safe complete round
       setState(() {
          _phase = BlackjackPhase.shuffleNotify;
       });
       _saveState();
       return;
    }

    setState(() {
       _phase = BlackjackPhase.dealing;
       _isDealerHiddenCardRevealed = false;
       _dealerHand.clear();
       for (int i = 0; i < 5; i++) {
         _playerHands[i].clear();
       }
    });

    // Simulated staggered dealing
    for (int i = 0; i < 2; i++) {
      for (int p = 0; p < 5; p++) {
         await Future.delayed(Duration(milliseconds: _dealDelayMs.toInt()));
         if (!mounted) return;
         setState(() {
           String card = _shoe.removeLast();
           _playerHands[p].add(card);
           _updateCount(card);
         });
      }
      
      await Future.delayed(Duration(milliseconds: _dealDelayMs.toInt()));
      if (!mounted) return;
      setState(() {
         String card = _shoe.removeLast();
         _dealerHand.add(card);
         // Only update count for dealer's UP card (first card)
         if (i == 0) {
            _updateCount(card);
         }
      });
    }

    _saveState();
    _playOutHands();
  }

  void _playOutHands() async {
      setState(() {
        _phase = BlackjackPhase.playing;
      });

      // Players hit until >= 17
      for (int p = 0; p < 5; p++) {
         while (_calculateHandValue(_playerHands[p]) < 17) {
            await Future.delayed(Duration(milliseconds: (_dealDelayMs * 1.5).toInt()));
            if (!mounted) return;
            setState(() {
               String card = _shoe.removeLast();
               _playerHands[p].add(card);
               _updateCount(card);
            });
         }
      }

      // Dealer reveals down card
      await Future.delayed(Duration(milliseconds: (_dealDelayMs * 2).toInt()));
      if (!mounted) return;
      setState(() {
         _isDealerHiddenCardRevealed = true;
         // Now add the hidden card to the count since we can see it
         _updateCount(_dealerHand[1]);
      });
      
      // Dealer hits until >= 17
      while (_calculateHandValue(_dealerHand) < 17) {
         await Future.delayed(Duration(milliseconds: (_dealDelayMs * 1.5).toInt()));
         if (!mounted) return;
         setState(() {
            String card = _shoe.removeLast();
            _dealerHand.add(card);
            _updateCount(card);
         });
      }

      await Future.delayed(const Duration(milliseconds: 4000));
      if (!mounted) return;
      
      // Ask user for the count
      setState(() {
         _phase = BlackjackPhase.askingCount;
         _inputValue = '';
         _textController.clear();
      });
      _saveState();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_inputFocusNode);
      });
  }

  void _submitCount() {
    if (_inputValue.isEmpty) return;
    final guess = int.tryParse(_inputValue);
    if (guess == null) return;

    setState(() {
       if (guess == _runningCount) {
          _phase = BlackjackPhase.result;
          _score += 50;
       } else {
          _phase = BlackjackPhase.result;
       }
       _roundsPlayed++;
    });
    
    _clearActiveHandState();
  }

  void _nextRound() {
     setState(() {
        _phase = BlackjackPhase.betting;
     });
     _saveState();
     _dealHand();
  }

  void _reshuffle() {
     _generateShoe();
     setState(() {
        _phase = BlackjackPhase.betting;
     });
     _saveState();
     _dealHand();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A3015), // Casino Green
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          children: [
             const Text('Blackjack Simulator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
             Text('Cards left: ${_shoe.length}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
             icon: const Icon(Icons.refresh, color: Colors.white70),
             tooltip: 'Restart Session',
             onPressed: () {
                _clearActiveHandState();
                setState(() {
                   _score = 0;
                   _roundsPlayed = 0;
                   _phase = BlackjackPhase.betting;
                   _isDealerHiddenCardRevealed = false;
                   _dealerHand.clear();
                   for (int i = 0; i < 5; i++) {
                     _playerHands[i].clear();
                   }
                });
                _generateShoe();
                _saveState();
             },
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('Score: $_score', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFDCB6E))),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
           // Base Table Layout
           SafeArea(
             child: Column(
               children: [
                 // Dealer Area
                 Expanded(
                   flex: 3,
                   child: _buildDealerArea(),
                 ),
                 // Table Logo
                 const Opacity(
                    opacity: 0.15,
                    child: Center(
                      child: Icon(Icons.style, size: 100, color: Colors.white),
                    )
                 ),
                 // Players Area
                 Expanded(
                   flex: 4,
                   child: Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                     child: _buildPlayerArea(),
                   ),
                 ),
                 // Control Strip
                 Container(
                   height: 60,
                   width: double.infinity,
                   color: Colors.black26,
                   child: _buildBottomControls(),
                 )
               ],
             ),
           ),
           
           // Overlays
           if (_phase == BlackjackPhase.askingCount)
             _buildOverlayPrompt(),
           
           if (_phase == BlackjackPhase.result)
             _buildOverlayResult(),
             
           if (_phase == BlackjackPhase.shuffleNotify)
             _buildOverlayShuffle(),
        ],
      )
    );
  }

  Widget _buildDealerArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("DEALER MUST STAND ON 17", style: TextStyle(color: Colors.white30, letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: _dealerHand.asMap().entries.map((entry) {
              int idx = entry.key;
              String card = entry.value;
              bool hideCard = idx == 1 && !_isDealerHiddenCardRevealed;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _buildCard(hideCard ? "HIDDEN" : card),
              );
           }).toList(),
        )
      ],
    );
  }

  Widget _buildPlayerArea() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (pIndex) {
         // Create an arc effect with padding
         double bottomPadding = (pIndex == 2) ? 0 : (pIndex == 1 || pIndex == 3) ? 20 : 50;
         
         return Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: Column(
               mainAxisAlignment: MainAxisAlignment.end,
               children: [
                  Stack(
                     clipBehavior: Clip.none,
                     children: _playerHands[pIndex].asMap().entries.map((entry) {
                        return Padding(
                           padding: EdgeInsets.only(top: entry.key * 25.0),
                           child: _buildCard(entry.value, mini: true),
                        );
                     }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24)
                     ),
                     child: Text("Seat ${pIndex+1}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  )
               ],
            ),
         );
      }),
    );
  }

  Widget _buildCard(String card, {bool mini = false}) {
     if (card == "HIDDEN") {
       return Container(
          width: mini ? 50 : 70,
          height: mini ? 75 : 105,
          decoration: BoxDecoration(
             color: const Color(0xFFD63031),
             borderRadius: BorderRadius.circular(8),
             border: Border.all(color: Colors.white),
          ),
          child: const Center(child: Icon(Icons.ac_unit, color: Colors.white54)),
       );
     }
     
     final valStr = card.replaceAll(RegExp(r'[♠♥♦♣]'), '');
     final suit = card.replaceAll(RegExp(r'[0-9JQKA]'), '');
     final isRed = suit == '♥' || suit == '♦';

     return Container(
         width: mini ? 50 : 70,
         height: mini ? 75 : 105,
         decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black26),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2,2))]
         ),
         child: Stack(
            children: [
               Positioned(
                  top: 4, left: 4,
                  child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                        Text(valStr, style: TextStyle(color: isRed ? Colors.red : Colors.black, fontSize: mini ? 12 : 16, fontWeight: FontWeight.bold, height: 1)),
                        Text(suit, style: TextStyle(color: isRed ? Colors.red : Colors.black, fontSize: mini ? 10 : 14, height: 1)),
                     ],
                  )
               ),
               Center(
                  child: Text(suit, style: TextStyle(color: isRed ? Colors.red : Colors.black, fontSize: mini ? 20 : 32)),
               )
            ],
         ),
     );
  }

  Widget _buildBottomControls() {
     if (_phase == BlackjackPhase.betting) {
        return Row(
           children: [
              Expanded(
                 child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                       children: [
                          const Icon(Icons.speed, color: Colors.white54, size: 20),
                          Expanded(
                             child: Slider(
                                value: _dealDelayMs,
                                min: 50.0,
                                max: 1500.0,
                                activeColor: const Color(0xFFFDCB6E),
                                inactiveColor: Colors.white24,
                                onChanged: (val) {
                                   setState(() {
                                      _dealDelayMs = val;
                                   });
                                },
                                onChangeEnd: (_) => _saveState(),
                             ),
                          ),
                       ],
                    ),
                 ),
              ),
              Padding(
                 padding: const EdgeInsets.only(right: 24),
                 child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDCB6E)),
                    onPressed: _dealHand,
                    child: const Text('DEAL', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 2)),
                 ),
              )
           ],
        );
     }
     return const Center(
        child: Text("Round in Progress...", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
     );
  }

  Widget _buildOverlayPrompt() {
     return Container(
        color: Colors.black87,
        child: Center(
           child: Padding(
             padding: const EdgeInsets.all(32.0),
             child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Text("ROUND COMPLETE", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                   const SizedBox(height: 16),
                   const Text("What is the current running count?", style: TextStyle(color: Colors.white70, fontSize: 16)),
                   const SizedBox(height: 32),
                   TextField(
                      controller: _textController,
                      focusNode: _inputFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(signed: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFD63031), width: 2)),
                      ),
                      onChanged: (val) => _inputValue = val,
                      onSubmitted: (_) => _submitCount(),
                   ),
                   const SizedBox(height: 24),
                   ElevatedButton(
                      style: ElevatedButton.styleFrom(
                         backgroundColor: const Color(0xFFD63031),
                         padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                      onPressed: _submitCount,
                      child: const Text("SUBMIT", style: TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2)),
                   )
                ],
             ),
           ),
        ),
     );
  }
  
  Widget _buildOverlayResult() {
     bool isCorrect = _textController.text == _runningCount.toString();
     return Container(
        color: Colors.black87,
        child: Center(
           child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 Icon(isCorrect ? Icons.check_circle_outline : Icons.cancel_outlined, color: isCorrect ? Colors.greenAccent : Colors.redAccent, size: 80),
                 const SizedBox(height: 16),
                 Text(isCorrect ? "CORRECT!" : "INCORRECT", style: TextStyle(color: isCorrect ? Colors.greenAccent : Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 16),
                 Text("The running count is $_runningCount", style: const TextStyle(color: Colors.white, fontSize: 20)),
                 const SizedBox(height: 48),
                 ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDCB6E), padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16)),
                    onPressed: _nextRound,
                    child: const Text("NEXT ROUND", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 2)),
                 )
              ],
           ),
        ),
     );
  }

  Widget _buildOverlayShuffle() {
      return Container(
        color: Colors.black87,
        child: Center(
           child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 const Icon(Icons.info_outline, color: Colors.amber, size: 80),
                 const SizedBox(height: 24),
                 const Text("SHOE CUT CARD REACHED", style: TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 16),
                 const Text("The shoe has 6 decks. They are now depleted.", style: TextStyle(color: Colors.white70, fontSize: 16)),
                 const SizedBox(height: 8),
                 const Text("The count will reset to 0.", style: TextStyle(color: Colors.white70, fontSize: 16)),
                 const SizedBox(height: 48),
                 ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD63031), padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16)),
                    onPressed: _reshuffle,
                    child: const Text("RESHUFFLE & DEAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
                 )
              ],
           ),
        ),
     );
  }
}
