"""
    examples/demo.jl  (v1.6 — V2 master-D)

End-to-end demo of the V2 master-D architecture:
  * `Differential` struct: the master bicomodule `D : O ⇸ P`
  * `OComonoid(Σ_obs_v2, depth)`: left-base observation comonoid
  * Joint disease-frame positions; uniform Σ-event directions
  * `validate_v2_axiom` checks post-σ readout consistency
  * `simulate_v2` drives D's coactions in `:sequential` or `:panel` mode

Run with:
    julia --project=. examples/demo.jl
or from REPL:
    include("examples/demo.jl")
"""

include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS

import .PolyCDS:
    Differential, OComonoid, O_positions, O_directions_at,
    Σ_obs_v2,
    D_v2_toy, toy_v2_workup_state,
    D_v2_compiled, D_v2_compiled_workup,
    validate_v2_axiom,
    Patient, Patient_D1, Patient_D2, Patient_neither,
    simulate_v2, print_trajectory_v2

println("=" ^ 78)
println("PolyCDS V2 — master-D bicomodule  D : O ⇸ P")
println("=" ^ 78)

# ============================================================
# 1. The observation comonoid O
# ============================================================

println("\n--- O = cofree(Q, depth), the encounter-log comonoid ---\n")
O = D_v2_toy.O
println("O.Σ           = ", sort(collect(O.Σ)))
println("O.depth       = ", O.depth)
println("|Σ_obs_v2|    = ", length(Σ_obs_v2))
println()
println("(O-positions are encounter logs in Σ^{≤depth}. O-directions at log w")
println(" are Σ if |w| < depth, else empty. Materialized as `OComonoid` —")
println(" parameter struct; full Poly.jl-backed comonoid deferred to v1.7+.)")

# ============================================================
# 2. The master Differential D_v2_toy
# ============================================================

println("\n--- D_v2_toy (manually-authored 4-state-per-disease toy) ---\n")
println("|D-positions|    = ", length(D_v2_toy.positions),
        "   (4 D1-phenotypes × 4 D2-phenotypes; via_o1a/via_o1b collapsed)")
println("|D.f| (non-id)   = ", length(D_v2_toy.f))
println("|D.emit|         = ", length(D_v2_toy.emit))
println("|P_positions|    = ", length(D_v2_toy.P_positions))

print("\nvalidate_v2_axiom(D_v2_toy, toy_v2_workup_state) = ")
println(validate_v2_axiom(D_v2_toy, toy_v2_workup_state))

# ============================================================
# 3. The compiled Differential D_v2_compiled (from D{1,2}_protocol)
# ============================================================

println("\n--- D_v2_compiled (compiled from D1+D2 protocols, 5 phenotypes/disease) ---\n")
println("|D-positions|    = ", length(D_v2_compiled.positions),
        "   (5 D1-phenotypes × 5 D2-phenotypes; via_o1a/via_o1b distinct)")
println("|D.Σ|            = ", length(D_v2_compiled.O.Σ))
println("|D.f| (non-id)   = ", length(D_v2_compiled.f))

print("\nvalidate_v2_axiom(D_v2_compiled, D_v2_compiled_workup) = ")
println(validate_v2_axiom(D_v2_compiled, D_v2_compiled_workup))
println()
println("(Both D_v2_toy and D_v2_compiled satisfy the axiom by construction,")
println(" since emit is built via post-σ readout. The check would catch any")
println(" authoring drift from the convention.)")

# ============================================================
# 4. Patient trajectories — sequential vs panel
# ============================================================

function run_demo(label, patient, mode)
    println("\n--- $label ---\n")
    println("Patient: $(patient.label)   Mode: $mode")
    traj = simulate_v2(patient; mode=mode)
    print_trajectory_v2(traj)
    final = traj[end]
    println("\nFinal D-position: $(final.p)   workup: $(final.workup_state)   ($(length(traj)) steps)")
end

println("\n" * "=" ^ 78)
println("Patient trajectories — sequential vs panel")
println("=" ^ 78)

run_demo("Patient_D1, mode=:sequential",  Patient_D1,      :sequential)
run_demo("Patient_D1, mode=:panel",       Patient_D1,      :panel)
run_demo("Patient_D2, mode=:sequential",  Patient_D2,      :sequential)
run_demo("Patient_D2, mode=:panel",       Patient_D2,      :panel)
run_demo("Patient_neither, mode=:panel",  Patient_neither, :panel)

println("\n" * "=" ^ 78)
println("Demo complete.")
println("=" ^ 78)
println()
println("V2 architecture summary:")
println("  D : O ⇸ P  — single master bicomodule (the `Differential`)")
println("  O          — cofree(Q, depth), encounter-log comonoid (OComonoid)")
println("  P          — joint protocol comonoid (per-disease P_d via tensor)")
println("  D-positions — joint per-disease epistemic+phenotype tags")
println("  D-directions — atomic Σ_obs_v2 events; sharp_L = path concatenation (implicit)")
println("  emit        — post-σ readout: emit_p(σ) = workup_state(f_p(σ))")
println("  V2 axiom    — emit_p table consistent with workup_state ∘ f")
println()
println("Two simulator modes:")
println("  :sequential — one disease per step, exactly one σ firing")
println("  :panel      — both non-terminal diseases per step; per-disease")
println("                screen-positive fires confirm too (2 σ in one step)")
