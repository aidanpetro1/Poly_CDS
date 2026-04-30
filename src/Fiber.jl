# ============================================================
# A_h fibers — the H-fibration's fiber predicate  (v1.6.B PR 2)
# ============================================================
#
# Foundations doc §26: A is a contravariant pseudofunctor
# A : H^op → Bicomod(S, P), assigning each h ∈ Ob(H) a sub-bicomodule
# A_h ⊆ A_∅ defined by a predicate on A_∅(1). As h grows (more
# clinical content recorded), A_h shrinks (fewer A-positions remain
# consistent with h).
#
# The predicate, settled 2026-04-30 with Aidan:
#
#   is_h_compatible(h, (s_D1, s_D2)) iff
#     ∀ d ∈ {D1, D2}: restrict_to_disease(h, d) ⊆ realize(d, s_d)
#
# In words: h's disease-d-slice (the tokens namespaced to disease d
# in h) must be a subset of the position's per-disease realize.
# CC-provenance tokens don't constrain positions; they're carried
# along.
#
# Why this is structurally right:
#   * A_∅ ≅ A_∅ (all 25 positions): at h=∅, every restrict is ∅,
#     ⊆ anything.
#   * Contravariance: h ⊆ h' implies A_h ⊇ A_h'.
#   * Strict-coherence-on-fiber-crossings (§28): a position falls out
#     of A_h when h grows by adding a disease-d token that doesn't
#     match the current s_d's realize. Framework rejects, no silent
#     rebase.
#   * Incoherent h (e.g. both :D1_suspected and :D1_present in h)
#     yields empty A_h. **No validate_h_coherent gate** — empty
#     fiber IS the signal.
#
# ----------------------------------------------------------------
# Friedman's Fundamental Theorem of Informatics
# ----------------------------------------------------------------
#
# The predicate intentionally cannot distinguish "considered & ruled
# out" from "never on DDx" at the fiber level — that distinction
# lives in the patient's trajectory through ∫A, not in any snapshot.
# This is a structural reflection of Friedman's fundamental theorem
# of biomedical informatics (Friedman 2009): the value of a clinical
# decision support system lies in the *partnership* — the interaction
# trajectory between clinician and information resource — not in the
# data snapshot alone. Empty A_h at runtime is itself a meaningful
# signal (incoherent h has no compatible positions; the framework
# surfaces this rather than masking it).
#
# Reference: Friedman, C.P. (2009). "A 'Fundamental Theorem' of
# Biomedical Informatics." JAMIA 16(2): 169-170.
#
# ----------------------------------------------------------------
# Structural vs. dynamical separation
# ----------------------------------------------------------------
#
# The predicate captures what's NOT RULED OUT BY h's clinical content.
# What runtime ACTUALLY VISITS is the protocol-recommendation question
# (the ρ coaction). DDx routing is a runtime/dynamical property
# determined by what the protocol recommends, NOT a structural
# property of A_h. So:
#
#   * After chest_pain CC: h = {:chest_pain, :considering_D1}.
#     A_h still contains positions like (a_D1_initial, a_D2_pending)
#     — D2 isn't structurally excluded.
#   * The simulator never lands on those positions because the
#     protocol's ρ doesn't issue D2-observation orders in this fiber.
#
# Don't bake DDx routing into the predicate.

# ============================================================
# is_h_compatible — the fiber predicate
# ============================================================

"""
    is_h_compatible(h::ListState, joint_pos::Tuple{Symbol,Symbol}) -> Bool

True iff joint A-position `(s_D1, s_D2)` is in fiber A_h. The predicate:

  ∀ d ∈ {:D1, :D2}: restrict_to_disease(h, d) ⊆ realize(d, s_d)

i.e. h's disease-d-slice must be a subset of the position's per-disease
realize-content. CC-provenance tokens in h don't constrain positions.

Walkthrough (with v1.6.B Σ_prob and realize content):
  * `is_h_compatible(∅, (a_D1_initial, a_D2_initial))` = true
    (both restrictions are ∅ ⊆ anything).
  * `is_h_compatible({:chest_pain, :considering_D1}, (a_D1_initial, *))` = true
    (D1-restriction = {:considering_D1} ⊆ realize(:D1, :a_D1_initial) = {:considering_D1};
     D2-restriction = ∅ ⊆ anything).
  * `is_h_compatible({:chest_pain, :considering_D1}, (a_D1_pending, *))` = false
    (D1-restriction {:considering_D1} ⊄ realize(:D1, :a_D1_pending) = {:D1_suspected}).
  * `is_h_compatible({:D1_suspected, :D1_present}, *)` = false for all positions
    (incoherent h — no s_D1 has both :D1_suspected and :D1_present in realize).
"""
function is_h_compatible(h::ListState, joint_pos::Tuple{Symbol,Symbol})
    s_D1, s_D2 = joint_pos
    issubset(restrict_to_disease(h, :D1), realize(:D1, s_D1)) || return false
    issubset(restrict_to_disease(h, :D2), realize(:D2, s_D2)) || return false
    return true
end

"""
    fiber_membership(h::ListState, base::Bicomodule) -> BitVector

The membership table for fiber A_h over `base` (= A_∅). Entry `i` is
true iff `is_h_compatible(h, base.carrier.positions.elements[i])`.

This is the underlying data of the fiber filtration; consumed by
`materialize_fiber` (Fiber.jl PR 2 step 3) to construct the actual
sub-Bicomodule object.
"""
function fiber_membership(h::ListState, base::Bicomodule)
    positions = base.carrier.positions.elements
    return BitVector(is_h_compatible(h, p) for p in positions)
end

"""
    fiber_positions(h::ListState, base::Bicomodule) -> Vector

Just the positions of `base.carrier` that lie in fiber A_h —
filtered by `is_h_compatible`. Convenience accessor for consumers
that want the position list without the BitVector.
"""
function fiber_positions(h::ListState, base::Bicomodule)
    return [p for p in base.carrier.positions.elements
              if is_h_compatible(h, p)]
