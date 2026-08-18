/// A functionally complete set of primitive combinators.
public enum Basis: Hashable, Sendable, CaseIterable {
    /// Schönfinkel's basis: `S`, `K` and `I`.
    case ski
    /// Curry's basis: `B`, `C`, `K` and `W`.
    case bckw

    /// The primitive combinators of the basis.
    public var primitives: [Term] {
        switch self {
        case .ski: [.s, .k, .i]
        case .bckw: [.b, .c, .k, .w]
        }
    }

    /// How each primitive missing from this basis is encoded within it.
    var encodings: [Term: Term] {
        switch self {
        case .ski: Self.skiEncodings
        case .bckw: Self.bckwEncodings
        }
    }

    private static let skiEncodings: [Term: Term] = [
        .b: "S(KS)K",
        .c: "S(S(K(S(KS)K))S)(KK)",
        .w: "SS(KI)",
    ]

    private static let bckwEncodings: [Term: Term] = [
        .s: "B(BW)(BBC)",
        .i: "WK",
    ]
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
