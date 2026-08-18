# swift-combinators

Combinator calculus in Swift — the [SKI combinator calculus](https://en.wikipedia.org/wiki/SKI_combinator_calculus) and Curry's [BCKW system](https://en.wikipedia.org/wiki/B,_C,_K,_W_system).

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
```

`:help` lists the commands.

## What's inside

- `Term` — an `indirect enum` over the primitives `S K I B C W`, free
  variables and application, with parsing (`"S(K(SI))K"`, `λ`-syntax) and
  minimal-parenthesis printing.
- Normal-order (leftmost-outermost) reduction: `reduced()`, the lazy
  `reductions` sequence, and bounded `normalize(maxSteps:)` — total, because
  terms like `Ω` never terminate.
- Bracket abstraction (`Term.lambda`/`Term.abstract`) with the η-rule, into
  either basis: the classic SKI translation or Curry's BCKW one.
- `Basis` — `.ski` and `.bckw`, with `rewritten(in:)` to translate any term
  into a single basis and `isExpressed(in:)` to check membership.
- A prelude: `M`, `Y`, Church booleans, numerals and pairs, plus decoders
  (`booleanValue()`, `naturalValue()`) to read results back.

## Requirements

Swift 6.0 or later.

```sh
swift build
swift test
```

## License

[MIT](LICENSE). Copyright (c) 2026 Dan Kogai.
