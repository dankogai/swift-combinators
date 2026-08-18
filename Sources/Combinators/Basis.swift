/// A functionally complete set of primitive combinators.
public enum Basis: Hashable, Sendable, CaseIterable {
    /// Schönfinkel's basis: `S`, `K` and `I`.
    case ski
    /// Curry's basis: `B`, `C`, `K` and `W`.
    case bckw
    /// Barker's basis: the single combinator `ι`, where `ι x → x S K`.
    case iota
    /// The one-point basis of the single combinator `X`, where `X a → a K S K`;
    /// `K = XXX` and `S = X(XX)`.
    case x

    /// The primitive combinators of the basis.
    public var primitives: [Term] {
        switch self {
        case .ski: [.s, .k, .i]
        case .bckw: [.b, .c, .k, .w]
        case .iota: [.iota]
        case .x: [.x]
        }
    }

    /// How each primitive missing from this basis is encoded within it.
    var encodings: [Term: Term] {
        switch self {
        case .ski: Self.skiEncodings
        case .bckw: Self.bckwEncodings
        case .iota: Self.iotaEncodings
        case .x: Self.xEncodings
        }
    }

    private static let skiEncodings: [Term: Term] = [
        .b: "S(KS)K",
        .c: "S(S(K(S(KS)K))S)(KK)",
        .w: "SS(KI)",
        .iota: "S(SI(KS))(KK)",
        .x: "S(S(SI(KK))(KS))(KK)",
    ]

    private static let bckwEncodings: [Term: Term] = [
        .s: "B(BW)(BBC)",
        .i: "WK",
        // ι and X pass a literal S to their argument, and in this basis that
        // S must itself be spelled B(BW)(BBC).
        .iota: "C(C(WK)(B(BW)(BBC)))K",
        .x: "C(C(C(WK)K)(B(BW)(BBC)))K",
    ]

    private static let iotaEncodings: [Term: Term] = {
        let identity: Term = .iota(.iota)              // ιι
        let constant: Term = .iota(.iota(identity))    // ι(ι(ιι))
        let substitution: Term = .iota(constant)       // ι(ι(ι(ιι)))
        // The SKI encodings of B, C, W and X contain only S, K and I, so
        // mapping those leaves suffices to bring them into the iota basis too.
        func inIota(_ term: Term) -> Term {
            switch term {
            case .apply(let function, let argument):
                .apply(inIota(function), inIota(argument))
            case .s: substitution
            case .k: constant
            case .i: identity
            default: term
            }
        }
        var encodings: [Term: Term] = [.s: substitution, .k: constant, .i: identity]
        for combinator in [Term.b, .c, .w, .x] {
            encodings[combinator] = inIota(skiEncodings[combinator]!)
        }
        return encodings
    }()

    private static let xEncodings: [Term: Term] = {
        let constant: Term = .x(.x, .x)                         // K = XXX
        let substitution: Term = .x(.x(.x))                     // S = X(XX)
        let identity: Term = substitution(constant, constant)   // I = SKK
        // As above: mapping the S, K and I leaves of the SKI encodings brings
        // every other primitive into the X basis.
        func inX(_ term: Term) -> Term {
            switch term {
            case .apply(let function, let argument):
                .apply(inX(function), inX(argument))
            case .s: substitution
            case .k: constant
            case .i: identity
            default: term
            }
        }
        var encodings: [Term: Term] = [.s: substitution, .k: constant, .i: identity]
        for combinator in [Term.b, .c, .w, .iota] {
            encodings[combinator] = inX(skiEncodings[combinator]!)
        }
        return encodings
    }()
}

extension Term {
    /// Rewrites the term to use only the primitives of `basis`, replacing each
    /// foreign combinator with an equivalent term of the basis.
    ///
    /// ```swift
    /// Term.b.rewritten(in: .ski)   // S(KS)K
    /// Term.i.rewritten(in: .bckw)  // WK
    /// ```
    public func rewritten(in basis: Basis) -> Term {
        switch self {
        case .apply(let function, let argument):
            .apply(function.rewritten(in: basis), argument.rewritten(in: basis))
        default:
            basis.encodings[self] ?? self
        }
    }

    /// Whether the term is built only from variables and the primitives of
    /// `basis`.
    public func isExpressed(in basis: Basis) -> Bool {
        switch self {
        case .apply(let function, let argument):
            function.isExpressed(in: basis) && argument.isExpressed(in: basis)
        case .variable:
            true
        default:
            basis.primitives.contains(self)
        }
    }
}
