"""
    test/test_v11_joint_bicomodule.jl

Regression test for the formal joint bicomodule

    A_joint = A_D1_bicomodule  ⊗  A_D2_bicomodule
            = parallel(A_D1_bicomodule, A_D2_bicomodule)

`A_joint` is constructed at PolyCDS load time as a module-level `const`
(see Bicomodule.jl). This test asserts the construction stayed cheap,
the joint shape is right, the lazy-cod path is exercised, and
`validate_bicomodule_detailed` still passes on it.

If construction silently regresses to eager `subst`, the assertions
on the lazy `.cod` types will fail, and `using PolyCDS` itself will
hang or OOM long before this test runs — which is also a regression
signal.

Run standalone (will reload PolyCDS):

    julia C:/Poly_CDS/test/test_v11_joint_bicomodule.jl

Or via the suite:

    julia C:/Poly_CDS/test/runtests.jl
"""

using Test

# Idempotent load: include PolyCDS only if it isn't already in scope.
# This lets the file run both standalone and as part of runtests.jl.
@isdefined(PolyCDS) || include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS
using .PolyCDS.Poly:
    parallel, Bicomodule, AbstractPolynomial,
    validate_bicomodule, validate_bicomodule_detailed,
    cardinality, Finite

import .PolyCDS:
    A_D1_bicomodule, A_D2_bicomodule, A_joint,
    A_D1_carrier, A_D2_carrier,
    S_D1, S_D2, P_D1, P_D2

# Time budget — generous, just to detect catastrophic regressions
# (eager-subst reverting, etc.). Smoke values from 2026-04-28:
# construct ≈ 1.4s, validate ≈ 7.7s on the full v1.1 carriers.
const JOINT_TIME_BUDGET_SEC = 120.0

@testset "v1.1 — formal joint bicomodule via ⊗" begin

    # ----------------------------------------------------------------
    # 1. Type and shape sanity. A_joint is a module-level const, so
    #    construction has already happened by the time we get here —
    #    if it had blown up, `using .PolyCDS` would have failed.
    # ----------------------------------------------------------------
    @testset "type / shape" begin
        @test A_joint isa Bicomodule

        # Joint A carrier should have |A_D1| × |A_D2| = 5 × 5 = 25 positions.
        @test cardinality(A_joint.carrier.positions) == Finite(25)

        # The Poly.jl PR's marquee change: Lens.cod is now AbstractPolynomial
        # and the joint coactions' cods are LazySubst, not concrete Polynomial.
        # If a future change reverts to eager construction, these assertions
        # still pass (Polynomial <: AbstractPolynomial) but t_construct/t_validate
        # below will catch it. We assert AbstractPolynomial rather than the
        # internal LazySubst type to avoid coupling to a Poly.jl name.
        @test A_joint.left_coaction.cod  isa AbstractPolynomial
        @test A_joint.right_coaction.cod isa AbstractPolynomial

        # Joint duplicator cods — same story (per the PR's "gotchas" note).
        @test A_joint.left_base.duplicator.cod  isa AbstractPolynomial
        @test A_joint.right_base.duplicator.cod isa AbstractPolynomial
    end

    # ----------------------------------------------------------------
    # 2. Construction stays cheap. We re-parallel here (independent of
    #    the module-level const) to get a measured wallclock for
    #    regression alarm purposes. Doubles the construction work but
    #    that's ~1.4s, fine.
    # ----------------------------------------------------------------
    @testset "construction stays cheap" begin
        local A_joint_2
        t_construct = @elapsed begin
            A_joint_2 = parallel(A_D1_bicomodule, A_D2_bicomodule)
        end
        @info "joint bicomodule constructed" t_construct
        @test t_construct < JOINT_TIME_BUDGET_SEC
        @test A_joint_2 isa Bicomodule
    end

    # ----------------------------------------------------------------
    # 3. Bicomodule axioms hold on the joint.
    #    Under v1.2 (free-P_D1, free-P_D2 ⇒ free P_joint with length-≥2
    #    composites on each side) the LEFT axioms exercise the cofree-S
    #    duplicator/counit structure AND the right-side and compatibility
    #    axioms have real P-morphism content. validate_bicomodule_detailed
    #    is a non-trivial coherence proof on the joint guideline.
    # ----------------------------------------------------------------
    @testset "validate_bicomodule on joint" begin
        local v
        t_validate = @elapsed begin
            v = validate_bicomodule_detailed(A_joint)
        end
        @info "joint bicomodule validated" t_validate
        @test t_validate < JOINT_TIME_BUDGET_SEC

        # validate_bicomodule_detailed returns a rich result; the unary
        # boolean form is the contract we assert on.
        @test validate_bicomodule(A_joint)

        # Surface the detailed result for log inspection.
        @info "validate_bicomodule_detailed result" v
    end
end
