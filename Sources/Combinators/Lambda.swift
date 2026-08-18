/// A term of the untyped λ-calculus, with named variables.
///
/// Unlike ``Term``, whose lambdas are eliminated into combinators while
/// parsing, `Lambda` keeps its abstractions and reduces by β-conversion with
/// capture-avoiding substitution.  The two worlds convert freely:
/// ``Lambda/init(_:)`` lifts a combinator term to its defining abstractions,
/// and ``Lambda/combinator(in:)`` compiles a λ-term into any ``Basis``.
///
/// ```swift
/// let two: Lambda = "λfx.f(fx)"
/// try two.normalize()              // already β-normal
/// two.combinator()                 // S(S(KS)K)(S(S(KS)K)(KI))
/// Lambda(Term.b)                   // λabc.a(bc)
/// ```
public indirect enum Lambda: Hashable, Sendable {
    /// A variable, free or bound.
    case variable(String)
    /// An abstraction `λname.body`.
    case abstraction(String, Lambda)
    /// The application of one term to another.
    case application(Lambda, Lambda)
}

extension Lambda {
    /// Applies this term to `arguments`, associating to the left.
    public func callAsFunction(_ arguments: Lambda...) -> Lambda {
        arguments.reduce(self) { .application($0, $1) }
    }

    /// The variables occurring free in the term.
    public var freeVariables: Set<String> {
        switch self {
        case .variable(let name): [name]
        case .abstraction(let name, let body): body.freeVariables.subtracting([name])
        case .application(let function, let argument):
            function.freeVariables.union(argument.freeVariables)
        }
    }

    /// A name based on `base` that does not occur in `used`, made by
    /// appending primes.
    static func freshName(_ base: String, avoiding used: Set<String>) -> String {
        var name = base + "′"
        while used.contains(name) { name += "′" }
        return name
    }

    /// Replaces every free occurrence of `name` with `replacement`, renaming
    /// bound variables where needed so nothing free in `replacement` is
    /// captured.
    public func substituting(_ name: String, with replacement: Lambda) -> Lambda {
        switch self {
        case .variable(let variable):
            return variable == name ? replacement : self
        case .application(let function, let argument):
            return .application(function.substituting(name, with: replacement),
                                argument.substituting(name, with: replacement))
        case .abstraction(let binder, let body):
            guard binder != name else { return self }  // the binder shadows it
            guard body.freeVariables.contains(name) else { return self }
            guard replacement.freeVariables.contains(binder) else {
                return .abstraction(binder, body.substituting(name, with: replacement))
            }
            // λbinder.body would capture a free `binder` of the replacement:
            // α-convert the binder first.
            let fresh = Self.freshName(binder,
                avoiding: replacement.freeVariables.union(body.freeVariables))
            return .abstraction(fresh, body
                .substituting(binder, with: .variable(fresh))
                .substituting(name, with: replacement))
        }
    }

    /// The canonical representative of the term's α-equivalence class: every
    /// bound variable is renamed, outermost binder first, to the first name
    /// in `a b c … z a′ b′ …` that does not occur free.
    ///
    /// ```swift
    /// Lambda("λx y′.y′x").alphaNormalized()   // λab.ba
    /// ```
    public func alphaNormalized() -> Lambda {
        let letters = "abcdefghijklmnopqrstuvwxyz".map(String.init)
        let free = freeVariables
        var next = 0
        func freshCanonical() -> String {
            while true {
                let i = next
                next += 1
                let name = letters[i % 26] + String(repeating: "′", count: i / 26)
                if !free.contains(name) { return name }
            }
        }
        func walk(_ term: Lambda, _ renaming: [String: String]) -> Lambda {
            switch term {
            case .variable(let name):
                return .variable(renaming[name] ?? name)
            case .application(let function, let argument):
                return .application(walk(function, renaming), walk(argument, renaming))
            case .abstraction(let binder, let body):
                let fresh = freshCanonical()
                return .abstraction(fresh,
                    walk(body, renaming.merging([binder: fresh]) { _, new in new }))
            }
        }
        return walk(self, [:])
    }

