# Checkers Rules

## Ruleset Identity

Crown Checkers uses the WCDF Rules of Checkers (English Draughts), 2012 publication, under Go As You Please opening play: https://wcdf.net/rules/rules_of_checkers_english.pdf

The MVP ruleset identifier is:

```txt
checkers-wcdf-gayp-v1.0.0
```

This identifier cites that adopted WCDF publication. Release records retain a repository copy or checksum of the publication used during conformance review. The product does not depend on an unversioned external rules page at runtime.

This document is the complete executable game contract for the identifier above. If an external rules source is ambiguous, changes, or includes tournament procedure that is not represented here, this document controls engine behavior until a new Crown ruleset identifier is published.

Go As You Please means every game starts from the normal initial position with no drawn opening ballot and no mandatory three-move opening.

---

# Terms

## Side

The two logical sides are Black and White. Cosmetic colors do not change logical side.

## Man

An uncrowned piece. The plural is men.

## King

A crowned piece that may move and capture in both diagonal directions.

## Turn

One player's complete action. A non-capturing turn contains one step. A capturing turn contains one or more jumps made by the same piece.

## Ply

One completed turn by one side. A multi-jump capture is one ply.

## Playable Square

One of the 32 dark squares on which pieces may exist and move.

---

# Board and Coordinates

The board has eight rows and eight columns.

The canonical engine coordinate system is zero-based:

- Rows are `0` through `7`, from Black's home edge toward White's home edge.
- Columns are `0` through `7`, from left to right when viewed with White at the bottom.
- A square is playable when `(row + column) % 2 == 1`.
- A square is unplayable when `(row + column) % 2 == 0`.

Human-readable coordinates map columns `0` through `7` to `a` through `h`, and rows `0` through `7` to ranks `8` through `1`. For example, engine square `(0, 1)` is `b8` and `(7, 0)` is `a1`.

The engine coordinate system never rotates. A client may rotate presentation so that the local player appears at the bottom, but must translate input back to canonical coordinates before validation.

---

# Initial Position

The standard initial position contains 24 men:

- Black has one man on every playable square in rows `0`, `1`, and `2`.
- White has one man on every playable square in rows `5`, `6`, and `7`.
- Rows `3` and `4` are empty.
- Black takes the first turn.

The initial position contains no kings.

Authored puzzle positions and restored match positions may differ from the initial position but must satisfy the state validity rules below.

---

# State Validity

A valid engine state has:

- Exactly 64 board locations, of which only the 32 playable squares may contain pieces.
- At most one piece on a square.
- Each piece assigned to Black or White.
- Each piece assigned exactly one rank: man or king.
- No more than 12 pieces for either side in a standard match lineage.
- An active side to move when the game is not final.
- A nonnegative quiet-king ply counter.
- A ruleset identifier equal to the rules used to create or restore the state.

An authored puzzle may use fewer than 24 total pieces. It may not use more than 12 pieces for a side, place a piece on an unplayable square, or mark an active state when the side to move has already lost under the terminal rules unless the authored content explicitly represents a completed position.

The engine rejects malformed state. It does not silently move pieces, change ranks, change the active side, or infer a different ruleset.

---

# Order of Play

Black moves first. Sides then alternate after each complete turn.

The active side may make exactly one legal turn. A client may animate or submit the jumps of a multi-capture incrementally, but the side does not change until the complete forced sequence ends.

There is no pass. If the active side has no legal turn, that side loses.

---

# Non-Capturing Moves

A non-capturing move is legal only when the active side has no capture anywhere on the board.

## White Man

A White man moves one row toward row `0` and one column diagonally:

- `(row - 1, column - 1)`, or
- `(row - 1, column + 1)`.

The destination must be on the board, playable, and empty.

## Black Man

A Black man moves one row toward row `7` and one column diagonally:

- `(row + 1, column - 1)`, or
- `(row + 1, column + 1)`.

The destination must be on the board, playable, and empty.

## King

A king moves one row and one column diagonally in any direction. The destination must be on the board, playable, and empty.

Kings are not flying kings. They cannot slide over multiple empty squares in one move.

---

# Captures

A capture jumps an adjacent opposing piece and lands on the empty playable square immediately beyond it on the same diagonal.

The jumped piece is removed before continuation captures are evaluated.

## White Man Capture

A White man captures forward only. Its landing square is two rows toward row `0` and two columns left or right:

- `(row - 2, column - 2)`, or
- `(row - 2, column + 2)`.

The intermediate square must contain a Black piece and the landing square must be empty.

## Black Man Capture

A Black man captures forward only. Its landing square is two rows toward row `7` and two columns left or right:

- `(row + 2, column - 2)`, or
- `(row + 2, column + 2)`.

