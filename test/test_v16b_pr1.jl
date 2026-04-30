# ============================================================
# v1.6.B PR 1 — infrastructure tests
# ============================================================
#
# Covers:
#   * ProblemVocabulary — Σ_prob, ListState, toggle laws
#   * Q polynomial — y^Σ_prob shape, σ coalgebra
#   * Realize — cc_realize / realize content + handover coherence
#   * Theta — derived S→H quotient at A-phenotype and joint levels
#   * History — H-objects, canonical paths, materialized comonoid
#
# v1.6.B foundations: §22 (Q toggle reframe), §25 (Θ via realize),
# §29 (CC = H-generator). Authoring decisions: project_polycds_v16_design.md.

using Test

@isdefined(PolyCDS) || include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS

import .PolyCDS:
    # ProblemVocabulary
    Σ_prob, Σ_prob_cc_provenance, Σ_prob_considering, Σ_prob_disease_state,
    ListState, ListState_empty, valid_liststate,
    toggle, op_for, realize_symdiff,
    # Polynomials (Q, σ)
    Q, sigma_Q, sigma_Q_table, reachable_liststates,
    # Realize
    DDx_route, cc_realize, realize,
    cc_realize_handover_coherent, cc_realize_handover_violations,
    # Theta
    theta_phenotype, joint_realize, theta_joint, theta_advance,
    initial_h_from_cc, theta_phenotype_functorial,
    # History
    History, objects, is_object,
    Path, apply_path, path_dom, path_cod, path_compose, path_identity,
    canonical_path,
    as_smallcategory, as_state_comonoid,
    sub_history, U,
    behavior_tree_at

using .PolyCDS.Poly: cardinality, Finite, FinPolySet, direction_at

