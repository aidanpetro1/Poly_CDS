# ============================================================
# The CDS bicomodule  A : S ⇸ P  (v1.1)
# ============================================================
#
# Architectural rationale (see project_polycds_coherence.md and
# project_polycds_phenotypes.md for the full settled design):
#
#   * S = `cofree_comonoid(p_D_obs, 2)` per disease — universal
#     derivation from the observation polynomial. Patient (a coalgebra
#     for p_D_obs) plugs in via cofree's universal property.
#
#   * P = thin protocol-category per disease — encodes the planned
#     pathway (which order can follow which). Thin (at most one
#     morphism per pair of objects) for v1.1 to avoid `♯_R` ambiguity
#     from free-category length-2 composites.
#
#   * A = hand-crafted phenotypes (6 per disease — see Carrier.jl).
#     Direction-sets at each phenotype = paths through the chosen
#     cofree subtree at that phenotype, with clinical labels
#     (`:stay`, `:seq_neg`, `:seq_pos`, `:panel_pos_neg`, etc.).
#
#   * Joint via `Bicomodule ⊗` from Poly.jl v0.2.0.
#
# Bicomodule axiom = guideline coherence: the compatibility law
# requires that result-routing (left) agrees with planned-order
# pathway (right). `validate_bicomodule_detailed` is the correctness
# criterion.

# ============================================================
# Helper: build a thin protocol-category from a directed graph
# ============================================================

"""
    build_thin_protocol_category(objects, edges) -> SmallCategory

Build the thin protocol-category over the directed graph defined by
`objects` (vertex set) and `edges` (single-step transition list).
"Thin" means at most one morphism between any pair of objects — the
free-category composites collapse into a unique morphism per
(source, target) pair, which is determined by reachability.

Identities are added automatically. The morphism encoding follows the
SmallCategory convention: `(source, direction_label)` where the
`direction_label` for the morphism `src → tgt` is `tgt` itself
(unique per (src, tgt) since the category is thin).
"""
function build_thin_protocol_category(objects::Vector{Symbol},
                                       edges::Vector{<:Tuple{Symbol,Symbol}})
    obj_set = FinPolySet(objects)

    # Reachability via transitive closure of the edge relation.
    reachable = Dict{Symbol, Set{Symbol}}(o => Set([o]) for o in objects)
    for (src, tgt) in edges
        push!(reachable[src], tgt)
    end
    changed = true
    while changed
        changed = false
        for o in objects
            for r in collect(reachable[o])
                for r2 in reachable[r]
                    if !(r2 in reachable[o])
                        push!(reachable[o], r2)
                        changed = true
                    end
                end
            end
        end
    end

    # Morphisms encoded as (src, tgt) — direction-label is the target.
    morphisms_list = Tuple{Symbol,Symbol}[]
    morphism_dom = Dict{Tuple{Symbol,Symbol}, Symbol}()
    morphism_cod = Dict{Tuple{Symbol,Symbol}, Symbol}()
    morphism_identity = Dict{Symbol, Tuple{Symbol,Symbol}}()
    for src in objects
        for tgt in sort(collect(reachable[src]); by=string)
            f = (src, tgt)
            push!(morphisms_list, f)
            morphism_dom[f] = src
            morphism_cod[f] = tgt
            if src == tgt
                morphism_identity[src] = f
            end
        end
    end
    morphisms_set = FinPolySet(morphisms_list)

    # Composition: (src, mid) ; (mid, tgt) = (src, tgt). Always defined,
    # always unique (thin).
    composition = Dict{Tuple{Tuple{Symbol,Symbol}, Tuple{Symbol,Symbol}}, Tuple{Symbol,Symbol}}()
    for f in morphisms_list
        mid = morphism_cod[f]
        for g in morphisms_list
            if morphism_dom[g] == mid
                composition[(f, g)] = (morphism_dom[f], morphism_cod[g])
            end
        end
    end

    SmallCategory(obj_set, morphisms_set, morphism_dom, morphism_cod,
                  morphism_identity, composition)
end

