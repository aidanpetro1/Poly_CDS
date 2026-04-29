"""
    PolyCDS

Clinical Decision Support (CDS) modeled as polynomial functors and bicomodules,
built on top of `Poly.jl`. The architecture has three intertwined threads, each
of which is a distinct categorical structure on the same observation polynomial
`p_obs = Σ_obs y^{Results(obs)}`:

  1. **Observations comonoid `S`** — `discrete_comonoid` on the event set
     for v1 (with the upgrade path to `cofree_comonoid(p_obs, depth)` flagged
     for a richer v1.1).

  2. **Patient coalgebra** — a state machine `X → p_obs(X)` representing the
     patient as a result-producing system. Trajectories of patient state are
     observation-result histories.

  3. **FHIR copresheaf** — the patient's data lives in a copresheaf `F : C → Set`
     on the FHIR schema category. Not wired in v1; the patient state is just a
     tiny `struct`. v2 swaps in the copresheaf.

The CDS guideline is a `Bicomodule` `A : S ⇸ P` whose left coaction routes
observation events into interpretations and whose right coaction recommends
diagnostic orders.

Compositional design (per the user's request, 2026-04-27):

  * Each observation is its own polynomial (atomic building block).
  * Each disease's observation polynomial is a coproduct `+` of its
    observation polynomials (clinician picks at each step).
  * The joint observation polynomial is the Cartesian product `×` of the
    per-disease polynomials (independent advancement of D1 and D2).
  * Per-disease assessment carriers are also combined by `×`, giving 16
    joint interpretation positions (4 D1 × 4 D2).

See `examples/demo.jl` for the runnable end-to-end story.
"""
module PolyCDS

# Load Poly.jl from the sibling repo. Adjust this path if your checkout
# lives elsewhere.
const POLY_JL_PATH = joinpath(@__DIR__, "..", "..", "Polynomial", "src", "Poly.jl")
isfile(POLY_JL_PATH) || error("PolyCDS: cannot find Poly.jl at $POLY_JL_PATH")
include(POLY_JL_PATH)
using .Poly

# Re-export the Poly names users will reach for.
export Poly

# Component modules.
include("Vocabulary.jl")
include("Polynomials.jl")
include("Carrier.jl")
include("Bicomodule.jl")
include("Patient.jl")
include("Simulate.jl")

end # module PolyCDS