end

# ============================================================
# Direction-prune helpers  (B2 — v1.x-specific via mbar_L)
# ============================================================
#
# **Limitation note (B2).** These helpers use the v1.x compiled
# mbar_L_D1, mbar_L_D2 dicts directly to look up "next position given
# direction." This is the v1.x paths-as-directions encoding from §22
# of v1.3's compiler design. If v1.7 (FHIR substrate) or v1.8
# (⊙-composed shared-objective library) introduces Bicomodules whose
# directions aren't paths-through-cofree, replace these with the
# lens-generic (B1) variant: enumerate (S ▷ A)-directions, apply
# λ♯, and pull S-direction component for choice lookup.

"""
    next_pos_via_λ_per_disease(disease::Symbol, x::Symbol, path::Tuple) -> Symbol

The destination phenotype after walking `path` from per-disease
phenotype `x`. Direct lookup via the compiled mbar_L for that
disease. Errors on invalid paths.
"""
function next_pos_via_λ_per_disease(disease::Symbol, x::Symbol, path::Tuple)
    mbar = (disease === :D1) ? mbar_L_D1 :
           (disease === :D2) ? mbar_L_D2 :
           error("next_pos_via_λ_per_disease: unknown disease $(disease)")
    haskey(mbar, x) ||
        error("next_pos_via_λ_per_disease: no entry for phenotype $(x) in $(disease)")
    haskey(mbar[x], path) ||
        error("next_pos_via_λ_per_disease: invalid path $(path) at $(disease)/$(x)")
    return mbar[x][path]
end

"""
    next_pos_via_λ(joint_pos::Tuple{Symbol,Symbol},
                   joint_dir::Tuple{Tuple,Tuple}) -> Tuple{Symbol,Symbol}

Joint version: destination of joint direction `(path_D1, path_D2)`
applied to joint position `(x_D1, x_D2)`. Each disease advances along
its own path independently — matches the ⊗ structure of A_∅.
"""
function next_pos_via_λ(joint_pos::Tuple{Symbol,Symbol},
                        joint_dir::Tuple{Tuple,Tuple})
    x_D1, x_D2 = joint_pos
    path_D1, path_D2 = joint_dir
    return (next_pos_via_λ_per_disease(:D1, x_D1, path_D1),
            next_pos_via_λ_per_disease(:D2, x_D2, path_D2))
end

"""
    intermediate_phenotypes(disease::Symbol, x::Symbol, path::Tuple)
      -> Vector{Symbol}

The full sequence of phenotypes traversed when walking `path` from
`x` in `disease`'s sub-cofree S, INCLUDING `x` and the final
destination. For path = (), returns [x]. For path = (r,), returns
[x, mbar_L[x][(r,)]]. For path = (r1, r2), returns
[x, mbar_L[x][(r1,)], mbar_L[x][(r1, r2)]].

Used by A2 prune semantics — every intermediate phenotype must
satisfy the fiber predicate for the direction to be kept.
"""
function intermediate_phenotypes(disease::Symbol, x::Symbol, path::Tuple)
    out = Symbol[x]
    for k in 1:length(path)
        prefix = path[1:k]
        push!(out, next_pos_via_λ_per_disease(disease, x, prefix))
    end
    return out
end

"""
    keep_joint_direction(h::ListState, joint_pos::Tuple{Symbol,Symbol},
                         joint_dir::Tuple{Tuple,Tuple}) -> Bool

True iff joint direction `(path_D1, path_D2)` at joint position
`(x_D1, x_D2)` is KEPT in fiber A_h under A2 (full-path-stays-in-fiber)
prune semantics.

Per-disease check: for each disease d, every intermediate phenotype
along d's path (including start and end) must satisfy the d-restriction
of the fiber predicate. D1 and D2 are checked independently because
restrict_to_disease(h, d) decomposes per disease.
"""
function keep_joint_direction(h::ListState,
                              joint_pos::Tuple{Symbol,Symbol},
                              joint_dir::Tuple{Tuple,Tuple})
    x_D1, x_D2 = joint_pos
    path_D1, path_D2 = joint_dir

    h_D1 = restrict_to_disease(h, :D1)
    for s in intermediate_phenotypes(:D1, x_D1, path_D1)
        issubset(h_D1, realize(:D1, s)) || return false
    end

    h_D2 = restrict_to_disease(h, :D2)
    for s in intermediate_phenotypes(:D2, x_D2, path_D2)
        issubset(h_D2, realize(:D2, s)) || return false
    end

    return true
end

# ============================================================
# ∫A — the Grothendieck total space  (v1.6.B PR 2, δ presentation)
# ============================================================
#
# Foundations doc §27. ∫A is a category whose:
#   * objects are pairs (h, a) with h ∈ Ob(H) and a ∈ A_h(1)
#   * morphisms (h_1, a_1) → (h_2, a_2) are pairs (f, β) with
#     f : h_1 → h_2 in H and β : a_1 → f*(a_2) a witness in A_{h_1}
#
# Under v1.6.B's filtration semantics (§26: A_h ⊆ A_∅ as a sub-object),
# the reindexing f* is the natural inclusion, so β is just an
# A_{h_1}-morphism a_1 → a_2 with the strict-coherence requirement
# that a_2 ∈ A_{h_2} too (no silent rebase, §28).
#
# Morphism encoding: a single morphism in ∫A is a 4-tuple
# `(h_dom, a_dom, h_path, a_path)`, with h_path ∈ Path being the
# H_path morphism (sequence of token-toggles) and a_path being a
# sequence of A_∅-directions (paths-as-directions in v1.3+).
#
# Typing per Aidan's call (2026-04-30): only :vertical
# (h_path = (), within-fiber motion via a_path) and :horizontal
# (h_path ≠ (), between-fiber motion). Mixed motions arise as
# compositions of vertical ∘ horizontal or vice versa.
#
# Construction strategy (eager, depth-bounded):
#   1. Phase 1 — objects: enumerate (h, a) pairs filtered by
#      is_h_compatible.
#   2. Phase 2 — pure-vertical morphisms: for each (h, a), enumerate
#      A_∅-directions at a whose path stays in A_h (= keep_joint_direction).
#   3. Phase 3 — pure-horizontal morphisms: for each (h_1, h_2)
#      pair within intA_depth, enumerate H-paths between them; for
#      each (h_path, a) with a in BOTH A_{h_1} and A_{h_2}, emit a
#      morphism with a_path = ().
#   4. Phase 4 — composition closure: compose pure-vertical and
#      pure-horizontal morphisms iteratively until closure.
#   5. Wrap as SmallCategory.

