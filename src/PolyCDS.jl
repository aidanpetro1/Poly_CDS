"""
    PolyCDS

Clinical Decision Support (CDS) modeled as polynomial functors and bicomodules,
built on top of `Poly.jl`. The architecture is V2 master-D (settled 2026-05-01):

A single bicomodule `D : O ⇸ P` represents the joint clinical decision support:

  * `O = cofree(Q, depth)` — the observation comonoid (encounter-log,
    sequence-based; alphabet `Σ_obs_v2`). `OComonoid` struct in `Differential.jl`.

  * `P = ⊗_d P_d` — the joint protocol comonoid; recommendation alphabet drawn
    from the per-disease P_d objects (free protocol-categories per v1.2).

  * `D` (the `Differential` struct) — D-positions are joint disease-frame states
    (per-disease epistemic + phenotype tags); D-directions are atomic Σ events;
    `f` is the position-forward of λ_L; `emit` follows post-σ readout
    (`emit_p(σ) = workup_state(f_p(σ))`).

The chief authoring surface is per-disease `Protocol` IR (in `Protocol.jl`),
parsed from markdown via `ProtocolDoc.jl`, compiled via `ProtocolCompileV2.jl`
into `PerDiseaseV2` records and composed into a joint `Differential`.

The simulator (`SimulateV2.jl`) drives D's coactions via Σ events; the renderer
(`Render.jl`) produces Mermaid flowcharts of D and trajectories.

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

# Component modules (V2 master-D architecture, post Phase 3 cleanup 2026-05-01).
include("Vocabulary.jl")          # observation/order/disease symbol tables
include("Polynomials.jl")         # per-disease p_obs (used by Protocol IR)
include("Protocol.jl")            # Protocol IR types + per-disease Protocol consts
include("ProtocolDoc.jl")         # markdown ProtocolDoc parser → Protocol struct
include("Differential.jl")        # V2 master-D: OComonoid + Differential struct + axiom validator + toy
include("ProtocolCompileV2.jl")   # V2 compiler: Protocol IR → Differential (per-disease + compose)
include("Render.jl")              # V2 renderers: mermaid_differential + mermaid_trajectory_v2
include("Patient.jl")             # Patient coalgebra (respond)
include("SimulateV2.jl")          # V2 simulator over Differential

end # module PolyCDS
