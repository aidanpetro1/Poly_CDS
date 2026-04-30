"""
    examples/demo.jl  (v1.1)

End-to-end demo of the PolyCDS v1.1 architecture:
  * cofree-S as derived universal observations comonoid (per disease)
  * discrete P (v1.1; protocol-on-P deferred to v1.2 — see Bicomodule.jl)
  * 5 hand-crafted phenotypes per disease
  * **joint via formal Bicomodule ⊗** (A_∅, post-2026-04-28 Poly.jl PR)
  * patient as responder; bicomodule's right coaction recommends orders
  * simulator drives A_∅ with mode=:sequential or :panel

Run with:
    julia --project=. examples/demo.jl
or from REPL:
    include("examples/demo.jl")
"""

include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS
using .PolyCDS.Poly: validate_bicomodule, validate_comonoid, cardinality

import .PolyCDS:
    p_o1a, p_D1_obs, p_D2_obs, p_obs,
    A_D1_carrier, A_D2_carrier, A_carrier,
    S_D1, S_D2, P_D1, P_D2,
    A_D1_bicomodule, A_D2_bicomodule, A_∅,
    Patient, Patient_D1, Patient_D2, Patient_neither,
    simulate, print_trajectory

println("=" ^ 78)
println("PolyCDS v1.1 — sub-cofree S, discrete P, phenotype-as-A, formal joint ⊗")
println("=" ^ 78)

# ============================================================
# 1. Polynomial structure (compositional)
# ============================================================

println("\n--- Compositional polynomials ---\n")
println("p_o1a (atomic)              = ", p_o1a)
println("p_D1_obs = coproduct(o1a, o1b) = ", p_D1_obs)
println("p_D2_obs                    = ", p_D2_obs)
println("p_obs = p_D1_obs * p_D2_obs = ", p_obs)
println()
println("|positions(p_obs)|          = ", cardinality(p_obs.positions))

# ============================================================
# 2. Sub-cofree S — derived from p_obs, trimmed to the protocol
# ============================================================

println("\n--- Sub-cofree observations comonoid (S, per disease) ---\n")
println("S_D1 = sub-cofree of cofree(p_D1_obs)")
println("       carrier positions    = ", cardinality(S_D1.carrier.positions))
println("S_D2 = sub-cofree of cofree(p_D2_obs)")
println("       carrier positions    = ", cardinality(S_D2.carrier.positions))
println()
println("(Sub-cofree contains only the protocol-relevant trees — 4 per")
println(" disease — making bicomodule construction tractable. We trade")
println(" cofree's universal property for tractability; see")
println(" project_polycds_coherence.md for the rationale.)")

# ============================================================
# 3. Discrete P (per disease)
# ============================================================

println("\n--- Discrete order comonoid P (per disease, v1.1) ---\n")
println("P_D1 carrier = ", P_D1.carrier)
println("P_D2 carrier = ", P_D2.carrier)
println()
println("(P is discrete in v1.1 — orders are atomic, no protocol structure.")
println(" The 'planned pathway' lives in mbar_R per A-direction. v1.2 will")
println(" promote P to a free protocol-category once we have the matching")
println(" 'extend by length(P-morph) S-steps' rule for sharp_R.)")

# ============================================================
# 4. Phenotype carriers
# ============================================================

println("\n--- Phenotype carriers (A, per disease and joint) ---\n")
println("A_D1_carrier (5 phenotypes) = ", A_D1_carrier)
println("A_D2_carrier (5 phenotypes) = ", A_D2_carrier)
println("|joint phenotypes|          = ", cardinality(A_∅.carrier.positions))

# ============================================================
# 5. Validation — bicomodule axiom = guideline coherence
# ============================================================

println("\n--- Validation ---\n")
print("validate_comonoid(S_D1)             : "); println(validate_comonoid(S_D1))
print("validate_comonoid(S_D2)             : "); println(validate_comonoid(S_D2))
print("validate_comonoid(P_D1)             : "); println(validate_comonoid(P_D1))
print("validate_comonoid(P_D2)             : "); println(validate_comonoid(P_D2))
print("validate_bicomodule(A_D1_bicomodule): "); println(validate_bicomodule(A_D1_bicomodule))
print("validate_bicomodule(A_D2_bicomodule): "); println(validate_bicomodule(A_D2_bicomodule))
print("validate_bicomodule(A_∅)        : "); println(validate_bicomodule(A_∅))
println()
println("All passing means: the joint guideline is internally coherent —")
println("result-driven interpretation updates (left coaction) agree with the")
println("planned-order pathway (right coaction). The joint axioms hold by")
println("Poly.jl's formal Bicomodule ⊗ being faithful to the categorical")
println("definition; we don't hand-verify them ourselves.")

# ============================================================
# 6. Patient trajectories — sequential vs panel
# ============================================================

function run_demo(label, patient, mode)
    println("\n--- $label ---\n")
    println("Patient: $(patient.label)   Mode: $mode")
    traj = simulate(patient; mode=mode)
    print_trajectory(traj)
    final_state = traj[end].joint_pos
    println("\nFinal joint phenotype: $(final_state)   ($(length(traj)) trajectory entries)")
end

println("\n" * "=" ^ 78)
println("Patient trajectories — sequential vs panel")
println("=" ^ 78)

# Same patient, two modes — shows the path-length contrast.
run_demo("Patient_D1, mode=:sequential",  Patient_D1,      :sequential)
run_demo("Patient_D1, mode=:panel",       Patient_D1,      :panel)

# Patient_D2 — D1 ruled out at screen, D2 confirmed via panel.
run_demo("Patient_D2, mode=:sequential",  Patient_D2,      :sequential)
run_demo("Patient_D2, mode=:panel",       Patient_D2,      :panel)

# Patient_neither — both screens neg, panel degenerates to sequential.
run_demo("Patient_neither, mode=:panel (degenerates to seq on screen-neg)",
         Patient_neither, :panel)

println("\n" * "=" ^ 78)
println("Demo complete.")
println("=" ^ 78)
println()
println("v1.1 architecture summary:")
println("  S = sub-cofree_comonoid (derived, universal — patient plugs in formally)")
println("  P = discrete (v1.1; protocol-on-P deferred to v1.2)")
println("  A = 5 hand-crafted phenotypes per disease")
println("  A_∅ = parallel(A_D1_bicomodule, A_D2_bicomodule)")
println("          = formal Bicomodule ⊗ (categorical ground truth, not")
println("            orchestration code)")
println("  Bicomodule axiom = guideline internal coherence")
println()
println("Two simulator modes drive the same A_∅:")
println("  :sequential — one disease at a time, single tests (~3-4 steps)")
println("  :panel      — both diseases at once, length-2 panel directions")
println("                when screens are positive (~1-2 steps)")
println("Both reach the same final joint phenotype; mode controls path length")
println("and observation ordering, not the destination.")