"""
    int_A_object_type(h::ListState, a::Tuple{Symbol,Symbol}) -> Tuple

The standard encoding of an ∫A-object: just the pair `(h, a)` as a
plain `Tuple`. Used as elements of the SmallCategory's
`objects::FinPolySet`.
"""
int_A_object_type(h::ListState, a::Tuple{Symbol,Symbol}) = (h, a)

"""
    int_A_morphism_type(h_dom::ListState, a_dom::Tuple{Symbol,Symbol},
                        h_path::Vector{Symbol},
                        a_path::Vector{Tuple{Tuple,Tuple}}) -> Tuple

Standard encoding of an ∫A-morphism. The 4-tuple
`(h_dom, a_dom, h_path, a_path)` carries:
  * `h_dom, a_dom` — domain (h, a) pair
  * `h_path` — sequence of Σ_prob token-toggles for the H-side
  * `a_path` — sequence of A_∅-directions (themselves paths under
    v1.3 paths-as-directions) for the A-side

Codomain is computable: h_cod = apply_path(h_dom, h_path),
a_cod = apply A-side path step-by-step.

Vertical: h_path = []. Horizontal: h_path ≠ [] AND a_path = [].
Mixed (compositions): both non-empty.
"""
int_A_morphism_type(h_dom::ListState, a_dom::Tuple{Symbol,Symbol},
                    h_path::Vector{Symbol},
                    a_path::Vector) =
    (h_dom, a_dom, h_path, a_path)

"""
    apply_a_path(a_dom::Tuple{Symbol,Symbol},
                 a_path::Vector{Tuple{Tuple,Tuple}}) -> Tuple{Symbol,Symbol}

Apply a sequence of A-side directions starting from `a_dom`. Each
direction is a joint direction `(path_D1, path_D2)`; the destination
is computed via `next_pos_via_λ` and threaded through the sequence.
"""
function apply_a_path(a_dom::Tuple{Symbol,Symbol},
                      a_path::Vector)
    cur = a_dom
    for d in a_path
        cur = next_pos_via_λ(cur, d)
    end
    return cur
end

"""
    int_A_morph_cod(morph) -> Tuple{ListState, Tuple{Symbol,Symbol}}

Codomain of an ∫A-morphism: applies both h_path and a_path to compute
(h_cod, a_cod).
"""
function int_A_morph_cod(morph)
    h_dom, a_dom, h_path, a_path = morph
    h_cod = apply_path(h_dom, h_path)
    a_cod = apply_a_path(a_dom, a_path)
    return (h_cod, a_cod)
end

"""
    paths_between_in_h(h_1::ListState, h_2::ListState; max_length::Int)
      -> Vector{Vector{Symbol}}

Enumerate path-discriminated H_path morphisms from `h_1` to `h_2`
of length ≤ `max_length`. Under the toggle reframe, paths from h_1
to h_2 must apply each token in `symdiff(h_1, h_2)` an odd number
of times and other tokens an even number. The minimal paths are
the |symdiff|! orderings of the symdiff tokens.

For path-discriminating ∫A enumeration: returns ALL minimal paths
(orderings of the symdiff). Redundant paths (with extra back-and-forth
toggles) are not enumerated for v1.6.B; they're meaningful only for
trajectory-with-revisit analytics, which aren't on the v1.6 roadmap.
"""
function paths_between_in_h(h_1::ListState, h_2::ListState; max_length::Int)
    diff = sort(collect(symdiff(h_1, h_2)))
    length(diff) > max_length && return Vector{Vector{Symbol}}()
    isempty(diff) && return [Symbol[]]
    # All permutations of diff
    out = Vector{Vector{Symbol}}()
    function perms!(prefix::Vector{Symbol}, remaining::Vector{Symbol})
        if isempty(remaining)
            push!(out, copy(prefix))
            return
        end
        for i in 1:length(remaining)
            push!(prefix, remaining[i])
            perms!(prefix, vcat(remaining[1:i-1], remaining[i+1:end]))
            pop!(prefix)
        end
    end
    perms!(Symbol[], diff)
    return out
end

