# ============================================================
# History — the patient-history category H  (v1.6.B)
# ============================================================
#
# H is the patient-history category from §23-24 of the foundations
# doc — the cofree comonoid on Q rooted at the universal-empty
# list-state ∅. Under the toggle reframe (§22), Q = y^Σ_prob and σ
# is the strict total toggle coalgebra, so cofree-of-Q-rooted-at-∅
# unfolds without validity-restriction — every direction works at
# every state.
#
# We expose H in TWO co-existing views, both described in the
# foundations doc but operationally distinct:
#
#   * H_path — the path-discriminating category. Objects are
#     reachable list-states; morphisms are *sequences* of token-
#     toggles; distinct sequences with the same dom/cod are
#     distinct morphisms. Faithful to §24's "morphisms are
#     histories of problem-events." Functorially presented:
#     paths are `Vector{Symbol}` data, dom/cod/compose are
#     functions. No materialization required, scales freely.
#
#   * H_quot — the state-quotient comonoid. Morphisms are (dom, cod)
#     pairs canonically labeled by sorted-symmetric-difference
#     paths. Materialized as a Comonoid in (Poly, ▷) via
#     SmallCategory + from_category, suitable as the concrete
#     categorical object that A_h, DDx-projection, and the
#     simulator's two-level dynamics consume.
#
# Quotient functor π: H_path → H_quot collapses morphisms by
# (dom, cod). We don't materialize π itself, but the canonical
# representative under π is `realize_symdiff(dom, cod)`.
#
# Trajectory analytics (e.g., "did this protocol take an unusual
# route?") use H_path. State-determined consumers (fibers,
# DDx, simulator) use H_quot.
#
# ----------------------------------------------------------------
# Relationship to Poly.jl's `cofree_comonoid(Q, depth)`
# ----------------------------------------------------------------
#
# Cofree.jl's `cofree_comonoid(p, depth)` builds the abstract Cof(p)
# whose carrier-positions are p-behavior-trees of depth ≤ depth.
# For Q = y^Σ_prob (representable), all behavior trees of given
# depth are isomorphic up to direction-uniformity — the carrier
# doesn't directly carry list-state information.
#
# Cof(Q)|_x (foundations doc §23) — "the comonoid Cof(Q) restricted
# at x" — is the IMAGE of x under cofree_universal applied to the
# σ-coalgebra. That image is a sub-comonoid whose carrier-positions
# are list-states reachable from x. It IS H rooted at x.
#
# We construct H_quot directly via SmallCategory + from_category
# (matching `build_subcofree_comonoid` in ProtocolCompile.jl) rather
# than going through Cof(Q) + cofree_universal, because:
#   1. It's simpler — no need to manufacture the σ-as-Lens.
#   2. The result is the same up to iso (verifiable in tests).
#   3. The foundations-doc reading of C_x as "list-states + paths"
#      is direct in this construction.
# We provide a `behavior_tree_at` helper for cofree-cross-check
# in tests if needed.

# ============================================================
# History — the data carrier
# ============================================================

"""
    History(root::ListState=ListState_empty, depth::Int=4)

The patient-history category H rooted at `root` and bounded to
`depth` toggle-events from the root. The default root is ∅ (the
universal-empty list-state); the default depth (4) is a v1.6.B
choice balancing clinical reach and combinatorics.

A `History` value is a thin specification — both H_path and H_quot
views derive from it. Heavy materialization (e.g., `as_state_comonoid`)
is on-demand.
"""
struct History
    root::ListState
    depth::Int
    function History(root::ListState, depth::Int)
        valid_liststate(root) ||
            error("History: root has foreign tokens: $root")
        depth ≥ 0 ||
            error("History: depth must be ≥ 0; got $depth")
        new(root, depth)
    end
end

History(; root::ListState=ListState_empty, depth::Int=4) = History(root, depth)

function Base.show(io::IO, h::History)
    n_obj = length(reachable_liststates(h.root, depth=h.depth))
    print(io, "History(root=", h.root,
              ", depth=", h.depth,
              ", |objects|=", n_obj, ")")
end

# ============================================================
# Shared accessors — H-objects (= reachable list-states)
# ============================================================

"""
    objects(h::History) -> Vector{ListState}

All list-states reachable from `h.root` within `h.depth` toggles —
the carrier-objects of both H_path and H_quot. Order is insertion-
order from the BFS in `reachable_liststates`; for stable iteration,
sort by `length`.
"""
objects(h::History) = collect(reachable_liststates(h.root, depth=h.depth))

