# ============================================================
# v1.6.B PR 2 — fibration + ∫A + DDx + two-level dynamics
# ============================================================
#
# Comprehensive PR 2 tests: fiber predicate, ∫A construction (δ),
# DDx projection, cc_fire, reindexing, ∫A enumerators, and the
# simulator's two-level dynamics extension.
#
# β-side (per-fiber strict Bicomodule construction) is lazy — its
# materialization isn't exercised here per the performance decision
# of 2026-04-30. See project_polycds_v16_design.md.

using Test

@isdefined(PolyCDS) || include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS

import .PolyCDS:
    # Core
    A_∅, A_D1_bicomodule, A_D2_bicomodule,
    ListState, ListState_empty, Σ_prob,
    History, objects,
    # Token-disease classification (PR 2 step 1)
    Σ_prob_D1, Σ_prob_D2, disease_namespace, disease_of_token,
    restrict_to_disease,
    # Fiber predicate (PR 2 step 2)
    is_h_compatible, fiber_positions, fiber_membership,
    # ∫A construction (PR 2 step 3a)
    build_int_A, paths_between_in_h, morph_kind,
    apply_a_path, int_A_morph_cod, next_pos_via_λ,
    # FiberedAssessment (PR 2 step 4)
    FiberedAssessment, fiber_slice_objects,
    vertical_morphisms_at, horizontal_morphisms_at,
    fiber_membership_cached!,
    # Reindexing + ∫A enumerators (PR 2 step 5)
    reindex, total_space, grothendieck_morphisms, morphisms_from,
    # cc_fire (PR 2 step 6)
    cc_fire, initial_h_from_cc, cc_realize, DDx_route,
    # DDx projection (PR 2 step 7)
    DDx, DDx_narrowed, DDx_concluded_disease,
    A_D1_active_workup, A_D2_active_workup, active_workup_states,
    # Two-level dynamics (PR 2 step 8)
    simulate, Patient_D1, Patient_D2, Patient_neither

using .PolyCDS.Poly: cardinality, Finite, FinPolySet