"""
    build_int_A(base::Bicomodule, history::History; intA_depth::Int=2)
      -> SmallCategory

Construct ∫A as a SmallCategory per §27, using the (δ) presentation
with vertical/horizontal-typed morphisms over the global (S, P) bases.

`intA_depth` bounds the H-side path length for horizontal morphisms.
The default (2) is sufficient for most clinical scenarios. At
intA_depth = 4 the construction is much heavier; opt in only when
trajectory analytics need it.

Throws if construction encounters an out-of-bound composition; this
indicates intA_depth is too low for the protocol's reachable structure.
"""
function build_int_A(base::Bicomodule, history::History; intA_depth::Int=2)
    # ----------------------------------------------------------------
    # Phase 1 — objects
    # ----------------------------------------------------------------
    objects_list = Tuple[]
    objects_set = Set{Any}()
    for h in objects(history)
        for a in fiber_positions(h, base)
            obj = int_A_object_type(h, a)
            if !(obj in objects_set)
                push!(objects_set, obj)
                push!(objects_list, obj)
            end
        end
    end

    # ----------------------------------------------------------------
    # Phase 2 — pure-vertical morphisms
    # ----------------------------------------------------------------
    morphisms_list = Tuple[]
    morphisms_set = Set{Any}()
    morphism_dom = Dict()
    morphism_cod = Dict()
    morphism_identity = Dict()

    for obj in objects_list
        h, a = obj
        # Identity at (h, a) — empty a_path
        id_morph = int_A_morphism_type(h, a, Symbol[],
                                       Vector{Any}())
        if !(id_morph in morphisms_set)
            push!(morphisms_set, id_morph)
            push!(morphisms_list, id_morph)
            morphism_dom[id_morph] = obj
            morphism_cod[id_morph] = obj
            morphism_identity[obj] = id_morph
        end
        # Non-trivial vertical morphisms — one per kept non-identity A-direction
        for d in direction_at(base.carrier, a).elements
            # Skip A-identity direction (handled above)
            if length(d) == 2 && isempty(d[1]) && isempty(d[2])
                continue
            end
            keep_joint_direction(h, a, d) || continue
            morph = int_A_morphism_type(h, a, Symbol[], Any[d])
            if !(morph in morphisms_set)
                push!(morphisms_set, morph)
                push!(morphisms_list, morph)
                morphism_dom[morph] = obj
                a_cod = next_pos_via_λ(a, d)
                morphism_cod[morph] = (h, a_cod)
            end
        end
    end

    # ----------------------------------------------------------------
    # Phase 3 — pure-horizontal morphisms
    # ----------------------------------------------------------------
    history_objects = collect(objects_set_listates(objects_list))
    for h_1 in history_objects
        for h_2 in history_objects
            h_1 == h_2 && continue
            for h_path in paths_between_in_h(h_1, h_2; max_length=intA_depth)
                # For each a that's in both A_{h_1} and A_{h_2}, emit
                # a pure-horizontal morphism (id_a-like, a_path = []).
                for a in fiber_positions(h_1, base)
                    is_h_compatible(h_2, a) || continue
                    morph = int_A_morphism_type(h_1, a, h_path,
                                                Vector{Any}())
                    if !(morph in morphisms_set)
                        push!(morphisms_set, morph)
                        push!(morphisms_list, morph)
                        morphism_dom[morph] = (h_1, a)
                        morphism_cod[morph] = (h_2, a)
                    end
                end
            end
        end
    end

    # ----------------------------------------------------------------
    # Phase 4 — composition closure (PARTIAL — bounded by intA_depth)
    # ----------------------------------------------------------------
    # Compose pairs iteratively until no new morphisms are added under
    # the depth bound. Compositions whose combined h_path exceeds
    # intA_depth are SKIPPED (not erroring) — full categorical closure
    # under path-discrimination is unbounded (round-trip paths can be
    # made arbitrarily long via toggle-and-back), so we ship a
    # PARTIAL CATEGORY closed under compositions of total h-path length
    # ≤ intA_depth.
    #
    # For v1.6.B's actual ∫A consumers (DDx projection, simulator's
    # single-step dynamics, validate_grothendieck_pointwise's slice-
    # at-h equivalence checks), single-step morphisms suffice and the
    # partial closure is sufficient. Document the limitation; revisit
    # if trajectory analytics need full closure later.
    composition = Dict()
    changed = true
    while changed
        changed = false
        # Snapshot to avoid concurrent modification during iteration
        snapshot = copy(morphisms_list)
        # Index by dom for O(|objects|) composition lookup
        morphs_by_dom = Dict{Any,Vector{Any}}()
        for m in snapshot
            push!(get!(morphs_by_dom, morphism_dom[m], []), m)
        end
        for f in snapshot
            f_cod = morphism_cod[f]
            haskey(morphs_by_dom, f_cod) || continue
            for g in morphs_by_dom[f_cod]
                # Compose f ∘ g (first f, then g; convention from
                # SmallCategory.composition keying)
                f_h_dom, f_a_dom, f_h_path, f_a_path = f
                g_h_dom, g_a_dom, g_h_path, g_a_path = g
                combined_h_path = vcat(f_h_path, g_h_path)
                combined_a_path = vcat(f_a_path, g_a_path)
                # Skip out-of-bound compositions silently (partial closure)
                length(combined_h_path) > intA_depth && continue
                composed = int_A_morphism_type(f_h_dom, f_a_dom,
                                               combined_h_path,
                                               combined_a_path)
                if !haskey(composition, (f, g))
                    composition[(f, g)] = composed
                end
                if !(composed in morphisms_set)
                    push!(morphisms_set, composed)
                    push!(morphisms_list, composed)
                    morphism_dom[composed] = (f_h_dom, f_a_dom)
                    morphism_cod[composed] = morphism_cod[g]
                    changed = true
                end
            end
        end
    end

    # ----------------------------------------------------------------
    # Wrap as SmallCategory
    # ----------------------------------------------------------------
    objs_polyset = FinPolySet(objects_list)
    morphs_polyset = FinPolySet(morphisms_list)

    return SmallCategory(objs_polyset, morphs_polyset,
                         morphism_dom, morphism_cod,
                         morphism_identity, composition)
end

# Internal helper to extract unique h's from objects_list
function objects_set_listates(objects_list)
    out = Set{ListState}()
    for (h, _) in objects_list
        push!(out, h)
    end
    return out
end

"""
    morph_kind(morph) -> Symbol

Classify an ∫A-morphism as `:vertical` (h_path empty), `:horizontal`
(h_path non-empty AND a_path empty), or `:mixed` (both non-empty).

Vertical and horizontal are the primary types per §28's two-level
dynamics; mixed arise as compositions and represent simultaneous
within-visit + problem-list updates (e.g., "observation result returns
+ corresponding problem-list update applied").
"""
function morph_kind(morph)
    _, _, h_path, a_path = morph
    isempty(h_path) && return :vertical
    isempty(a_path) && return :horizontal
    return :mixed
