extension Term {
    /// Parses a program in Barker's Iota language, in which `i` (or `ι`)
    /// denotes the iota combinator and `*FG` denotes the application of `F`
    /// to `G`.  Whitespace is insignificant.
    ///
    /// ```swift
    /// try Term(iota: "*ii")       // ιι, which behaves like I
    /// try Term(iota: "*i*i*ii")   // ι(ι(ιι)), which behaves like K
    /// ```
    public init(iota source: String) throws {
        let characters = Array(source)
        var index = 0
        func skipWhitespace() {
            while index < characters.count, characters[index].isWhitespace { index += 1 }
        }
        func parse() throws -> Term {
            skipWhitespace()
            guard index < characters.count else {
                throw ParseError(reason: "expected a term", position: index)
            }
            let character = characters[index]
            index += 1
            switch character {
            case "*": return .apply(try parse(), try parse())
            case "i", "ι": return .iota
            default:
                throw ParseError(reason: "unexpected \(character.debugDescription)", position: index - 1)
            }
        }
        self = try parse()
        skipWhitespace()
        guard index == characters.count else {
            throw ParseError(reason: "unexpected \(characters[index].debugDescription)", position: index)
        }
    }

    /// The term written as an Iota program, or `nil` if the term contains
    /// free variables, which Iota cannot express.
    ///
    /// Foreign primitives are rewritten into the ``Basis/iota`` basis first,
    /// so every closed term has an encoding.
    ///
    /// ```swift
    /// Term.k.iotaEncoding   // "*i*i*ii"
    /// ```
    public var iotaEncoding: String? {
        guard freeVariables.isEmpty else { return nil }
        func serialize(_ term: Term) -> String {
            switch term {
            case .apply(let function, let argument):
                "*" + serialize(function) + serialize(argument)
            default: "i"
            }
        }
        return serialize(rewritten(in: .iota))
    }
}
