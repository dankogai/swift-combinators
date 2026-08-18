/// An error raised while reducing a term.
public enum ReductionError: Error, Hashable, Sendable, CustomStringConvertible {
    /// The term did not reach a normal form within the allotted number of steps.
    ///
    /// Not every term has a normal form — `SII(SII)` reduces to itself forever —
    /// so reduction is always bounded.
    case stepLimitExceeded(term: Term, limit: Int)

    public var description: String {
        switch self {
        case .stepLimitExceeded(let term, let limit):
            "no normal form after \(limit) steps; reached \(term)"
        }
    }
}

extension Term {
    /// Contracts the redex at the root of this term, if there is one.
    ///
    /// The rules of the calculus are
    /// `I x → x`, `K x y → x`, `S x y z → x z (y z)`,
    /// `B x y z → x (y z)`, `C x y z → x z y` and `W x y → x y y`.
    /// Arguments beyond those consumed by the rule are re-applied to the result,
    /// so `Kxyz` contracts to `xz`.
    public func reducedAtRoot() -> Term? {
        let (head, arguments) = spine
        switch head {
        case .i where arguments.count >= 1:
            return Term.applying(arguments[0], to: arguments.dropFirst())
        case .k where arguments.count >= 2:
            return Term.applying(arguments[0], to: arguments.dropFirst(2))
        case .s where arguments.count >= 3:
            let (x, y, z) = (arguments[0], arguments[1], arguments[2])
            return Term.applying(.apply(.apply(x, z), .apply(y, z)), to: arguments.dropFirst(3))
        case .b where arguments.count >= 3:
            let (x, y, z) = (arguments[0], arguments[1], arguments[2])
            return Term.applying(.apply(x, .apply(y, z)), to: arguments.dropFirst(3))
        case .c where arguments.count >= 3:
            let (x, y, z) = (arguments[0], arguments[1], arguments[2])
            return Term.applying(.apply(.apply(x, z), y), to: arguments.dropFirst(3))
        case .w where arguments.count >= 2:
            let (x, y) = (arguments[0], arguments[1])
            return Term.applying(.apply(.apply(x, y), y), to: arguments.dropFirst(2))
        default:
            return nil
        }
    }

    /// Performs a single reduction step in normal order, or returns `nil` if the
    /// term is already in normal form.
    ///
    /// Normal order contracts the leftmost outermost redex first, which finds a
    /// normal form whenever one exists.
    public func reduced() -> Term? {
        if let contracted = reducedAtRoot() { return contracted }
        guard case .apply(let function, let argument) = self else { return nil }
        if let function = function.reduced() { return .apply(function, argument) }
        if let argument = argument.reduced() { return .apply(function, argument) }
        return nil
    }

    /// Whether the term contains no redex at all.
    public var isNormalForm: Bool { reduced() == nil }

    /// The lazy sequence of terms starting with this one, each the normal-order
    /// reduct of the previous, ending at the normal form if there is one.
    ///
    /// ```swift
    /// for step in Term.s(.k, .k, .variable("x")).reductions { print(step) }
    /// // SKKx
    /// // Kx(Kx)
    /// // x
    /// ```
    public var reductions: UnfoldFirstSequence<Term> {
        sequence(first: self) { $0.reduced() }
    }

    /// Reduces the term to normal form.
    ///
    /// - Parameter maxSteps: How many reduction steps to take before giving up.
    /// - Throws: ``ReductionError/stepLimitExceeded(term:limit:)`` if no normal
    ///   form is reached within `maxSteps`.
    @discardableResult
    public func normalize(maxSteps: Int = 1_000) throws -> Term {
        var term = self
        for _ in 0 ..< maxSteps {
            guard let next = term.reduced() else { return term }
            term = next
        }
        guard let stalled = term.reduced() else { return term }
        throw ReductionError.stepLimitExceeded(term: stalled, limit: maxSteps)
    }

    /// Whether two terms reduce to the same normal form.
    public func isEquivalent(to other: Term, maxSteps: Int = 1_000) throws -> Bool {
        try normalize(maxSteps: maxSteps) == other.normalize(maxSteps: maxSteps)
    }
}
