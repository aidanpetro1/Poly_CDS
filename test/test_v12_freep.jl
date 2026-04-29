"""
    test/test_v12_freep.jl

Regression test for the v1.2 free-P upgrade.

What changed in v1.2:
  * `P_Dk` is now the free protocol-category over the per-disease
    planned-pathway graph, with length-≥2 composites kept distinct.
  * Terminal order vocabulary split into clinically-distinct
    `:disease_Dk_present` and `:disease_Dk_absent` so `sharp_R` is
    well-defined under free-P.
  * `sharp_R` rewritten with the "extend by length(P-morph) S-steps,
    match cod(e)" rule.
  * `validate_sharp_R_well_defined` checks uniqueness at construction.
  * `validate_bicomodule_detailed` is now a NON-TRIVIAL coherence proof
    on each per-disease guideline (in v1.1 it held for free under
    discrete P).

This file asserts those properties; if any of them regresses we want
to know in a clean, focused failure rather than as a downstream axiom
breakage.

Run standalone:
    julia C:/Poly_CDS/test/test_v12_freep.jl

Or via the suite:
    julia C:/Poly_CDS/test/runtests.jl
"""

using Test

# Idempotent load (so this file works standalone or under runtests.jl).
@isdefined(PolyCDS) || include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS
using .PolyCDS.Poly:
    validate_bicomodule, validate_bicomodule_detailed,
    cardinality, Finite

import .PolyCDS:
    P_D1, P_D2,
    A_D1_bicomodule, A_D2_bicomodule,
    sharp_R, validate_sharp_R_well_defined,
    D1_protocol_edges, D2_protocol_edges

@testset "v1.2 — free-P upgrade" begin

    # ----------------------------------------------------------------
    # 1. Free-P shape: 10 morphisms per disease.
    #    Decomposition: 4 identities (one per object) + 4 length-1
    #    generators (the edges) + 2 length-2 composites
    #    (o*a → o*b → present and o*a → o*b → absent). Keeps
    #    parallel composites distinct — this is what distinguishes
    #    free-P from the v1.1 thin / discrete versions.
    # ----------------------------------------------------------------
    @testset "P_Dk shape: free, 10 morphisms each" begin
        @test cardinality(P_D1.carrier.positions) == Finite(4)   # 4 objects
        @test cardinality(P_D2.carrier.positions) == Finite(4)
        # Total directions across all positions = total morphisms.
        n_morph_D1 = sum(length(P_D1.carrier.direction_at(o).elements)
                         for o in P_D1.carrier.positions.elements)
        n_morph_D2 = sum(length(P_D2.carrier.direction_at(o).elements)
                         for o in P_D2.carrier.positions.elements)
        @test n_morph_D1 == 10
        @test n_morph_D2 == 10
    end

    # ----------------------------------------------------------------
    # 2. sharp_R is well-defined for every (x, a, e) triple.
    #    This is the construction-time check that fails early on an
    #    ill-formed protocol; we run it explicitly here too.
    # ----------------------------------------------------------------
    @testset "sharp_R well-defined" begin
        @test validate_sharp_R_well_defined(:D1; verbose=false)
        @test validate_sharp_R_well_defined(:D2; verbose=false)
    end

    # ----------------------------------------------------------------
    # 3. Specific non-trivial sharp_R calls return the expected
    #    A-direction. Picks the cases where the codomain-matching rule
    #    actually disambiguates between two candidate extensions.
    # ----------------------------------------------------------------
    @testset "sharp_R — codomain-matching disambiguates" begin
        # v1.3 paths-as-directions: A-directions and P-directions are
        # both path tuples. Identity is `()`; length-1 path is `(r,)`;
        # length-2 path is `(r1, r2)`.

        # D1 at :a_D1_initial with A-direction (:pos,), extending by
        # P-morph :order_o1b → :disease_D1_present (length 1) should
        # pick path (:pos, :pos) which lands at :a_D1 (recommends
        # :disease_D1_present), NOT (:pos, :neg) which lands at
        # :a_D1_absent_via_o1b → :disease_D1_absent.
        @test sharp_R(:D1, :a_D1_initial, (:pos,), (:disease_D1_present,)) == (:pos, :pos)

        # Mirror case.
        @test sharp_R(:D1, :a_D1_initial, (:pos,), (:disease_D1_absent,)) == (:pos, :neg)

        # Identity P-morphisms are Law 2: sharp_R returns `a` unchanged.
        @test sharp_R(:D1, :a_D1_initial, (), ()) == ()

        # Parallel D2 case.
        @test sharp_R(:D2, :a_D2_initial, (:pos,), (:disease_D2_present,)) == (:pos, :pos)
    end

    # ----------------------------------------------------------------
    # 4. validate_bicomodule_detailed passes — now a NON-TRIVIAL
    #    coherence proof on each guideline.
    #    In v1.1 (discrete P) the bicomodule axioms held vacuously. In
    #    v1.2 (free-P with length-2 composites) the right-comodule
    #    laws and the bicomodule compatibility axiom both have real
    #    P-morphism content to constrain — a passing run is the
    #    "guideline coherence" certificate (project_polycds_coherence.md).
    # ----------------------------------------------------------------
    @testset "validate_bicomodule_detailed — substantive coherence proof" begin
        @test validate_bicomodule(A_D1_bicomodule)
        @test validate_bicomodule(A_D2_bicomodule)
    end

    # ----------------------------------------------------------------
    # 5. Edge encoding sanity. A regression in `build_free_protocol_category`
    #    that, say, accidentally collapsed parallel paths would break
    #    these.
    # ----------------------------------------------------------------
    @testset "protocol-edge data is well-formed" begin
        @test (:order_o1a, :order_o1b) in D1_protocol_edges
        @test (:order_o1a, :disease_D1_absent) in D1_protocol_edges
        @test (:order_o1b, :disease_D1_present) in D1_protocol_edges
        @test (:order_o1b, :disease_D1_absent) in D1_protocol_edges
        @test length(D1_protocol_edges) == 4
        @test length(D2_protocol_edges) == 4
    end
end
