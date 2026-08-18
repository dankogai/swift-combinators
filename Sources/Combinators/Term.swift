/// A term of the combinator calculus.
///
/// A term is either a primitive combinator, a free variable standing for an
/// unknown term, or the application of one term to another.  The primitives
/// cover two classic bases — Schönfinkel's `S`, `K`, `I` and Curry's `B`, `C`,
/// `K`, `W` — and may be mixed freely; ``rewritten(in:)`` restricts a term to
/// a single ``Basis``.  Application is written by juxtaposition and associates
/// to the left, so `SKKx` means `(((S K) K) x)`.
///
/// ```swift
/// let term: Term = "S(K(SI))K"   // parsed from the classic notation
/// try term(.variable("x"), .variable("y")).normalize()   // yx
/// ```
public indirect enum Term: Hashable, Sendable {
    /// The substitution combinator: `S x y z → x z (y z)`.
    case s
    /// The constant combinator: `K x y → x`.
    case k
    /// The identity combinator: `I x → x`.
    case i
    /// The composition combinator: `B x y z → x (y z)`.
    case b
    /// The exchange combinator: `C x y z → x z y`.
    case c
    /// The duplication combinator: `W x y → x y y`.
    case w
    /// A free variable, which never reduces.
    case variable(String)
    /// The application of one term to another, `f x`.
    case apply(Term, Term)
}

extension Term {
    /// Applies this term to `arguments`, associating to the left.
    ///
    /// ```swift
    /// Term.s(.k, .k)   // SKK
    /// ```
    public func callAsFunction(_ arguments: Term...) -> Term {
        Term.applying(self, to: arguments)
    }

    /// Applies `head` to every element of `arguments`, associating to the left.
    public static func applying(_ head: Term, to arguments: some Sequence<Term>) -> Term {
        arguments.reduce(head) { .apply($0, $1) }
    }

    /// Decomposes a term into the head of its application spine and the
    /// arguments applied to it, in order.
    ///
    /// `SKKx` decomposes into `(head: .s, arguments: [.k, .k, .variable("x")])`.
    public var spine: (head: Term, arguments: [Term]) {
        var arguments: [Term] = []
        var current = self
        while case .apply(let function, let argument) = current {
            arguments.append(argument)
            current = function
        }
        return (current, arguments.reversed())
    }

    /// The number of primitive combinators and variables the term is built from.
    public var size: Int {
        if case .apply(let function, let argument) = self {
            function.size + argument.size
        } else {
            1
        }
    }
}

extension Term: CustomStringConvertible {
    /// The term in the classic notation, with redundant parentheses omitted.
    public var description: String {
        let (head, arguments) = spine
        let pieces = [head.atomDescription] + arguments.map(\.argumentDescription)
        // Single characters and parenthesised groups juxtapose unambiguously;
        // anything else (a multi-character variable) needs a separator.
        let unambiguous = pieces.allSatisfy { $0.count == 1 || $0.hasPrefix("(") }
        return pieces.joined(separator: unambiguous ? "" : " ")
    }

    private var atomDescription: String {
        switch self {
        case .s: "S"
        case .k: "K"
        case .i: "I"
        case .b: "B"
        case .c: "C"
        case .w: "W"
        case .variable(let name): name
        case .apply: "(\(description))"
        }
    }

    private var argumentDescription: String {
        if case .apply = self { "(\(description))" } else { atomDescription }
    }
}

extension Term: CustomDebugStringConvertible {
    public var debugDescription: String { "Term(\(description))" }
}
