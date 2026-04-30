# PolyCDS

A research-stage clinical decision support framework where guidelines
live as composable categorical artifacts. Built on
[Poly.jl](../Polynomial); modeled in the category of polynomial
functors **Poly**.

The aesthetic: **CDS as data**. A clinical guideline isn't an
imperative program with hard-coded routing — it's a single algebraic
object whose internal coherence (does it self-contradict?) is
established at construction time, not by case-by-case audit.

---

## What this is, for non-mathematicians

Imagine you're building software that helps a doctor work through a
patient's case. The doctor walks in with a chief complaint (chest
pain, shortness of breath, fatigue, etc.). The software has to:

- Suggest the right tests to order
- Interpret the results as they come back
- Update the differential diagnosis (which conditions are still in
  play vs. ruled out)
- Track what's been tried and what's left

Most clinical decision support is built imperatively — `if/else`
branches, look-up tables, bespoke routing logic per guideline. That
makes guidelines hard to verify ("does this guideline ever
contradict itself?"), hard to compose ("what happens when the patient
has two conditions being worked up at once?"), and hard to evolve
("what's the right place to add a new finding?").

PolyCDS takes a different approach. Each guideline is a **single
mathematical object**. Two guidelines combine via a
mathematical operation (a "tensor product") — there's no
orchestration code coordinating them. If you can build the object,
the framework guarantees it's internally coherent. If you can't, the
construction fails with a precise diagnostic.

The mathematical structures involved (polynomial functors,
bicomodules, fibrations) are tools from category theory. They give
us *one place* to express each pattern in clinical reasoning:

| Clinical concept | Mathematical structure |
|---|---|
| The patient's evolving state | A coalgebra (system that produces observations over time) |
| The protocol's planned sequence of orders | A category (objects = orders, morphisms = "what comes next") |
| The bridge between observations and recommendations | A bicomodule (sits between two categories) |
| The chief complaint at intake | A "generator" of the patient-history category |
| The differential diagnosis at any time | A projection from a total space |
| "Considered & ruled out" vs. "never on the differential" | The trajectory through the total space (not the snapshot) |

The last one is the most subtle and the most clinically meaningful.
A patient with HF ruled out yesterday has different downstream
implications than a patient where HF was never considered. PolyCDS
captures this distinction structurally — it's a property of the
*history* of the encounter, not the current snapshot. (This is a
direct reflection of Friedman's [Fundamental Theorem of Biomedical
Informatics](https://academic.oup.com/jamia/article-pdf/16/2/169/49951/16-2-169.pdf):
the value of a CDS lies in the partnership / interaction
trajectory between clinician and information resource, not in the
data alone.)

If you want to play with the framework without engaging with the
math, the `examples/demo.jl` file walks through a two-disease
scenario end-to-end with output you can read top-to-bottom. The
mathematical content is in the *types* and *constructions*; the
runtime behavior is conventional simulation code.

---

## Why categorical?

Most CDS frameworks pay the same costs we mentioned (verification,
composition, evolution) because they conflate *what a guideline
says* with *how it's run*. A guideline's clinical content is
algebraic — phenotypes, tests, recommendations, and the rules
relating them. But it usually gets serialized into ad-hoc code that
makes those rules invisible.

Polynomial functors are a discrete-mathematical structure that
naturally encodes "input/output systems with branching." Bicomodules
are how two such systems share an interface (in our case: the
patient-side observation interface and the protocol-side
recommendation interface). The math has been worked out by
[Niu and Spivak](https://topos.site/poly-book.pdf) in *Polynomial
Functors: A Mathematical Theory of Interaction*, and Poly.jl
implements the constructive content faithfully. PolyCDS is what
happens when you commit to that vocabulary all the way through a
clinical-decision-support stack.

The payoff:

- **Coherence by construction.** A guideline that fails to be a
  proper bicomodule won't compile. The bicomodule axioms encode
  "result-routing agrees with planned-order pathway" — they're a
  precise version of "the guideline doesn't contradict itself."
- **Composition without orchestration.** Two guidelines combine via
  formal tensor product. There's no glue code. The result is a
  guideline; it composes again.
- **Visit-history as first-class structure.** v1.6.B introduces
  a fibration over a patient-history category, so clinical
  context (problem-list state, prior visits) shapes the
  active-DDx without ad-hoc gating.

---

## Mathematical foundation

The framework's structure is documented in detail in
[`docs/PolyCDS_categorical_foundations.md`](docs/PolyCDS_categorical_foundations.md).
Brief table of contents:

- **Part I — Underlying machinery.** Polynomial functors, the
  composition tensor `◁`, comonoids, bicomodules, cofree
  comonoids and sub-cofree.
- **Part II — Disease-level bicomodules (v1.x).** The patient-state
  comonoid `S_d`, the protocol algebra `P_d`, the assessment
  bicomodule `A_d`, the two coactions `λ` and `ρ`. Bicomodule axioms
  as guideline coherence (key insight). Computable phenotypes.
  Paths-as-directions.
- **Part III — v1.x design rationale.** Memory in `A` not `S`.
  Sub-cofree vs full cofree. The codomain-matching rule for
  `sharp_R`. The disease-combination story (× → formal ⊗).
- **Part IV — Patient history (v1.6.B).** Disease-vs-problem
  ontology. The problem vocabulary `Σ_prob`. The list-state
  coalgebra `Q` (post-2026-04-30 toggle reframe: `Q = y^Σ_prob`).
  The history category `H`.
- **Part V — The fibration.** `realize` and `cc_realize`. The
  derived `S → H` quotient `Θ`. The contravariant pseudofunctor
  `A : H^op → Bicomod`. The Grothendieck total space `∫A`.
  Two-level dynamics (vertical = within-fiber observations;
  horizontal = problem-list-changing events).
- **Part VI — Chief complaints and DDx.** CC as `H`-generator.
  DDx as projection from `∫A`. The "considered & ruled out" vs
  "never on DDx" distinction recovered from the trajectory.
- **Part VII — Coherence properties.** Foundational (the
  bicomodule axioms — non-optional, enforced by construction).
  Optional (lattice-ness, universality, op-equivalence —
  per-protocol).
- **Part VIII — Authoring surface.** What protocol authors write
  in markdown + YAML. What the framework derives.
- **Part IX — Implementation status.** v1.0 → v1.6.B history,
  v1.7/v1.8 roadmap.

### Two presentations of the v1.6.B fibration

The fibration `A : H^op → Bicomod` admits two equivalent
presentations (related by Grothendieck's theorem on indexed/fibered
categories), both implemented in the codebase:

- **(δ) Grothendieck total space `∫A`** — a single category whose
  objects are `(h, a)` pairs and whose morphisms are typed
  `vertical` (within fiber) or `horizontal` (between fibers).
  Construction is eager at protocol-load. This is what runtime
  consumers (DDx projection, simulator) operate on.
- **(β) Per-fiber strict sub-Bicomodule `A_h`** — for each `h ∈
  Ob(H)`, `A_h` is a Bicomodule with sub-bases `(S_h, P_h)`. This is
  a real Poly.jl `Bicomodule` and slots into Poly.jl's monoidal
  operations directly. Construction is lazy: paid only for fibers
  that external composition (v1.7+) actually touches.

`validate_grothendieck_pointwise` checks that the two presentations
agree pointwise on the materialized fibers — coherence as an
enforced contract rather than a documented assumption.

---

## Technical considerations

A few non-obvious decisions worth knowing about, especially if
you're extending the framework.

### The toggle reframe (v1.6.B, 2026-04-30)

The problem-list coalgebra `Q` was originally specified with
positions parameterized by `(op, problem)` for `op ∈ {add, remove,
escalate, resolve}`. This required validity-restricted enabled-relation
semantics (multi-valued `σ`), and made `H = cofree(Q)` non-trivial
to derive.

Reframing `Q` as the representable polynomial `y^Σ_prob` (single
position, problem-tokens as **directions**) makes `σ` a strict total
function (toggle: add the token if absent, remove if present). The
op-distinction is recoverable from context — at any state `x`,
direction `p` is a clinically-named "add" if `p ∉ x`, "remove" if
`p ∈ x`. Cofree-on-`Q`-rooted-at-`∅` then yields `H` directly without
custom path-category construction.

`escalate` and `resolve` return when the deferred problem-internal
coalgebra arrives — not as ops on `Q`, but as direction-set
extensions of *per-problem* polynomials.

### Path-discriminating ∫A with bounded composition

`∫A` is constructed with **path-discriminating** morphisms — distinct
sequences of token-toggles between two fibers are distinct
`H`-morphisms (not quotiented to canonical sorted-symdiff). This
preserves clinical trajectory information that snapshot-only models
discard.

The catch: full categorical closure under composition is unbounded
(you can always toggle a token and toggle it back, producing
arbitrarily long round-trip paths). PolyCDS ships with **partial
closure**: compositions whose combined `H`-path length exceeds
`intA_depth` (default 2) are silently skipped. The category is
closed under compositions of bounded length; longer compositions
exist in principle but aren't materialized in the SmallCategory.

For v1.6.B's load-bearing consumers (DDx projection, simulator's
single-step dynamics, `validate_grothendieck_pointwise`), this
partial closure is sufficient — no consumer traverses arbitrary-length
compositions. If trajectory analytics later need full closure, lift
the bound or use `H_quot` (canonical-only paths).

### Lazy β-side, eager δ-side

Building per-fiber strict sub-Bicomodules eagerly at protocol-load
proved intractable: the bottleneck is `cached_to_category(S_joint)`
on v1.x's joint comonoids, where the joint duplicator is evaluated
pointwise via the formal-`⊗` formula on every direction call (>3
minutes for the first call).

The framework now constructs `∫A` (δ-side) eagerly and leaves
per-fiber Bicomodules (β-side) as lazy materializations. Internal
consumers (DDx, simulator, runtime checks) use only `∫A`. β-side
materializes only when external composition (v1.8 shared-objective
library) or opt-in `validate_grothendieck_pointwise` asks. The
`fiber_bicomodule(fa, h)` accessor populates a cache on first call.

### The fiber predicate and the fundamental theorem

The fiber predicate `is_h_compatible(h, (s_D1, s_D2))` requires
`restrict_to_disease(h, d) ⊆ realize(d, s_d)` for each disease — the
disease-`d` slice of `h` must be a subset of the position's
realize-content.

This predicate intentionally **cannot distinguish** "considered &
ruled out" from "never on DDx" at the fiber level — the distinction
lives in the patient's trajectory through `∫A`, not in any snapshot.
This is a structural reflection of Friedman's *Fundamental Theorem
of Biomedical Informatics* (Friedman 2009): the value of a CDS lies
in the *partnership* — the interaction trajectory — not in the data
snapshot alone. Empty `A_h` at runtime is itself a meaningful signal
(an incoherent `h` has no compatible positions; the framework
surfaces this rather than masking it).

### Strict-coherence-on-fiber-crossings

When `h` grows from `h_1` to `h_2` along an `H`-morphism, the
current within-fiber position `a` must already lie in the smaller
`A_h_2`. If `a ∉ A_h_2(1)`, the framework rejects the update.
Out-of-band updates ("oh, the patient also has CKD that wasn't on
our radar") are protocol-author bugs — to be either anticipated by
the protocol or treated as out-of-scope. **No silent rebase.**

---

## Repo layout

```
src/
  PolyCDS.jl              — module entry point
  Vocabulary.jl           — observation, order, phenotype symbol tables; per-disease A-states
  ProblemVocabulary.jl    — Σ_prob (problem alphabet), ListState, toggle, disease namespaces
  Polynomials.jl          — observation polynomials; Q = y^Σ_prob; σ coalgebra
  Protocol.jl             — Protocol IR types
  ProtocolCompile.jl      — compile_protocol → CompiledProtocol; D{k}_compiled
  ProtocolDoc.jl          — markdown ProtocolDoc parser → Protocol struct (v1.4)
  Carrier.jl              — A_Dk_carrier (computable phenotypes as positions)
  Bicomodule.jl           — S_Dk sub-cofree, P_Dk free protocol-category, A_∅ joint bicomodule
  History.jl              — patient-history category H (path + state-quotient views)
  Realize.jl              — cc_realize / realize maps + handover coherence checks
  Theta.jl                — derived S→H quotient functor Θ; cc_fire (H-generator)
  Fiber.jl                — is_h_compatible predicate, ∫A SmallCategory, lazy β-fibers,
                            FiberedAssessment, reindexing, ∫A enumerators,
                            validate_grothendieck_pointwise
  DDx.jl                  — differential diagnosis projection from ∫A
  Render.jl               — text-mode wiring-diagram prints (v1.4)
  Patient.jl              — patient as a section of p_obs (struct + respond)
  Simulate.jl             — joint-bicomodule driver with two-level dynamics tracking
test/
  runtests.jl             — main test entry
  test_v11_joint_bicomodule.jl     — joint construction + validation (v1.1)
  test_v12_freep.jl                — free-P + sharp_R well-definedness (v1.2)
  test_v13_compiler_equivalence.jl — Protocol IR + compiler equivalence (v1.3, deleted in v1.6.B)
  test_v14_protocoldoc.jl          — ProtocolDoc round-trip (v1.4)
  test_v15_viz.jl                  — viz layer smoke tests (v1.5)
  test_v16b_pr1.jl                 — v1.6.B PR 1: vocabulary, Q, σ, realize, Θ, History
  test_v16b_pr2.jl                 — v1.6.B PR 2: fibration, ∫A, DDx, cc_fire, two-level dynamics
examples/
  demo.jl                 — sequential vs panel side-by-side runs
  show_renders.jl         — exercise every render function
protocols/
  D1.md                   — sample protocol (diabetes-shaped, screen-then-confirm)
  D2.md                   — sample protocol (anemia-shaped)
renders/                  — auto-generated text/markdown protocol artifacts
docs/
  PolyCDS_categorical_foundations.md — full categorical foundations (definitive reference)
  historical/
    v11_categorical_summary.md       — v1.1 design retrospective (archived)
```

---

## Quick start

PolyCDS loads `Poly.jl` from a sibling repo path
(`..\..\Polynomial\src\Poly.jl`). Clone both adjacent:

```
$WORKSPACE/
  Polynomial/    (Poly.jl checkout)
  Poly_CDS/      (this repo)
```

Then from the PolyCDS repo:

```sh
julia --project=. test/runtests.jl
```

For the demo:

```sh
julia --project=. examples/demo.jl
```

---

## Status

- **v1.1** (origin/main, 2026-04-28) — sub-cofree S, joint via formal
  Bicomodule ⊗, mode-parameterized simulator. 31 tests.
- **v1.2** (origin/main, 2026-04-29) — free protocol-category P with
  length-≥2 composites distinct; bicomodule compatibility axiom now
  does substantive coherence work.
  `validate_bicomodule_detailed` passing is a non-trivial
  guideline-coherence certificate.
- **v1.3** (origin/main, 2026-04-29) — Protocol IR + compiler;
  paths-as-directions cutover; per-disease bicomodules slimmed to
  aliases of compiled output.
- **v1.4** (origin/main, 2026-04-29) — ProtocolDoc parser
  (markdown + YAML); sample protocols `protocols/D1.md`,
  `protocols/D2.md`; round-trip parse/compile.
- **v1.5** (origin/main, 2026-04-29) — Two-tier viz layer: Mermaid
  for clinician-facing flowcharts, Catlab.jl for categorical wiring
  diagrams.
- **v1.6.A** (origin/main, 2026-04-29) — Chief-complaint
  infrastructure: 5-symptom CC alphabet, `p_chief_complaint`,
  `p_intake`. Additive only.
- **v1.6.B PR 1** (origin/main, 2026-04-30) — H-fibration
  infrastructure: problem vocabulary `Σ_prob`, ListState as
  `Set{Symbol}`, `Q = y^Σ_prob` toggle reframe, `σ` strict toggle
  coalgebra, `realize` / `cc_realize` maps, derived `Θ` quotient,
  patient-history category `H` with path-discriminating + state-
  quotient dual views.
- **v1.6.B PR 2** (local, 2026-04-30) — Fibration: fiber predicate
  `is_h_compatible`, ∫A SmallCategory (δ-side, eager), per-fiber
  strict Bicomodule (β-side, lazy), `FiberedAssessment` struct,
  reindexing + ∫A enumerators, DDx projection (active-workup
  reading), `cc_fire` H-generator, two-level dynamics in simulator
  with `:vertical` / `:horizontal` / `:cc_fire` edge-typing,
  `A_joint → A_∅` rename, `validate_grothendieck_pointwise` (light).
  1251 tests.
- **v1.6.B PR 3** (planned) — ProtocolDoc YAML extension for
  `problem_vocab`, `realize`, `cc_realize` blocks; per-fiber
  validators (`validate_history_quotient`, `validate_fibration`);
  foundations doc deferral entry for the span/comma-category
  formalization.
- **v1.7** (planned) — FHIR substrate. 4-object category
  `C = {Patient, Observation, Practitioner, Condition}`. Phenotype
  migrates from `Bool` tuple into `Condition` instances.
- **v1.8** (planned) — Shared objective library + cross-linked
  workup composition via `⊙` (cross-linked / horizontal
  bicomodule composition).

---

## Further reading

- [`docs/PolyCDS_categorical_foundations.md`](docs/PolyCDS_categorical_foundations.md)
  — the definitive categorical reference for the framework.
- [`docs/historical/v11_categorical_summary.md`](docs/historical/v11_categorical_summary.md)
  — v1.1 design retrospective (archived; superseded by the foundations
  doc but preserved for its dated snapshot voice and the "settled
  choices" / "load-bearing ideas" framings).
- Niu and Spivak, [*Polynomial Functors: A Mathematical Theory of
  Interaction*](https://topos.site/poly-book.pdf) — the mathematical
  foundation for the framework.
- Friedman, C.P. (2009). [*A "Fundamental Theorem" of Biomedical
  Informatics*](https://academic.oup.com/jamia/article-pdf/16/2/169/49951/16-2-169.pdf).
  JAMIA 16(2): 169-170. The structural inspiration for v1.6.B's
  trajectory-vs-snapshot distinction.
