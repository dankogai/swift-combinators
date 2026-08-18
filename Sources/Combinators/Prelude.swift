private func v(_ name: String) -> Term { .variable(name) }

// MARK: - Derived combinators

extension Term {
    /// `B f g x → f (g x)` — composition, `S(KS)K`.
    public static let b: Term = "S(KS)K"

    /// `C f x y → f y x` — argument exchange, `S(S(K(S(KS)K))S)(KK)`.
    public static let c: Term = "S(S(K(S(KS)K))S)(KK)"

    /// `W f x → f x x` — duplication, `SS(KI)`.
    public static let w: Term = "SS(KI)"

    /// `M x → x x` — self-application, `SII`.  Has no normal form when applied
    /// to itself.
    public static let m: Term = "SII"

    /// `Ω = M M` — the smallest term with no normal form.
    public static let omega: Term = "SII(SII)"

    /// The fixed-point combinator, `Y f → f (Y f)`.
    ///
    /// Under normal-order reduction `Y f` never reaches a normal form; it keeps
    /// unfolding into `f (f (… (Y f)))`.
    public static let y: Term = "S(K(SII))(S(S(KS)K)(K(SII)))"
}

// MARK: - Church booleans

extension Term {
    /// `true x y → x`, which is just `K`.
    public static let churchTrue: Term = .k

    /// `false x y → y`, which is `SK` (or equivalently `KI`).
    public static let churchFalse: Term = "SK"

    /// `not p → ¬p`.
    public static let not: Term = lambda("p", body: v("p")(churchFalse, churchTrue))

    /// `and p q → p ∧ q`.
    public static let and: Term = lambda("p", "q", body: v("p")(v("q"), churchFalse))

    /// `or p q → p ∨ q`.
    public static let or: Term = lambda("p", "q", body: v("p")(churchTrue, v("q")))

    /// `if p then a else b`, which is just `I`: a Church boolean already selects
    /// between its two arguments.
    public static let ifThenElse: Term = .i

    /// Reads a Church boolean back out of a term, or `nil` if it is not one.
    public func booleanValue(maxSteps: Int = 1_000) -> Bool? {
        guard let normal = try? self(v("a"), v("b")).normalize(maxSteps: maxSteps) else {
            return nil
        }
        switch normal {
        case .variable("a"): return true
        case .variable("b"): return false
        default: return nil
        }
    }
}

// MARK: - Church numerals

extension Term {
    /// The Church numeral `n`, that is `λf.λx. f (f (… (f x)))` with `n`
    /// applications of `f`.
    public static func church(_ n: Int) -> Term {
        precondition(n >= 0, "a Church numeral cannot be negative")
        var body = v("x")
        for _ in 0 ..< n { body = .apply(v("f"), body) }
        return lambda("f", "x", body: body)
    }

    /// `successor n → n + 1`.
    public static let successor: Term =
        lambda("n", "f", "x", body: v("f")(v("n")(v("f"), v("x"))))

    /// `add m n → m + n`.
    public static let add: Term =
        lambda("m", "n", "f", "x", body: v("m")(v("f"), v("n")(v("f"), v("x"))))

    /// `multiply m n → m × n`, which is just composition, `B`.
    public static let multiply: Term = lambda("m", "n", "f", body: v("m")(v("n")(v("f"))))

    /// `power m n → mⁿ`.
    public static let power: Term = lambda("m", "n", body: v("n")(v("m")))

    /// `isZero n → true` exactly when `n` is `0`.
    public static let isZero: Term =
        lambda("n", body: v("n")(.apply(.k, churchFalse), churchTrue))

    /// Reads a Church numeral back out of a term, or `nil` if it is not one.
    public func naturalValue(maxSteps: Int = 1_000) -> Int? {
        guard var normal = try? self(v("f"), v("x")).normalize(maxSteps: maxSteps) else {
            return nil
        }
        var count = 0
        while case .apply(.variable("f"), let rest) = normal {
            count += 1
            normal = rest
        }
        return normal == v("x") ? count : nil
    }
}

// MARK: - Church pairs

extension Term {
    /// `pair a b` holds `a` and `b`; apply it to a selector to get one back.
    public static let pair: Term = lambda("a", "b", "s", body: v("s")(v("a"), v("b")))

    /// `first (pair a b) → a`.
    public static let first: Term = lambda("p", body: v("p")(churchTrue))

    /// `second (pair a b) → b`.
    public static let second: Term = lambda("p", body: v("p")(churchFalse))
}
