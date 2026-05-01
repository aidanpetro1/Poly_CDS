# ============================================================
# v1.6 Phase 1 — Differential (V2 master-D) scaffolding tests
# ============================================================
#
# Smoke tests for the V2 master-D data shape and (b)-flavored axiom
# validator (D-directions = paths through O, sharp_L = implicit
# concatenation, emit follows post-σ readout convention).

using Test

@isdefined(PolyCDS) || include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS

import .PolyCDS:
    Differential, OComonoid, O_positions, O_directions_at,
    as_polynomial, as_comonoid,
    f_at, emit_at, sharp_L_at,
    validate_v2_axiom,
    tiny_D, tiny_D_workup_state,
    # D1/D2 toy port
    Σ_obs_v2, TOY_V2_PHENOTYPES_D1, TOY_V2_PHENOTYPES_D2,
    TOY_V2_POSITIONS, TOY_V2_P_POSITIONS,
    toy_v2_workup_state, D_v2_toy

using .PolyCDS.Poly:
    validate_comonoid, cardinality, Finite, FinPolySet,
    Polynomial, Comonoid

@testset "v1.6 Phase 1 — Differential scaffolding" begin

    # ============================================================
    @testset "OComonoid struct + helpers" begin
        O = OComonoid(Set([:a, :b]), 2)
        @test O.Σ == Set([:a, :b])
        @test O.depth == 2
        # 1 + 2 + 4 = 7 positions for depth=2, |Σ|=2
        positions = O_positions(O)
        @test length(positions) == 1 + 2 + 4
        @test Symbol[] in positions       # empty log = root
        @test [:a] in positions
        @test [:a, :b] in positions
        # Directions: Σ if below depth, empty otherwise
        @test sort(O_directions_at(O, Symbol[])) == [:a, :b]
        @test sort(O_directions_at(O, [:a])) == [:a, :b]
        @test O_directions_at(O, [:a, :b]) == Symbol[]   # at depth bound
    end

    # ============================================================
    @testset "Differential struct constructs and has expected fields" begin
        @test tiny_D isa Differential
        # O is the left base; Σ is accessible via getproperty shim
        @test tiny_D.O isa OComonoid
        @test tiny_D.O.Σ == Set([:σa, :σb])
        @test tiny_D.Σ == Set([:σa, :σb])         # via getproperty shim
        @test tiny_D.O.depth == 5                 # depth set in Differential.jl
        @test sort(tiny_D.positions) == [:p0, :p1]
        @test sort(tiny_D.P_positions) == [:q0, :q1]
        @test length(tiny_D.f) == 1            # only p0,σa is non-identity
        @test length(tiny_D.emit) == 4         # all four (position, event) pairs authored
        @test length(tiny_D.sharp_L) == 0      # vestigial under (b)
    end

    # ============================================================
    @testset "f_at — identity default for un-authored (p, σ)" begin
        @test f_at(tiny_D, :p0, :σa) == :p1     # explicit
        @test f_at(tiny_D, :p0, :σb) == :p0     # default identity
        @test f_at(tiny_D, :p1, :σa) == :p1     # default identity
        @test f_at(tiny_D, :p1, :σb) == :p1     # default identity

        # Foreign event errors
        @test_throws Exception f_at(tiny_D, :p0, :not_in_sigma)
    end

    # ============================================================
    @testset "emit_at — explicit-only, errors when unauthored" begin
        @test emit_at(tiny_D, :p0, :σa) == :q1
        @test emit_at(tiny_D, :p1, :σb) == :q1

        # Build a mini-D with a missing emit, confirm error
        D_partial = Differential{Symbol, Symbol}(
            OComonoid(Set([:σa]), 2), [:p0], [:q0],
            Dict{Tuple{Symbol, Symbol}, Symbol}(),
            Dict{Tuple{Symbol, Symbol}, Symbol}(),  # no emits
            Dict{Tuple{Symbol, Symbol, Symbol}, Symbol}(),
        )
        @test_throws Exception emit_at(D_partial, :p0, :σa)
    end

    # ============================================================
    @testset "sharp_L_at — default = σ′ (vestigial under (b))" begin
        # Default returns σ′ regardless. Used only by non-canonical authoring.
        @test sharp_L_at(tiny_D, :p0, :σa, :σa) == :σa
        @test sharp_L_at(tiny_D, :p0, :σa, :σb) == :σb
        @test sharp_L_at(tiny_D, :p1, :σb, :σa) == :σa
    end

    # ============================================================
    @testset "validate_v2_axiom — tiny example follows post-σ readout" begin
        @test validate_v2_axiom(tiny_D, tiny_D_workup_state)
    end

    # ============================================================
    @testset "validate_v2_axiom — catches post-σ readout violations" begin
        # Break tiny_D's emit at (p1, σa) by changing q1 → q0. Now the
        # emit table no longer matches workup_state(f_p1(σa)) = q1.
        # The (b)-flavored validator should catch this.
        broken_emit = copy(tiny_D.emit)
        broken_emit[(:p1, :σa)] = :q0
        D_broken = Differential{Symbol, Symbol}(
            tiny_D.O, tiny_D.positions, tiny_D.P_positions,
            tiny_D.f, broken_emit, tiny_D.sharp_L,
        )
        @test !validate_v2_axiom(D_broken, tiny_D_workup_state)
    end

    # ============================================================
    # D1/D2 toy port  (V2 master-D for the v1.x toy)
    # ============================================================

    @testset "Toy V2 D — shape" begin
        @test length(TOY_V2_PHENOTYPES_D1) == 4
        @test length(TOY_V2_PHENOTYPES_D2) == 4
        @test length(TOY_V2_POSITIONS) == 16
        @test length(TOY_V2_P_POSITIONS) == 16
        @test length(Σ_obs_v2) == 8
        @test D_v2_toy isa Differential
        @test D_v2_toy.Σ == Σ_obs_v2
        @test length(D_v2_toy.positions) == 16
    end

    @testset "Toy V2 D — workup_state map" begin
        @test toy_v2_workup_state((:a_D1_initial, :a_D2_initial)) == (:order_o1a, :order_o2a)
        @test toy_v2_workup_state((:a_D1_pending, :a_D2_initial)) == (:order_o1b, :order_o2a)
        @test toy_v2_workup_state((:a_D1, :a_D2_absent)) == (:disease_D1_present, :disease_D2_absent)
    end

    @testset "Toy V2 D — f respects per-disease transitions" begin
        @test f_at(D_v2_toy,
                   (:a_D1_initial, :a_D2_initial),
                   :result_o1a_pos) == (:a_D1_pending, :a_D2_initial)
        @test f_at(D_v2_toy,
                   (:a_D1_initial, :a_D2_initial),
                   :result_o1a_neg) == (:a_D1_absent, :a_D2_initial)
        @test f_at(D_v2_toy,
                   (:a_D1_pending, :a_D2_initial),
                   :result_o1b_pos) == (:a_D1, :a_D2_initial)
        @test f_at(D_v2_toy, (:a_D1, :a_D2_initial), :result_o1a_pos) == (:a_D1, :a_D2_initial)
        @test f_at(D_v2_toy, (:a_D1_absent, :a_D2_initial), :result_o1b_pos) == (:a_D1_absent, :a_D2_initial)
    end

    @testset "Toy V2 D — emit derived via post-σ readout" begin
        @test emit_at(D_v2_toy,
                      (:a_D1_initial, :a_D2_initial),
                      :result_o1a_pos) ==
              toy_v2_workup_state((:a_D1_pending, :a_D2_initial))
        @test emit_at(D_v2_toy,
                      (:a_D1_initial, :a_D2_initial),
                      :result_o1b_pos) ==
              toy_v2_workup_state((:a_D1_initial, :a_D2_initial))
    end

    @testset "Toy V2 D — V2 axiom holds under (b) + post-σ readout" begin
        # Under interpretation (b) (D-directions = paths through O,
        # sharp_L = path concatenation) and post-σ readout, the V2
        # compatibility axiom is structural: it reduces to "emit table
        # follows workup_state ∘ f at every authored entry," which
        # holds by construction since we built emit via post-σ readout.
        @test validate_v2_axiom(D_v2_toy, toy_v2_workup_state)
    end

    @testset "Toy V2 D — validator catches deliberate readout drift" begin
        # If a protocol author authored emit incorrectly (not via post-σ
        # readout), the validator should catch it. Break one entry and
        # verify the validator returns false.
        broken_emit = copy(D_v2_toy.emit)
        broken_emit[((:a_D1_initial, :a_D2_initial), :result_o1a_pos)] =
            (:disease_D1_present, :order_o2a)   # wrong: should be (:order_o1b, :order_o2a)
        D_drifted = Differential{Tuple{Symbol, Symbol}, Tuple{Symbol, Symbol}}(
            D_v2_toy.O, D_v2_toy.positions, D_v2_toy.P_positions,
            D_v2_toy.f, broken_emit, D_v2_toy.sharp_L,
        )
        @test !validate_v2_axiom(D_drifted, toy_v2_workup_state)
    end

    # ============================================================
    # Poly.jl-backed materialization (real Comonoid via cofree_comonoid)
    # ============================================================

    @testset "as_polynomial — Q = y^Σ representable" begin
        O = OComonoid(Set([:a, :b, :c]), 2)
        Q = as_polynomial(O)
        @test Q isa Polynomial
        # Single position labeled :pt
        @test cardinality(Q.positions) == Finite(1)
        # |Σ|-many directions at that position
        the_position = first(Q.positions.elements)
        @test cardinality(Q.direction_at(the_position)) == Finite(3)
    end

    @testset "as_comonoid — real cofree_comonoid materialization" begin
        # Use depth=2 with small alphabet for tractable materialization
        O = OComonoid(Set([:a, :b]), 2)
        comonoid = as_comonoid(O)
        @test comonoid isa Comonoid
        # Comonoid axioms hold for cofree (Niu/Spivak Ch. 8)
        @test validate_comonoid(comonoid)
    end

    @testset "as_comonoid — depth override caps materialization cost" begin
        # tiny_D's OComonoid has depth=5, but materializing at depth=2 is fine
        comonoid_2 = as_comonoid(tiny_D.O; depth=2)
        @test comonoid_2 isa Comonoid
        @test validate_comonoid(comonoid_2)
    end

end