end

# ============================================================
# Per-fiber sub-Bicomodule construction  (β presentation)
# ============================================================
#
# materialize_fiber(base, h) builds A_h as a strict Bicomodule with
# sub-bases (S_h, P_h) per §26's "sub-bicomodule" reading. This is the
# heavy categorical construction — paired with build_int_A above to
# give us the dual presentation.
#
# Equivalence to ∫A's slice at h is the Grothendieck-pointwise
# equivalence (validated by validate_grothendieck_pointwise — task #20).
#
# ----------------------------------------------------------------
# Performance limitation (settled 2026-04-30, lazy-by-default β-side)
# ----------------------------------------------------------------
#
# `materialize_fiber` is EXPENSIVE on its FIRST call against a given
# `base` Bicomodule, because building the sub-Comonoids S_h and P_h
# requires `cached_to_category(base.left_base)` and
# `cached_to_category(base.right_base)`. For v1.x's joint comonoids
# (parallel-construction-built), `to_category` evaluates the joint
# duplicator pointwise on every (position, direction) pair — slow at
# joint scale (>3 minutes observed for `S_joint` of v1.x's two-disease
# protocols).
#
# After the first call, the cache makes subsequent fibers fast. But
# eagerly materializing all fibers at protocol-load (the original
# v1.6.B PR 2 plan) is intractable.
#
# **Decision (Aidan, 2026-04-30): LAZY-BY-DEFAULT for β-side.**
#
# - `FiberedAssessment` constructs only `∫A` (δ presentation) eagerly
#   at protocol-load.
# - `materialize_fiber` is invoked on-demand: when an external
#   consumer (v1.8 shared-objective composition, etc.) actually needs
#   A_h as a strict Bicomodule, or when `validate_grothendieck_pointwise`
#   is opt-in invoked for QA.
# - For v1.6.B's load-bearing consumers (DDx, simulator, runtime-side
#   fiber checks), only ∫A is consulted — no β-side cost.
#
# The strict (β) machinery is preserved for forward-compat; the cost
# is just deferred to actual use rather than paid upfront. If `to_category`
# performance becomes a hot path for some consumer, the next move is
# direct sub-Comonoid construction that bypasses `to_category` entirely
# (skipping the SmallCategory round-trip).

# Module-level cache for `to_category` results — these are pure
# functions of the Comonoid, expensive on joint comonoids (parallel
# constructions evaluate their duplicator pointwise via the formal-⊗
# formula on each call). We pay the cost ONCE per Comonoid identity,
# then reuse for every fiber materialization.
#
# Keys are `objectid` to avoid hashing the full Comonoid (which would
# itself be expensive). The cache is populated lazily.
const _TO_CATEGORY_CACHE = Dict{UInt,SmallCategory}()

"""
    cached_to_category(c::Comonoid) -> SmallCategory

Memoized `to_category(c)`. The first call for each unique `c`
(by objectid) does the expensive work; subsequent calls return the
cached result. Critical for performance of `materialize_fiber` over
many fibers — `to_category` on joint comonoids is the v1.6.B PR 2
performance bottleneck without this cache.
"""
function cached_to_category(c::Comonoid)
    key = objectid(c)
    haskey(_TO_CATEGORY_CACHE, key) && return _TO_CATEGORY_CACHE[key]
    cat = to_category(c)
    _TO_CATEGORY_CACHE[key] = cat
    return cat
end

"""
    reachable_positions_in_comonoid(parent::Comonoid, seeds) -> Set

Closure of `seeds` under one-step-reachability via `parent`'s morphisms:
starting from the seed positions, follow morphisms forward and add
each reached destination. Iterated to fixed point.

Used to build sub-Comonoids (S_h, P_h) from "directly recommended"
seed positions — closure ensures the sub-Comonoid is closed under
the parent's category structure.
"""
function reachable_positions_in_comonoid(parent::Comonoid, seeds)
    cat = cached_to_category(parent)
    kept = Set(collect(seeds))
    changed = true
    while changed
        changed = false
        for m in cat.morphisms.elements
            d = cat.dom[m]
            if d in kept
                c = cat.cod[m]
                if !(c in kept)
                    push!(kept, c)
                    changed = true
                end
            end
        end
    end
    return kept
end

"""
    build_sub_comonoid(parent::Comonoid, seeds) -> Comonoid

Construct a sub-Comonoid of `parent` whose carrier-positions are the
closure of `seeds` under reachability via `parent`'s morphisms.
Morphisms restrict to those whose dom AND cod are in the closure.
Identity, composition, eraser, duplicator inherit from `parent`'s
SmallCategory presentation, restricted appropriately.

Built via `to_category(parent)` → filter → `from_category`. The result
is a strict Comonoid that validates under `validate_comonoid` iff
`parent` does.
"""
function build_sub_comonoid(parent::Comonoid, seeds)
    cat = cached_to_category(parent)
    kept_objs = reachable_positions_in_comonoid(parent, seeds)

    sub_objs_list = [o for o in cat.objects.elements if o in kept_objs]
    sub_objs_set = FinPolySet(sub_objs_list)

    sub_morphs_list = Any[]
    sub_dom = Dict()
    sub_cod = Dict()
    sub_id = Dict()
    for m in cat.morphisms.elements
        d = cat.dom[m]
        c = cat.cod[m]
        if d in kept_objs && c in kept_objs
            push!(sub_morphs_list, m)
            sub_dom[m] = d
            sub_cod[m] = c
        end
    end
    sub_morphs_set = FinPolySet(sub_morphs_list)

    for o in sub_objs_list
        if haskey(cat.identity, o)
            id_m = cat.identity[o]
            id_m in sub_morphs_list && (sub_id[o] = id_m)
        end
    end

    sub_comp = Dict()
    for ((f, g), composed) in cat.composition
        if (f in sub_morphs_list) && (g in sub_morphs_list) && (composed in sub_morphs_list)
            sub_comp[(f, g)] = composed
        end
    end

    sub_cat = SmallCategory(sub_objs_set, sub_morphs_set,
                            sub_dom, sub_cod, sub_id, sub_comp)
    return from_category(sub_cat)