The intermediate square must contain a White piece and the landing square must be empty.

## King Capture

A king captures forward or backward. Its landing square is two rows and two columns diagonally from its origin. The intermediate square must contain an opposing piece and the landing square must be empty.

Kings are not flying kings. A jump crosses exactly one adjacent opposing piece.

---

# Mandatory Capture

If any piece belonging to the active side can capture, the side must choose a capturing turn.

Non-capturing moves are illegal while any capture exists, even when the selected piece itself cannot capture.

When more than one piece can capture, the player may choose any capturing piece. When a piece has more than one legal capture branch, the player may choose any branch.

There is no maximum-capture or majority-capture rule. The player is not required to choose the line that captures the most pieces or kings.

---

# Multiple Captures

After each jump, the engine removes the jumped piece and checks whether the same moving piece has another legal capture from its new square.

If another capture exists:

- The player must continue with the same piece.
- The active side does not change.
- No other piece may move.
- The player may choose any available continuation branch.

The turn ends only when the moving piece has no legal continuation, except that crowning ends a man's turn immediately as defined below.

A piece may visit a square more than once during a king capture sequence if the evolving board makes that route legal. A piece already captured and removed cannot be captured again.

---

# Crowning

A White man is crowned when it ends a step or jump on row `0`.

A Black man is crowned when it ends a step or jump on row `7`.

The piece becomes a king before the resulting position is stored.

When a man reaches its crown row during a capture, the turn ends immediately. It may not continue capturing backward as a king during that turn. The opposing side becomes active unless the game has ended.

A man cannot exist on its crown row in a stored active match state. Restoration or authored-state validation must represent such a piece as a king.

---

# Legal Turn Generation

The engine generates complete legal turns in this order of logic:

1. Find every capture available to every piece of the active side.
2. If at least one capture exists, generate every complete capture sequence and no non-capturing move.
3. Stop a sequence when no continuation exists or when a man reaches its crown row.
4. If no capture exists, generate every legal single-step move.

Generation order in memory is not a game rule. Tests and network payloads must compare turns by canonical origin, ordered landing squares, and ordered captured squares rather than relying on incidental collection order.

A submitted turn is legal only when it exactly matches one generated complete turn. For incremental online submission, every submitted jump must match a prefix of at least one generated complete turn, and the server must require continuation while a legal suffix remains.

---

# Turn Application

Applying a legal turn performs these operations atomically at the rules layer:

1. Confirm the submitted side is active.
2. Confirm the turn is in the generated legal set.
3. Move the selected piece through each landing square.
4. Remove each captured piece after its corresponding jump.
5. Crown a man when applicable.
6. Update draw counters and repetition history.
7. Evaluate terminal state.
8. If the game remains active, set the opposing side as active.

An illegal turn leaves the state unchanged.

---

# Winning and Losing

The active player wins when the opposing player resigns or loses on time at the match layer.

At the board-rules layer, a side loses when either condition is true at the start of its turn:

- It has no pieces.
- It has pieces but no legal turn.

After a turn is applied, the engine evaluates the opposing side. If the opposing side has no pieces or no legal turn, the moving side wins immediately.

Having fewer pieces does not itself lose the game. Reaching a particular king count does not itself win the game.

Board-rule result reasons are:

```txt
no_pieces
no_legal_move
draw_repetition
draw_quiet_kings
```

Played match-layer result reasons defined directly by this rules contract are:

```txt
resignation
timeout
```

Administrative cancellation or voiding is not a played Checkers result and must not be serialized as a win, loss, or draw.

Online-service reasons such as disconnect and no-show are defined in [[Match and Rating State Machine]] and do not alter board legality.

---

# Draws

The MVP engine recognizes automatic draws. Draw offers and draws by agreement are not included.

## Threefold Repetition

The game is drawn when the same position occurs for the third time.

Position identity includes:

- Every occupied square.
- Each piece's side.
- Each piece's rank as man or king.
- The side to move.
- The ruleset identifier.

The initial position counts as its first occurrence. A position is recorded after a complete turn and side change. Intermediate squares inside a multi-capture do not count as positions for repetition.

The occurrences do not need to be consecutive.

## Forty-Move King Rule

The game is drawn after 40 moves by each player, or 80 consecutive plies, during which:

- No piece is captured.
- No man moves.

The engine stores a `quietKingPlyCount`.

- Set it to zero after any capture.
- Set it to zero after any turn made by a man, including a move that crowns the man.
- Increment it by one after a non-capturing king turn.
- Declare a draw when it reaches 80 after applying a legal turn, unless that turn has already produced a win by leaving the opponent with no pieces or no legal move.

## Draw Precedence

After applying a turn, evaluate outcomes in this order:

