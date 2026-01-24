import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

void main() {
  runApp(const MinesweeperApp());
}

class MinesweeperApp extends StatelessWidget {
  const MinesweeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minesweeper',
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          background: Colors.black,
          surface: Colors.black,
          onSurface: Colors.white,
          onBackground: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const MinesweeperGame(),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum CellState {
  hidden,
  flagged,
  questioned,
  revealed,
}

class _GamePreset {
  final String label;
  final int gridSize;
  final int mineCount;

  const _GamePreset({
    required this.label,
    required this.gridSize,
    required this.mineCount,
  });
}

class MinesweeperGame extends StatefulWidget {
  const MinesweeperGame({super.key});

  @override
  State<MinesweeperGame> createState() => _MinesweeperGameState();
}

class _MinesweeperGameState extends State<MinesweeperGame>
    with TickerProviderStateMixin {
  // Default (phone) game config
  static const int _defaultGridSize = 12;
  static const int _defaultMineCount = 20;

  static const double _tabletShortestSideThreshold = 600.0;

  static const List<_GamePreset> _tabletPresets = [
    _GamePreset(label: '12×12', gridSize: 12, mineCount: 20),
    _GamePreset(label: '16×16', gridSize: 16, mineCount: 40),
    _GamePreset(label: '20×20', gridSize: 20, mineCount: 80),
  ];

  late _GamePreset _currentPreset;
  int _gridSize = _defaultGridSize;
  int _mineCount = _defaultMineCount;
  
  late List<List<bool>> mines;
  late List<List<CellState>> cellStates;
  late List<List<int>> adjacentMineCounts;
  bool gameStarted = false;
  bool gameOver = false;
  bool gameWon = false;
  int revealedCount = 0;
  Timer? gameTimer;
  int elapsedSeconds = 0;
  late AnimationController _lossAnimationController;
  late Animation<double> _lossAnimation;
  late AnimationController _winAnimationController;
  late Animation<double> _winAnimation;
  int? hoveredRow;
  int? hoveredCol;

  @override
  void initState() {
    super.initState();
    _currentPreset = const _GamePreset(
      label: '12×12',
      gridSize: _defaultGridSize,
      mineCount: _defaultMineCount,
    );
    _initializeGame();
    _lossAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _lossAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _lossAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _winAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _winAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _winAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _initializeGame() {
    mines = List.generate(_gridSize, (_) => List.filled(_gridSize, false));
    cellStates = List.generate(
      _gridSize,
      (_) => List.filled(_gridSize, CellState.hidden),
    );
    adjacentMineCounts = List.generate(
      _gridSize,
      (_) => List.filled(_gridSize, 0),
    );
    gameStarted = false;
    gameOver = false;
    gameWon = false;
    revealedCount = 0;
    elapsedSeconds = 0;
    hoveredRow = null;
    hoveredCol = null;
    gameTimer?.cancel();
  }

  void _placeMines(int firstClickRow, int firstClickCol) {
    final random = Random();
    int placed = 0;
    final int maxMines = (_gridSize * _gridSize) - 1; // keep first click safe
    final int minesToPlace = _mineCount.clamp(0, maxMines);
    
    while (placed < minesToPlace) {
      final row = random.nextInt(_gridSize);
      final col = random.nextInt(_gridSize);
      
      // Don't place mine on first click or if already has mine
      if ((row == firstClickRow && col == firstClickCol) || mines[row][col]) {
        continue;
      }
      
      mines[row][col] = true;
      placed++;
    }
    
    // Calculate adjacent mine counts
    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        if (!mines[row][col]) {
          int count = 0;
          for (int dr = -1; dr <= 1; dr++) {
            for (int dc = -1; dc <= 1; dc++) {
              if (dr == 0 && dc == 0) continue;
              final nr = row + dr;
              final nc = col + dc;
              if (nr >= 0 && nr < _gridSize && nc >= 0 && nc < _gridSize) {
                if (mines[nr][nc]) count++;
              }
            }
          }
          adjacentMineCounts[row][col] = count;
        }
      }
    }
  }