    /// Whether the two terms are equal up to a consistent renaming of bound
    /// variables.
    public func isAlphaEquivalent(to other: Lambda) -> Bool {
        func walk(_ left: Lambda, _ right: Lambda,
                  _ leftDepths: [String: Int], _ rightDepths: [String: Int],
                  _ depth: Int) -> Bool {
            switch (left, right) {
            case (.variable(let a), .variable(let b)):
                switch (leftDepths[a], rightDepths[b]) {
                case (nil, nil): a == b               // both free
                case (let l?, let r?): l == r         // bound by the same λ
                default: false
                }
            case (.application(let f1, let a1), .application(let f2, let a2)):
                walk(f1, f2, leftDepths, rightDepths, depth)
                    && walk(a1, a2, leftDepths, rightDepths, depth)
            case (.abstraction(let v1, let b1), .abstraction(let v2, let b2)):
                walk(b1, b2,
                     leftDepths.merging([v1: depth]) { _, new in new },
                     rightDepths.merging([v2: depth]) { _, new in new },
                     depth + 1)
            default:
                false
            }
        }
        return walk(self, other, [:], [:], 0)
    }
}

// MARK: - β-reduction

/// An error raised while β-reducing a λ-term.
public enum LambdaReductionError: Error, Hashable, Sendable, CustomStringConvertible {
    /// The term did not reach a β-normal form within the allotted steps.
    case stepLimitExceeded(term: Lambda, limit: Int)

    public var description: String {
        switch self {
        case .stepLimitExceeded(let term, let limit):
            "no β-normal form after \(limit) steps; reached \(term)"
        }
    }
}

extension Lambda {
    /// Performs a single β-reduction step in normal order — leftmost
    /// outermost, contracting under abstractions — or returns `nil` if the
    /// term is already in β-normal form.
    public func reduced() -> Lambda? {
        switch self {
        case .application(.abstraction(let binder, let body), let argument):
            return body.substituting(binder, with: argument)  // β
        case .application(let function, let argument):
            if let function = function.reduced() { return .application(function, argument) }
            if let argument = argument.reduced() { return .application(function, argument) }
            return nil
        case .abstraction(let binder, let body):
            return body.reduced().map { .abstraction(binder, $0) }
        case .variable:
            return nil
        }
    }

    /// Whether the term contains no β-redex.
    public var isNormalForm: Bool { reduced() == nil }

    /// The lazy sequence of terms starting with this one, each the
    /// normal-order reduct of the previous.
    public var reductions: UnfoldFirstSequence<Lambda> {
        sequence(first: self) { $0.reduced() }
    }

    /// Reduces the term to β-normal form.
    ///
    /// - Throws: ``LambdaReductionError/stepLimitExceeded(term:limit:)`` if no
    ///   normal form is reached within `maxSteps`.
    @discardableResult
    public func normalize(maxSteps: Int = 1_000) throws -> Lambda {
        var term = self
        for _ in 0 ..< maxSteps {
            guard let next = term.reduced() else { return term }
            term = next
        }
        guard let stalled = term.reduced() else { return term }
        throw LambdaReductionError.stepLimitExceeded(term: stalled, limit: maxSteps)
    }
}

// MARK: - Conversions

extension Lambda {
    /// The λ-image of a combinator term: each primitive becomes its defining
    /// abstraction, and applications and variables are preserved.
    public init(_ term: Term) {
        switch term {
        case .variable(let name): self = .variable(name)
        case .apply(let function, let argument):
            self = .application(Lambda(function), Lambda(argument))
        case .s: self = "λabc.ac(bc)"
        case .k: self = "λab.a"
        case .i: self = "λa.a"
        case .b: self = "λabc.a(bc)"
        case .c: self = "λabc.acb"
        case .w: self = "λab.abb"
        case .iota: self = "λa.a(λbcd.bd(cd))(λbc.b)"
        case .x: self = "λa.a(λbc.b)(λbcd.bd(cd))(λbc.b)"
        }
    }

    /// Compiles the λ-term into combinators by bracket abstraction into
    /// `basis`.
    ///
    /// ```swift
    /// Lambda("λxy.yx").combinator(in: .bckw)   // C(WK)
    /// ```
    public func combinator(in basis: Basis = .ski) -> Term {
        switch self {
        case .variable(let name): .variable(name)
        case .application(let function, let argument):
            .apply(function.combinator(in: basis), argument.combinator(in: basis))
        case .abstraction(let binder, let body):
            Term.abstract(binder, from: body.combinator(in: basis), in: basis)
        }
    }

    /// Reads a Church numeral back out of the term, or `nil` if it is not one.
    public func naturalValue(maxSteps: Int = 1_000) -> Int? {
        combinator().naturalValue(maxSteps: maxSteps)
    }

    /// Reads a Church boolean back out of the term, or `nil` if it is not one.
    public func booleanValue(maxSteps: Int = 1_000) -> Bool? {
        combinator().booleanValue(maxSteps: maxSteps)
    }
}

extension Term {
    /// Compiles a λ-term into combinators; see ``Lambda/combinator(in:)``.
    public init(_ lambda: Lambda, in basis: Basis = .ski) {
        self = lambda.combinator(in: basis)
    }
}