end

"""
    materialize_fiber(base::Bicomodule, h::ListState; validate::Bool=true)
      -> Bicomodule

Construct the strict sub-Bicomodule A_h with sub-bases (S_h, P_h)
per §26 (β presentation). Steps:

  1. Filter A_∅.positions to A_h.positions via `is_h_compatible`.
  2. For each kept position, prune A-directions via A2 (full-path-stays-
     in-fiber) using `keep_joint_direction`.
  3. Build A_h.carrier as the resulting sub-Polynomial.
  4. Compute S-seeds = `i_S` images of A_h.positions (from
     `base.left_coaction.on_positions`); build sub-Comonoid S_h.
  5. Compute P-seeds = `mbar_R` images for kept (a, d) pairs; build
     sub-Comonoid P_h.
  6. Restrict lenses λ, ρ to the new sub-domain and sub-bases.
  7. Wrap as `Bicomodule`. Validate if requested.

The result is a real Poly.jl `Bicomodule` — it slots into Poly.jl's
monoidal operations (⊗, parallel, compose) directly, important for
v1.7+ external composition.

**B2 limitation**: this implementation uses `mbar_L_D1`, `mbar_L_D2`
(via `next_pos_via_λ`) for direction-walking, tying it to v1.x's
paths-as-directions encoding. For Bicomodules built outside v1.x's
compiled-protocol pipeline, replace with the lens-generic (B1)
restriction.
"""
function materialize_fiber(base::Bicomodule, h::ListState; validate::Bool=true)
    # ----------------------------------------------------------------
    # 1-3. A_h.carrier — positions filtered + directions pruned
    # ----------------------------------------------------------------
    a_pos_kept = [p for p in base.carrier.positions.elements
                    if is_h_compatible(h, p)]
    isempty(a_pos_kept) &&
        error("materialize_fiber: empty A_h at h=$(h) — incoherent fiber predicate, check h's content")

    a_dirs = Dict()
    for a in a_pos_kept
        kept = [d for d in direction_at(base.carrier, a).elements
                  if keep_joint_direction(h, a, d)]
        a_dirs[a] = FinPolySet(kept)
    end
    a_carrier = Polynomial(FinPolySet(a_pos_kept), x -> a_dirs[x])

    # ----------------------------------------------------------------
    # 4. S_h — sub-Comonoid of S
    # ----------------------------------------------------------------
    s_seeds = Set()
    for a in a_pos_kept
        (s, _) = base.left_coaction.on_positions.f(a)
        push!(s_seeds, s)
    end
    S_h = build_sub_comonoid(base.left_base, s_seeds)

    # ----------------------------------------------------------------
    # 5. P_h — sub-Comonoid of P, seeded by recommendations on kept directions
    # ----------------------------------------------------------------
    p_seeds = Set()
    for a in a_pos_kept
        (_, choice) = base.right_coaction.on_positions.f(a)
        for d in a_dirs[a].elements
            haskey(choice, d) && push!(p_seeds, choice[d])
        end
    end
    P_h = build_sub_comonoid(base.right_base, p_seeds)

    # ----------------------------------------------------------------
    # 6. Restricted lenses
    # ----------------------------------------------------------------
    # λ_h : a_carrier → S_h.carrier ▷ a_carrier
    # The on_positions function inherits from base's λ, but with the
    # codomain re-interpreted: choice's domain is now restricted to
    # S_h.directions[s], and its image must land in a_carrier.positions.
    # By construction (S_h.positions = i_S images, A2 prune),
    # closure holds.
    cod_λ = subst(S_h.carrier, a_carrier)
    λ_h = Lens(
        a_carrier, cod_λ,
        x -> begin
            (s, choice) = base.left_coaction.on_positions.f(x)
            # Restrict choice's domain to S_h.directions[s]
            sh_dirs = direction_at(S_h.carrier, s)
            restricted_choice = Dict{Any,Any}()
            for ds in sh_dirs.elements
                # Look up choice for this S-direction; should be in a_carrier.positions
                if haskey(choice, ds)
                    restricted_choice[ds] = choice[ds]
                end
            end
            (s, restricted_choice)
        end,
        (x, ba_pair) -> begin
            # Inherit from base's on_directions
            base.left_coaction.on_directions.f(x).f(ba_pair)
        end
    )

    # ρ_h : a_carrier → a_carrier ▷ P_h.carrier
    cod_ρ = subst(a_carrier, P_h.carrier)
    ρ_h = Lens(
        a_carrier, cod_ρ,
        x -> begin
            (a, choice) = base.right_coaction.on_positions.f(x)
            ah_dirs = a_dirs[x]
            restricted_choice = Dict{Any,Any}()
            for da in ah_dirs.elements
                if haskey(choice, da)
                    restricted_choice[da] = choice[da]
                end
            end
            (a, restricted_choice)
        end,
        (x, ae_pair) -> begin
            base.right_coaction.on_directions.f(x).f(ae_pair)
        end
    )

    # ----------------------------------------------------------------
    # 7. Build and validate
    # ----------------------------------------------------------------
    bm = Bicomodule(a_carrier, S_h, P_h, λ_h, ρ_h)
    if validate
        validate_bicomodule(bm) ||
            error("materialize_fiber: A_h fails bicomodule axioms at h=$(h)")
    end
    return bm
end

# ============================================================
# FiberedAssessment — the v1.6.B fibration as a single struct
# ============================================================
#
# Wraps base Bicomodule, History, ∫A SmallCategory, plus on-demand
# caches for per-fiber Bicomodules / sub-Comonoids / membership tables.
#
# Construction is EAGER on the (δ)-side (∫A) and LAZY on the (β)-side
# (per-fiber Bicomodules). See the performance limitation note above
# materialize_fiber for the rationale.