"""
    is_object(h::History, x::ListState) -> Bool

True iff `x` is reachable from `h.root` within `h.depth` toggles.
"""
is_object(h::History, x::ListState) =
    x in reachable_liststates(h.root, depth=h.depth)

# ============================================================
# H_path — path-discriminating view (functorially presented)
# ============================================================
#
# H_path morphisms are paths: `Path = Vector{Symbol}` with all
# elements in Σ_prob. Dom is the implicit starting state (carried
# by the caller); cod is computed by replaying toggles. Composition
# is concatenation. Identity is the empty path. No materialization.
# Distinct sequences with the same effect are distinct morphisms.

"""
    Path

Type alias for `Vector{Symbol}` — a sequence of token-toggles.
Each entry must be in Σ_prob.
"""
const Path = Vector{Symbol}

"""
    apply_path(x::ListState, π::Path) -> ListState

Replay a path of token-toggles starting from `x`. Equivalent to
folding `toggle` over `π`. Errors on foreign tokens.
"""
function apply_path(x::ListState, π::Path)
    cur = x
    for p in π
        cur = toggle(p, cur)
    end
    return cur
end

"""
    path_dom(::History, π::Path; from::ListState) -> ListState

The (declared) domain of a path. Trivial — paths in H_path don't
carry their dom intrinsically; the caller supplies it. Provided
for symmetry with `path_cod` and for use in test fixtures.
"""
path_dom(::History, π::Path; from::ListState) = from

"""
    path_cod(::History, π::Path; from::ListState) -> ListState

The codomain of a path applied from `from` — i.e., `apply_path(from, π)`.
"""
path_cod(::History, π::Path; from::ListState) = apply_path(from, π)

"""
    path_compose(π1::Path, π2::Path) -> Path

Compose two paths by concatenation: `π1 ∘ π2` returns `vcat(π1, π2)`.
No automatic dom/cod check — the caller composes morphisms whose
dom/cod align.
"""
path_compose(π1::Path, π2::Path) = vcat(π1, π2)

"""
    path_identity() -> Path

The empty path — the identity morphism at every H-object.
"""
path_identity() = Symbol[]

"""
    canonical_path(x::ListState, y::ListState) -> Path

The canonical (sorted-symdiff) path from `x` to `y` under H_path —
the canonical representative of the equivalence class
`{ π : apply_path(x, π) == y }` under the quotient π: H_path → H_quot.
Equivalent to `realize_symdiff(x, y)`.
"""
canonical_path(x::ListState, y::ListState) = realize_symdiff(x, y)

# ============================================================
# H_quot — state-quotient comonoid (materialized)
# ============================================================
#
# H_quot's morphisms are (dom, cod) pairs canonically labeled by
# sorted-symdiff. We materialize via SmallCategory + from_category,
# matching the existing pattern in ProtocolCompile.jl.

"""
    as_smallcategory(h::History) -> SmallCategory

Materialize H_quot as a `SmallCategory`:
- objects = reachable list-states from `h.root` within `h.depth`
- morphisms = `(dom, sorted-symdiff-path)` for *every* pair of
  reachable (dom, cod) states. Note: the depth bound applies to
  REACHABILITY-FROM-ROOT, not to morphism path-length. Two objects
  each within depth d of root can be up to symdiff-distance 2d apart;
  we include the morphism between them unconditionally so composition
  closure is automatic.
- identity at x = `(x, Symbol[])`
- composition = canonical-symdiff of the (dom, cod) pair —
  always in the morphism set since every reachable-pair has a
  morphism.

Morphism count = `|objects|^2`. At depth=2 with full Σ_prob
(|Σ_prob|=13, |objs|≈92), that's ~8.5K morphisms. At depth=4
(|objs|≈1093), ~1.2M — slow but completes. Use sparingly at depth>4.
"""
function as_smallcategory(h::History)
    objs = sort(objects(h); by=x -> (length(x), sort(collect(x))))
    objs_set = FinPolySet(objs)

    morphisms_list = Tuple{ListState,Path}[]
    morphism_dom = Dict{Tuple{ListState,Path},ListState}()
    morphism_cod = Dict{Tuple{ListState,Path},ListState}()
    morphism_identity = Dict{ListState,Tuple{ListState,Path}}()

    for x in objs
        for y in objs
            π = realize_symdiff(x, y)
            morph = (x, π)
            push!(morphisms_list, morph)
            morphism_dom[morph] = x
            morphism_cod[morph] = y
            if isempty(π)
                morphism_identity[x] = morph
            end
        end
    end
    morphs_set = FinPolySet(morphisms_list)

    # Group morphisms by dom for O(|objs|) composition lookup per f
    # instead of O(|morphisms|).
    morphs_by_dom = Dict{ListState,Vector{Tuple{ListState,Path}}}()
    for m in morphisms_list
        push!(get!(morphs_by_dom, morphism_dom[m], Tuple{ListState,Path}[]), m)
    end

    composition = Dict{Tuple{Tuple{ListState,Path},Tuple{ListState,Path}},Tuple{ListState,Path}}()
    for f in morphisms_list
        x = morphism_dom[f]
        y = morphism_cod[f]
        for g in morphs_by_dom[y]   # only morphisms with dom = y
            z = morphism_cod[g]
            combined = (x, realize_symdiff(x, z))
            # combined always exists in morphism_dom since we generated
            # every (x, *) pair above.
            composition[(f, g)] = combined
        end
    end

    return SmallCategory(objs_set, morphs_set,
                         morphism_dom, morphism_cod,
                         morphism_identity, composition)
