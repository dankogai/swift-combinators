import Combinators
import Foundation

/// A tiny read-eval-print loop for the SKI combinator calculus.
///
///     swift run ski                 # interactive
///     swift run ski 'SKKx'          # evaluate one expression
///     swift run ski -v 'S(K(SI))Kxy'  # show every reduction step

let maxSteps = 1_000

var definitions: [String: Term] = [
    "B": .b, "C": .c, "W": .w, "M": .m, "Y": .y,
    "T": .churchTrue, "F": .churchFalse,
]
for n in 0 ... 9 { definitions[String(n)] = .church(n) }

@MainActor
func expand(_ term: Term) -> Term {
    term.substituting(definitions.filter { term.freeVariables.contains($0.key) })
}

@MainActor
func evaluate(_ source: String, verbose: Bool) {
    do {
        let term = expand(try Term(parsing: source))
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

let help = """
    <expression>   reduce a term to normal form; \\x.body abstracts a variable
    :v <expr>      print every reduction step
    :let X = <expr>  bind a single-character name
    :env           list the bound names
    :help          this message
    :quit          leave
    """

let arguments = Array(CommandLine.arguments.dropFirst())
if !arguments.isEmpty {
    let verbose = arguments.first == "-v"
    evaluate(arguments.drop { $0 == "-v" }.joined(separator: " "), verbose: verbose)
} else {
    print("SKI combinator calculus. :help for help, :quit to leave.")
    while true {
        print("ski> ", terminator: "")
        guard let line = readLine() else { break }
        let input = line.trimmingCharacters(in: .whitespaces)
        switch input {
        case "": continue
        case ":quit", ":q": exit(0)
        case ":help", ":h", ":?": print(help)
        case ":env":
            for (name, term) in definitions.sorted(by: { $0.key < $1.key }) {
                print("  \(name) = \(term)")
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