# ============================================================
# Per-disease P comonoids — discrete (v1.1 simplification)
# ============================================================
#
# We had P as a thin protocol-category to encode "the planned pathway,"
# making the bicomodule axiom = guideline coherence. But thin-P
# collapses parallel morphisms (direct vs composite paths to the same
# target are identified), and the corresponding A-direction transitions
# are NOT collapsable — so `sharp_R` becomes non-associative, breaking
# the right-comodule coassoc / bicomodule compatibility laws.
#
# Free-P (length-2 composites distinct) + a "extend by length(P-morph)
# S-steps" rule for `sharp_R` satisfies the axioms, but is a
# substantive refactor. Deferred to v1.2.
#
# For v1.1: P discrete. Validates trivially. The protocol pathway
# lives only in `mbar_R`'s per-A-direction recommendations, not in
# P's category structure. The "guideline coherence = bicomodule
# compatibility" insight is *deferred*, not retracted.

"P_D1 — discrete comonoid over D1's order vocabulary (v1.1)."
const P_D1 = discrete_comonoid(FinPolySet(D1_orders))

"P_D2 — discrete comonoid over D2's order vocabulary (v1.1)."
const P_D2 = discrete_comonoid(FinPolySet(D2_orders))

# ============================================================
# Per-disease S comonoids — sub-cofree (only the protocol-relevant trees)
# ============================================================
#
# Originally we used `cofree_comonoid(p_Dk_obs, 2)` (the universal
# cofree at depth 2 — 138 tree-positions per disease). Construction
# was untenably slow: the duplicator's `subst(carrier, carrier)` for a
# 138-position carrier with depth-2 trees has tens of millions of
# positions in the eager subst.
#
# Fix: build a SUB-comonoid of cofree containing only the 5 specific
# behavior trees our bicomodule actually picks at A-positions. This is
# closed under composition (path concatenation within our trees stays
# in the set) so it's a valid sub-comonoid. We trade cofree's universal
# property for tractability — see project_polycds_coherence.md.
#
# Future direction: derive the sub-cofree mechanically from a
# ProtocolDoc instead of hand-picking the trees.

"""
    build_subcofree_comonoid(roots::Vector{BehaviorTree}, p::Polynomial) -> Comonoid

Build a sub-cofree comonoid containing the given root behavior trees
(plus any subtrees reachable via tree_walk). Morphisms are paths
through each tree; composition is path concatenation; codomains are
subtree-walks. Closed under composition by the user's tree-design
constraints.

Built via SmallCategory + from_category for clean construction.
"""
function build_subcofree_comonoid(roots::Vector{BehaviorTree}, p::Polynomial)
    # Closure: collect all subtrees reachable by tree_walk
    objects_set = Set{BehaviorTree}()
    queue = collect(roots)
    while !isempty(queue)
        t = pop!(queue)
        if !(t in objects_set)
            push!(objects_set, t)
            for child in values(t.children)
                push!(queue, child)
            end
        end
    end
    obj_list = collect(objects_set)
    obj_polyset = FinPolySet(obj_list)

    # Morphisms = (object, path) pairs — one per tree-path
    morphisms_list = Tuple[]
    morphism_dom = Dict()
    morphism_cod = Dict()
    morphism_identity = Dict()
    for t in obj_list
        for path in tree_paths(t)
            morph = (t, path)
            push!(morphisms_list, morph)
            morphism_dom[morph] = t
            morphism_cod[morph] = tree_walk(t, path)
            if isempty(path)
                morphism_identity[t] = morph
            end
        end
    end
    morphisms_polyset = FinPolySet(morphisms_list)

    # Composition: path concatenation. Closure ensures composites are in our set.
    composition = Dict()
    for f in morphisms_list
        t_f, path_f = f
        cod_f = morphism_cod[f]
        for g in morphisms_list
            t_g, path_g = g
            t_g == cod_f || continue
            combined = (t_f, (path_f..., path_g...))
            haskey(morphism_dom, combined) ||
                error("build_subcofree: composition closure violated; $combined not in set")
            composition[(f, g)] = combined
        end
    end

    cat = SmallCategory(obj_polyset, morphisms_polyset,
                        morphism_dom, morphism_cod,
                        morphism_identity, composition)
    return from_category(cat)
end

# ============================================================
# Specific behavior trees used by the bicomodule's left coaction
# ============================================================
#
# Our bicomodule picks SPECIFIC trees at each A-position (the choice
# IS the protocol). These constants pin those choices.
#
# The key constraint from cofree coassoc: i_S at a child A-position
# must be `tree_walk(i_S_at_parent, b)` for the routing path b. We
# choose tree-internal labels and child-trees to satisfy this.

