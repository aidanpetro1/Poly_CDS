# PolyCDS

Clinical Decision Support modeled as polynomial functors and bicomodules
in **Poly**, built on [Poly.jl](../Polynomial). The aesthetic: **CDS as
data** — guidelines as composable categorical artifacts whose internal
coherence is established by construction, not by case-by-case audit.

## The architecture in one paragraph

A CDS guideline lives as a single algebraic object — a bicomodule
$A : S \rightleftharpoons P$ where $S$ is a comonoid encoding observation
histories, $P$ is a comonoid encoding the planned-pathway protocol, and
$A$'s left coaction routes patient-result events into phenotype updates
while its right coaction recommends diagnostic orders. Two guidelines
compose by tensor product: $A_{\text{joint}} := A_{D_1} \otimes A_{D_2}$
*is* the joint CDS, formally — there is no orchestration code mediating
between them.

## Repo layout

```
src/
  PolyCDS.jl        — module entry point
  Vocabulary.jl     — observation, order, phenotype symbol tables
  Polynomials.jl    — observation polynomials (per-disease + joint)
  Carrier.jl        — A_Dk_carrier (computable phenotypes as positions)
  Bicomodule.jl     — S_Dk sub-cofree, P_Dk free protocol-category,
                      mbar_L / mbar_R / sharp_L / sharp_R, A_joint
  Patient.jl        — patient as a section of p_obs (struct + respond)
  Simulate.jl       — joint-bicomodule driver, mode = :sequential | :panel
test/
  runtests.jl                    — main test entry
  test_v11_joint_bicomodule.jl   — joint construction + validation
  test_v12_freep.jl              — free-P + sharp_R well-definedness
examples/
  demo.jl           — sequential vs panel side-by-side runs
```

## Quick start

PolyCDS loads `Poly.jl` from a sibling repo path
(`..\..\Polynomial\src\Poly.jl`). Clone both adjacent:

```
$WORKSPACE/
  Polynomial/    (Poly.jl checkout)
  Poly_CDS/     (this repo)
```

Then from the PolyCDS repo:

```sh
julia --project=. test/runtests.jl
```

For the demo:

```sh
julia --project=. examples/demo.jl
```

## Status

- **v1.1** (origin/main, 2026-04-28) — sub-cofree S, joint via formal
  Bicomodule ⊗, mode-parameterized simulator. 31 tests.
- **v1.2** (local, 2026-04-29) — free protocol-category P with length-≥2
  composites distinct; bicomodule compatibility axiom now does
  substantive coherence work. `validate_bicomodule_detailed` passing
  is a non-trivial guideline-coherence certificate.

## Design references

The categorical structure (cofree $S$, free $P$, the
$\bar m_R[\texttt{:stay}]$ recommendation slot, the codomain-matching
rule for $\sharp_R$, lazy-substitution as the load-bearing dependency)
is documented in source-comments alongside the code that uses it.
Start at `src/Bicomodule.jl` for the bicomodule architecture.
