# ============================================================
# v1.6 Phase 2 — V2 master-D renderer tests
# ============================================================
#
# Smoke tests for the two V2 renderers added to Render.jl:
#   * mermaid_differential — D's f-graph
#   * mermaid_trajectory_v2 — V2 simulator trace

using Test

@isdefined(PolyCDS) || include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS

import .PolyCDS:
    mermaid_differential, mermaid_trajectory_v2,
    D_v2_toy, toy_v2_workup_state,
    simulate_v2, TrajectoryStepV2, Patient_D1, Patient_D2

@testset "v1.6 Phase 2 — V2 renderers" begin

    # ============================================================
    @testset "mermaid_differential — D_v2_toy structure" begin
        m = mermaid_differential(D_v2_toy, toy_v2_workup_state)
        @test m isa String
        # Header
        @test occursin("flowchart LR", m)
        # Should contain at least some expected D-positions
        @test occursin("a_D1_initial, a_D2_initial", m)
        @test occursin("a_D1, a_D2_absent", m)
        # Should contain at least some Σ event labels on edges
        @test occursin("result_o1a_pos", m)
        @test occursin("result_o2b_neg", m)
        # Terminal styling included
        @test occursin("classDef terminal", m)
    end

    # ============================================================
    @testset "mermaid_differential — direction option" begin
        m_lr = mermaid_differential(D_v2_toy, toy_v2_workup_state; direction="LR")
        m_td = mermaid_differential(D_v2_toy, toy_v2_workup_state; direction="TD")
        @test occursin("flowchart LR", m_lr)
        @test occursin("flowchart TD", m_td)
    end

    # ============================================================
    @testset "mermaid_differential — show_terminals=false skips styling" begin
        m = mermaid_differential(D_v2_toy, toy_v2_workup_state;
                                  show_terminals=false)
        @test !occursin("classDef terminal", m)
    end

    # ============================================================
    @testset "mermaid_trajectory_v2 — Patient_D1 sequential" begin
        traj = simulate_v2(Patient_D1; mode=:sequential)
        m = mermaid_trajectory_v2(traj)
        @test m isa String
        @test occursin("flowchart LR", m)
        # Step labels
        @test occursin("step 0", m)
        @test occursin("step $(traj[end].step)", m)
        # σ events appear on edges
        @test occursin("result_o1a_pos", m)
        # Terminal step is styled
        @test occursin("classDef terminal", m)
        # The final step's node is in the terminal class
        @test occursin("class t$(traj[end].step) terminal", m)
    end

    # ============================================================
    @testset "mermaid_trajectory_v2 — panel mode with multi-σ edges" begin
        traj = simulate_v2(Patient_D1; mode=:panel)
        m = mermaid_trajectory_v2(traj)
        # Panel step 1 has 3 σ firings; render should join with <br/>
        @test occursin("result_o1a_pos<br/>result_o1b_pos", m) ||
              occursin("result_o1b_pos<br/>result_o1a_pos", m) ||
              occursin("<br/>result_o1a_pos", m) ||  # any ordering with multi-σ separator
              occursin("<br/>result_o1b_pos", m)
    end

    # ============================================================
    @testset "mermaid_trajectory_v2 — empty trajectory returns header only" begin
        m = mermaid_trajectory_v2(TrajectoryStepV2[])
        @test m == "flowchart LR"
    end

end