end

"""
    as_state_comonoid(h::History) -> Comonoid

Materialize H_quot as a Comonoid in (Poly, ▷) via
`from_category(as_smallcategory(h))`. This is the concrete
categorical object suitable for the labeling functor U: H → Comon
(§24) and for downstream consumers (A_h fiber filtration, DDx
projection, simulator's two-level dynamics).

Computation cost is dominated by `as_smallcategory`; this wrapper
just runs `from_category` over the result.
"""
as_state_comonoid(h::History) = from_category(as_smallcategory(h))

# ============================================================
# Sub-history (= the labeling functor U at x)
# ============================================================
#
# Foundations doc §24: U: H → Comon(Poly, ▷) sends each H-object x
# to the derived comonoid C_x = Cof(Q)|_x — the sub-history rooted
# at x. We provide it operationally as a History constructor.

"""
    sub_history(h::History, x::ListState) -> History

The labeling functor's image at `x ∈ Ob(H)`: a `History` rooted at
`x` with depth = `h.depth - canonical-distance(h.root, x)`. This is
C_x (foundations doc §23-24): the sub-history reachable from `x`
within the remaining depth budget.

Errors if `x` is not an H-object of `h`.
"""
function sub_history(h::History, x::ListState)
    is_object(h, x) ||
        error("sub_history: $x is not an object of $h")
    distance = length(canonical_path(h.root, x))
    return History(x, h.depth - distance)
end

"""
    U(h::History, x::ListState) -> Comonoid

The labeling functor U: H → Comon(Poly, ▷) at `x ∈ Ob(H)`. Returns
the materialized Comonoid for the sub-history rooted at `x`.

Convenience: equivalent to `as_state_comonoid(sub_history(h, x))`.
Use sparingly — materializes a fresh Comonoid per call.
"""
U(h::History, x::ListState) = as_state_comonoid(sub_history(h, x))

# ============================================================
# Cross-check helper for cofree machinery (test-only convenience)
# ============================================================

"""
    behavior_tree_at(h::History, x::ListState; depth::Int=h.depth) -> BehaviorTree

The unique σ-behavior-tree rooted at `x`, depth-bounded to `depth`.
Each node has label `:step` (Q's single position) and children
indexed by Σ_prob — the child at direction `p` is the σ-tree at
`toggle(p, x)`.

Useful for cross-checking H against Cofree.jl's `cofree_comonoid(Q, depth)`
+ `cofree_universal` machinery in tests. Not used at runtime by
fibration / simulator code.
"""
function behavior_tree_at(h::History, x::ListState; depth::Int=h.depth)
    valid_liststate(x) || error("behavior_tree_at: foreign tokens in $x")
    depth ≥ 0 || error("behavior_tree_at: depth must be ≥ 0")
    if depth == 0
        return BehaviorTree(:step, Dict{Any,BehaviorTree}())
    end
    children = Dict{Any,BehaviorTree}(
        p => behavior_tree_at(h, toggle(p, x); depth=depth-1)
        for p in Σ_prob
    )
    return BehaviorTree(:step, children)
end