@testset "v1.6.B PR 1 — infrastructure" begin

    # ============================================================
    @testset "ProblemVocabulary — Σ_prob and layering" begin
        # Three layers, disjoint by construction
        @test isempty(intersect(Σ_prob_cc_provenance, Σ_prob_considering))
        @test isempty(intersect(Σ_prob_cc_provenance, Σ_prob_disease_state))
        @test isempty(intersect(Σ_prob_considering, Σ_prob_disease_state))

        # Σ_prob is the union
        @test Σ_prob == union(Σ_prob_cc_provenance,
                              Σ_prob_considering,
                              Σ_prob_disease_state)

        # Specific tokens we expect at each layer
        @test :chest_pain in Σ_prob_cc_provenance
        @test :well_visit ∉ Σ_prob_cc_provenance       # by design
        @test :considering_D1 in Σ_prob_considering
        @test :considering_D2 in Σ_prob_considering
        @test :D1_present in Σ_prob_disease_state
        @test :D2_absent in Σ_prob_disease_state

        # ListState basics
        @test ListState_empty == Set{Symbol}()
        @test valid_liststate(ListState_empty)
        @test valid_liststate(Set([:chest_pain, :considering_D1]))
        @test !valid_liststate(Set([:not_a_real_token]))
    end

    # ============================================================
    @testset "toggle is total + idempotent (involution)" begin
        x = ListState(Set([:chest_pain, :considering_D1]))

        # Idempotence: toggle twice == identity
        for p in Σ_prob
            @test toggle(p, toggle(p, x)) == x
        end

        # Add direction (p ∉ x) ↦ adds p
        @test :D1_present ∉ x
        @test toggle(:D1_present, x) == union(x, Set([:D1_present]))

        # Remove direction (p ∈ x) ↦ removes p
        @test toggle(:chest_pain, x) == setdiff(x, Set([:chest_pain]))

        # Foreign tokens error
        @test_throws Exception toggle(:not_a_real_token, x)

        # op_for recovers the implicit op
        @test op_for(:chest_pain, x) == :remove   # already in x
        @test op_for(:D1_present, x) == :add      # not in x
    end

    # ============================================================
    @testset "Q polynomial — y^Σ_prob shape" begin
        # Single position
        @test cardinality(Q.positions) == Finite(1)

        # |Σ_prob| directions at that position
        the_position = first(Q.positions.elements)
        @test cardinality(direction_at(Q, the_position)) == Finite(length(Σ_prob))

        # Direction-set is exactly Σ_prob
        @test Set(direction_at(Q, the_position).elements) == Σ_prob
    end

    # ============================================================
    @testset "σ — strict toggle coalgebra" begin
        x = ListState(Set([:chest_pain]))

        # sigma_Q returns a function; toggle equivalence
        σx = sigma_Q(x)
        for p in Σ_prob
            @test σx(p) == toggle(p, x)
        end

        # sigma_Q_table is the dict form
        tbl = sigma_Q_table(x)
        @test length(tbl) == length(Σ_prob)
        for p in Σ_prob
            @test tbl[p] == toggle(p, x)
        end

        # Foreign-token state errors
        @test_throws Exception sigma_Q(Set([:not_real]))
    end

    # ============================================================
    @testset "reachable_liststates — depth-bounded closure under toggle" begin
        # Depth 0: only the root
        @test reachable_liststates(ListState_empty; depth=0) ==
              Set([ListState_empty])

        # Depth 1: ∅ + one toggle = singletons
        d1 = reachable_liststates(ListState_empty; depth=1)
        @test ListState_empty in d1
        for p in Σ_prob
            @test Set([p]) in d1
        end
        @test length(d1) == 1 + length(Σ_prob)

        # Depth 2: includes pairs
        d2 = reachable_liststates(ListState_empty; depth=2)
        @test Set([:chest_pain, :considering_D1]) in d2
        # All single-token states still present
        @test Set([:chest_pain]) in d2
    end

    # ============================================================
    @testset "DDx_route mirrors v1.6.A's CC routing" begin
        @test DDx_route(:chest_pain) == [:D1]
        @test DDx_route(:abd_pain) == [:D2]
        @test sort(DDx_route(:dyspnea)) == [:D1, :D2]
        @test sort(DDx_route(:fatigue)) == [:D1, :D2]
        @test DDx_route(:well_visit) == Symbol[]
        @test_throws Exception DDx_route(:not_a_cc)
    end

    # ============================================================
    @testset "cc_realize — content + structural conventions" begin
        # CC-provenance + considering tokens, layered correctly
        @test cc_realize(:chest_pain) == Set([:chest_pain, :considering_D1])
        @test cc_realize(:abd_pain)   == Set([:abd_pain, :considering_D2])
        @test cc_realize(:dyspnea)    == Set([:dyspnea, :considering_D1, :considering_D2])
        @test cc_realize(:fatigue)    == Set([:fatigue, :considering_D1, :considering_D2])
        @test cc_realize(:well_visit) == Set{Symbol}()

        # All CC-provenance contributions are valid Σ_prob tokens
        for cc in [:chest_pain, :abd_pain, :dyspnea, :fatigue]
            @test valid_liststate(cc_realize(cc))
        end
    end

    # ============================================================
    @testset "realize — per-disease A-phenotype content" begin
        # D1
        @test realize(:D1, :a_D1_initial)        == Set([:considering_D1])
        @test realize(:D1, :a_D1_pending)        == Set([:D1_suspected])
        @test realize(:D1, :a_D1)                == Set([:D1_present])
        @test realize(:D1, :a_D1_absent_via_o1a) == Set([:D1_absent])
        @test realize(:D1, :a_D1_absent_via_o1b) == Set([:D1_absent])

        # D2 — symmetric structure
        @test realize(:D2, :a_D2_initial)        == Set([:considering_D2])
        @test realize(:D2, :a_D2_pending)        == Set([:D2_suspected])
        @test realize(:D2, :a_D2)                == Set([:D2_present])
        @test realize(:D2, :a_D2_absent_via_o2a) == Set([:D2_absent])
        @test realize(:D2, :a_D2_absent_via_o2b) == Set([:D2_absent])

        # Coarsening: both absent-via-* paths collapse to :Dk_absent
        @test realize(:D1, :a_D1_absent_via_o1a) == realize(:D1, :a_D1_absent_via_o1b)

        # Foreign args error
        @test_throws Exception realize(:D1, :not_a_state)
        @test_throws Exception realize(:D3, :a_D3_initial)
    end

    # ============================================================
    @testset "cc_realize / realize handover coherence" begin
        @test cc_realize_handover_coherent()
        @test isempty(cc_realize_handover_violations())
    end

    # ============================================================
    @testset "Θ at A-phenotype level" begin
        # Stable phenotype: empty Θ-image
        @test theta_phenotype(:D1, :a_D1_pending, :a_D1_pending) == Symbol[]

        # initial → pending: drop :considering, add :suspected
        π = theta_phenotype(:D1, :a_D1_initial, :a_D1_pending)
        @test sort(π) == sort([:considering_D1, :D1_suspected])

        # pending → confirmed
        π = theta_phenotype(:D1, :a_D1_pending, :a_D1)
        @test sort(π) == sort([:D1_suspected, :D1_present])

        # initial → absent (via o1a)
        π = theta_phenotype(:D1, :a_D1_initial, :a_D1_absent_via_o1a)
        @test sort(π) == sort([:considering_D1, :D1_absent])

        # Both absent paths give the same Θ-image (state-quotient)
        @test theta_phenotype(:D1, :a_D1_initial, :a_D1_absent_via_o1a) ==
              theta_phenotype(:D1, :a_D1_initial, :a_D1_absent_via_o1b)
    end

    # ============================================================
    @testset "joint Θ — disjoint per-disease realize unions" begin
        # joint_realize is the disjoint union of per-disease realizes
        @test joint_realize((:a_D1_initial, :a_D2_initial)) ==
              Set([:considering_D1, :considering_D2])

        @test joint_realize((:a_D1, :a_D2)) ==
              Set([:D1_present, :D2_present])

        # theta_joint computes the joint-state symdiff
        π = theta_joint((:a_D1_initial, :a_D2_initial),
                        (:a_D1_pending, :a_D2_initial))
        # Only D1 advanced; D2 unchanged
        @test sort(π) == sort([:considering_D1, :D1_suspected])

        # Both diseases advancing in one step
        π = theta_joint((:a_D1_initial, :a_D2_initial),
                        (:a_D1_pending, :a_D2_absent_via_o2a))
        @test sort(π) == sort([:considering_D1, :D1_suspected,
                               :considering_D2, :D2_absent])
    end

    # ============================================================
    @testset "theta_advance threads CC-provenance correctly" begin
        # Patient walks in with chest_pain, disease state advances D1 only
        h0 = initial_h_from_cc(:chest_pain)
        @test h0 == Set([:chest_pain, :considering_D1])

        h1 = theta_advance(h0,
                           (:a_D1_initial, :a_D2_initial),
                           (:a_D1_pending, :a_D2_initial))
        # CC-provenance preserved; considering removed; suspected added;
        # D2's :considering_D2 was never in h0 so no D2 motion
        @test h1 == Set([:chest_pain, :D1_suspected])
    end

    # ============================================================
    @testset "Θ functoriality predicate (trivial under H_quot)" begin
        # By construction Θ via realize_symdiff is automatically
        # functorial under H_quot — both "composite" and "step-by-step"
        # depend only on (start, end) realize-sets.
        traj = [:a_D1_initial, :a_D1_pending, :a_D1]
        @test theta_phenotype_functorial(:D1, traj)

        traj = [:a_D1_initial, :a_D1_absent_via_o1a]
        @test theta_phenotype_functorial(:D1, traj)

        # Single-element trajectory: trivially functorial
        @test theta_phenotype_functorial(:D1, [:a_D1])
    end

    # ============================================================
    @testset "initial_h_from_cc — H-generator step" begin
        @test initial_h_from_cc(:chest_pain) == Set([:chest_pain, :considering_D1])
        @test initial_h_from_cc(:dyspnea) ==
              Set([:dyspnea, :considering_D1, :considering_D2])
        @test initial_h_from_cc(:well_visit) == ListState_empty
    end

    # ============================================================
    @testset "History — H-objects and structural accessors" begin
        h = History(root=ListState_empty, depth=2)

        # objects: BFS closure to depth 2
        objs = objects(h)
        @test ListState_empty in objs
        @test Set([:chest_pain]) in objs
        @test Set([:chest_pain, :considering_D1]) in objs

        # is_object: O(1) reachability check
        @test is_object(h, ListState_empty)
        @test is_object(h, Set([:chest_pain]))
        # depth=2, so 3-token states are not reachable
        @test !is_object(h,
                         Set([:chest_pain, :considering_D1, :D1_suspected]))

        # depth=0 trivializes objects
        h0 = History(root=ListState_empty, depth=0)
        @test objects(h0) == [ListState_empty]
    end

    # ============================================================
    @testset "Path operations (H_path view)" begin
        # apply_path replays toggles
        @test apply_path(ListState_empty, [:chest_pain]) == Set([:chest_pain])
        @test apply_path(ListState_empty, [:chest_pain, :chest_pain]) == ListState_empty
        @test apply_path(ListState_empty,
                         [:chest_pain, :considering_D1]) ==
              Set([:chest_pain, :considering_D1])

        # path_compose = vcat
        @test path_compose([:a, :b], [:c, :d]) == [:a, :b, :c, :d]
        @test path_compose(path_identity(), [:chest_pain]) == [:chest_pain]

        # canonical_path = sorted symdiff
        @test canonical_path(ListState_empty, Set([:chest_pain])) == [:chest_pain]
        @test canonical_path(Set([:chest_pain, :dyspnea]),
                             Set([:dyspnea, :fatigue])) ==
              sort([:chest_pain, :fatigue])

        # Identity path is empty
        @test canonical_path(Set([:chest_pain]), Set([:chest_pain])) == Symbol[]
    end

    # ============================================================
    @testset "H_quot materialization — SmallCategory + Comonoid" begin
        h = History(root=ListState_empty, depth=2)

        cat = as_smallcategory(h)
        n_obj = length(cat.objects.elements)
        @test n_obj == length(objects(h))

        # Every object has an identity morphism
        for o in cat.objects.elements
            @test haskey(cat.identity, o)
            id_morph = cat.identity[o]
            @test cat.dom[id_morph] == o
            @test cat.cod[id_morph] == o
            @test id_morph[2] == Symbol[]   # identity path is empty
        end

        # as_state_comonoid wraps from_category
        cm = as_state_comonoid(h)
        @test length(cm.carrier.positions.elements) == n_obj
    end

    # ============================================================
    @testset "sub_history — labeling functor U" begin
        h = History(root=ListState_empty, depth=4)

        # Sub-history at root is the same depth
        sh_root = sub_history(h, ListState_empty)
        @test sh_root.root == ListState_empty
        @test sh_root.depth == h.depth

        # Sub-history at a 1-token state has 1 less depth
        sh_one = sub_history(h, Set([:chest_pain]))
        @test sh_one.root == Set([:chest_pain])
        @test sh_one.depth == h.depth - 1

        # Sub-history at non-reachable state errors
        unreachable = Set([Symbol("totally_fake_token")])
        @test_throws Exception sub_history(h, unreachable)
    end

    # ============================================================
    @testset "behavior_tree_at — cofree cross-check" begin
        h = History(root=ListState_empty, depth=2)

        t = behavior_tree_at(h, ListState_empty; depth=1)
        # Root has |Σ_prob| children (all directions)
        @test length(keys(t.children)) == length(Σ_prob)

        # Each child is a depth-0 leaf
        for (_, child) in t.children
            @test isempty(child.children)
        end

        # depth=0 ↦ a leaf
        t0 = behavior_tree_at(h, ListState_empty; depth=0)
        @test isempty(t0.children)
    end

end
