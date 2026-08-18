import Testing
@testable import Combinators

private func v(_ name: String) -> Term { .variable(name) }
private let x = v("x"), y = v("y"), z = v("z")

@Suite("Primitive combinators")
struct PrimitiveTests {
    @Test func identity() throws {
        #expect(try Term.i(x).normalize() == x)
    }

    @Test func constant() throws {
        #expect(try Term.k(x, y).normalize() == x)
    }

    @Test func substitution() throws {
        #expect(try Term.s(x, y, z).normalize() == x(z, y(z)))
    }

    @Test func extraArgumentsAreKept() throws {
        #expect(try Term.k(x, y, z).normalize() == x(z))
        #expect(try Term.i(x, y, z).normalize() == x(y, z))
    }

    @Test func underAppliedTermsAreNormal() {
        #expect(Term.s(x, y).isNormalForm)
        #expect(Term.k.isNormalForm)
        #expect(x(y, z).isNormalForm)
    }

    @Test func skkIsIdentity() throws {
        #expect(try Term("SKK")(x).normalize() == x)
        #expect(try Term("SKS")(x).normalize() == x)  // any SKz works
    }
}

@Suite("Reduction")
struct ReductionTests {
    @Test func reductionsSequence() {
        let steps = Array(Term("SKKx").reductions)
        #expect(steps == ["SKKx", "Kx(Kx)", "x"])
    }

    @Test func normalOrderFindsNormalForms() throws {
        // KIΩ diverges under applicative order but normalizes in normal order.
        #expect(try Term.k(.i, .omega).normalize() == .i)
    }

    @Test func omegaHasNoNormalForm() {
        #expect(throws: ReductionError.self) {
            try Term.omega.normalize(maxSteps: 100)
        }
    }

    @Test func equivalence() throws {
        #expect(try Term("SKK").isEquivalent(to: "SKS") == false)  // distinct normal forms
        #expect(try Term("SKKx").isEquivalent(to: "Ix"))
    }

    @Test func size() {
        #expect(Term("SKKx").size == 4)
        #expect(Term.i.size == 1)
    }
}

@Suite("Derived combinators")
struct DerivedTests {
    @Test func composition() throws {
        #expect(try Term.b(x, y, z).normalize() == x(y(z)))
    }

    @Test func exchange() throws {
        #expect(try Term.c(x, y, z).normalize() == x(z, y))
    }

    @Test func duplication() throws {
        #expect(try Term.w(x, y).normalize() == x(y, y))
        #expect(try Term.m(x).normalize() == x(x))
    }

    @Test func fixedPoint() throws {
        // Y f unfolds to f (Y f); one outer f should appear after enough steps.
        let unfolded = try #require(
            Term.y(v("f")).reductions.prefix(20).first { term in
                if case .apply(.variable("f"), _) = term { true } else { false }
            }
        )
        guard case .apply(.variable("f"), let inner) = unfolded else {
            Issue.record("expected f applied to something"); return
        }
        // and the inner term again unfolds to f (…)
        let again = inner.reductions.prefix(20).first { term in
            if case .apply(.variable("f"), _) = term { true } else { false }
        }
        #expect(again != nil)
    }
}

@Suite("BCKW")
struct BCKWTests {
    @Test func primitiveRules() throws {
        #expect(try Term.b(x, y, z).normalize() == x(y(z)))
        #expect(try Term.c(x, y, z).normalize() == x(z, y))
        #expect(try Term.w(x, y).normalize() == x(y, y))
    }

    @Test func extraArgumentsAreKept() throws {
        #expect(try Term.b(x, y, z, v("w")).normalize() == x(y(z), v("w")))
        #expect(try Term.w(x, y, z).normalize() == x(y, y, z))
    }

    @Test func underAppliedTermsAreNormal() {
        #expect(Term.b(x, y).isNormalForm)
        #expect(Term.c(x, y).isNormalForm)
        #expect(Term.w(x).isNormalForm)
    }

    @Test func identityIsWK() throws {
        #expect(try Term("WK")(x).normalize() == x)
    }

