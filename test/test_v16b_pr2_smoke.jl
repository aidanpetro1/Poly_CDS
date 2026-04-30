# ============================================================
# v1.6.B PR 2 smoke test
# ============================================================
#
# Minimal construction smoke test for build_int_A and
# materialize_fiber. Goal: surface construction-time errors
# (Bicomodule type-check failures, composition-closure errors,
# substitution-shape mismatches) before adding more code on top.
#
# No detailed assertions — just "doesn't error" + sanity-level
# size reporting via @info. If something pops, we iterate on the
# Fiber.jl construction code.

using Test

@isdefined(PolyCDS) || include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS

import .PolyCDS:
    A_∅,
    ListState, ListState_empty,
    History, objects,
    is_h_compatible, fiber_positions,
    build_int_A, materialize_fiber,
    morph_kind

using .PolyCDS.Poly: cardinality, Finite

@testset "v1.6.B PR 2 smoke — construction" begin

    @testset "History at depth=2 — basic shape" begin
        h = History(root=ListState_empty, depth=2)
        objs = objects(h)
        @info "History" depth=2 num_objects=length(objs)
        @test length(objs) > 0
    end

    @testset "fiber_positions(∅) ≅ A_∅.positions" begin
        # At h=∅, every joint position is compatible (predicate trivially holds)
        n_full = length(A_∅.carrier.positions.elements)
        n_empty_fiber = length(fiber_positions(ListState_empty, A_∅))
        @info "Empty-fiber size" full_A=n_full empty_fiber=n_empty_fiber
        @test n_empty_fiber == n_full
    end

    @testset "fiber_positions narrows for non-trivial h" begin
        h_chest = ListState(Set([:chest_pain, :considering_D1]))
        n_chest = length(fiber_positions(h_chest, A_∅))
        @info "Chest-pain fiber size" expected=5 actual=n_chest
        @test n_chest == 5
    end

    # ----------------------------------------------------------------
    # NOTE: materialize_fiber tests are SKIPPED in the smoke run.
    # ----------------------------------------------------------------
    # Per the lazy-by-default β-side decision (project_polycds_v16_design.md):
    # `materialize_fiber` is expensive on the FIRST call against a base
    # Bicomodule, because building S_h and P_h sub-Comonoids requires
    # `cached_to_category(S_joint)` / `cached_to_category(P_joint)`. For
    # v1.x's joint comonoids the first call exceeded 3 minutes.
    #
    # v1.6.B's load-bearing consumers (DDx, simulator, runtime-side
    # checks) use only ∫A (δ-side, fast). Per-fiber strict Bicomodule
    # construction (β-side) is invoked on-demand when external composition
    # (v1.8) or opt-in validate_grothendieck_pointwise asks.
    #
    # When you want to exercise materialize_fiber, run the dedicated
    # β-side tests (deferred to a separate test file or env-var-gated
    # block). For now, the smoke test only exercises the (δ)-side.

    @testset "build_int_A at depth=2, intA_depth=2 — completes" begin
        h = History(root=ListState_empty, depth=2)
        local int_A
        try
            int_A = build_int_A(A_∅, h; intA_depth=2)
        catch e
            @error "build_int_A FAILED" exception=e
            rethrow(e)
        end
        n_obj = length(int_A.objects.elements)
        n_morph = length(int_A.morphisms.elements)
        n_comp = length(int_A.composition)

        # Count morphism kinds
        n_vert = count(m -> morph_kind(m) == :vertical, int_A.morphisms.elements)
        n_horiz = count(m -> morph_kind(m) == :horizontal, int_A.morphisms.elements)
        n_mixed = count(m -> morph_kind(m) == :mixed, int_A.morphisms.elements)

        @info "∫A constructed" objects=n_obj morphisms=n_morph composition_entries=n_comp
        @info "∫A morphism breakdown" vertical=n_vert horizontal=n_horiz mixed=n_mixed
        @test n_obj > 0
        @test n_morph > 0
    end

    # NOTE: materialize_fiber tests skipped for now — `to_category(S_joint)`
    # and `to_category(P_joint)` inside build_sub_comonoid hangs at >3 minutes
    # on v1.x's joint comonoids (joint duplicator/eraser are expensive to
    # evaluate pointwise). Need to either cache to_category results across
    # fiber calls, or build sub-Comonoids directly without going through
    # SmallCategory. Coming back to this in PR 2 step 3b iteration.

end
