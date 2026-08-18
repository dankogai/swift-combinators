// The birds of Raymond Smullyan's “To Mock a Mockingbird” (1985), each built
// by the construction the book (and combinatory-logic tradition) gives for
// it, on top of the primitives S, K, I, B, C and W.  Every law below is
// verified by the test suite.

extension Term {
    /// The bald eagle, `Ê a b c d e f g → a (b c d) (e f g)`: `E E`.
    public static let baldEagle: Term = eagle(eagle)

    /// The becard, `B₃ a b c d → a (b (c d))`: `B (B B) B`.
    public static let becard: Term = .b(.b(.b), .b)

    /// The blackbird, `B₁ a b c d → a (b c d)`: `B B B`.
    public static let blackbird: Term = .b(.b, .b)

    /// The bluebird, `B a b c → a (b c)` — the primitive ``b``.
    public static let bluebird: Term = .b

    /// The bunting, `B₂ a b c d e → a (b c d e)`: `B (B B B) B`.
    public static let bunting: Term = .b(blackbird, .b)

    /// The cardinal, `C a b c → a c b` — the primitive ``c``.
    public static let cardinal: Term = .c

    /// The cardinal once removed, `C* a b c d → a b d c`: `B C`.
    public static let cardinalOnceRemoved: Term = .b(.c)

    /// The cardinal twice removed, `C** a b c d e → a b c e d`: `B C*`.
    public static let cardinalTwiceRemoved: Term = .b(cardinalOnceRemoved)

    /// The converse warbler, `W′ a b → b a a`: `C W`.
    public static let converseWarbler: Term = .c(.w)

    /// The dickcissel, `D₁ a b c d e → a b c (d e)`: `B (B B)`.
    public static let dickcissel: Term = .b(.b(.b))

    /// The double mockingbird, `M₂ a b → a b (a b)`: `B M`.
    public static let doubleMockingbird: Term = .b(.m)

    /// The dove, `D a b c d → a b (c d)`: `B B`.
    public static let dove: Term = .b(.b)

    /// The dovekie, `D₂ a b c d e → a (b c) (d e)`: `B B (B B)`.
    public static let dovekie: Term = .b(.b, dove)

    /// The eagle, `E a b c d e → a b (c d e)`: `B (B B B)`.
    public static let eagle: Term = .b(blackbird)

    /// The finch, `F a b c → c b a`: `E T T E T`.
    public static let finch: Term = eagle(thrush, thrush, eagle, thrush)

    /// The finch once removed, `F* a b c d → a d c b`: `B C* R*`.
    public static let finchOnceRemoved: Term = .b(cardinalOnceRemoved, robinOnceRemoved)

    /// The finch twice removed, `F** a b c d e → a b e d c`: `B F*`.
    public static let finchTwiceRemoved: Term = .b(finchOnceRemoved)

    /// The goldfinch, `G a b c d → a d (b c)`: `B B C`.
    public static let goldfinch: Term = .b(.b, .c)

    /// The hummingbird, `H a b c → a b c b`: `B W (B C)`.
    public static let hummingbird: Term = .b(.w, .b(.c))

    /// The identity bird, or idiot, `I a → a` — the primitive ``i``.
    public static let idiot: Term = .i

    /// The idiot once removed, `I* a b → a b`: `S (S K)`.
    public static let idiotOnceRemoved: Term = .s(.s(.k))

    /// The jay, `J a b c d → a b (a d c)`: `B (B C) (W (B C E))`.
    public static let jay: Term = .b(.b(.c), .w(.b(.c, eagle)))

    /// The kestrel, `K a b → a` — the primitive ``k``.
    public static let kestrel: Term = .k

    /// The kite, `KI a b → b`: `K I`.
    public static let kite: Term = .k(.i)

    /// The lark, `L a b → a (b b)`: `C B M`.
    public static let lark: Term = .c(.b, .m)

    /// The mockingbird, `M a → a a` — ``m``, that is `S I I`.
    public static let mockingbird: Term = .m

    /// The owl, `O a b → b (a b)`: `S I`.
    public static let owl: Term = .s(.i)

    /// The quacky bird, `Q₄ a b c → c (b a)`: `F* B`.
    public static let quackyBird: Term = finchOnceRemoved(.b)

    /// The queer bird, `Q a b c → b (a c)`: `C B`.
    public static let queerBird: Term = .c(.b)

    /// The quirky bird, `Q₃ a b c → c (a b)`: `B T`.
    public static let quirkyBird: Term = .b(thrush)