    @Test func abstractionStaysInBasis() throws {
        let lambdas: [Term] = [
            .lambda("x", body: x, in: .bckw),                     // I
            .lambda("x", "y", body: y(x), in: .bckw),             // flip apply
            .lambda("f", "x", body: v("f")(x, x), in: .bckw),     // W
            .lambda("x", body: x(x), in: .bckw),                  // M
            .lambda("f", "g", "x", body: v("f")(x, v("g")(x)), in: .bckw),  // S
        ]
        for term in lambdas {
            #expect(term.isExpressed(in: .bckw), "\(term) is not pure BCKW")
        }
        // …and they still behave like the lambdas they came from.
        #expect(try lambdas[0](x).normalize() == x)
        #expect(try lambdas[1](x, y).normalize() == y(x))
        #expect(try lambdas[2](x, y).normalize() == x(y, y))
        #expect(try lambdas[3](x).normalize() == x(x))
        #expect(try lambdas[4](x, y, z).normalize() == x(z, y(z)))
    }

    @Test func rewritingIntoSKI() throws {
        for term in [Term.b, .c, .w] {
            let rewritten = term.rewritten(in: .ski)
            #expect(rewritten.isExpressed(in: .ski))
            #expect(try rewritten(x, y, z).normalize() == term(x, y, z).normalize())
        }
    }

    @Test func rewritingIntoBCKW() throws {
        let s = Term.s.rewritten(in: .bckw)
        #expect(s.isExpressed(in: .bckw))
        #expect(try s(x, y, z).normalize() == x(z, y(z)))

        let i = Term.i.rewritten(in: .bckw)
        #expect(i.isExpressed(in: .bckw))
        #expect(try i(x).normalize() == x)
    }

    @Test func rewritingRecursesIntoApplications() throws {
        let term: Term = "B(SW)x"
        let rewritten = term.rewritten(in: .ski)
        #expect(rewritten.isExpressed(in: .ski))
        #expect(try rewritten(y, z).normalize() == term(y, z).normalize())
    }

    @Test func thrushIsCI() throws {
        // T x y → y x; the thrush is C applied to I.
        let thrush: Term = "S(K(SI))K"
        #expect(try Term.c(.i)(x, y).normalize() == y(x))
        #expect(try Term.c(.i)(x, y).normalize() == thrush(x, y).normalize())
    }

    @Test func parsing() throws {
        #expect(try Term(parsing: "BCKW") == .b(.c, .k, .w))
        #expect(try Term(parsing: #"\xy.yx"#, basis: .bckw).isExpressed(in: .bckw))
        #expect(try Term(parsing: #"\fx.f(fx)"#, basis: .bckw).naturalValue() == 2)
    }

    @Test func printingRoundTrips() throws {
        for source in ["B", "BCKW", "B(CK)W", "W(B(CB)I)"] {
            let term = try Term(parsing: source)
            #expect(term.description == source)
            #expect(try Term(parsing: term.description) == term)
        }
    }
}

@Suite("Basis closure")
struct BasisClosureTests {
    let primitives: [Term] = [.s, .k, .i, .b, .c, .w, .iota, .x]

    @Test func everyEncodingStaysInItsBasis() {
        for basis in Basis.allCases {
            for primitive in primitives {
                #expect(primitive.rewritten(in: basis).isExpressed(in: basis),
                        "\(primitive) rewritten into \(basis) escapes the basis")
            }
        }
    }

    @Test func everyEncodingIsExtensionallyFaithful() throws {
        // Probing with I first flushes out any encoded S or K hiding in the
        // reduct, so both sides meet in an all-variable normal form.
        let probe: [Term] = [.i, x, y, z, v("u")]
        for basis in Basis.allCases {
            for primitive in primitives {
                let expected = try Term.applying(primitive, to: probe)
                    .normalize(maxSteps: 1_000_000)
                let actual = try Term.applying(primitive.rewritten(in: basis), to: probe)
                    .normalize(maxSteps: 1_000_000)
                #expect(actual == expected, "\(primitive) in \(basis) misbehaves")
            }
        }
    }
}

@Suite("X combinator")
struct XCombinatorTests {
    @Test func rule() throws {
        #expect(try Term.x(x).normalize() == x(.k, .s, .k))
    }

