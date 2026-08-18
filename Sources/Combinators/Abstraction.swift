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

    /// Bracket abstraction: builds a term that behaves like `λvariable.body`,
    /// using nothing but `S`, `K` and `I`.
    ///
    /// The translation is the classic one, with the η rule as an optimisation:
    ///
    /// - `[x] x = I`
    /// - `[x] E = K E` when `x` is not free in `E`
    /// - `[x] (E x) = E` when `x` is not free in `E`
    /// - `[x] (E₁ E₂) = S ([x] E₁) ([x] E₂)`
    public static func abstract(_ variable: String, from body: Term) -> Term {
        if body == .variable(variable) { return .i }
        guard body.freeVariables.contains(variable) else { return .apply(.k, body) }
        guard case .apply(let function, let argument) = body else { return .apply(.k, body) }
        if argument == .variable(variable), !function.freeVariables.contains(variable) {
            return function  // η: [x] (E x) = E
        }
        return .s(abstract(variable, from: function), abstract(variable, from: argument))
    }

    /// Bracket abstraction over several variables at once, outermost first.
    ///
    /// ```swift
    /// Term.lambda("x", "y", body: .variable("x"))   // K
    /// ```
    public static func lambda(_ variables: String..., body: Term) -> Term {
        variables.reversed().reduce(body) { abstract($1, from: $0) }
    }
}
