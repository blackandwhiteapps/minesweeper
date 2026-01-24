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

class MinesweeperGame extends StatefulWidget {
  const MinesweeperGame({super.key});

  @override
  State<MinesweeperGame> createState() => _MinesweeperGameState();
}

class _MinesweeperGameState extends State<MinesweeperGame>
    with TickerProviderStateMixin {
  static const int gridSize = 12;
  static const int mineCount = 20; // Adjustable mine count
  
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
    mines = List.generate(gridSize, (_) => List.filled(gridSize, false));
    cellStates = List.generate(
      gridSize,
      (_) => List.filled(gridSize, CellState.hidden),
    );
    adjacentMineCounts = List.generate(
      gridSize,
      (_) => List.filled(gridSize, 0),
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
    
    while (placed < mineCount) {
      final row = random.nextInt(gridSize);
      final col = random.nextInt(gridSize);
      
      // Don't place mine on first click or if already has mine
      if ((row == firstClickRow && col == firstClickCol) || mines[row][col]) {
        continue;
      }
      
      mines[row][col] = true;
      placed++;
    }
    
    // Calculate adjacent mine counts
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (!mines[row][col]) {
          int count = 0;
          for (int dr = -1; dr <= 1; dr++) {
            for (int dc = -1; dc <= 1; dc++) {
              if (dr == 0 && dc == 0) continue;
              final nr = row + dr;
              final nc = col + dc;
              if (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
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
        for (int r = 0; r < gridSize; r++) {
          for (int c = 0; c < gridSize; c++) {
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
        row >= gridSize ||
        col < 0 ||
        col >= gridSize ||
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
        if (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
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
          if (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
            final state = cellStates[nr][nc];
            if (state != CellState.flagged && state != CellState.revealed) {
              if (mines[nr][nc]) {
                // Hit a mine - game over
                setState(() {
                  gameOver = true;
                  // Reveal all mines
                  for (int r = 0; r < gridSize; r++) {
                    for (int c = 0; c < gridSize; c++) {
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
    final totalCells = gridSize * gridSize;
    if (revealedCount == totalCells - mineCount) {
      setState(() {
        gameWon = true;
      });
      gameTimer?.cancel();
      _winAnimationController.forward();
    }
  }

  void _newGame() {
    _lossAnimationController.reset();
    _winAnimationController.reset();
    _initializeGame();
    setState(() {});
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
    final mineCount = adjacentMineCounts[row][col];
    
    Color backgroundColor;
    Color textColor;
    String displayText = '';
    
    if (state == CellState.revealed) {
      backgroundColor = Colors.black;
      textColor = Colors.white;
      if (isMine) {
        displayText = '●';
      } else if (mineCount > 0) {
        displayText = mineCount.toString();
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
                    onPressed: _newGame,
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
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: gridSize,
                                  crossAxisSpacing: 0,
                                  mainAxisSpacing: 0,
                                ),
                                itemCount: gridSize * gridSize,
                                itemBuilder: (context, index) {
                                  final row = index ~/ gridSize;
                                  final col = index % gridSize;
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