    @Test func bootstrapsTheWholeCalculus() throws {
        // The whole point of X: S and K fall out of self-application — exactly,
        // not merely extensionally.
        #expect(try Term("XXX").normalize() == .k)
        #expect(try Term("X(XX)").normalize() == .s)
        #expect(try Term("X(XX)(XXX)(XXX)")(x).normalize() == x)   // SKK = I
    }

    @Test func rewritingIntoX() throws {
        let table: [(Term, [Term], Term)] = [
            (.s, [x, y, z], x(z, y(z))),
            (.k, [x, y], x),
            (.i, [x], x),
            (.b, [x, y, z], x(y(z))),
            (.c, [x, y, z], x(z, y)),
            (.w, [x, y], x(y, y)),
            (.iota, [x], x(.s, .k)),
        ]
        for (combinator, arguments, expected) in table {
            let rewritten = combinator.rewritten(in: .x)
            #expect(rewritten.isExpressed(in: .x))
            #expect(try Term.applying(rewritten, to: arguments).normalize(maxSteps: 100_000) == expected)
        }
        #expect(Term.k.rewritten(in: .x) == "XXX")
        #expect(Term.s.rewritten(in: .x) == "X(XX)")
    }

    @Test func abstractionStaysInBasis() throws {
        let lambda = Term.lambda("x", "y", body: y(x), in: .x)
        #expect(lambda.isExpressed(in: .x))
        #expect(try lambda(x, y).normalize(maxSteps: 100_000) == y(x))
    }

    @Test func parsingAndPrinting() throws {
        #expect(try Term(parsing: "X(XX)") == .x(.x(.x)))
        #expect(Term.x(.x(.x)).description == "X(XX)")
    }
}

@Suite("Birds")
struct BirdTests {
    let a = v("a"), b = v("b"), c = v("c"), d = v("d")
    let e = v("e"), f = v("f"), g = v("g")

    /// Every bird except the two sage birds, with the law from the book.
    var laws: [(name: String, bird: Term, arguments: [Term], result: Term)] {
        [
            ("bald eagle", .baldEagle, [a, b, c, d, e, f, g], a(b(c, d), e(f, g))),
            ("becard", .becard, [a, b, c, d], a(b(c(d)))),
            ("blackbird", .blackbird, [a, b, c, d], a(b(c, d))),
            ("bluebird", .bluebird, [a, b, c], a(b(c))),
            ("bunting", .bunting, [a, b, c, d, e], a(b(c, d, e))),
            ("cardinal", .cardinal, [a, b, c], a(c, b)),
            ("cardinal once removed", .cardinalOnceRemoved, [a, b, c, d], a(b, d, c)),
            ("cardinal twice removed", .cardinalTwiceRemoved, [a, b, c, d, e], a(b, c, e, d)),
            ("converse warbler", .converseWarbler, [a, b], b(a, a)),
            ("dickcissel", .dickcissel, [a, b, c, d, e], a(b, c, d(e))),
            ("double mockingbird", .doubleMockingbird, [a, b], a(b, a(b))),
            ("dove", .dove, [a, b, c, d], a(b, c(d))),
            ("dovekie", .dovekie, [a, b, c, d, e], a(b(c), d(e))),
            ("eagle", .eagle, [a, b, c, d, e], a(b, c(d, e))),
            ("finch", .finch, [a, b, c], c(b, a)),
            ("finch once removed", .finchOnceRemoved, [a, b, c, d], a(d, c, b)),
            ("finch twice removed", .finchTwiceRemoved, [a, b, c, d, e], a(b, e, d, c)),
            ("goldfinch", .goldfinch, [a, b, c, d], a(d, b(c))),
            ("hummingbird", .hummingbird, [a, b, c], a(b, c, b)),
            ("idiot", .idiot, [a], a),
            ("idiot once removed", .idiotOnceRemoved, [a, b], a(b)),
            ("jay", .jay, [a, b, c, d], a(b, a(d, c))),
            ("kestrel", .kestrel, [a, b], a),
            ("kite", .kite, [a, b], b),
            ("lark", .lark, [a, b], a(b(b))),
            ("mockingbird", .mockingbird, [a], a(a)),
            ("owl", .owl, [a, b], b(a(b))),
            ("quacky bird", .quackyBird, [a, b, c], c(b(a))),
            ("queer bird", .queerBird, [a, b, c], b(a(c))),
            ("quirky bird", .quirkyBird, [a, b, c], c(a(b))),
            ("quixotic bird", .quixoticBird, [a, b, c], a(c(b))),
            ("quizzical bird", .quizzicalBird, [a, b, c], b(c(a))),
            ("robin", .robin, [a, b, c], b(c, a)),
            ("robin once removed", .robinOnceRemoved, [a, b, c, d], a(c, d, b)),
            ("robin twice removed", .robinTwiceRemoved, [a, b, c, d, e], a(b, d, e, c)),
            ("starling", .starling, [a, b, c], a(c, b(c))),
            ("thrush", .thrush, [a, b], b(a)),
            ("Turing bird", .turingBird, [a, b], b(a(a, b))),
            ("vireo", .vireo, [a, b, c], c(a, b)),
            ("vireo once removed", .vireoOnceRemoved, [a, b, c, d], a(d, b, c)),
            ("vireo twice removed", .vireoTwiceRemoved, [a, b, c, d, e], a(b, e, c, d)),
            ("warbler", .warbler, [a, b], a(b, b)),
            ("warbler once removed", .warblerOnceRemoved, [a, b, c], a(b, c, c)),
            ("warbler twice removed", .warblerTwiceRemoved, [a, b, c, d], a(b, c, d, d)),
        ]
    }

