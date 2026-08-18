# swift-combinators

Combinator calculus in Swift — the [SKI combinator calculus](https://en.wikipedia.org/wiki/SKI_combinator_calculus), Curry's [BCKW system](https://en.wikipedia.org/wiki/B,_C,_K,_W_system), Barker's [Iota and Jot](https://en.wikipedia.org/wiki/Iota_and_Jot), the [one-point basis](https://en.wikipedia.org/wiki/Combinatory_logic#One-point_basis) `X`, and the full aviary of Smullyan's [*To Mock a Mockingbird*](https://en.wikipedia.org/wiki/To_Mock_a_Mockingbird).

## Synopsis

```swift
import Combinators

let x = Term.variable("x"), y = Term.variable("y")

// The three primitives:  I x → x,  K x y → x,  S x y z → x z (y z)
try Term.i(x).normalize()        // x
try Term.k(x, y).normalize()     // x
try Term("SKK")(x).normalize()   // x — SKK behaves like I

// Terms parse from the classic notation (string literals too):
let flip: Term = "S(K(SI))K"
try flip(x, y).normalize()       // yx

// Lambdas are eliminated into S, K and I by bracket abstraction:
let three = try Term(parsing: #"\fx.f(f(fx))"#)
three.naturalValue()             // 3

// Church arithmetic:
Term.add(.church(2), .church(3)).naturalValue()       // 5
Term.multiply(.church(2), .church(3)).naturalValue()  // 6

// Reduction is normal-order and bounded; Ω = SII(SII) has no normal form:
try Term.omega.normalize()       // throws ReductionError.stepLimitExceeded

// Watch a reduction, step by step:
for step in Term("SKKx").reductions { print(step) }
// SKKx
// Kx(Kx)
// x
```

## BCKW

`B`, `C` and `W` are primitives too — `B x y z → x (y z)`, `C x y z → x z y`,
`W x y → x y y` — so terms may mix both bases freely, and either basis can be
targeted or eliminated:

```swift
// Bracket abstraction into Curry's basis instead of Schönfinkel's:
try Term(parsing: #"\xy.yx"#, basis: .bckw)   // C(WK), pure BCKW
Term.lambda("f", "x", body: .variable("f")(x, x), in: .bckw)   // W

// Rewrite a term into a single basis:
Term.b.rewritten(in: .ski)    // S(KS)K
Term.s.rewritten(in: .bckw)   // B(BW)(BBC)
Term.i.rewritten(in: .bckw)   // WK

Term("B(SW)x").rewritten(in: .ski).isExpressed(in: .ski)   // true
```

## Iota and Jot

`ι` is a primitive too, with the rule `ι x → x S K`; the whole calculus folds
into it (`I = ιι`, `K = ι(ι(ιι))`, `S = ι(ι(ι(ιι)))`):

```swift
// Barker's Iota language: i (or ι) and prefix application *FG
try Term(iota: "*i*i*ii")     // ι(ι(ιι)), which behaves like K
Term.k.iotaEncoding           // "*i*i*ii"
Term.s.rewritten(in: .iota)   // ι(ι(ι(ιι)))

// Jot: every string of 0s and 1s is a program —
// [] = I, [F0] = FSK, [F1] = λxy.F(xy)
try Term(jot: "11100")        // behaves like K
try Term(jot: "11111000")     // behaves like S
Term.s.jotEncoding            // "11111000" — a Gödel numbering of all terms
```

Both encoders return `nil` for terms with free variables, which the languages
cannot express.  (Note that iota terms rarely stay iota-pure under reduction:
`ι`'s own rule reintroduces `S` and `K`.)

## The X combinator

Another one-point basis, with an even tidier bootstrap than `ι`'s:
`X a → a K S K`, so the whole calculus falls out of self-application —
exactly, not merely extensionally:

```swift
try Term("XXX").normalize()     // K — literally the primitive
try Term("X(XX)").normalize()   // S
Term.k.rewritten(in: .x)        // XXX
Term.s.rewritten(in: .x)        // X(XX)
try Term(parsing: #"\xy.yx"#, basis: .x).isExpressed(in: .x)   // true
```

## The aviary

Every bird from *To Mock a Mockingbird*, each built by the book's own
construction and named on `Term`:

```swift
Term.thrush              // CI       — T a b → b a
Term.robin               // BBT      — R a b c → b c a
Term.jay                 // B(BC)(W(BC(B(BBB)))) — J a b c d → a b (a d c)
Term.turingBird          // LO       — U a b → b (a a b)
Term.theta               // UU       — Turing's sage bird, Θ a → a (Θ a)

// The book's famous puzzle: a robin composed with itself thrice is a cardinal.
try Term.robin(.robin, .robin, x, y, z).normalize()   // xzy — behaves like C
```

`Term.aviary` lists all 46 by name, and the REPL's `:birds` prints them;
`D E G H J L O Q R U V` come predefined (`M` the mockingbird and `Y` the sage
were already there).  Every bird's law is verified in the test suite.

## The REPL

```sh
swift run ski                # interactive
swift run ski 'SKKx'         # one-shot
swift run ski -v 'SKKx'      # …showing every step
```

```
ski> :v S(K(SI))Kxy
  S(K(SI))Kxy
  K(SI)x(Kx)y
  SI(Kx)y
  Iy(Kxy)
  y(Kxy)
  yx
yx
ski> \fx.f(fx)
S(S(KS)K)(S(S(KS)K)(KI))    -- 2
ski> :let A = \mnfx.mf(nfx)
ski> A23
S(S(KS)(S(KK)(S(S(KS)K)I)))(S(S(KS)K)(S(S(KS)K)I))    -- 5
```

The REPL predefines `M Y`, the booleans `T F`, and the digits `0`–`9` as
Church numerals; `S K I B C W` are the primitives. `:basis bckw` switches
which basis lambdas are eliminated into, and `:to <basis> <expr>` rewrites a
term into a basis:

```
ski> :basis bckw
ski> \xy.yx
C(WK)
ski> :to bckw S
B(BW)(BBC)
ski> :iota *i*i*ii
K    -- true
ski> :jot 11111000
S
ski> :jot S(K(SI))K
11111110001111001111110001111111000111001110011100
```

`:iota` and `:jot` evaluate a program in those languages, or — given an
ordinary expression — encode it into one.

`:help` lists the commands.

## What's inside

- `Term` — an `indirect enum` over the primitives `S K I B C W ι X`, free
  variables and application, with parsing (`"S(K(SI))K"`, `λ`-syntax) and
  minimal-parenthesis printing.
- Normal-order (leftmost-outermost) reduction: `reduced()`, the lazy
  `reductions` sequence, and bounded `normalize(maxSteps:)` — total, because
  terms like `Ω` never terminate.
- Bracket abstraction (`Term.lambda`/`Term.abstract`) with the η-rule, into
  either basis: the classic SKI translation or Curry's BCKW one.
- `Basis` — `.ski`, `.bckw`, `.iota` and the one-point `.x`, with
  `rewritten(in:)` to translate any term into a single basis and
  `isExpressed(in:)` to check membership.
- Iota and Jot codecs — `Term(iota:)`/`iotaEncoding` for the `*FG` prefix
  language and `Term(jot:)`/`jotEncoding` for the binary Gödel numbering.
- A prelude: `M`, `Y`, Church booleans, numerals and pairs, plus decoders
  (`booleanValue()`, `naturalValue()`) to read results back.
- The aviary — all 46 birds of *To Mock a Mockingbird* as named terms, from
  `bluebird` to `theta`, each obeying its law under test.

## Requirements

Swift 6.0 or later.

```sh
swift build
swift test
```

## License

[MIT](LICENSE). Copyright (c) 2026 Dan Kogai.