"""
    FiberedAssessment(base::Bicomodule, history::History;
                      intA_depth::Int=2)

The H-fibration of `base` over `history`, with both presentations
available:
  * `int_A` — the Grothendieck total space (δ presentation), eager.
  * `fiber_bicomodules` — per-h strict sub-Bicomodules (β presentation),
    materialized on demand via `fiber_bicomodule(fa, h)`.

Construction-time cost: dominated by `build_int_A` (~1 minute at
depth=2 with v1.x's two-disease protocols). β-side cost is paid only
for fibers that get touched.
"""
struct FiberedAssessment
    base::Bicomodule
    history::History
    int_A::SmallCategory
    fiber_bicomodules::Dict{ListState,Bicomodule}
    fiber_S::Dict{ListState,Comonoid}
    fiber_P::Dict{ListState,Comonoid}
    membership::Dict{ListState,BitVector}
end

function FiberedAssessment(base::Bicomodule, history::History;
                           intA_depth::Int=2)
    int_A = build_int_A(base, history; intA_depth=intA_depth)
    return FiberedAssessment(
        base, history, int_A,
        Dict{ListState,Bicomodule}(),
        Dict{ListState,Comonoid}(),
        Dict{ListState,Comonoid}(),
        Dict{ListState,BitVector}(),
    )
end

function Base.show(io::IO, fa::FiberedAssessment)
    n_obj = length(fa.int_A.objects.elements)
    n_morph = length(fa.int_A.morphisms.elements)
    n_materialized = length(fa.fiber_bicomodules)
    print(io, "FiberedAssessment(",
              "history=", fa.history,
              ", ∫A=", n_obj, " objects/", n_morph, " morphisms",
              ", β-fibers materialized=", n_materialized,
              ")")
end

# ============================================================
# δ-side accessors  (cheap, query ∫A directly)
# ============================================================

"""
    fiber_slice_objects(fa::FiberedAssessment, h::ListState)
      -> Vector{Tuple{Symbol,Symbol}}

The A-positions at h — i.e., positions `a` such that `(h, a)` is an
object of `∫A`. Pulled from the cached membership table for O(|positions|)
filtering, with the result memoized per h.
"""
function fiber_slice_objects(fa::FiberedAssessment, h::ListState)
    bv = fiber_membership_cached!(fa, h)
    pos = fa.base.carrier.positions.elements
    return [pos[i] for i in eachindex(pos) if bv[i]]
end

"""
    vertical_morphisms_at(fa::FiberedAssessment, h::ListState,
                          a::Tuple{Symbol,Symbol}) -> Vector

All vertical morphisms in ∫A at `(h, a)` — i.e., morphisms with
`h_path = []` and `dom == (h, a)`. Filters ∫A's morphism set; cheap
because `morph_kind` is local.
"""
function vertical_morphisms_at(fa::FiberedAssessment, h::ListState,
                                a::Tuple{Symbol,Symbol})
    out = []
    target_dom = (h, a)
    for m in fa.int_A.morphisms.elements
        morph_kind(m) === :vertical || continue
        fa.int_A.dom[m] == target_dom || continue
        push!(out, m)
    end
    return out
end

"""
    horizontal_morphisms_at(fa::FiberedAssessment, h::ListState,
                            a::Tuple{Symbol,Symbol}) -> Vector

All pure-horizontal morphisms in ∫A at `(h, a)` — h_path non-empty,
a_path empty.
"""
function horizontal_morphisms_at(fa::FiberedAssessment, h::ListState,
                                  a::Tuple{Symbol,Symbol})
    out = []
    target_dom = (h, a)
    for m in fa.int_A.morphisms.elements
        morph_kind(m) === :horizontal || continue
        fa.int_A.dom[m] == target_dom || continue
        push!(out, m)
    end
    return out
end

# ============================================================
# Membership cache (mutating accessor)
# ============================================================

"""
    fiber_membership_cached!(fa::FiberedAssessment, h::ListState)
      -> BitVector

Returns the BitVector of `is_h_compatible` evaluations for fiber `h`,
computing it on the first call and caching for subsequent calls.
"""
function fiber_membership_cached!(fa::FiberedAssessment, h::ListState)
    haskey(fa.membership, h) && return fa.membership[h]
    bv = fiber_membership(h, fa.base)
    fa.membership[h] = bv
    return bv
end

# ============================================================
# β-side accessors  (lazy, materialize on demand)
# ============================================================

"""
    fiber_bicomodule(fa::FiberedAssessment, h::ListState;
                      validate::Bool=false) -> Bicomodule

The strict per-fiber Bicomodule A_h with sub-bases (S_h, P_h),
materializing on demand. The first call against any base pays the
`cached_to_category` cost (~minutes for joint comonoids); subsequent
calls reuse the cache.

Use sparingly — for v1.6.B's load-bearing consumers prefer the (δ)-side
accessors (`fiber_slice_objects`, `vertical_morphisms_at`) which don't
trigger materialization.
"""
function fiber_bicomodule(fa::FiberedAssessment, h::ListState;
                          validate::Bool=false)
    haskey(fa.fiber_bicomodules, h) && return fa.fiber_bicomodules[h]
    bm = materialize_fiber(fa.base, h; validate=validate)
    fa.fiber_bicomodules[h] = bm
    return bm
end

# ============================================================
# Reindexing  (foundations doc §26)
# ============================================================
#
# For f : h_1 → h_2 an H-morphism (path of toggles taking h_1 to h_2),
# the reindexing f* : A_h_2 → A_h_1 is the natural inclusion under
# v1.6.B's filtration semantics. Operationally: a position a ∈ A_h_2
# is also a position of A_h_1 (since A_h_2 ⊆ A_h_1 by contravariance),
# so f*(a) = a. The "morphism" is the identity-on-position with
# domain re-cast to A_h_2 and codomain to A_h_1.