1. Opponent has no pieces.
2. Opponent has no legal turn.
3. Third occurrence of the resulting position.
4. Quiet-king ply count reaches 80.
5. Game remains active.

No arbitrary total-turn limit applies.

---

# Clocks, Resignation, and Connectivity

Clocks, resignation, and connectivity are match concerns layered around the board engine.

Every online human-vs-human Checkers match gives each player 15 minutes with no increment. The server is authoritative. The active player's clock runs for the entire turn, including all jumps in a multi-capture sequence.

When the authoritative clock reaches zero before a legal complete turn is committed, that player loses by timeout. A client-side animation or unconfirmed move does not stop the clock.

Resignation immediately ends an active match as a loss for the resigning side.

Disconnecting, backgrounding the app, or closing the client does not pause an online clock and does not alter the board position. Reconnection restores authoritative state.

Bot matches have no MVP clock.

---

# Serialization and Replay

Every match and puzzle position validated under this contract stores:

- `rulesetId` equal to `checkers-wcdf-gayp-v1.0.0`.
- Canonical initial state.
- Active side.
- Ordered complete turns or an equivalent ordered jump representation preserving turn boundaries.
- Crowning events or enough information to derive them deterministically.
- Final result and result reason when complete.

A replay must reconstruct state by applying the stored turns through the same rules implementation. A replay must fail explicitly if its ruleset implementation is unavailable. It must not silently use the newest rules.

---

# Engine Conformance Criteria

An implementation conforms to `checkers-wcdf-gayp-v1.0.0` only when all of the following are true:

- The initial position contains 12 White men, 12 Black men, and Black to move.
- Pieces never occupy unplayable squares.
- Men step and capture only forward.
- Kings step and capture both forward and backward, one diagonal step or one adjacent-piece jump at a time.
- Any available capture suppresses every non-capturing move.
- Capture choice is unrestricted by capture count.
- A multi-capture continues with the same piece until no continuation exists.
- Crowning ends the current turn immediately.
- No-piece and no-legal-move losses are detected.
- Repetition and quiet-king draws are deterministic and use the precedence in this document.
- Illegal state and illegal turns do not mutate authoritative state.
- Presentation rotation and cosmetics do not alter generated turns.

---

# Required Rules Tests

## Initial Position Tests

- Load the standard position and assert 12 men per side, no kings, and Black to move.
- Assert every occupied initial square is playable.
- Assert Black has seven legal opening steps and no captures.

## Man Movement Tests

- Place an unblocked White man away from an edge and assert only its two forward steps are generated.
- Place an unblocked Black man away from an edge and assert only its two forward steps are generated.
- Assert neither man receives a backward non-capturing move.
- Assert edge and occupied destinations are excluded.

## King Movement Tests

- Place an unblocked king centrally and assert up to four one-square diagonal steps.
- Assert a king cannot slide two empty squares.
- Assert a king can capture forward and backward.

## Mandatory Capture Tests

- Give one piece a capture and another piece a legal step; assert only capture turns are generated.
- Give two pieces captures; assert complete capture turns from both pieces are generated.
- Give one branch one capture and another branch two captures; assert both branches remain legal.

## Multi-Capture Tests

- Create a forced two-jump sequence and assert the turn cannot stop after the first jump.
- Create two continuation branches and assert both complete sequences are legal.
- Assert another piece cannot replace the moving piece during continuation.
- Assert each jumped piece is removed before the next jump is evaluated.

## Crowning Tests

- Move a White man to row `0` and assert it is stored as a king.
- Move a Black man to row `7` and assert it is stored as a king.
- Jump a man into its crown row with a potential backward king capture available; assert the piece crowns and the turn ends without that capture.

## Terminal Result Tests

- Capture the opponent's final piece and assert `no_pieces` victory.
- Block every legal move while leaving opponent pieces and assert `no_legal_move` victory.
- Apply resignation and timeout at the match layer and assert the correct winner and distinct reason.

## Draw Tests

- Repeat the same position with the same side to move three times and assert `draw_repetition` on the third occurrence.
- Reach the same board with the opposite side to move and assert it is not the same repetition position.
- Complete 79 qualifying king plies and assert the game remains active; complete ply 80 and assert `draw_quiet_kings`.
- Move a man or make a capture and assert the quiet-king counter resets to zero.
- On a move that both reaches a draw threshold and leaves the opponent without a legal move, assert the win takes precedence.

## Robustness Tests

- Submit a step while another piece can capture and assert rejection with no state mutation.
- Submit a partial capture sequence as a complete turn and assert rejection.
- Submit a turn for the inactive side and assert rejection.
- Restore a piece on an unplayable square and assert state rejection.
- Replay a recorded game and assert every reconstructed state and final result match the authoritative record.
