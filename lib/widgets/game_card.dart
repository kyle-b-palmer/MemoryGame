import 'package:flutter/material.dart';
import '../models/game_type.dart';

class GameCard extends StatefulWidget {
  final GameType gameType;
  final VoidCallback onTap;

  const GameCard({
    super.key,
    required this.gameType,
    required this.onTap,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = widget.gameType.isAvailable;

    return GestureDetector(
      onTapDown: isAvailable ? _onTapDown : null,
      onTapUp: isAvailable ? _onTapUp : null,
      onTapCancel: isAvailable ? _onTapCancel : null,
      onTap: isAvailable ? widget.onTap : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isAvailable
                  ? [
                      const Color(0xFF1A1A2E),
                      const Color(0xFF16213E),
                    ]
                  : [
                      const Color(0xFF1A1A2E).withOpacity(0.5),
                      const Color(0xFF16213E).withOpacity(0.5),
                    ],
            ),
            border: Border.all(
              color: _isPressed
                  ? widget.gameType.gradientColors[0]
                  : widget.gameType.gradientColors[0].withOpacity(0.3),
              width: _isPressed ? 2 : 1,
            ),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: widget.gameType.gradientColors[0].withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isAvailable
                          ? widget.gameType.gradientColors
                          : widget.gameType.gradientColors
                              .map((c) => c.withOpacity(0.3))
                              .toList(),
                    ),
                  ),
                  child: Icon(
                    widget.gameType.icon,
                    size: 32,
                    color: isAvailable ? Colors.white : Colors.white54,
                  ),
                ),
                const SizedBox(width: 16),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.gameType.title,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: isAvailable ? Colors.white : Colors.white54,
                            ),
                          ),
                          if (!isAvailable) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'SOON',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.gameType.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isAvailable ? Colors.white54 : Colors.white30,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.chevron_right_rounded,
                  color: isAvailable
                      ? widget.gameType.gradientColors[0]
                      : Colors.white24,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

