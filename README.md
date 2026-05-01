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

You're building software that helps a doctor work through a patient's
case: suggest tests, interpret results, update the differential,
track what's been tried. PolyCDS expresses each guideline as a
**single mathematical object** (a `Differential` bicomodule). Two
guidelines combine via a tensor product — there's no orchestration
code coordinating them. If the object can be built and validated, the
framework guarantees it's internally coherent.

The mathematical structures (polynomial functors, comonoids,
bicomodules) give us *one place* to express each pattern in clinical
reasoning:

| Clinical concept | Mathematical structure |
|---|---|
| The patient's evolving observation log | A comonoid `O = cofree(Q, depth)` |
| The protocol's recommendation alphabet | A free comonoid `P = ⊗_d P_d` |
| The bridge between observations and recommendations | A bicomodule `D : O ⇸ P` (the `Differential`) |
| The differential diagnosis at any time | A `D`-position (joint per-disease epistemic+phenotype state) |
| Order-dependent reasoning | Distinct `D`-positions, named explicitly |

`examples/demo.jl` walks through a two-disease scenario end-to-end.

---

## Architecture (V2 master-D)

A single bicomodule `D : O ⇸ P`:

- **`O`** — observation comonoid, `cofree(Q, depth)` over the
  observation-event alphabet `Σ_obs_v2`. The `OComonoid` struct is the
  V2 parameter wrapper; `as_comonoid(O)` materializes a real Poly.jl
  `Comonoid` via `cofree_comonoid(Q, depth)` for use with the
  categorical machinery (`validate_comonoid`, comodule construction,
  v1.7+ Kan-extension queries).
- **`P`** — joint protocol comonoid, `⊗_d P_d` per-disease (free
  category on each per-disease protocol graph). `as_protocol_comonoid(pd)`
  materializes each per-disease `P_d` as a real Poly.jl `Comonoid` via
  `from_category` on the SmallCategory presentation.
- **`D`** — the `Differential` struct. `D`-positions are joint
  disease-frame states (per-disease epistemic + phenotype tags);
  `D`-directions are atomic Σ-events; `f` is the position-forward of
  the left coaction; `emit` follows post-σ readout
  (`emit_p(σ) = workup_state(f_p(σ))`).

`λ_R` is fire-and-forget: emitting a recommendation doesn't move
`D`'s position. The clinical loop closes externally — system-emitted
orders enter the encounter log as Σ-events, which `λ_L` then absorbs.
This makes the system clinical *support*, not a closed-loop decision
machine.

The bicomodule compatibility axiom under post-σ readout reduces to a
structural check: every authored `emit[(p, σ)]` agrees with
`workup_state(f_p(σ))`. `validate_v2_axiom(D, workup_state)` runs
this check.

---

## Repo layout

```
src/
  PolyCDS.jl              — module entry point
  Vocabulary.jl           — observation/order/phenotype symbol tables
  Polynomials.jl          — per-disease observation polynomials
  Protocol.jl             — Protocol IR types + per-disease const protocols
  ProtocolDoc.jl          — markdown ProtocolDoc parser → Protocol
  Differential.jl         — OComonoid, Differential, validate_v2_axiom, toy D
  ProtocolCompileV2.jl    — compile_protocol_v2, compose_differentials_2
  Render.jl               — Mermaid renderers (mermaid_differential, mermaid_trajectory_v2)
  Patient.jl              — Patient struct + respond + demo patients
  SimulateV2.jl           — simulate_v2 (sequential + panel modes)
test/
  runtests.jl
  test_v16_differential.jl       — Differential + OComonoid + validator
  test_v16_simulate_v2.jl        — V2 simulator
  test_v16_render_v2.jl          — V2 renderers
  test_v16_protocoldoc_v2.jl     — V2 compiler (Protocol IR → Differential)
examples/
  demo.jl                 — end-to-end runnable demo
  show_renders.jl         — generate the Mermaid render artifacts
protocols/
  D1.md, D2.md            — sample per-disease ProtocolDoc files
renders/                  — auto-generated render outputs
docs/
  PolyCDS_categorical_foundations.md — categorical foundations reference
```

---

## Quick start

PolyCDS loads `Poly.jl` from a sibling repo path
(`..\..\Polynomial\src\Poly.jl`). Clone both adjacent:

```
$WORKSPACE/
  Polynomial/
  Poly_CDS/
```

Then from the PolyCDS repo:

```sh
julia --project=. test/runtests.jl
julia --project=. examples/demo.jl
julia --project=. examples/show_renders.jl
```

---

## Further reading

- [`docs/PolyCDS_categorical_foundations.md`](docs/PolyCDS_categorical_foundations.md)
  — categorical foundations reference, rewritten for V2 master-D.
- Niu and Spivak, [*Polynomial Functors: A Mathematical Theory of
  Interaction*](https://topos.site/poly-book.pdf) — mathematical
  foundation for the framework.
- Friedman, C.P. (2009). [*A "Fundamental Theorem" of Biomedical
  Informatics*](https://academic.oup.com/jamia/article-pdf/16/2/169/49951/16-2-169.pdf).
  JAMIA 16(2): 169-170. The structural inspiration for representing
  CDS as an interaction trajectory rather than a snapshot.
