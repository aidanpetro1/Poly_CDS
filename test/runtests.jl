"""
    test/runtests.jl  (v1.2)

Tests for PolyCDS v1.2: per-disease cofree-S bicomodules + free protocol-P
(length-≥2 composites distinct) + joint via Bicomodule ⊗. Under v1.2's
free-P, `validate_bicomodule_detailed` is a NON-TRIVIAL coherence proof
on each guideline (v1.1's discrete-P made the axioms hold vacuously).

Uses validate_*_detailed companions throughout
(per the v0.2.0 design — see project_polycds_coherence.md).

Run with:
    julia --project=. test/runtests.jl
"""

using Test

include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS
using .PolyCDS.Poly:
    validate_bicomodule, validate_bicomodule_detailed,
    validate_comonoid, validate_comonoid_detailed,
    cardinality, Finite

import .PolyCDS:
    p_o1a, p_D1_obs, p_D2_obs, p_obs,
    A_D1_carrier, A_D2_carrier, A_carrier,
    S_D1, S_D2, P_D1, P_D2,
    A_D1_bicomodule, A_D2_bicomodule,
    Patient_D1, Patient_D2, Patient_neither,
    simulate

@testset "PolyCDS v1.2" begin

    @testset "Polynomial structure" begin
        # Atomic obs are y² each
        @test cardinality(p_o1a.positions) == Finite(1)
        # Per-disease via flat coproduct
        @test cardinality(p_D1_obs.positions) == Finite(2)
        @test cardinality(p_D2_obs.positions) == Finite(3)
        # Joint via Cartesian
        @test cardinality(p_obs.positions) == Finite(6)
    end

    @testset "Carrier shapes — 5 phenotypes per disease, 25 joint" begin
        @test cardinality(A_D1_carrier.positions) == Finite(5)
        @test cardinality(A_D2_carrier.positions) == Finite(5)
        @test cardinality(A_carrier.positions) == Finite(25)
    end

    @testset "Comonoid laws hold (sub-cofree S, free-P, both per-disease)" begin
        @test validate_comonoid(S_D1)
        @test validate_comonoid(S_D2)
        @test validate_comonoid(P_D1)
        @test validate_comonoid(P_D2)
    end

    @testset "Per-disease bicomodule laws (non-trivial under free-P)" begin
        # In v1.2 with free-P (length-≥2 composites distinct), the
        # bicomodule compatibility axiom does substantive work — a
        # passing validate_bicomodule is the "guideline coherence"
        # certificate (project_polycds_coherence.md).
        @test validate_bicomodule(A_D1_bicomodule)
        @test validate_bicomodule(A_D2_bicomodule)
    end

    # v1.2 free-P specific tests: shape, sharp_R well-definedness, and
    # the codomain-matching disambiguation rule.
    include(joinpath(@__DIR__, "test_v12_freep.jl"))

    # v1.4 ProtocolDoc parser — round-trip from markdown + parse-time
    # cross-reference validation.
    include(joinpath(@__DIR__, "test_v14_protocoldoc.jl"))

    # v1.5 viz layer — Mermaid flowcharts + Catlab WiringDiagrams.
    include(joinpath(@__DIR__, "test_v15_viz.jl"))

    # v1.6.B PR 1 — H-fibration infrastructure (Q toggle, σ, realize, Θ, H).
    # Tests the path-discriminating + state-quotient duality for H, plus
    # cc_realize/realize handover coherence.
    include(joinpath(@__DIR__, "test_v16b_pr1.jl"))

    # v1.6.B PR 2 — comprehensive: fibration + ∫A + DDx + cc_fire +
    # reindexing + two-level dynamics. β-side (per-fiber strict
    # Bicomodule) is lazy and not exercised here.
    include(joinpath(@__DIR__, "test_v16b_pr2.jl"))

    # Joint bicomodule via formal Bicomodule ⊗ — A_∅ is a module-level
    # const constructed in Bicomodule.jl as parallel(A_D1_bicomodule,
    # A_D2_bicomodule). Adds ~9s to the test run (construction ≈ 1.4s,
    # validation ≈ 7.7s on v1.1 carriers; v1.2 free-P costs are similar).
    include(joinpath(@__DIR__, "test_v11_joint_bicomodule.jl"))

    @testset "Patient_D1 trajectory (sequential): confirms D1, rules out D2" begin
        traj = simulate(Patient_D1; mode=:sequential)
        final = traj[end].joint_pos
        @test final[1] == :a_D1                            # D1 confirmed
        @test final[2] in (:a_D2_absent_via_o2a,
                           :a_D2_absent_via_o2b)           # D2 ruled out (either way)
    end

    @testset "Patient_D2 trajectory (sequential): rules out D1, confirms D2" begin
        traj = simulate(Patient_D2; mode=:sequential)
        final = traj[end].joint_pos
        @test final[1] in (:a_D1_absent_via_o1a,
                           :a_D1_absent_via_o1b)
        @test final[2] == :a_D2
    end

    @testset "Patient_neither trajectory (sequential): both ruled out" begin
        traj = simulate(Patient_neither; mode=:sequential)
        final = traj[end].joint_pos
        @test final[1] in (:a_D1_absent_via_o1a,
                           :a_D1_absent_via_o1b)
        @test final[2] in (:a_D2_absent_via_o2a,
                           :a_D2_absent_via_o2b)
    end

    @testset "Same final phenotype regardless of mode (sequential vs panel)" begin
        # Both modes are valid trajectories through A_∅; the cofree-S
        # routing structure is mode-agnostic at the destination level.
        # Mode controls path length and observation ordering, not the
        # phenotype reached.
        for patient in (Patient_D1, Patient_D2, Patient_neither)
            traj_seq = simulate(patient; mode=:sequential)
            traj_pan = simulate(patient; mode=:panel)
            @test traj_seq[end].joint_pos == traj_pan[end].joint_pos
        end
    end

    @testset "Panel mode reaches halt in fewer steps than sequential (Patient_D1)" begin
        # Patient_D1 has all D1 obs :pos, so D1 takes a length-2 :panel_pos_pos
        # direction in panel mode (one trajectory step) instead of two
        # consecutive :seq_pos steps.
        traj_seq = simulate(Patient_D1; mode=:sequential)
        traj_pan = simulate(Patient_D1; mode=:panel)
        @test length(traj_pan) < length(traj_seq)
    end

    @testset "Phenotype distinguishes ruled-out-at-screen from ruled-out-at-confirm" begin
        # Patient_D2 has D2 only — under :sequential, D1 is screened
        # negative (o1a returns neg), so D1 is ruled out at SCREEN.
        # Phenotype: a_D1_absent_via_o1a (NOT a_D1_absent_via_o1b).
        traj = simulate(Patient_D2; mode=:sequential)
        @test traj[end].joint_pos[1] == :a_D1_absent_via_o1a
    end

    @testset "TrajectoryStep schema (six columns, list-shaped obs/result)" begin
        traj = simulate(Patient_D1; mode=:sequential)
        # Initial step has empty obs/result lists.
        @test traj[1].step == 0
        @test traj[1].obs_issued == (Symbol[], Symbol[])
        @test traj[1].result == (Symbol[], Symbol[])
        @test traj[1].mode == :sequential
        # Joint order at the initial state is the (:order_o1a, :order_o2a) pair.
        @test traj[1].joint_order == (:order_o1a, :order_o2a)
        # Final step is at a joint terminal; joint_order is (nothing, nothing).
        @test traj[end].joint_order == (nothing, nothing)
    end

end