    @Test func everyBirdObeysItsLaw() throws {
        for (name, bird, arguments, result) in laws {
            #expect(try Term.applying(bird, to: arguments).normalize(maxSteps: 10_000) == result,
                    "the \(name) disobeyed its law")
        }
    }

    @Test func lawsAreStableUnderExtraArguments() throws {
        // A bird's law holds with a trailing argument tacked on, too.
        for (name, bird, arguments, result) in laws {
            #expect(try Term.applying(bird, to: arguments + [g]).normalize(maxSteps: 10_000) == result(g),
                    "the \(name) disobeyed its law with an extra argument")
        }
    }

    @Test func sageBirdsUnfoldFixedPoints() throws {
        for (name, sage) in [("sage", Term.sage), ("theta", Term.theta)] {
            func unfoldsToF(_ term: Term) -> Term? {
                term.reductions.prefix(50).first {
                    if case .apply(.variable("f"), _) = $0 { true } else { false }
                }
            }
            let unfolded = try #require(unfoldsToF(sage(f)), "\(name) never unfolded to f(…)")
            guard case .apply(.variable("f"), let inner) = unfolded else { continue }
            #expect(unfoldsToF(inner) != nil, "\(name) stopped unfolding after one f(…)")
        }
    }

    @Test func aviaryIsWellFormed() {
        let names = Term.aviary.map(\.name)
        #expect(Set(names).count == names.count, "duplicate bird names")
        #expect(laws.count == Term.aviary.count - 2)  // every bird but the two sages has a law
        for (name, bird) in Term.aviary {
            #expect(bird.freeVariables.isEmpty, "the \(name) is not a closed term")
        }
    }

    @Test func bookConstructions() throws {
        // A few identities the book celebrates.
        #expect(Term.theta == Term.turingBird(.turingBird))         // Θ = UU
        #expect(try Term.lark(f).isEquivalent(to: .b(f, .m)))       // L f = B f M
        #expect(try Term.mockingbird(a).isEquivalent(to: .w(.i, a)))  // M ≡ WI, extensionally
        #expect(try Term.robin(.robin, .robin, a, b, c).normalize() == a(c, b))  // RRR ≡ C
    }
}

@Suite("Iota and Jot")
struct IotaJotTests {
    @Test func iotaRule() throws {
        #expect(try Term.iota(x).normalize() == x(.s, .k))
    }

    @Test func skiFromIota() throws {
        #expect(try Term(iota: "*ii")(x).normalize() == x)                        // I = ιι
        #expect(try Term(iota: "*i*i*ii")(x, y).normalize() == x)                 // K = ι(ι(ιι))
        #expect(try Term(iota: "*i*i*i*ii")(x, y, z).normalize() == x(z, y(z)))   // S = ι(ι(ι(ιι)))
    }