@testset "v1.6.B PR 2 — fibration + ∫A + dynamics" begin

    # ============================================================
    @testset "Token-disease classification" begin
        # Disease namespaces are disjoint and cover state-tokens
        @test :considering_D1 in Σ_prob_D1
        @test :D1_present in Σ_prob_D1
        @test :considering_D2 in Σ_prob_D2
        @test :D2_absent in Σ_prob_D2
        @test isempty(intersect(Σ_prob_D1, Σ_prob_D2))

        @test disease_of_token(:D1_suspected) == :D1
        @test disease_of_token(:considering_D2) == :D2
        @test disease_of_token(:chest_pain) === nothing  # CC-provenance

        # restrict_to_disease slices h by disease namespace
        h = ListState(Set([:chest_pain, :considering_D1, :D2_present]))
        @test restrict_to_disease(h, :D1) == Set([:considering_D1])
        @test restrict_to_disease(h, :D2) == Set([:D2_present])
    end

    # ============================================================
    @testset "Fiber predicate is_h_compatible" begin
        # h = ∅: all 25 positions admitted
        for s_D1 in [:a_D1_initial, :a_D1_pending, :a_D1, :a_D1_absent_via_o1a]
            for s_D2 in [:a_D2_initial, :a_D2_pending, :a_D2, :a_D2_absent_via_o2a]
                @test is_h_compatible(ListState_empty, (s_D1, s_D2))
            end
        end

        # chest_pain fiber: only D1 at initial admitted (D2 unconstrained)
        h_chest = ListState(Set([:chest_pain, :considering_D1]))
        @test is_h_compatible(h_chest, (:a_D1_initial, :a_D2_initial))
        @test is_h_compatible(h_chest, (:a_D1_initial, :a_D2_pending))
        @test !is_h_compatible(h_chest, (:a_D1_pending, :a_D2_initial))
        @test !is_h_compatible(h_chest, (:a_D1, :a_D2_initial))

        # Incoherent h: no positions admitted (empty fiber as natural signal)
        h_bad = ListState(Set([:D1_suspected, :D1_present]))  # D1 in two state-buckets
        for s_D1 in [:a_D1_initial, :a_D1_pending, :a_D1, :a_D1_absent_via_o1a]
            for s_D2 in [:a_D2_initial, :a_D2_pending]
                @test !is_h_compatible(h_bad, (s_D1, s_D2))
            end
        end
    end

    # ============================================================
    @testset "fiber_positions and fiber_membership" begin
        n_full = length(A_∅.carrier.positions.elements)
        @test length(fiber_positions(ListState_empty, A_∅)) == n_full

        bv = fiber_membership(ListState_empty, A_∅)
        @test all(bv)  # all 25 positions ∈ fiber at ∅
        @test length(bv) == n_full

        h_chest = ListState(Set([:chest_pain, :considering_D1]))
        bv_chest = fiber_membership(h_chest, A_∅)
        @test count(bv_chest) == 5
    end

    # ============================================================
    @testset "DDx projection (active-workup reading)" begin
        # Initial joint state — both diseases on DDx
        @test sort(DDx(ListState_empty, (:a_D1_initial, :a_D2_initial))) == [:D1, :D2]

        # D1 confirmed → D1 leaves DDx
        @test DDx(ListState_empty, (:a_D1, :a_D2_initial)) == [:D2]

        # D1 ruled out → D1 leaves DDx
        @test DDx(ListState_empty, (:a_D1_absent_via_o1a, :a_D2_pending)) == [:D2]

        # Both terminal → empty DDx
        @test isempty(DDx(ListState_empty, (:a_D1, :a_D2)))
        @test isempty(DDx(ListState_empty, (:a_D1_absent_via_o1a, :a_D2_absent_via_o2b)))

        # Pending counts as still on DDx
        @test sort(DDx(ListState_empty, (:a_D1_pending, :a_D2_pending))) == [:D1, :D2]
    end

    # ============================================================
    @testset "DDx narrowing predicates" begin
        prev_a = (:a_D1_initial, :a_D2_initial)  # DDx = {D1, D2}
        cur_a  = (:a_D1, :a_D2_initial)          # DDx = {D2}

        @test DDx_narrowed(ListState_empty, prev_a, ListState_empty, cur_a) ==
              Set([:D1])
        @test DDx_concluded_disease(prev_a, cur_a) == [:D1]

        # No conclusion if both stayed in active workup
        prev_a2 = (:a_D1_initial, :a_D2_initial)
        cur_a2  = (:a_D1_pending, :a_D2_initial)
        @test isempty(DDx_concluded_disease(prev_a2, cur_a2))
    end

    # ============================================================
    @testset "active_workup_states" begin
        @test active_workup_states(:D1) == [:a_D1_initial, :a_D1_pending]
        @test active_workup_states(:D2) == [:a_D2_initial, :a_D2_pending]
        @test_throws Exception active_workup_states(:D3)
    end

    # ============================================================
    @testset "cc_fire — H-generator semantics" begin
        # From ∅: f_c is sorted cc_realize(c)
        f_c, h_next = cc_fire(:chest_pain, ListState_empty)
        @test sort(f_c) == sort([:chest_pain, :considering_D1])
        @test h_next == cc_realize(:chest_pain)

        # well_visit: empty path, h unchanged
        f_c, h_next = cc_fire(:well_visit, ListState_empty)
        @test isempty(f_c)
        @test h_next == ListState_empty

        # Precondition violation: cc_realize ∩ h_current ≠ ∅
        h_current = ListState(Set([:chest_pain]))  # Already has chest_pain
        @test_throws Exception cc_fire(:chest_pain, h_current)

        # initial_h_from_cc backwards-compat
        @test initial_h_from_cc(:chest_pain) == cc_realize(:chest_pain)
        @test initial_h_from_cc(:well_visit) == ListState_empty
    end

    # ============================================================
    @testset "DDx_route consistent with cc_realize" begin
        # Each disease in DDx_route(c) should have :considering_<d> in cc_realize(c)
        for c in [:chest_pain, :abd_pain, :dyspnea, :fatigue, :well_visit]
            for d in DDx_route(c)
                considering_token = Symbol("considering_", d)
                @test considering_token in cc_realize(c)
            end
        end
    end

    # ============================================================
    @testset "∫A construction at depth=2" begin
        h = History(root=ListState_empty, depth=2)
        int_A = build_int_A(A_∅, h; intA_depth=2)

        n_obj = length(int_A.objects.elements)
        n_morph = length(int_A.morphisms.elements)

        @test n_obj > 0
        @test n_morph > 0

        # Identity morphisms exist for every object
        for o in int_A.objects.elements
            @test haskey(int_A.identity, o)
        end

        # Vertical morphisms count >= number of objects (each object has at least
        # the identity vertical morphism)
        n_vert = count(m -> morph_kind(m) == :vertical, int_A.morphisms.elements)
        @test n_vert ≥ n_obj
    end

    # ============================================================
    @testset "FiberedAssessment construction + accessors" begin
        h = History(root=ListState_empty, depth=2)
        fa = FiberedAssessment(A_∅, h; intA_depth=2)

        # δ-side accessors (cheap)
        @test fa.base === A_∅
        @test fa.history === h
        @test isempty(fa.fiber_bicomodules)  # lazy β-side, none yet

        # fiber_slice_objects at ∅: all 25 positions
        objs_empty = fiber_slice_objects(fa, ListState_empty)
        @test length(objs_empty) == length(A_∅.carrier.positions.elements)

        # fiber_slice_objects at chest_pain: 5
        h_chest = ListState(Set([:chest_pain, :considering_D1]))
        objs_chest = fiber_slice_objects(fa, h_chest)
        @test length(objs_chest) == 5

        # Membership cache is populated by fiber_slice_objects
        @test haskey(fa.membership, ListState_empty)
        @test haskey(fa.membership, h_chest)
    end

    # ============================================================
    @testset "vertical/horizontal morphisms at a point" begin
        h_history = History(root=ListState_empty, depth=2)
        fa = FiberedAssessment(A_∅, h_history; intA_depth=2)

        # At (∅, (a_D1_initial, a_D2_initial)) we have vertical motion
        a_init = (:a_D1_initial, :a_D2_initial)
        verts = vertical_morphisms_at(fa, ListState_empty, a_init)
        @test !isempty(verts)
        @test all(m -> morph_kind(m) == :vertical, verts)
    end

    # ============================================================
    @testset "reindex — natural inclusion + strict-coherence rejection" begin
        h_history = History(root=ListState_empty, depth=2)
        fa = FiberedAssessment(A_∅, h_history; intA_depth=2)

        h_chest = ListState(Set([:chest_pain, :considering_D1]))
        a_init = (:a_D1_initial, :a_D2_initial)

        # a_init is in both ∅-fiber and chest_pain-fiber → reindex returns a_init
        # H-path from ∅ to chest_pain is sorted symdiff
        f_path = sort([:chest_pain, :considering_D1])
        @test reindex(fa, f_path, ListState_empty, a_init) == a_init

        # a_pending = (a_D1_pending, ...) is NOT in chest_pain-fiber → reindex errors
        a_pending = (:a_D1_pending, :a_D2_initial)
        @test_throws Exception reindex(fa, f_path, ListState_empty, a_pending)
    end

    # ============================================================
    @testset "total_space and grothendieck_morphisms" begin
        h_history = History(root=ListState_empty, depth=2)
        fa = FiberedAssessment(A_∅, h_history; intA_depth=2)

        ts = total_space(fa)
        @test length(ts) == length(fa.int_A.objects.elements)

        # grothendieck_morphisms between same object includes at least the identity
        a_init = (:a_D1_initial, :a_D2_initial)
        dom = (ListState_empty, a_init)
        morphs = grothendieck_morphisms(fa, dom, dom)
        @test !isempty(morphs)
    end

    # ============================================================
    @testset "Simulator: two-level dynamics with CC firing" begin
        # Without CC: backwards-compat — h stays at ∅ throughout
        traj = simulate(Patient_D1; mode=:sequential)
        @test traj[1].step == 0
        @test traj[1].h == ListState_empty
        @test traj[1].edge_kind == :init
        # All non-init steps should be vertical (no realize change without CC firing context)
        # Actually since realize maps from initial → pending DOES change tokens,
        # subsequent steps WILL be horizontal. That's expected — the simulator
        # always tracks Θ-image even without explicit CC firing.

        # With CC: first non-init step is :cc_fire
        traj_cc = simulate(Patient_D1; cc=:chest_pain, mode=:sequential)
        @test traj_cc[1].step == 0
        @test traj_cc[1].h == ListState_empty
        @test traj_cc[2].edge_kind == :cc_fire
        @test traj_cc[2].h == cc_realize(:chest_pain)
        # The patient's joint position stays at initial during cc_fire
        @test traj_cc[2].joint_pos == traj_cc[1].joint_pos
    end

    # ============================================================
    @testset "Simulator: edge_kind classification on D1-confirmation trajectory" begin
        traj = simulate(Patient_D1; cc=:chest_pain, mode=:sequential)

        # First step is init
        @test traj[1].edge_kind == :init
        # Second step is cc_fire (h advances)
        @test traj[2].edge_kind == :cc_fire
        # Subsequent steps: workup advances. When per-disease state changes
        # in a way that changes realize, edge_kind = :horizontal.
        # The transitions a_D1_initial → a_D1_pending DO change realize
        # (from {:considering_D1} to {:D1_suspected}) — should be :horizontal.
        for k in 3:length(traj)
            @test traj[k].edge_kind in (:vertical, :horizontal)
        end
    end

    # ============================================================
    @testset "A_∅ migration: replaces A_joint" begin
        # A_∅ exists at module level; A_joint should NOT
        @test isdefined(PolyCDS, :A_∅)
        @test !isdefined(PolyCDS, :A_joint)
    end

end
