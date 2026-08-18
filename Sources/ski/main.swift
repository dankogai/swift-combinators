import Combinators
import Foundation

/// A tiny read-eval-print loop for the SKI combinator calculus.
///
///     swift run ski                 # interactive
///     swift run ski 'SKKx'          # evaluate one expression
///     swift run ski -v 'S(K(SI))Kxy'  # show every reduction step

let maxSteps = 1_000

var basis = Basis.ski

var definitions: [String: Term] = [
    "M": .m, "Y": .y,
    "T": .churchTrue, "F": .churchFalse,
    // Birds from “To Mock a Mockingbird” whose letters are free.
    // (T and F stay the Church booleans; :let T = CI gets you the thrush.)
    "D": .dove, "E": .eagle, "G": .goldfinch, "H": .hummingbird,
    "J": .jay, "L": .lark, "O": .owl, "Q": .queerBird,
    "R": .robin, "U": .turingBird, "V": .vireo,
]
for n in 0 ... 9 { definitions[String(n)] = .church(n) }

@MainActor
func expand(_ term: Term) -> Term {
    term.substituting(definitions.filter { term.freeVariables.contains($0.key) })
}

@MainActor
func evaluate(_ source: String, verbose: Bool) {
    do {
        evaluate(expand(try Term(parsing: source, basis: basis)), verbose: verbose)
    } catch {
        print("error: \(error)")
    }
}

@MainActor
func evaluate(_ term: Term, verbose: Bool) {
    do {
        if verbose {
            for step in term.reductions.prefix(maxSteps + 1) { print("  \(step)") }
        }
        let normal = try term.normalize(maxSteps: maxSteps)
        var annotations: [String] = []
        if let n = normal.naturalValue() { annotations.append("\(n)") }
        if let b = normal.booleanValue() { annotations.append("\(b)") }
        print("\(normal)\(annotations.isEmpty ? "" : "    -- \(annotations.joined(separator: ", "))")")
    } catch {
        print("error: \(error)")
    }
}

func basisNamed(_ name: String) -> Basis? {
    switch name.lowercased() {
    case "ski": .ski
    case "bckw": .bckw
    case "iota", "\u{03B9}": .iota
    default: nil
    }
}

let help = """
    <expression>       reduce a term to normal form; \\x.body abstracts a variable
    :v <expr>          print every reduction step
    :let X = <expr>    bind a single-character name
    :env               list the bound names
    :birds             list every bird from “To Mock a Mockingbird”
    :basis <name>      show or set the basis (ski, bckw or iota) lambdas
                       are eliminated into
    :to <basis> <expr> rewrite a term into the given basis
    :iota <prog|expr>  evaluate an Iota program (*FG notation), or encode
                       a closed term as one
    :jot <bits|expr>   evaluate a Jot program (a string of 0s and 1s), or
                       encode a closed term as one
    :help              this message
    :quit              leave
    """

let arguments = Array(CommandLine.arguments.dropFirst())
if !arguments.isEmpty {
    let verbose = arguments.first == "-v"
    evaluate(arguments.drop { $0 == "-v" }.joined(separator: " "), verbose: verbose)
} else {
    print("Combinator calculus (SKI, BCKW, Iota/Jot). :help for help, :quit to leave.")
    while true {
        print("ski> ", terminator: "")
        guard let line = readLine() else { break }
        let input = line.trimmingCharacters(in: .whitespaces)
        switch input {
        case "": continue
        case ":quit", ":q": exit(0)
        case ":help", ":h", ":?": print(help)
        case ":birds":
            let width = Term.aviary.map(\.name.count).max() ?? 0
            for (name, term) in Term.aviary {
                print("  \(name.padding(toLength: width, withPad: " ", startingAt: 0))  \(term)")
            }
        case ":env":
            for (name, term) in definitions.sorted(by: { $0.key < $1.key }) {
                print("  \(name) = \(term)")
            }
        case ":basis":
            print("  basis: \(["ski", "bckw", "iota"][Basis.allCases.firstIndex(of: basis)!])")
        case let input where input.hasPrefix(":basis "):
            let name = input.dropFirst(7).trimmingCharacters(in: .whitespaces)
            if let named = basisNamed(name) {
                basis = named
            } else {
                print("error: unknown basis \(name); expected ski, bckw or iota")
            }
        case let input where input.hasPrefix(":iota "):
            let text = String(input.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            do {
                if text.allSatisfy({ "*iι".contains($0) || $0.isWhitespace }) {
                    evaluate(try Term(iota: text), verbose: false)
                } else if let encoding = expand(try Term(parsing: text, basis: basis)).iotaEncoding {
                    print(encoding)
                } else {
                    print("error: the term has free variables, which Iota cannot express")
                }
            } catch {
                print("error: \(error)")
            }
        case let input where input.hasPrefix(":jot "):
            let text = String(input.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            do {
                if text.allSatisfy({ "01".contains($0) || $0.isWhitespace }) {
                    evaluate(try Term(jot: text), verbose: false)
                } else if let encoding = expand(try Term(parsing: text, basis: basis)).jotEncoding {
                    print(encoding)
                } else {
                    print("error: the term has free variables, which Jot cannot express")
                }
            } catch {
                print("error: \(error)")
            }
        case let input where input.hasPrefix(":to "):
            let parts = input.dropFirst(4).split(separator: " ", maxSplits: 1)
            guard parts.count == 2, let target = basisNamed(String(parts[0])) else {
                print("error: expected :to <ski|bckw> <expression>")
                continue
            }
            do {
                let term = expand(try Term(parsing: String(parts[1]), basis: basis))
                print(term.rewritten(in: target))
            } catch {
                print("error: \(error)")
            }
        case let input where input.hasPrefix(":v "):
            evaluate(String(input.dropFirst(3)), verbose: true)
        case let input where input.hasPrefix(":let "):
            let parts = input.dropFirst(5).split(separator: "=", maxSplits: 1)
            guard parts.count == 2, let name = parts[0].trimmingCharacters(in: .whitespaces).first else {
                print("error: expected :let X = <expression>")
                continue
            }
            do {
                definitions[String(name)] = expand(try Term(parsing: String(parts[1])))
            } catch {
                print("error: \(error)")
            }
        case let input where input.hasPrefix(":"):
            print("error: unknown command \(input); try :help")
        default:
            evaluate(input, verbose: false)
        }
    }
}
