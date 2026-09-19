import 'package:flutter/foundation.dart';

@immutable
class LearnLesson {
  const LearnLesson(
    this.number,
    this.name,
    this.objective,
    this.contentAndExercise,
  );

  final int number;
  final String name;
  final String objective;
  final String contentAndExercise;

  bool get isChallenge => number % 8 == 0;
}

@immutable
class LearnUnit {
  const LearnUnit(this.number, this.name, this.lessons);

  final int number;
  final String name;
  final List<LearnLesson> lessons;
}

/// Board order: each unit is a row, read left to right, from the top down.
const learnCurriculum = <LearnUnit>[
  LearnUnit(1, 'The Fundamentals', [
    LearnLesson(
      1,
      'Meet the Board',
      'Restore the starting position and make the first move for each side.',
      'Have the player replace three missing black pieces, replace three missing white pieces, then make one legal move for Black and one for White.',
    ),
    LearnLesson(
      2,
      'Your First Moves',
      'Find legal diagonal moves and learn how turns alternate.',
      'Teach diagonal forward movement, empty destinations, and alternating turns. Ask the player to find legal moves in increasingly crowded positions.',
    ),
    LearnLesson(
      3,
      'Making a Capture',
      'Spot legal jumps and learn when a capture is compulsory.',
      'Teach jumping an adjacent opponent into an empty square beyond it, removing the captured piece, and mandatory captures. Distinguish genuine captures from blocked jumps.',
    ),
    LearnLesson(
      4,
      'Keep Jumping',
      'Follow a capture through every jump with the same piece.',
      'Teach complete multiple-jump sequences and choices between capture routes. Practice continuing with the same piece and recognizing when a sequence ends.',
    ),
    LearnLesson(
      5,
      'Becoming a King',
      'Reach the promotion row and learn when your turn ends.',
      'Explain the promotion row and that reaching it ends the turn, including during a capture. Guide pieces to promotion through ordinary moves and jumps.',
    ),
    LearnLesson(
      6,
      'Moving with Kings',
      'Use a king’s backward moves and captures to explore new routes.',
      'Teach one-square forward and backward movement, backward captures, and changing direction during multiple jumps. Compare legal moves for kings and uncrowned pieces.',
    ),
    LearnLesson(
      7,
      'How Games End',
      'Recognize wins, resignation, and drawn positions.',
      'Cover winning by capturing or immobilizing the opponent, resignation, and basic draw recognition. Classify finished positions and introduce Crown’s draw indicators.',
    ),
    LearnLesson(
      8,
      'Challenge: Your First Game',
      'Put the rules together in a guided miniature game.',
      'Complete a guided miniature game containing captures, promotion, and a finish. Assess rules comprehension; allow retries without requiring a full starting-position game.',
    ),
  ]),
  LearnUnit(2, 'Keeping Your Pieces Safe', [
    LearnLesson(
      9,
      'Spot the Threat',
      'Find the pieces your opponent could capture next turn.',
      'Identify pieces the opponent could capture on their next turn. Mark both the threatened piece and the landing square that makes the jump possible.',
    ),
    LearnLesson(
      10,
      'Before You Move',
      'Check whether moving one piece exposes another to capture.',
      'Show how moving one piece can expose another. Preview a candidate move and identify any new captures it permits.',
    ),
    LearnLesson(
      11,
      'Find a Safe Square',
      'Choose a legal destination that avoids an immediate material loss.',
      'Compare legal destinations for the same piece. Choose a destination that avoids an immediate material loss in the supplied position.',
    ),
    LearnLesson(
      12,
      'Protecting a Piece',
      'Protect your pieces through support and blocked jump destinations.',
      'Introduce support through recaptures and denying jump landing squares. Show why merely standing beside a friendly piece does not guarantee protection.',
    ),
    LearnLesson(
      13,
      'Count the Exchange',
      'Count each side’s losses through a capture and recapture.',
      'Follow a short capture-and-recapture sequence and count what each side loses. Distinguish equal exchanges from losing trades.',
    ),
    LearnLesson(
      14,
      'Beware the Second Jump',
      'See the full damage hidden behind an opponent’s first jump.',
      'Show how a seemingly harmless capture can become a multiple jump. Identify the full damage before deciding whether a move is safe.',
    ),
    LearnLesson(
      15,
      'The Safety Check',
      'Check forced captures, the opponent’s reply, and the resulting exchange.',
      'Combine the section into a repeatable routine: check compulsory captures, inspect the opponent’s reply, and count the resulting exchange. Apply it to mixed positions.',
    ),
    LearnLesson(
      16,
      'Challenge: Hold Your Ground',
      'Defend short positions without preventable material losses.',
      'Play short defensive positions and a brief continuation. Succeed by avoiding preventable material losses, rather than by defeating the opponent outright.',
    ),
  ]),
  LearnUnit(3, 'Forcing Moves and Combinations', [
    LearnLesson(
      17,
      'Make Them Jump',
      'Use compulsory captures to force a specific response.',
      'Introduce using compulsory captures to direct an opponent’s response. Choose a move that forces a specific capture when no alternative capture exists.',
    ),
    LearnLesson(
      18,
      'Give One, Take Two',
      'Offer one piece to force a reply that wins back more material.',
      'Teach a basic material-winning sacrifice. Offer one piece, follow the forced reply, and recover more material than was sacrificed.',
    ),
    LearnLesson(
      19,
      'Build a Multiple Jump',
      'Find the setup move that creates a multiple-jump capture.',
      'Arrange an opponent’s pieces into a capturable sequence. Find the setup move before executing the combination.',
    ),
    LearnLesson(
      20,
      'Remove the Defender',
      'Force away a supporting piece and exploit the weakness it leaves.',
      'Force away or exchange a piece that supports an opponent’s position. Exploit the weakness created after its removal.',
    ),
    LearnLesson(
      21,
      'Open the Landing Square',
      'Clear the landing square needed to make a capture possible.',
      'Teach that a blocked landing square can prevent a capture. Find a forcing sequence that clears the required square.',
    ),
    LearnLesson(
      22,
      'Choose Your Capture',
      'Compare capture routes by what happens after the jumps.',
      'Compare alternative legal capture routes by their consequences. Include examples where taking more immediately produces a worse result.',
    ),
    LearnLesson(
      23,
      'When the Sacrifice Fails',
      'Test a tempting sacrifice against alternative replies and recaptures.',
      'Examine tempting combinations that fail because of another legal reply or a final recapture. Separate sound sacrifices from hopeful ones.',
    ),
    LearnLesson(
      24,
      'Challenge: Find the Combination',
      'Find a sound setup and continuation in unfamiliar tactical positions.',
      'Solve unfamiliar positions mixing the section’s patterns. Require the setup and continuation, including recognizing a position where the apparent combination does not work.',
    ),
  ]),
  LearnUnit(4, 'Thinking Ahead', [
    LearnLesson(
      25,
      'Their Best Reply',
      'Find your opponent’s strongest reply to a proposed move.',
      'Replace “What do I want them to do?” with “What can they do?” Choose the opponent’s strongest immediate response to a proposed move.',
    ),
    LearnLesson(
      26,
      'Your Move, Their Move, Your Move',
      'Predict the squares and material balance three turns ahead.',
      'Calculate a three-turn sequence before moving. Predict the final squares and material balance, then play it out.',
    ),
    LearnLesson(
      27,
      'Find the Branches',
      'Spot where a forced sequence gives way to a choice of replies.',
      'Distinguish a forced sequence from one with alternatives. Identify the points where the opponent can choose a different reply.',
    ),
    LearnLesson(
      28,
      'Compare Two Plans',
      'Look ahead equally far to compare two candidate moves.',
      'Analyze two candidate moves using the same short lookahead. Compare the resulting material, safety, and promotion prospects.',
    ),
    LearnLesson(
      29,
      'Finish the Sequence',
      'Resolve the forced captures before judging an exchange.',
      'Avoid evaluating halfway through a capture exchange. Continue until immediate forced captures are resolved before judging the outcome.',
    ),
    LearnLesson(
      30,
      'Work Backward',
      'Work back from a desired capture or promotion to find its setup.',
      'Start from a desired capture or promotion and identify the arrangement needed to achieve it. Find a short sequence that creates that arrangement.',
    ),
    LearnLesson(
      31,
      'Calculate Without Moving',
      'Track a short sequence mentally and identify its final position.',
      'Gradually remove preview assistance. Track a short sequence mentally, then select or reconstruct its final position.',
    ),
    LearnLesson(
      32,
      'Challenge: Read Ahead',
      'Choose a move and predict the response with limited preview help.',
      'Solve mixed positions with limited preview support. Give the move and expected response; accept multiple sound solutions where appropriate.',
    ),
  ]),
  LearnUnit(5, 'Building a Strong Position', [
    LearnLesson(
      33,
      'Beyond the Piece Count',
      'Judge mobility, support, and promotion chances alongside material.',
      'Introduce mobility, support, and promotion prospects as additional ways to judge a position. Compare equal-material examples with visibly different strengths.',
    ),
    LearnLesson(
      34,
      'Stay Connected',
      'Improve coordination without creating an immediate tactical weakness.',
      'Explain how coordinated pieces can support exchanges and advances. Improve a fragmented position without creating an immediate tactical weakness.',
    ),
    LearnLesson(
      35,
      'Using the Center',
      'Develop useful central influence while keeping your pieces supported.',
      'Explore central influence and access to both sides of the board. Contrast useful central development with an unsupported advance.',
    ),
    LearnLesson(
      36,
      'Playing the Edges',
      'Weigh an edge route’s protection against its limited mobility.',
      'Examine the trade-off between fewer attacking approaches and fewer movement options. Choose between an edge route and a central route in contrasting positions.',
    ),
    LearnLesson(
      37,
      'Keep Your Options',
      'Preserve useful moves or restrict your opponent’s choices.',
      'Teach mobility and the danger of cramped formations. Select a move that preserves useful future moves or restricts the opponent.',
    ),
    LearnLesson(
      38,
      'Guarding the Back Row',
      'Decide when a back-row defender should stay or advance.',
      'Explain how back-row pieces can obstruct promotion and why holding them forever can also be costly. Decide when to retain or release a defender.',
    ),
    LearnLesson(
      39,
      'Trade with a Purpose',
      'Choose exchanges that improve your position or open a route forward.',
      'Evaluate exchanges that improve structure, remove a troublesome piece, or open a route forward. Compare the board before and after an equal trade.',
    ),
    LearnLesson(
      40,
      'Challenge: Improve Your Position',
      'Improve coordination, mobility, or promotion chances without conceding a tactic.',
      'Play several short scenarios with clear positional objectives. Assess whether the player improves mobility, coordination, or promotion prospects without conceding a tactic.',
    ),
  ]),
  LearnUnit(6, 'The Road to Promotion', [
    LearnLesson(
      41,
      'Find a Route to Crown',
      'Trace a promising promotion path and identify its obstacles.',
      'Trace possible promotion paths and identify obstacles. Select a promising route rather than simply advancing the nearest piece.',
    ),
    LearnLesson(
      42,
      'Escort the Runner',
      'Use supporting pieces to keep an advancing piece safe.',
      'Use supporting pieces to help an advancing piece survive. Choose an escort move that answers an interception threat.',
    ),
    LearnLesson(
      43,
      'Break Through',
      'Weigh the cost of an exchange or sacrifice that opens a promotion route.',
      'Use an exchange or sacrifice to open a promotion route. Compare the material cost with the resulting position.',
    ),
    LearnLesson(
      44,
      'Stop Their Promotion',
      'Intercept, block, or exchange an opposing runner before it crowns.',
      'Recognize an opposing runner and calculate an interception, block, or forced exchange. Solve defensive promotion problems.',
    ),
    LearnLesson(
      45,
      'Race to the Back Row',
      'Count the turns to promotion and decide whether to race or defend.',
      'Count turns to promotion while accounting for forced captures and interference. Decide whether to race or stop the opponent.',
    ),
    LearnLesson(
      46,
      'Activate Your King',
      'Bring your new king into useful play while avoiding traps.',
      'Bring a newly crowned king into useful play. Compare routes that improve its reach while avoiding traps and captures.',
    ),
    LearnLesson(
      47,
      'King and Piece Together',
      'Use a king to support an uncrowned piece’s advance.',
      'Coordinate a king with an uncrowned piece. Use the king to support an advance, remove an obstacle, or protect a promotion route.',
    ),
    LearnLesson(
      48,
      'Challenge: Earn the Crown',
      'Create and use a king, then stop an opposing promotion.',
      'Complete paired scenarios: create a king and use it effectively in one; prevent a dangerous opposing promotion in another.',
    ),
  ]),
  LearnUnit(7, 'Winning and Drawing Endgames', [
    LearnLesson(
      49,
      'Take Stock of the Ending',
      'Assess a sparse position and decide whether to convert or defend.',
      'Assess material, kings, mobility, and immediate threats in sparse positions. Identify whether the practical task is to convert, defend, or investigate further.',
    ),
    LearnLesson(
      50,
      'Trading When Ahead',
      'Check whether a proposed exchange preserves your advantage.',
      'Show when exchanging pieces simplifies a win—and when it gives away the advantage. Compare concrete end positions instead of teaching an absolute rule.',
    ),
    LearnLesson(
      51,
      'Opposition and Move Timing',
      'Discover how the side to move can change an ending’s outcome.',
      'Introduce simple positions whose outcome depends on whose turn it is. Play matched examples with the side to move reversed.',
    ),
    LearnLesson(
      52,
      'Keep a Move in Reserve',
      'Decide when to spend an extra move to influence the timing.',
      'Use an available move elsewhere on the board to influence timing. Decide when to spend or preserve that move in a small, verified position.',
    ),
    LearnLesson(
      53,
      'Coordinate Your Kings',
      'Use two kings together to reduce an opponent’s escape routes.',
      'Use two kings to restrict an opponent’s options while protecting one another. Practice reducing escape routes instead of chasing independently.',
    ),
    LearnLesson(
      54,
      'Finish the Win',
      'Preserve a winning ending through accurate moves to the finish.',
      'Convert selected, verified winning endings through capture or immobilization. Focus on preserving the win across several accurate moves.',
    ),
    LearnLesson(
      55,
      'Save the Draw',
      'Defend a drawable ending with safe positioning and draw awareness.',
      'Defend selected drawable endings through safe positioning and avoiding traps. Reinforce repetition and Crown’s implemented draw procedure.',
    ),
    LearnLesson(
      56,
      'Challenge: Win or Hold',
      'Convert a winning ending and hold a drawable one.',
      'Convert one verified winning position and defend one verified drawable position against a suitable response policy. Offer targeted retries from the first consequential mistake.',
    ),
  ]),
  LearnUnit(8, 'Putting It All Together', [
    LearnLesson(
      57,
      'A Sound Opening',
      'Develop safely from the starting position with support and mobility.',
      'Apply safety, support, and mobility from the starting position. Compare early moves by their purpose without requiring named-opening memorization.',
    ),
    LearnLesson(
      58,
      'Understand Their Last Move',
      'Identify what your opponent’s last move changed and respond.',
      'After each opposing move, identify what changed: a threat, an opening, a weakened defender, or a promotion route. Select an appropriate response.',
    ),
    LearnLesson(
      59,
      'Choose a Plan',
      'Set a concrete middlegame goal and choose a move that advances it.',
      'Assess a middlegame position and choose a concrete goal, such as improving a cramped side or preparing a breakthrough. Select a move that advances it.',
    ),
    LearnLesson(
      60,
      'Know When to Change Plans',
      'Recognize when an opposing reply calls for a different plan.',
      'Introduce an opponent’s reply that changes the position. Recognize when an existing plan should be revised or abandoned.',
    ),
    LearnLesson(
      61,
      'Play with an Advantage',
      'Continue a favorable position with safe, purposeful play.',
      'Combine safety, purposeful exchanges, and promotion planning. Continue a favorable middlegame without assuming that every trade is beneficial.',
    ),
    LearnLesson(
      62,
      'Play from Behind',
      'Preserve sound resistance, tactical opportunities, and drawing chances.',
      'Look for sound resistance, tactical opportunities, and drawing chances. Choose moves that preserve possibilities instead of relying on an obvious opponent mistake.',
    ),
    LearnLesson(
      63,
      'Learn from Your Game',
      'Review a consequential decision and identify a useful skill to practice.',
      'Review a short replay, locate a consequential decision, try an improvement, and identify the associated skill. End by selecting a useful practice topic.',
    ),
    LearnLesson(
      64,
      'Final Challenge: A Complete Game',
      'Play a complete game, then review and improve several key decisions.',
      'Play a full game at an appropriate fixed difficulty, then complete a guided review of several decisions. Assess the application of skills and the review—not victory alone.',
    ),
  ]),
];
