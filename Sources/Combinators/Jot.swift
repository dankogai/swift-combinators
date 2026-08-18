extension Term {
    /// Decodes a program in Barker's Jot language, in which every finite
    /// string of `0`s and `1`s — including the empty string — is a program.
    ///
    /// Reading left to right, the empty program denotes `I` and each bit
    /// transforms the program so far: `[F0] = [F] S K` and `[F1] = B [F]`
    /// (that is, `λxy. [F] (x y)`, traditionally written `S (K [F])`).
    /// Whitespace is ignored.
    ///
    /// ```swift
    /// try Term(jot: "11100")      // behaves like K
    /// try Term(jot: "11111000")   // behaves like S
    /// ```
    public init(jot source: String) throws {
        var term = Term.i
        for (offset, character) in source.enumerated() {
            switch character {
            case "0": term = term(.s, .k)
            case "1": term = .b(term)
            case let character where character.isWhitespace: continue
            default:
                throw ParseError(reason: "expected 0 or 1, got \(character.debugDescription)",
                                 position: offset)
            }
        }
        self = term
    }

    /// The term written as a Jot program, or `nil` if the term contains free
    /// variables, which Jot cannot express.
    ///
    /// The translation is Barker's: the term is first rewritten to use only
    /// `S` and `K` (`I` becomes `SKK`), then `S` becomes `11111000`, `K`
    /// becomes `11100`, and each application `F G` becomes `1FG`.  This makes
    /// Jot a Gödel numbering: decoding the encoding yields a term that
    /// reduces the same way.
    ///
    /// ```swift
    /// Term.s.jotEncoding   // "11111000"
    /// ```
    public var jotEncoding: String? {
        guard freeVariables.isEmpty else { return nil }
        func skOnly(_ term: Term) -> Term {
            switch term {
            case .apply(let function, let argument):
                .apply(skOnly(function), skOnly(argument))
            case .i: .s(.k, .k)
            default: term
            }
        }
        func encode(_ term: Term) -> String {
            switch term {
            case .apply(let function, let argument):
                "1" + encode(function) + encode(argument)
            case .s: "11111000"
            default: "11100"  // K, the only other primitive left after skOnly
            }
        }
        return encode(skOnly(rewritten(in: .ski)))
    }
}