# Depth-0 leaves (terminals)
const _leaf_o1a = BehaviorTree((1, :o1a), Dict{Any,BehaviorTree}())
const _leaf_o1b = BehaviorTree((2, :o1b), Dict{Any,BehaviorTree}())
const _leaf_o2a = BehaviorTree((1, :o2a), Dict{Any,BehaviorTree}())
const _leaf_o2b = BehaviorTree((2, :o2b), Dict{Any,BehaviorTree}())

# D1 trees — ragged depth (no off-protocol artifact)
"D1's :pos-subtree at the root: depth-1 rooted at o1b. Children differ so :pos-:neg vs :pos-:pos route distinctly."
const _T_pos_D1 = BehaviorTree((2, :o1b),
    Dict{Any,BehaviorTree}(:neg => _leaf_o1a, :pos => _leaf_o1b))

"""
D1's root tree at a_D1_initial. Ragged-depth: `:neg` child is a depth-0
leaf (workup terminates immediately at o1a-neg, no off-protocol
continuation), `:pos` child is the depth-1 confirmation subtree.
"""
const _T_root_D1 = BehaviorTree((1, :o1a),
    Dict{Any,BehaviorTree}(:neg => _leaf_o1a, :pos => _T_pos_D1))

# D2 trees — parallel structure
const _T_pos_D2 = BehaviorTree((2, :o2b),
    Dict{Any,BehaviorTree}(:neg => _leaf_o2a, :pos => _leaf_o2b))
const _T_root_D2 = BehaviorTree((1, :o2a),
    Dict{Any,BehaviorTree}(:neg => _leaf_o2a, :pos => _T_pos_D2))

# ============================================================
# Per-disease S comonoids — sub-cofree built from the trees above
# ============================================================

"S_D1 — sub-cofree comonoid containing only the 4 protocol-relevant trees for D1."
const S_D1 = build_subcofree_comonoid(
    [_T_root_D1, _T_pos_D1, _leaf_o1a, _leaf_o1b],
    p_D1_obs,
)

"S_D2 — sub-cofree for D2 (parallel structure)."
const S_D2 = build_subcofree_comonoid(
    [_T_root_D2, _T_pos_D2, _leaf_o2a, _leaf_o2b],
    p_D2_obs,
)

# ============================================================
# i_S mapping per A-position — the bicomodule's protocol choice
# ============================================================

"D1: at each phenotype, the cofree-subtree the bicomodule expects observations against."
const i_S_D1 = Dict{Symbol, BehaviorTree}(
    :a_D1_initial         => _T_root_D1,
    :a_D1_absent_via_o1a  => _leaf_o1a,    # T_root.children[:neg] (now a leaf)
    :a_D1_pending         => _T_pos_D1,
    :a_D1_absent_via_o1b  => _leaf_o1a,    # T_pos.children[:neg]
    :a_D1                 => _leaf_o1b,    # T_pos.children[:pos]
)

"D2: parallel structure."
const i_S_D2 = Dict{Symbol, BehaviorTree}(
    :a_D2_initial         => _T_root_D2,
    :a_D2_absent_via_o2a  => _leaf_o2a,
    :a_D2_pending         => _T_pos_D2,
    :a_D2_absent_via_o2b  => _leaf_o2a,
    :a_D2                 => _leaf_o2b,
)

# ============================================================
# Path → A-direction labels
# ============================================================
#
# Each cofree path through i_S(x) corresponds to a labeled direction
# of A.carrier at x (the labels we set up in Carrier.jl). The
# bijection per A-position:

"Path-to-direction-label mapping per A-position for D1."
const path_to_dir_D1 = Dict{Symbol, Dict{Tuple, Symbol}}(
    :a_D1_initial => Dict(
        ()                 => :stay,
        (:neg,)            => :seq_neg,
        (:pos,)            => :seq_pos,
        (:pos, :neg)       => :panel_pos_neg,
        (:pos, :pos)       => :panel_pos_pos,
    ),
    :a_D1_pending => Dict(
        ()       => :stay,
        (:neg,)  => :seq_neg,
        (:pos,)  => :seq_pos,
    ),
    :a_D1                 => Dict(() => :stay),
    :a_D1_absent_via_o1a  => Dict(() => :stay),
    :a_D1_absent_via_o1b  => Dict(() => :stay),
)

