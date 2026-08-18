extension Term {
    /// The variables occurring free in the term.
    public var freeVariables: Set<String> {
        switch self {
        case .variable(let name): [name]
        case .apply(let function, let argument):
            function.freeVariables.union(argument.freeVariables)
        default: []
        }
    }

    /// Replaces every free occurrence of `variable` with `replacement`.
    public func substituting(_ variable: String, with replacement: Term) -> Term {
        substituting([variable: replacement])
    }

    /// Replaces every free variable that appears in `replacements`.
    public func substituting(_ replacements: [String: Term]) -> Term {
        switch self {
        case .variable(let name): replacements[name] ?? self
        case .apply(let function, let argument):
            .apply(function.substituting(replacements), argument.substituting(replacements))
        default: self
        }
    }

    /// Bracket abstraction: builds a term that behaves like `λvariable.body`
    /// using only the primitives of `basis`.
    ///
    /// For ``Basis/ski`` the translation is the classic one, with the η rule
    /// as an optimisation:
    ///
    /// - `[x] x = I`
    /// - `[x] E = K E` when `x` is not free in `E`
    /// - `[x] (E x) = E` when `x` is not free in `E`
    /// - `[x] (E₁ E₂) = S ([x] E₁) ([x] E₂)`
    ///
    /// For ``Basis/bckw`` it is Curry's, which dispatches on where the
    /// variable occurs:
    ///
    /// - `[x] x = WK`
    /// - `[x] E = K E` when `x` is not free in `E`
    /// - `[x] (E x) = E` when `x` is not free in `E`
    /// - `[x] (E₁ E₂) = B E₁ ([x] E₂)` when `x` is free only in `E₂`
    /// - `[x] (E₁ E₂) = C ([x] E₁) E₂` when `x` is free only in `E₁`
    /// - `[x] (E₁ x) = W ([x] E₁)` when `x` is free in `E₁`
    /// - `[x] (E₁ E₂) = W (B (C ([x] E₁)) ([x] E₂))` when `x` is free in both
    ///
    /// For the one-point bases ``Basis/iota`` and ``Basis/x`` the SKI
    /// translation is performed first and the result is rewritten.
    public static func abstract(_ variable: String, from body: Term, in basis: Basis = .ski) -> Term {
        if basis == .iota || basis == .x {
            return abstract(variable, from: body, in: .ski).rewritten(in: basis)
        }
        if body == .variable(variable) {
            return basis == .ski ? .i : Term.w(.k)
        }
        guard body.freeVariables.contains(variable) else { return .apply(.k, body) }
        guard case .apply(let function, let argument) = body else { return .apply(.k, body) }
        let isArgumentTheVariable = argument == .variable(variable)
        guard function.freeVariables.contains(variable) else {
            if isArgumentTheVariable { return function }  // η: [x] (E x) = E
            let abstracted = abstract(variable, from: argument, in: basis)
            return basis == .ski ? Term.s(.apply(.k, function), abstracted)
                                 : Term.b(function, abstracted)
        }
        let abstractedFunction = abstract(variable, from: function, in: basis)
        switch basis {
        case .ski, .iota, .x:  // the one-point bases were already delegated to .ski above
            return Term.s(abstractedFunction, abstract(variable, from: argument, in: basis))
        case .bckw:
            if isArgumentTheVariable { return Term.w(abstractedFunction) }
            guard argument.freeVariables.contains(variable) else {
                return Term.c(abstractedFunction, argument)
            }
            return Term.w(Term.b(Term.c(abstractedFunction),
                                 abstract(variable, from: argument, in: basis)))
        }
    }

    /// Bracket abstraction over several variables at once, outermost first.
    ///
    /// ```swift
    /// Term.lambda("x", "y", body: .variable("x"))   // K
    /// ```
    public static func lambda(_ variables: String..., body: Term, in basis: Basis = .ski) -> Term {
        variables.reversed().reduce(body) { abstract($1, from: $0, in: basis) }
    }
}