  void _startTimer() {
    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!gameOver && !gameWon) {
        setState(() {
          elapsedSeconds++;
        });
      }
    });
  }

  void _revealCell(int row, int col) {
    if (gameOver || gameWon || cellStates[row][col] == CellState.revealed) {
      return;
    }

    if (!gameStarted) {
      _placeMines(row, col);
      gameStarted = true;
      _startTimer();
    }

    if (mines[row][col]) {
      // Game over
      setState(() {
        gameOver = true;
        // Reveal all mines
        for (int r = 0; r < _gridSize; r++) {
          for (int c = 0; c < _gridSize; c++) {
            if (mines[r][c]) {
              cellStates[r][c] = CellState.revealed;
            }
          }
        }
      });
      _lossAnimationController.forward();
      gameTimer?.cancel();
      return;
    }

    _revealRecursive(row, col);
    _checkWin();
  }

  void _revealRecursive(int row, int col) {
    if (row < 0 ||
        row >= _gridSize ||
        col < 0 ||
        col >= _gridSize ||
        cellStates[row][col] == CellState.revealed ||
        mines[row][col]) {
      return;
    }

    setState(() {
      cellStates[row][col] = CellState.revealed;
      revealedCount++;
    });

    // If no adjacent mines, reveal neighbors
    if (adjacentMineCounts[row][col] == 0) {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          _revealRecursive(row + dr, col + dc);
        }
      }
    }
  }

  void _chordReveal(int row, int col) {
    if (gameOver || gameWon || cellStates[row][col] != CellState.revealed) {
      return;
    }

    // Count adjacent flags
    int flagCount = 0;
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = row + dr;
        final nc = col + dc;
        if (nr >= 0 && nr < _gridSize && nc >= 0 && nc < _gridSize) {
          if (cellStates[nr][nc] == CellState.flagged) {
            flagCount++;
          }
        }
      }
    }

    // If flag count matches adjacent mine count, reveal all adjacent non-flagged squares
    if (flagCount == adjacentMineCounts[row][col]) {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final nr = row + dr;
          final nc = col + dc;
          if (nr >= 0 && nr < _gridSize && nc >= 0 && nc < _gridSize) {
            final state = cellStates[nr][nc];
            if (state != CellState.flagged && state != CellState.revealed) {
              if (mines[nr][nc]) {
                // Hit a mine - game over
                setState(() {
                  gameOver = true;
                  // Reveal all mines
                  for (int r = 0; r < _gridSize; r++) {
                    for (int c = 0; c < _gridSize; c++) {
                      if (mines[r][c]) {
                        cellStates[r][c] = CellState.revealed;
                      }
                    }
                  }
                });
                _lossAnimationController.forward();
                gameTimer?.cancel();
                return;
              } else {
                _revealRecursive(nr, nc);
              }
            }
          }
        }
      }
      _checkWin();
    }
  }

  void _cycleCellState(int row, int col) {
    if (gameOver || gameWon || cellStates[row][col] == CellState.revealed) {
      return;
    }

    setState(() {
      switch (cellStates[row][col]) {
        case CellState.hidden:
          cellStates[row][col] = CellState.flagged;
          break;
        case CellState.flagged:
          cellStates[row][col] = CellState.questioned;
          break;
        case CellState.questioned:
          cellStates[row][col] = CellState.hidden;
          break;
        case CellState.revealed:
          break;
      }
    });
  }

  void _checkWin() {
    final totalCells = _gridSize * _gridSize;
    if (revealedCount == totalCells - _mineCount) {
      setState(() {
        gameWon = true;
      });
      gameTimer?.cancel();
      _winAnimationController.forward();
    }
  }

  void _newGameSamePreset() {
    _lossAnimationController.reset();
    _winAnimationController.reset();
    _initializeGame();
    setState(() {});
  }

  void _startNewGameWithPreset(_GamePreset preset) {
    _currentPreset = preset;
    _gridSize = preset.gridSize;
    _mineCount = preset.mineCount;
    _newGameSamePreset();
  }

  bool _isLargeScreen(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.shortestSide >= _tabletShortestSideThreshold;
  }

  Future<void> _onNewGamePressed() async {
    if (!_isLargeScreen(context)) {
      // Phones: just restart the current preset
      _newGameSamePreset();
      return;
    }

    final preset = await showDialog<_GamePreset>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text(
            'New Game',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _tabletPresets
                .map(
                  (p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      p.label,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${p.mineCount} mines',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: p.gridSize == _currentPreset.gridSize &&
                            p.mineCount == _currentPreset.mineCount
                        ? const Text(
                            'Current',
                            style: TextStyle(color: Colors.white70),
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(p),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (preset != null) {
      setState(() {
        _startNewGameWithPreset(preset);
      });
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildCell(int row, int col) {
    final state = cellStates[row][col];
    final isHovered = hoveredRow == row && hoveredCol == col;
    final isMine = mines[row][col];
    final adjacentCount = adjacentMineCounts[row][col];
    
    Color backgroundColor;
    Color textColor;
    String displayText = '';
    
    if (state == CellState.revealed) {
      backgroundColor = Colors.black;
      textColor = Colors.white;
      if (isMine) {
        displayText = '●';
      } else if (adjacentCount > 0) {
        displayText = adjacentCount.toString();
      }
    } else {
      backgroundColor = Colors.white;
      textColor = Colors.black;
      switch (state) {
        case CellState.flagged:
          displayText = '⚑';
          break;
        case CellState.questioned:
          displayText = '?';
          break;
        default:
          break;
      }
    }
    
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          hoveredRow = row;
          hoveredCol = col;
        });
      },
      onTapUp: (_) {
        setState(() {
          hoveredRow = null;
          hoveredCol = null;
        });
      },
      onTapCancel: () {
        setState(() {
          hoveredRow = null;
          hoveredCol = null;
        });
      },
      onTap: () {
        if (state == CellState.revealed) {
          _chordReveal(row, col);
        } else {
          _revealCell(row, col);
        }
        // Clear hover after a brief delay to allow the reveal to be visible
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              hoveredRow = null;
              hoveredCol = null;
            });
          }
        });
      },
      onLongPress: () {
        _cycleCellState(row, col);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Transform.scale(
          scale: isHovered ? 0.9 : 1.0,
          child: Center(
            child: Text(
              displayText,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: New Game button and Timer (always accessible)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                  onPressed: _onNewGamePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'New Game',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    _formatTime(elapsedSeconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Game area with overlay
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Game grid
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _gridSize,
                                  crossAxisSpacing: 0,
                                  mainAxisSpacing: 0,
                                ),
                                itemCount: _gridSize * _gridSize,
                                itemBuilder: (context, index) {
                                  final row = index ~/ _gridSize;
                                  final col = index % _gridSize;
                                  return _buildCell(row, col);
                                },
                              ),
                            ),
                            
                            // Explanation text at bottom
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Tap to reveal\nLong press to cycle: Flag → Question → Blank',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Loss animation overlay (only over game area)
                        if (gameOver)
                          IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _lossAnimation,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _lossAnimation.value,
                                  child: Container(
                                    color: Colors.black,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'GAME OVER',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 48 * (1 - _lossAnimation.value * 0.3),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            'Tap New Game to restart',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        
                        // Win animation overlay (only over game area)
                        if (gameWon)
                          IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _winAnimation,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _winAnimation.value,
                                  child: Container(
                                    color: Colors.black,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'YOU WIN!',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 48 * (1 - _winAnimation.value * 0.3),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            'Time: ${_formatTime(elapsedSeconds)}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'Tap New Game to play again',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
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

  @override
  void dispose() {
    gameTimer?.cancel();
    _lossAnimationController.dispose();
    _winAnimationController.dispose();
    super.dispose();
  }
}
