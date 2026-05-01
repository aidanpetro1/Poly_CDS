"""
    test/runtests.jl  (v1.6 — V2 master-D)

Tests for PolyCDS V2 master-D architecture: a single Differential
bicomodule `D : O ⇸ P` with the (b)-flavored coherence axiom (post-σ
readout consistency) replacing the v1.x A : S ⇸ P + per-disease ⊗
construction.

Phase 3 cleanup (2026-05-01) removed all v1.x scaffolding
(A_D1_bicomodule, A_joint, ProtocolCompile, Simulate, Σ_prob, History,
toggle, etc.) and the corresponding tests. Surviving tests cover the
V2 stack only:

  * Differential struct + OComonoid + axiom validator
  * V2 simulator (sequential + panel)
  * V2 renderers (mermaid_differential + mermaid_trajectory_v2)
  * V2 compiler (Protocol IR → Differential)

Run with:
    julia --project=. test/runtests.jl
"""

using Test

include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS

@testset "PolyCDS V2 master-D" begin

    # v1.6 Phase 1 — Differential (V2 master-D) scaffolding. Data shape
    # for D : O ⇸ P, the (b)-flavored V2 coherence-axiom validator,
    # plus the D1/D2 toy port.
    include(joinpath(@__DIR__, "test_v16_differential.jl"))

    # v1.6 Phase 2 — V2 master-D simulator (simulate_v2 driving
    # D_v2_toy). Sequential and panel modes.
    include(joinpath(@__DIR__, "test_v16_simulate_v2.jl"))

    # v1.6 Phase 2 — V2 master-D renderers (mermaid_differential for
    # D's f-graph, mermaid_trajectory_v2 for simulator traces).
    include(joinpath(@__DIR__, "test_v16_render_v2.jl"))

    # v1.6 Phase 2 — V2 compiler (Protocol IR → Differential).
    # Compiles D1+D2 protocols into the joint master-D bicomodule.
    include(joinpath(@__DIR__, "test_v16_protocoldoc_v2.jl"))

end