"Inverse: direction-label to path."
const dir_to_path_D1 = Dict(
    pos => Dict(v => k for (k, v) in p2d)
    for (pos, p2d) in path_to_dir_D1
)

"D2 versions (parallel structure)."
const path_to_dir_D2 = Dict{Symbol, Dict{Tuple, Symbol}}(
    :a_D2_initial => Dict(
        ()                 => :stay,
        (:neg,)            => :seq_neg,
        (:pos,)            => :seq_pos,
        (:pos, :neg)       => :panel_pos_neg,
        (:pos, :pos)       => :panel_pos_pos,
    ),
    :a_D2_pending => Dict(
        ()       => :stay,
        (:neg,)  => :seq_neg,
        (:pos,)  => :seq_pos,
    ),
    :a_D2                 => Dict(() => :stay),
    :a_D2_absent_via_o2a  => Dict(() => :stay),
    :a_D2_absent_via_o2b  => Dict(() => :stay),
)

const dir_to_path_D2 = Dict(
    pos => Dict(v => k for (k, v) in p2d)
    for (pos, p2d) in path_to_dir_D2
)

# ============================================================
# mbar_L per A-position (S-path → next A-position)
# ============================================================

"D1 left routing: at each phenotype, each path through `i_S(x)` routes to a next phenotype."
const mbar_L_D1 = Dict{Symbol, Dict{Tuple, Symbol}}(
    :a_D1_initial => Dict(
        ()           => :a_D1_initial,
        (:neg,)      => :a_D1_absent_via_o1a,
        (:pos,)      => :a_D1_pending,
        (:pos, :neg) => :a_D1_absent_via_o1b,
        (:pos, :pos) => :a_D1,
    ),
    :a_D1_pending => Dict(
        ()       => :a_D1_pending,
        (:neg,)  => :a_D1_absent_via_o1b,
        (:pos,)  => :a_D1,
    ),
    :a_D1                 => Dict(() => :a_D1),
    :a_D1_absent_via_o1a  => Dict(() => :a_D1_absent_via_o1a),
    :a_D1_absent_via_o1b  => Dict(() => :a_D1_absent_via_o1b),
)

"D2 left routing — parallel."
const mbar_L_D2 = Dict{Symbol, Dict{Tuple, Symbol}}(
    :a_D2_initial => Dict(
        ()           => :a_D2_initial,
        (:neg,)      => :a_D2_absent_via_o2a,
        (:pos,)      => :a_D2_pending,
        (:pos, :neg) => :a_D2_absent_via_o2b,
        (:pos, :pos) => :a_D2,
    ),
    :a_D2_pending => Dict(
        ()       => :a_D2_pending,
        (:neg,)  => :a_D2_absent_via_o2b,
        (:pos,)  => :a_D2,
    ),
    :a_D2                 => Dict(() => :a_D2),
    :a_D2_absent_via_o2a  => Dict(() => :a_D2_absent_via_o2a),
    :a_D2_absent_via_o2b  => Dict(() => :a_D2_absent_via_o2b),
)

# ============================================================
# mbar_R per A-position (A-direction-label → P-position)
# ============================================================
#
# Each A-direction at x recommends a P-position. The mapping captures
# the protocol's planned next order at each "consistent transition slot."

"D1 right recommendations: A-direction-label → recommended P-position at each phenotype."
const mbar_R_D1 = Dict{Symbol, Dict{Symbol, Symbol}}(
    :a_D1_initial => Dict(
        :stay            => :order_o1a,                # current emission
        :seq_neg         => :no_further_workup_D1,     # screen-neg → stop
        :seq_pos         => :order_o1b,                # screen-pos → confirmation
        :panel_pos_neg   => :no_further_workup_D1,     # panel ends at no_further_workup
        :panel_pos_pos   => :no_further_workup_D1,
    ),
    :a_D1_pending => Dict(
        :stay     => :order_o1b,
        :seq_neg  => :no_further_workup_D1,
        :seq_pos  => :no_further_workup_D1,
    ),
    :a_D1                 => Dict(:stay => :no_further_workup_D1),
    :a_D1_absent_via_o1a  => Dict(:stay => :no_further_workup_D1),
    :a_D1_absent_via_o1b  => Dict(:stay => :no_further_workup_D1),
)

