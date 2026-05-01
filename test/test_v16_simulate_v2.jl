# ============================================================
# v1.6 Phase 2 — V2 master-D simulator tests
# ============================================================
#
# Verifies simulate_v2 drives D_v2_toy correctly under both
# sequential and panel modes, parallel to the v1.x simulator's
# behavior on the same patients.

using Test

@isdefined(PolyCDS) || include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS

import .PolyCDS:
    simulate_v2, TrajectoryStepV2, print_trajectory_v2,
    Patient_D1, Patient_D2, Patient_neither

@testset "v1.6 Phase 2 — simulate_v2 (V2 master-D simulator)" begin

    # ============================================================
    @testset "Patient_D1 (sequential): D1 confirmed, D2 ruled out" begin
        traj = simulate_v2(Patient_D1; mode=:sequential)
        final = traj[end]
        @test final.p == (:a_D1, :a_D2_absent)
        @test final.workup_state == (:disease_D1_present, :disease_D2_absent)
    end

    # ============================================================
    @testset "Patient_D2 (sequential): D1 ruled out, D2 confirmed" begin
        traj = simulate_v2(Patient_D2; mode=:sequential)
        final = traj[end]
        @test final.p == (:a_D1_absent, :a_D2)
        @test final.workup_state == (:disease_D1_absent, :disease_D2_present)
    end

    # ============================================================
    @testset "Patient_neither (sequential): both ruled out" begin
        traj = simulate_v2(Patient_neither; mode=:sequential)
        final = traj[end]
        @test final.p == (:a_D1_absent, :a_D2_absent)
    end

    # ============================================================
    @testset "Sequential vs panel reach the same final state" begin
        # Mode controls path length and ordering, not destination.
        for patient in (Patient_D1, Patient_D2, Patient_neither)
            traj_seq = simulate_v2(patient; mode=:sequential)
            traj_pan = simulate_v2(patient; mode=:panel)
            @test traj_seq[end].p == traj_pan[end].p
        end
    end

    # ============================================================
    @testset "Panel reaches halt in fewer steps for Patient_D1" begin
        # Patient_D1 has positive D1 screen, so panel mode fires
        # screen + immediate confirm in one step (2 σ firings).
        # That collapses D1's two-step sequential workup into one.
        traj_seq = simulate_v2(Patient_D1; mode=:sequential)
        traj_pan = simulate_v2(Patient_D1; mode=:panel)
        @test length(traj_pan) < length(traj_seq)
    end

    # ============================================================
    @testset "TrajectoryStepV2 shape and σ recording" begin
        traj = simulate_v2(Patient_D1; mode=:sequential)
        # Step 0 is initial — no transitions yet
        @test traj[1].step == 0
        @test isempty(traj[1].sigma_events)
        @test traj[1].p == (:a_D1_initial, :a_D2_initial)
        @test traj[1].workup_state == (:order_o1a, :order_o2a)
        # Step 1 should record exactly one σ (sequential)
        @test traj[2].step == 1
        @test length(traj[2].sigma_events) == 1
        # First σ for Patient_D1 sequential is :result_o1a_pos
        @test traj[2].sigma_events == [:result_o1a_pos]
        @test traj[2].p == (:a_D1_pending, :a_D2_initial)
    end

    # ============================================================
    @testset "Panel mode fires 2 σ on positive screen" begin
        # Patient_D1's first panel step: D1 screen :pos → confirm fires
        # immediately. Records 2 σ in the first trajectory step.
        traj = simulate_v2(Patient_D1; mode=:panel)
        # Step 1 advances both D1 (panel: 2 σ for pos screen) and D2
        # (panel: 1 σ for neg screen) → 3 σ total in this step.
        @test length(traj[2].sigma_events) == 3
        # D1 fires :result_o1a_pos then :result_o1b_pos
        @test :result_o1a_pos in traj[2].sigma_events
        @test :result_o1b_pos in traj[2].sigma_events
        # D2 fires :result_o2a_neg
        @test :result_o2a_neg in traj[2].sigma_events
    end

    # ============================================================
    @testset "Halt detection: trajectory terminates at joint terminal" begin
        for patient in (Patient_D1, Patient_D2, Patient_neither)
            traj = simulate_v2(patient; mode=:sequential, max_steps=20)
            final = traj[end]
            # Final p has both components terminal (a_D1/a_D1_absent,
            # a_D2/a_D2_absent)
            @test final.p[1] in (:a_D1, :a_D1_absent)
            @test final.p[2] in (:a_D2, :a_D2_absent)
        end
    end

end
