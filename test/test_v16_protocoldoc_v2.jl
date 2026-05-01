# ============================================================
# v1.6 Phase 2 — V2 compiler tests (Protocol IR → Differential)
# ============================================================
#
# Verifies that compile_protocol_v2 + compose_differentials_2 produce
# a coherent V2 master-D from existing v1.x Protocol IRs.

using Test

@isdefined(PolyCDS) || include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS

import .PolyCDS:
    PerDiseaseV2, compile_protocol_v2, compose_differentials_2,
    D1_v2, D2_v2, D_v2_compiled, D_v2_compiled_workup,
    D1_protocol, D2_protocol,
    Differential, validate_v2_axiom,
    as_protocol_smallcategory, as_protocol_comonoid

using .PolyCDS.Poly: SmallCategory, Comonoid, validate_comonoid, cardinality, Finite

@testset "v1.6 Phase 2 — V2 compiler" begin

    # ============================================================
    @testset "compile_protocol_v2 — D1 per-disease shape" begin
        @test D1_v2 isa PerDiseaseV2
        @test D1_v2.disease === :D1
        # 5 phenotypes from v1.x D1_protocol (initial, pending, present,
        # absent_via_o1a, absent_via_o1b)
        @test length(D1_v2.phenotypes) == 5
        @test :a_D1_initial in D1_v2.phenotypes
        @test :a_D1 in D1_v2.phenotypes
        @test :a_D1_absent_via_o1a in D1_v2.phenotypes
        @test :a_D1_absent_via_o1b in D1_v2.phenotypes
    end

    # ============================================================
    @testset "compile_protocol_v2 — workup_state map" begin
        # Internal phenotype → order
        @test D1_v2.workup_state[:a_D1_initial] == :order_o1a
        @test D1_v2.workup_state[:a_D1_pending] == :order_o1b
        # Terminal phenotype → conclusion
        @test D1_v2.workup_state[:a_D1] == :disease_D1_present
        @test D1_v2.workup_state[:a_D1_absent_via_o1a] == :disease_D1_absent
        @test D1_v2.workup_state[:a_D1_absent_via_o1b] == :disease_D1_absent
    end

    # ============================================================
    @testset "compile_protocol_v2 — transition table" begin
        # Screen-positive at initial → pending
        @test D1_v2.transitions[(:a_D1_initial, :result_o1a_pos)] == :a_D1_pending
        # Screen-negative at initial → absent_via_o1a
        @test D1_v2.transitions[(:a_D1_initial, :result_o1a_neg)] == :a_D1_absent_via_o1a
        # Confirm-positive at pending → confirmed
        @test D1_v2.transitions[(:a_D1_pending, :result_o1b_pos)] == :a_D1
        # Confirm-negative at pending → absent_via_o1b
        @test D1_v2.transitions[(:a_D1_pending, :result_o1b_neg)] == :a_D1_absent_via_o1b
    end

    # ============================================================
    @testset "compile_protocol_v2 — Σ_obs contribution" begin
        # 4 Σ events for D1: 2 results × 2 obs (o1a, o1b)
        @test D1_v2.sigma_obs == Set([
            :result_o1a_pos, :result_o1a_neg,
            :result_o1b_pos, :result_o1b_neg,
        ])
        # D2 symmetric
        @test D2_v2.sigma_obs == Set([
            :result_o2a_pos, :result_o2a_neg,
            :result_o2b_pos, :result_o2b_neg,
        ])
    end

    # ============================================================
    @testset "compose_differentials_2 — joint shape" begin
        @test D_v2_compiled isa Differential
        # 25 D-positions = 5 D1-phenotypes × 5 D2-phenotypes
        @test length(D_v2_compiled.positions) == 25
        # 8 Σ events total (4 D1 + 4 D2, disjoint)
        @test length(D_v2_compiled.Σ) == 8
        # Compiled D has more positions than the manually-authored
        # D_v2_toy (16): the via_* distinction is preserved here.
        @test length(D_v2_compiled.positions) > 16
    end

    # ============================================================
    @testset "compose_differentials_2 — joint workup_state" begin
        # At joint terminal positions, joint workup is the per-disease
        # conclusion tuple
        @test D_v2_compiled_workup((:a_D1, :a_D2)) ==
              (:disease_D1_present, :disease_D2_present)
        @test D_v2_compiled_workup((:a_D1_absent_via_o1a, :a_D2_absent_via_o2b)) ==
              (:disease_D1_absent, :disease_D2_absent)
        # At a workup position, both order pointers
        @test D_v2_compiled_workup((:a_D1_initial, :a_D2_initial)) ==
              (:order_o1a, :order_o2a)
    end

    # ============================================================
    @testset "compose_differentials_2 — joint transitions" begin
        # σ on D1 only moves the D1 component
        p = (:a_D1_initial, :a_D2_pending)
        @test D_v2_compiled.f[(p, :result_o1a_pos)] == (:a_D1_pending, :a_D2_pending)
        # σ on D2 only moves the D2 component
        @test D_v2_compiled.f[(p, :result_o2b_neg)] == (:a_D1_initial, :a_D2_absent_via_o2b)
    end

    # ============================================================
    @testset "Compiled V2 D — V2 axiom holds" begin
        # The compiled D follows post-σ readout (emit derived from f
        # via joint workup_state), so the (b)-flavored validator passes.
        @test validate_v2_axiom(D_v2_compiled, D_v2_compiled_workup)
    end

    # ============================================================
    # Poly.jl-backed per-disease P_d as a real Comonoid
    # ============================================================

    @testset "as_protocol_smallcategory — D1 produces a SmallCategory" begin
        cat = as_protocol_smallcategory(D1_v2)
        @test cat isa SmallCategory
        # Objects: 4 distinct workup-state pointers (order_o1a, order_o1b,
        # disease_D1_present, disease_D1_absent)
        @test cardinality(cat.objects) == Finite(4)
        # Identities exist for every object
        for o in cat.objects.elements
            @test haskey(cat.identity, o)
        end
    end

    @testset "as_protocol_comonoid — D1 produces a valid Poly.Comonoid" begin
        # Per-disease P_d as a real Poly.jl Comonoid.
        # Coassoc holds for the truncated free category at max_path_length=3.
        P_D1_v2 = as_protocol_comonoid(D1_v2; max_path_length=3)
        @test P_D1_v2 isa Comonoid
        @test validate_comonoid(P_D1_v2)
    end

end