"D2 right recommendations — parallel."
const mbar_R_D2 = Dict{Symbol, Dict{Symbol, Symbol}}(
    :a_D2_initial => Dict(
        :stay            => :order_o2a,
        :seq_neg         => :no_further_workup_D2,
        :seq_pos         => :order_o2b,
        :panel_pos_neg   => :no_further_workup_D2,
        :panel_pos_pos   => :no_further_workup_D2,
    ),
    :a_D2_pending => Dict(
        :stay     => :order_o2b,
        :seq_neg  => :no_further_workup_D2,
        :seq_pos  => :no_further_workup_D2,
    ),
    :a_D2                 => Dict(:stay => :no_further_workup_D2),
    :a_D2_absent_via_o2a  => Dict(:stay => :no_further_workup_D2),
    :a_D2_absent_via_o2b  => Dict(:stay => :no_further_workup_D2),
)

# ============================================================
# ♯_L direction maps  (S-path × next-A-direction → A-direction)
# ============================================================
#
# By cofree's structure, ♯_L = path concatenation: at A-position x,
# given S-path b and an A-direction at the next position (which
# corresponds to a path π through that next position's i_S),
# the result is the A-direction at x corresponding to (b ++ π).

"At A-position x in disease k (=:D1 or :D2), compute the A-direction-label resulting from the (S-path b) + (next-A-direction a) lifting."
function sharp_L(disease::Symbol, x::Symbol, b::Tuple, a::Symbol)
    next_pos_dict = disease == :D1 ? mbar_L_D1 : mbar_L_D2
    next_pos = next_pos_dict[x][b]
    dir_to_path = disease == :D1 ? dir_to_path_D1 : dir_to_path_D2
    π = dir_to_path[next_pos][a]
    combined_path = (b..., π...)
    path_to_dir = disease == :D1 ? path_to_dir_D1 : path_to_dir_D2
    return path_to_dir[x][combined_path]
end

# ============================================================
# ♯_R direction maps  (A-direction × P-direction → A-direction)
# ============================================================
#
# By thin-P's structure, ♯_R uses the canonical "shortest matching
# S-path" rule. For Law 2 (id P-direction), ♯_R(a, id) = a.
# For non-id P-direction e (a target order), find the A-direction at x
# whose mbar_R matches e and whose S-path is shortest.

"""
    sharp_R(disease, x, a, e) -> Symbol

At A-position `x`, given current A-direction `a` and P-direction `e`,
compute the lifted A-direction at x.

In v1.1's discrete-P, the only P-direction at any P-position is `:pt`
(the identity), so by Law 2 (counit) `sharp_R` always returns `a`.
This trivially satisfies the right-comodule axioms.

When P is upgraded to a protocol-category in v1.2 (free-P with
length-2 composites distinct + a "extend by length(P-morph) S-steps"
rule), `sharp_R` will become non-trivial.
"""
function sharp_R(disease::Symbol, x::Symbol, a::Symbol, e)
    return a    # Law 2 always (discrete P → e is :pt, the identity)
end

# ============================================================
# Building per-disease lenses (left and right coactions)
# ============================================================
#
# We use `subst_lazy` (v0.2.0) for the lens cods to avoid eager
# enumeration of subst polynomials. The bicomodule constructor uses
# `is_subst_of` for type-checking — fast, no enumeration.

