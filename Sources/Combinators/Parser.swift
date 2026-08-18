/// An error raised while parsing a combinator expression.
public struct ParseError: Error, Hashable, Sendable, CustomStringConvertible {
    /// What went wrong.
    public let reason: String
    /// The offset into the source string at which it went wrong.
    public let position: Int

    public var description: String { "\(reason) at position \(position)" }
}

extension Term {
    /// Parses a term written in the classic notation.
    ///
    /// Application is juxtaposition and associates to the left; `S`, `K` and `I`
    /// denote the primitive combinators and any other single letter or digit is
    /// a free variable, so `SKKx` is `(((S K) K) x)`.  Parentheses group, and
    /// whitespace is insignificant.
    ///
    /// A lambda abstraction may be written `\x.body`, `λxy.body` or `\x -> body`;
    /// it is eliminated into `S`, `K` and `I` while parsing, and extends as far
    /// to the right as it can.
    ///
    /// ```swift
    /// try Term(parsing: "S(K(SI))K")
    /// try Term(parsing: #"\fx.f(fx)"#)   // the Church numeral 2
    /// ```
    public init(parsing source: String) throws {
        var parser = Parser(source: Array(source))
        self = try parser.parseTerm()
        try parser.expectEndOfInput()
    }
}

/// A recursive-descent parser for the grammar
///
///     term   ::= atom+
///     atom   ::= "S" | "K" | "I" | letter | digit | "(" term ")" | lambda
///     lambda ::= ("\" | "λ") letter+ ("." | "->") term
private struct Parser {
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

    /// Parses a run of atoms and folds them into a left-associated application.
    mutating func parseTerm() throws -> Term {
        skipWhitespace()
        let start = index
        var term: Term?
        while let character = current, character != ")" {
            let atom = try parseAtom()
            term = term.map { Term.apply($0, atom) } ?? atom
            skipWhitespace()
        }
        guard let term else {
            throw ParseError(reason: "expected a term", position: start)
        }
        return term
    }

    mutating func parseAtom() throws -> Term {
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
            return try parseLambda()
        case "S": index += 1; return .s
        case "K": index += 1; return .k
        case "I": index += 1; return .i
        case let character where character.isLetter || character.isNumber:
            index += 1
            return .variable(String(character))
        default:
            throw ParseError(reason: "unexpected \(character.debugDescription)", position: index)
        }
    }

    /// Parses everything after the `\` of an abstraction and eliminates it.
    mutating func parseLambda() throws -> Term {
        var variables: [String] = []
        while true {
            skipWhitespace()
            guard let character = current, character.isLetter || character.isNumber else { break }
            variables.append(String(character))
            index += 1
        }
        guard !variables.isEmpty else {
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
        return variables.reversed().reduce(body) { Term.abstract($1, from: $0) }
    }
}

extension Term: ExpressibleByStringLiteral {
    /// Parses a term from a literal, trapping if it is malformed.
    ///
    /// ```swift
    /// let flip: Term = "S(K(SI))K"
    /// ```
    public init(stringLiteral value: String) {
        do {
            try self.init(parsing: value)
        } catch {
            fatalError("invalid combinator expression \(value.debugDescription): \(error)")
        }
    }
}