    /// The quixotic bird, `Q₁ a b c → a (c b)`: `B C B`.
    public static let quixoticBird: Term = .b(.c, .b)

    /// The quizzical bird, `Q₂ a b c → b (c a)`: `C (B C B)`.
    public static let quizzicalBird: Term = .c(quixoticBird)

    /// The robin, `R a b c → b c a`: `B B T`.
    public static let robin: Term = .b(.b, thrush)

    /// The robin once removed, `R* a b c d → a c d b`: `C* C*`.
    public static let robinOnceRemoved: Term = cardinalOnceRemoved(cardinalOnceRemoved)

    /// The robin twice removed, `R** a b c d e → a b d e c`: `B R*`.
    public static let robinTwiceRemoved: Term = .b(robinOnceRemoved)

    /// The sage bird, `Y a → a (Y a)` — the fixed-point combinator ``y``.
    public static let sage: Term = .y

    /// The starling, `S a b c → a c (b c)` — the primitive ``s``.
    public static let starling: Term = .s

    /// Turing's sage bird, `Θ a → a (Θ a)`: `U U`, as the book constructs it
    /// from the Turing bird.  Like every sage bird it has no normal form.
    public static let theta: Term = turingBird(turingBird)

    /// The thrush, `T a b → b a`: `C I`.
    public static let thrush: Term = .c(.i)

    /// The Turing bird, `U a b → b (a a b)`: `L O`.
    public static let turingBird: Term = lark(owl)

    /// The vireo, `V a b c → c a b`: `B C T`.
    public static let vireo: Term = .b(.c, thrush)

    /// The vireo once removed, `V* a b c d → a d b c`: `C* F*`.
    public static let vireoOnceRemoved: Term = cardinalOnceRemoved(finchOnceRemoved)

    /// The vireo twice removed, `V** a b c d e → a b e c d`: `B V*`.
    public static let vireoTwiceRemoved: Term = .b(vireoOnceRemoved)

    /// The warbler, `W a b → a b b` — the primitive ``w``.
    public static let warbler: Term = .w

    /// The warbler once removed, `W* a b c → a b c c`: `B W`.
    public static let warblerOnceRemoved: Term = .b(.w)

    /// The warbler twice removed, `W** a b c d → a b c d d`: `B W*`.
    public static let warblerTwiceRemoved: Term = .b(warblerOnceRemoved)
}

extension Term {
    /// Every bird of the book by name, in alphabetical order.
    public static let aviary: [(name: String, term: Term)] = [
        ("bald eagle", .baldEagle),
        ("becard", .becard),
        ("blackbird", .blackbird),
        ("bluebird", .bluebird),
        ("bunting", .bunting),
        ("cardinal", .cardinal),
        ("cardinal once removed", .cardinalOnceRemoved),
        ("cardinal twice removed", .cardinalTwiceRemoved),
        ("converse warbler", .converseWarbler),
        ("dickcissel", .dickcissel),
        ("double mockingbird", .doubleMockingbird),
        ("dove", .dove),
        ("dovekie", .dovekie),
        ("eagle", .eagle),
        ("finch", .finch),
        ("finch once removed", .finchOnceRemoved),
        ("finch twice removed", .finchTwiceRemoved),
        ("goldfinch", .goldfinch),
        ("hummingbird", .hummingbird),
        ("idiot", .idiot),
        ("idiot once removed", .idiotOnceRemoved),
        ("jay", .jay),
        ("kestrel", .kestrel),
        ("kite", .kite),
        ("lark", .lark),
        ("mockingbird", .mockingbird),
        ("owl", .owl),
        ("quacky bird", .quackyBird),
        ("queer bird", .queerBird),
        ("quirky bird", .quirkyBird),
        ("quixotic bird", .quixoticBird),
        ("quizzical bird", .quizzicalBird),
        ("robin", .robin),
        ("robin once removed", .robinOnceRemoved),
        ("robin twice removed", .robinTwiceRemoved),
        ("sage", .sage),
        ("starling", .starling),
        ("theta", .theta),
        ("thrush", .thrush),
        ("Turing bird", .turingBird),
        ("vireo", .vireo),
        ("vireo once removed", .vireoOnceRemoved),
        ("vireo twice removed", .vireoTwiceRemoved),
        ("warbler", .warbler),
        ("warbler once removed", .warblerOnceRemoved),
        ("warbler twice removed", .warblerTwiceRemoved),
    ]
}