    @Test func rewritingIntoIota() throws {
        let table: [(Term, [Term], Term)] = [
            (.s, [x, y, z], x(z, y(z))),
            (.k, [x, y], x),
            (.i, [x], x),
            (.b, [x, y, z], x(y(z))),
            (.c, [x, y, z], x(z, y)),
            (.w, [x, y], x(y, y)),
        ]
        for (combinator, arguments, expected) in table {
            let rewritten = combinator.rewritten(in: .iota)
            #expect(rewritten.isExpressed(in: .iota))
            #expect(try Term.applying(rewritten, to: arguments).normalize(maxSteps: 100_000) == expected)
        }
    }

    @Test func abstractionStaysInBasis() throws {
        let lambda = Term.lambda("x", "y", body: y(x), in: .iota)
        #expect(lambda.isExpressed(in: .iota))
        #expect(try lambda(x, y).normalize(maxSteps: 100_000) == y(x))
    }

    @Test func iotaSyntax() throws {
        #expect(try Term(iota: "*ii") == .iota(.iota))
        #expect(try Term(iota: " * i \u{03B9} ") == .iota(.iota))  // ι works too
        #expect(throws: ParseError.self) { try Term(iota: "") }
        #expect(throws: ParseError.self) { try Term(iota: "*i") }   // missing an operand
        #expect(throws: ParseError.self) { try Term(iota: "ii") }   // trailing junk
        #expect(throws: ParseError.self) { try Term(iota: "*ix") }  // no variables
    }

    @Test func iotaEncodingRoundTrips() throws {
        for term in [Term.s, .k, .i, "S(K(SI))K", .b(.s, .w)] {
            let encoding = try #require(term.iotaEncoding)
            let decoded = try Term(iota: encoding)
            #expect(try decoded(x, y, z).normalize(maxSteps: 100_000)
                 == term(x, y, z).normalize(maxSteps: 100_000))
        }
        #expect(Term.k.iotaEncoding == "*i*i*ii")
        #expect(x.iotaEncoding == nil)
    }

    @Test func jotDecoding() throws {
        #expect(try Term(jot: "") == .i)
        #expect(try Term(jot: "11100")(x, y).normalize(maxSteps: 100_000) == x)   // K
        #expect(try Term(jot: "11111000")(x, y, z).normalize(maxSteps: 100_000) == x(z, y(z)))  // S
        #expect(try Term(jot: "0")(x, y).normalize() == y)   // [0] = ISK = SK, i.e. false
        #expect(throws: ParseError.self) { try Term(jot: "10201") }
    }

    @Test func jotEncodingRoundTrips() throws {
        #expect(Term.s.jotEncoding == "11111000")
        #expect(Term.k.jotEncoding == "11100")
        for term in [Term.s, .k, .i, .b, .c, .w, .iota, .x, "S(K(SI))K"] {
            let encoding = try #require(term.jotEncoding)
            #expect(encoding.allSatisfy { $0 == "0" || $0 == "1" })
            let decoded = try Term(jot: encoding)
            #expect(try decoded(x, y, z).normalize(maxSteps: 100_000)
                 == term(x, y, z).normalize(maxSteps: 100_000))
        }
        #expect(x.jotEncoding == nil)
    }
}

@Suite("Booleans")
struct BooleanTests {
    @Test func truthTables() throws {
        let t = Term.churchTrue, f = Term.churchFalse
        #expect(t.booleanValue() == true)
        #expect(f.booleanValue() == false)
        #expect(Term.not(t).booleanValue() == false)
        #expect(Term.not(f).booleanValue() == true)
        for (p, q) in [(t, t), (t, f), (f, t), (f, f)] {
            #expect(Term.and(p, q).booleanValue() == ((p == t) && (q == t)))
            #expect(Term.or(p, q).booleanValue() == ((p == t) || (q == t)))
        }
    }

    @Test func selection() throws {
        #expect(try Term.ifThenElse(.churchTrue, x, y).normalize() == x)
        #expect(try Term.ifThenElse(.churchFalse, x, y).normalize() == y)
    }

    @Test func nonBooleansReadAsNil() {
        #expect(Term.s.booleanValue() == nil)
        #expect(Term.omega.booleanValue() == nil)
    }
}

