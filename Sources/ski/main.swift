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
]
for n in 0 ... 9 { definitions[String(n)] = .church(n) }

@MainActor
func expand(_ term: Term) -> Term {
    term.substituting(definitions.filter { term.freeVariables.contains($0.key) })
}

@MainActor
func evaluate(_ source: String, verbose: Bool) {
    do {
        let term = expand(try Term(parsing: source, basis: basis))
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
    default: nil
    }
}

let help = """
    <expression>       reduce a term to normal form; \\x.body abstracts a variable
    :v <expr>          print every reduction step
    :let X = <expr>    bind a single-character name
    :env               list the bound names
    :basis [ski|bckw]  show or set the basis lambdas are eliminated into
    :to <basis> <expr> rewrite a term into the given basis
    :help              this message
    :quit              leave
    """

let arguments = Array(CommandLine.arguments.dropFirst())
if !arguments.isEmpty {
    let verbose = arguments.first == "-v"
    evaluate(arguments.drop { $0 == "-v" }.joined(separator: " "), verbose: verbose)
} else {
    print("Combinator calculus (SKI + BCKW). :help for help, :quit to leave.")
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
        case ":basis":
            print("  basis: \(basis == .ski ? "ski" : "bckw")")
        case let input where input.hasPrefix(":basis "):
            let name = input.dropFirst(7).trimmingCharacters(in: .whitespaces)
            if let named = basisNamed(name) {
                basis = named
            } else {
                print("error: unknown basis \(name); expected ski or bckw")
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