// MARK: - Printing

extension Lambda: CustomStringConvertible {
    /// The term in the usual notation: `λ` runs of binders, application by
    /// juxtaposition, redundant parentheses omitted.
    public var description: String {
        switch self {
        case .variable(let name):
            return name
        case .abstraction:
            var binders: [String] = []
            var body = self
            while case .abstraction(let name, let inner) = body {
                binders.append(name)
                body = inner
            }
            let run = binders.allSatisfy { $0.count == 1 }
                ? binders.joined()
                : binders.joined(separator: " ")
            return "λ\(run).\(body)"
        case .application:
            var arguments: [Lambda] = []
            var head = self
            while case .application(let function, let argument) = head {
                arguments.append(argument)
                head = function
            }
            let pieces = ([head] + arguments.reversed()).map { piece in
                if case .variable(let name) = piece { name } else { "(\(piece))" }
            }
            let unambiguous = pieces.allSatisfy { $0.count == 1 || $0.hasPrefix("(") }
            return pieces.joined(separator: unambiguous ? "" : " ")
        }
    }
}

extension Lambda: CustomDebugStringConvertible {
    public var debugDescription: String { "Lambda(\(description))" }
}

// MARK: - Parsing

extension Lambda {
    /// Parses a λ-term.
    ///
    /// Application is juxtaposition and associates to the left; every single
    /// letter or digit (optionally primed, like `x′` or `x'`) is a variable —
    /// there are no combinator letters here.  An abstraction is written
    /// `λxy.body`, `\x.body` or `\x -> body` and extends as far to the right
    /// as it can.
    public init(parsing source: String) throws {
        var parser = LambdaParser(source: Array(source))
        self = try parser.parseTerm()
        try parser.expectEndOfInput()
    }
}

private struct LambdaParser {
    let source: [Character]
    var index = 0

    var current: Character? { index < source.count ? source[index] : nil }

    mutating func skipWhitespace() {
        while let character = current, character.isWhitespace { index += 1 }
    }

    mutating func expectEndOfInput() throws {
        skipWhitespace()
        if let character = current {
            throw ParseError(reason: "unexpected \(character.debugDescription)", position: index)
        }
    }

    /// A single letter or digit, plus any trailing primes.
    mutating func parseName() -> String? {
        guard let character = current, character.isLetter || character.isNumber,
              character != "λ" else { return nil }
        var name = String(character)
        index += 1
        while let prime = current, prime == "'" || prime == "′" {
            name.append("′")
            index += 1
        }
        return name
    }

    mutating func parseTerm() throws -> Lambda {
        skipWhitespace()
        let start = index
        var term: Lambda?
        while let character = current, character != ")" {
            let atom = try parseAtom()
            term = term.map { .application($0, atom) } ?? atom
            skipWhitespace()
        }
        guard let term else {
            throw ParseError(reason: "expected a term", position: start)
        }
        return term
    }

    mutating func parseAtom() throws -> Lambda {
        skipWhitespace()
        guard let character = current else {
            throw ParseError(reason: "expected a term", position: index)
        }
        switch character {
        case "(":
            index += 1
            let term = try parseTerm()
            skipWhitespace()
            guard current == ")" else {
                throw ParseError(reason: "expected \")\"", position: index)
            }
            index += 1
            return term
        case "\\", "λ":
            index += 1
            return try parseAbstraction()
        default:
            if let name = parseName() { return .variable(name) }
            throw ParseError(reason: "unexpected \(character.debugDescription)", position: index)
        }
    }

    mutating func parseAbstraction() throws -> Lambda {
        var binders: [String] = []
        while true {
            skipWhitespace()
            guard let name = parseName() else { break }
            binders.append(name)
        }
        guard !binders.isEmpty else {
            throw ParseError(reason: "expected a variable to bind", position: index)
        }
        skipWhitespace()
        if current == "." {
            index += 1
        } else if current == "-", index + 1 < source.count, source[index + 1] == ">" {
            index += 2
        } else {
            throw ParseError(reason: "expected \".\" or \"->\"", position: index)
        }
        let body = try parseTerm()
        return binders.reversed().reduce(body) { .abstraction($1, $0) }
    }
}

extension Lambda: ExpressibleByStringLiteral {
    /// Parses a λ-term from a literal, trapping if it is malformed.
    public init(stringLiteral value: String) {
        do {
            try self.init(parsing: value)
        } catch {
            fatalError("invalid λ-term \(value.debugDescription): \(error)")
        }
    }
}