@Suite("Numerals")
struct NumeralTests {
    @Test func roundTrip() {
        for n in 0 ... 5 {
            #expect(Term.church(n).naturalValue() == n)
        }
    }

    @Test func successor() {
        #expect(Term.successor(.church(4)).naturalValue() == 5)
    }

    @Test func arithmetic() {
        #expect(Term.add(.church(2), .church(3)).naturalValue() == 5)
        #expect(Term.multiply(.church(2), .church(3)).naturalValue() == 6)
        #expect(Term.power(.church(2), .church(3)).naturalValue() == 8)
    }

    @Test func zeroTest() {
        #expect(Term.isZero(.church(0)).booleanValue() == true)
        #expect(Term.isZero(.church(3)).booleanValue() == false)
    }

    @Test func nonNumeralsReadAsNil() {
        #expect(Term.k.naturalValue() == nil)
    }
}

@Suite("Pairs")
struct PairTests {
    @Test func projections() throws {
        let p = Term.pair(x, y)
        #expect(try Term.first(p).normalize() == x)
        #expect(try Term.second(p).normalize() == y)
    }
}

@Suite("Abstraction")
struct AbstractionTests {
    @Test func basics() {
        #expect(Term.abstract("x", from: x) == .i)
        #expect(Term.abstract("x", from: y) == .k(y))
        #expect(Term.abstract("x", from: y(x)) == y)  // η
    }

    @Test func abstractionsBehaveLikeLambdas() throws {
        let flip = Term.lambda("f", "x", "y", body: v("f")(y, x))
        #expect(try flip(v("f"), x, y).normalize() == v("f")(y, x))

        let twice = Term.lambda("f", "x", body: v("f")(v("f")(x)))
        #expect(try twice(v("f"), x).normalize() == v("f")(v("f")(x)))
    }

    @Test func kAndIAreDerivable() throws {
        #expect(Term.lambda("x", "y", body: x) == .k)
        #expect(try Term.lambda("x", body: x).isEquivalent(to: .i))
    }

    @Test func substitution() {
        #expect(x(y).substituting("x", with: .s) == Term.s(y))
        #expect(x(y).substituting(["x": .s, "y": .k]) == Term.s(.k))
    }

    @Test func freeVariables() {
        #expect(Term("SKxy(Kz)").freeVariables == ["x", "y", "z"])
        #expect(Term.s.freeVariables.isEmpty)
    }
}

@Suite("Parsing and printing")
struct ParserTests {
    @Test func leftAssociativity() throws {
        #expect(try Term(parsing: "SKKx") == .s(.k, .k, x))
        #expect(try Term(parsing: "S(K(SI))K") == .s(.k(.s(.i)), .k))
    }

    @Test func whitespaceIsInsignificant() throws {
        #expect(try Term(parsing: " S K K x ") == "SKKx")
    }

    @Test func lambdas() throws {
        #expect(try Term(parsing: #"\x.x"#) == .i)
        #expect(try Term(parsing: "λxy.x") == .k)
        #expect(try Term(parsing: #"\x -> x"#) == .i)
        #expect(try Term(parsing: #"\fx.f(fx)"#).naturalValue() == 2)
    }

    @Test func errors() {
        #expect(throws: ParseError.self) { try Term(parsing: "") }
        #expect(throws: ParseError.self) { try Term(parsing: "(SK") }
        #expect(throws: ParseError.self) { try Term(parsing: "SK)") }
        #expect(throws: ParseError.self) { try Term(parsing: "S?K") }
        #expect(throws: ParseError.self) { try Term(parsing: #"\.x"#) }
        #expect(throws: ParseError.self) { try Term(parsing: #"\x"#) }
    }

    @Test func printingRoundTrips() throws {
        for source in ["S", "SKKx", "S(K(SI))K", "K(K(KK))", "S(SS)(SS)S"] {
            let term = try Term(parsing: source)
            #expect(term.description == source)
            #expect(try Term(parsing: term.description) == term)
        }
    }

    @Test func spine() {
        let (head, arguments) = Term("SKKx").spine
        #expect(head == .s)
        #expect(arguments == [.k, .k, x])
    }
}