"""
    build_left_coaction(disease) -> Lens

The left coaction λ_L : A_Dk_carrier → S_Dk.carrier ▷ A_Dk_carrier.
At each A-position, picks the cofree subtree from `i_S_Dk` and the
routing function from `mbar_L_Dk`.
"""
function build_left_coaction(disease::Symbol)
    A_carrier = disease == :D1 ? A_D1_carrier : A_D2_carrier
    S = disease == :D1 ? S_D1 : S_D2
    i_S_dict = disease == :D1 ? i_S_D1 : i_S_D2
    mbar_L_dict = disease == :D1 ? mbar_L_D1 : mbar_L_D2

    # Regular eager subst — S is the small sub-cofree (5 positions × max
    # 7 directions = ~280K subst positions, tractable in Julia). If this
    # ever becomes the bottleneck, swap to `subst_lazy` (Lens.cod has
    # accepted AbstractPolynomial since the 2026-04-28 Poly.jl PR).
    cod = subst(S.carrier, A_carrier)

    Lens(
        A_carrier, cod,
        # on-positions: x ↦ (i_S, mbar_L_x_as_Dict)
        x -> begin
            tree = i_S_dict[x]
            mbar = mbar_L_dict[x]
            # mbar is already a Dict from path → A-position, which is what
            # subst expects as the second component (a function from
            # S.directions(tree) → A.positions encoded as Dict)
            (tree, Dict{Any,Any}(p => v for (p, v) in mbar))
        end,
        # on-directions: at x, given a subst-direction (b, a) where
        # b ∈ S.directions(tree) (= path through tree) and a is an
        # A.direction at mbar_L_x[b], produce an A.direction at x.
        (x, ba_pair) -> begin
            b, a = ba_pair
            sharp_L(disease, x, b, a)
        end
    )
end

"""
    build_right_coaction(disease) -> Lens

The right coaction λ_R : A_Dk_carrier → A_Dk_carrier ▷ P_Dk.carrier.
At each A-position, picks (x, mbar_R) — the per-direction P-recommendation
function from `mbar_R_Dk`.
"""
function build_right_coaction(disease::Symbol)
    A_carrier = disease == :D1 ? A_D1_carrier : A_D2_carrier
    P = disease == :D1 ? P_D1 : P_D2
    mbar_R_dict = disease == :D1 ? mbar_R_D1 : mbar_R_D2

    # Regular eager subst (~16K positions per disease for the right side —
    # very tractable).
    cod = subst(A_carrier, P.carrier)

    Lens(
        A_carrier, cod,
        # on-positions: x ↦ (x, mbar_R_x_as_Dict)
        x -> begin
            mbar = mbar_R_dict[x]
            (x, Dict{Any,Any}(d => p for (d, p) in mbar))
        end,
        # on-directions: at x, given (a, e) where a ∈ A.directions(x)
        # and e ∈ P.directions(mbar_R[x][a]), produce an A.direction at x.
        (x, ae_pair) -> begin
            a, e = ae_pair
            sharp_R(disease, x, a, e)
        end
    )
end

# ============================================================
# The per-disease bicomodules
# ============================================================

"D1 bicomodule: A_D1_carrier as a (S_D1, P_D1)-bicomodule."
const A_D1_bicomodule = Bicomodule(
    A_D1_carrier, S_D1, P_D1,
    build_left_coaction(:D1),
    build_right_coaction(:D1),
)

"D2 bicomodule: A_D2_carrier as a (S_D2, P_D2)-bicomodule."
const A_D2_bicomodule = Bicomodule(
    A_D2_carrier, S_D2, P_D2,
    build_left_coaction(:D2),
    build_right_coaction(:D2),
)

# ============================================================
# Joint bicomodule  —  A_joint  =  A_D1_bicomodule  ⊗  A_D2_bicomodule
# ============================================================
#
# The formal joint bicomodule, the categorical artifact representing
# the full joint CDS. Originally deferred in v1.1 because eager
# `subst(carrier, carrier)` in the joint comonoid's duplicator blew up
# combinatorially (~16^25 jbars). The 2026-04-28 Poly.jl PR widened
# `Lens.cod` to `AbstractPolynomial` and routed the joint duplicator
# and joint coactions through `subst_lazy`, making the formal ⊗
# tractable on v1.1's carriers (~1.4s to construct, ~7.7s to validate).
#
# Considered and ruled out: a reachability-restricted "joint sub-
# comonoid" `S_joint`. Was the workaround under the eager-subst
# constraint; no longer needed since the formal ⊗ is cheap. Could be
# revisited in v1.2 if joint validation cost grows.

"""
    A_joint :: Bicomodule

The joint bicomodule `A_joint : (S_D1 ⊗ S_D2) ⇸ (P_D1 ⊗ P_D2)`,
constructed as the formal `Bicomodule` tensor product of the
per-disease bicomodules. This IS the categorical ground truth of
v1.1's joint CDS — coherence is established by the construction
faithfully realising the formal ⊗ plus
`validate_bicomodule_detailed` passing.
"""
const A_joint = parallel(A_D1_bicomodule, A_D2_bicomodule)