"""
    reindex(fa::FiberedAssessment, f_h_path::Vector{Symbol},
            h_dom::ListState, a::Tuple{Symbol,Symbol})
      -> Tuple{Symbol,Symbol}

The reindexing of A-position `a` along H-morphism `f_h_path : h_dom → h_cod`,
where `h_cod = apply_path(h_dom, f_h_path)`. Returns `a` unchanged
(since reindexing is the natural inclusion under the filtration
semantics) — but errors if `a` isn't actually in the domain fiber
A_h_cod (caller bug).

Use this in code that needs to be explicit about the
fiber-membership cast: passing a position from one fiber to another's
context. The runtime check enforces strict-coherence-on-fiber-crossings
(§28): no silent rebase of out-of-fiber positions.
"""
function reindex(fa::FiberedAssessment, f_h_path::Vector{Symbol},
                 h_dom::ListState, a::Tuple{Symbol,Symbol})
    h_cod = apply_path(h_dom, f_h_path)
    is_h_compatible(h_cod, a) ||
        error("reindex: position $(a) not in A_$(h_cod); cannot reindex from $(h_dom). Strict-coherence violation.")
    is_h_compatible(h_dom, a) ||
        error("reindex: position $(a) not in A_$(h_dom); inclusion fails. Check fiber predicates.")
    return a
end

# ============================================================
# ∫A query operations  (enumerators, morphism filters)
# ============================================================

"""
    total_space(fa::FiberedAssessment) -> Vector

All `(h, a)` objects of `∫A` — the Grothendieck total space. Returned
in the order they were added during ∫A construction (stable across
runs).
"""
total_space(fa::FiberedAssessment) = collect(fa.int_A.objects.elements)

"""
    grothendieck_morphisms(fa::FiberedAssessment,
                           dom::Tuple{ListState,Tuple{Symbol,Symbol}},
                           cod::Tuple{ListState,Tuple{Symbol,Symbol}})
      -> Vector

All `∫A`-morphisms from `dom` to `cod`. Iterates `fa.int_A.morphisms`
and filters by the dom/cod tags. Returns vertical, horizontal, and
mixed morphisms uniformly — caller can post-classify with `morph_kind`.
"""
function grothendieck_morphisms(fa::FiberedAssessment,
                                dom, cod)
    out = []
    for m in fa.int_A.morphisms.elements
        fa.int_A.dom[m] == dom || continue
        fa.int_A.cod[m] == cod || continue
        push!(out, m)
    end
    return out
end

"""
    morphisms_from(fa::FiberedAssessment,
                   dom::Tuple{ListState,Tuple{Symbol,Symbol}})
      -> Vector

All ∫A-morphisms whose domain is `dom`. Useful for "what can happen
next from here?" queries — feeds the simulator's next-step logic.
"""
function morphisms_from(fa::FiberedAssessment, dom)
    out = []
    for m in fa.int_A.morphisms.elements
        fa.int_A.dom[m] == dom || continue
        push!(out, m)
    end
    return out
end

# ============================================================
# Grothendieck pointwise coherence  (PR 2 step 3c)
# ============================================================
#
# Light-version validator: checks that the (δ)-side fiber_slice_objects(h)
# matches the (β)-side fiber_bicomodule(h).carrier.positions for each h
# materialized.
#
# This is the MINIMAL coherence check — verifies that both presentations
# agree on the OBJECTS of A_h. Deeper morphism-level Grothendieck-
# equivalence (verifying that vertical morphisms in ∫A at h correspond
# to morphisms in the (β)-Bicomodule's category presentation) is
# deferred — it requires constructing the category presentation of A_h
# (via to_category) and comparing morphism sets, which is expensive
# (paying β-side materialization + further category enumeration).
#
# Opt-in: drives β-side materialization for the fibers it checks.

"""
    validate_grothendieck_pointwise(fa::FiberedAssessment, h::ListState;
                                     materialize::Bool=true) -> Bool

Light coherence check that the (δ)-side and (β)-side presentations
of A_h agree on objects.

If `materialize=true` (default), forces materialization of the
(β)-side Bicomodule for `h` (paying the per-base `cached_to_category`
cost on first call). Set `materialize=false` to skip h's that haven't
been materialized yet — useful for "validate only what's been touched."

**Light reading** (v1.6.B): equivalence of object sets. Morphism-level
equivalence is deferred — for v1.6.B's load-bearing consumers, object-
level agreement is sufficient.
"""
function validate_grothendieck_pointwise(fa::FiberedAssessment, h::ListState;
                                          materialize::Bool=true)
    delta_objects = Set(fiber_slice_objects(fa, h))

    if !materialize && !haskey(fa.fiber_bicomodules, h)
        @warn "validate_grothendieck_pointwise: fiber not yet materialized at h=$(h); skipping"
        return true
    end

    A_h = fiber_bicomodule(fa, h; validate=false)
    beta_objects = Set(A_h.carrier.positions.elements)

    return delta_objects == beta_objects
end

"""
    validate_grothendieck_all(fa::FiberedAssessment; materialize::Bool=false) -> Vector

Run the pointwise validator across every h in the history. Returns
`Vector{NamedTuple}` of (h, ok) pairs. With `materialize=true`, drives
β-materialization for all fibers — this is the OPT-IN heavy QA pass
that pays for full β-side construction.

Default `materialize=false` only checks fibers that have already been
materialized (e.g. by external composition or prior pointwise calls).
"""
function validate_grothendieck_all(fa::FiberedAssessment; materialize::Bool=false)
    out = NamedTuple[]
    for h in objects(fa.history)
        ok = validate_grothendieck_pointwise(fa, h; materialize=materialize)
        push!(out, (h=h, ok=ok))
    end
    return out
end
