# ============================================================
# Problem vocabulary  (v1.6.B — H-fibration)
# ============================================================
#
# v1.6.B introduces a patient-history category H whose objects are
# problem-list configurations (subsets of a problem alphabet Σ_prob)
# and whose morphisms are sequences of problem-events. This file
# declares Σ_prob, the ListState type, and the toggle transition
# function that drives Q's coalgebra. Q itself (the polynomial
# y^Σ_prob) and σ-as-Lens live in `Polynomials.jl`; H lives in
# `History.jl`.
#
# ----------------------------------------------------------------
# Layered Σ_prob (carried as naming convention; Grade enum deferred)
# ----------------------------------------------------------------
#
# The v1.6.B problem-token alphabet has three logical layers. Layering
# is carried as a naming convention + sub-Set declarations below; we do
# NOT type-tag tokens with a Grade enum. The structural formalization
# (the span / comma-category over the considering sub-alphabet Σ_DDx —
# see project_polycds_v16_design.md) is deferred to a future version
# when guideline composition (v1.8) makes it pay rent.
#
#   1. CC-provenance tokens — sticky entries recording the patient's
#      chief complaint. Naming: bare CC name (`:chest_pain`,
#      `:abd_pain`, `:dyspnea`, `:fatigue`). Added by `cc_realize` at
#      intake; never touched by Θ. (`:well_visit` produces NO problem-
#      list entry by design — a routine check leaves no provenance.)
#
#   2. Active-DDx tokens — record which diseases are currently being
#      considered. Naming: `:considering_<Dk>`. Added by `cc_realize`
#      AND mirrored in `realize(d, a_d_initial)` for proper Θ symmetric-
#      difference cleanup as workup advances off the initial state.
#
#   3. Per-disease state tokens — current per-disease summary. Naming:
#      `:<Dk>_<status>`. Set by `realize(d, s)` for s past-initial.
#
# The CC-provenance layer's symbols intentionally coincide with values
# in `CCResults` (Vocabulary.jl): `:chest_pain` is both a CC-observation
# value and a problem-list token. The contexts don't conflict — CC
# values appear as inputs to `cc_realize`, Σ_prob tokens appear in
# ListStates and as outputs of `cc_realize` / `realize`.
#
# ----------------------------------------------------------------
# The toggle reframe (2026-04-30): tokens are DIRECTIONS, not positions
# ----------------------------------------------------------------
#
# Earlier draft positioned ops `{add, remove}` as Q-positions and σ as
# the validity-restricted enabled relation. This was multi-valued and
# required a custom path-category build for H (cofree-of-Q wouldn't
# match §23-24's reading without restriction).
#
# Reframe (Aidan, 2026-04-30): ops aren't structural — they're
# context-dependent. Make Q = y^Σ_prob (a single position, |Σ_prob|
# directions). σ : ListState → ListState^Σ_prob becomes the strict
# toggle coalgebra: `σ(x)(p) = x ∖ {p}` if `p ∈ x` else `x ∪ {p}`.
# Total, single-valued. The op-distinction (add vs remove) is fully
# recoverable from context — at any state x, direction p is an "add"
# if p ∉ x else a "remove."
#
# Benefit: H = cofree(Q, depth) directly, no custom path-category code.
# The foundations doc §22 reflects this.
#
# Status enum on ListState is dropped for v1.6.B (returns when the
# problem-internal coalgebra arrives — escalate/resolve become
# direction-set extensions of per-problem polynomials, NOT op-set
# extensions of Q). ListState is `Set{Symbol}` (membership only);
# acquisition order lives in H as the path back to ∅.

# ============================================================
# Σ_prob — the v1.6.B problem-token alphabet
# ============================================================

"CC-provenance tokens (layer 1) — sticky problem-list entries recording the patient's chief complaint."
const Σ_prob_cc_provenance = Set{Symbol}([
    :chest_pain,
    :abd_pain,
    :dyspnea,
    :fatigue,
    # NOTE: :well_visit is intentionally absent — a routine check leaves
    # no problem-list provenance. cc_realize(:well_visit) = ∅.
])

"Active-DDx tokens (layer 2) — which diseases are currently being considered."
const Σ_prob_considering = Set{Symbol}([
    :considering_D1,
    :considering_D2,
])

"Per-disease state tokens (layer 3) — set by realize(d, s) for s past-initial."
const Σ_prob_disease_state = Set{Symbol}([
    :D1_suspected, :D1_present, :D1_absent,
    :D2_suspected, :D2_present, :D2_absent,
])

"The full v1.6.B problem-token alphabet (union of the three layers)."
const Σ_prob = union(
    Σ_prob_cc_provenance,
    Σ_prob_considering,
    Σ_prob_disease_state,
)

# ============================================================
# ListState — current problem-list snapshot
# ============================================================

"""
    ListState

A snapshot of currently-active problem-list tokens. v1.6.B is
membership-only: `ListState = Set{Symbol}`, no per-token Status.
Acquisition order is recovered from the H-trajectory (the path of
toggle-events back to the universal root ∅).
"""
const ListState = Set{Symbol}

"The empty list-state — universal root x_0 of the patient-history category H."
const ListState_empty = Set{Symbol}()

"""
    valid_liststate(x) -> Bool

True iff every token in `x` is a member of Σ_prob. Useful for guarding
authoring-time errors and as a precondition to ListState-consuming
machinery (σ, realize, Θ, …).
"""
valid_liststate(x::ListState) = all(p -> p in Σ_prob, x)

# ============================================================
# toggle — the strict transition function driving Q's coalgebra
# ============================================================

"""
    toggle(p::Symbol, x::ListState) -> ListState

Toggle problem-token `p` in list-state `x`. Total: if `p ∈ x` returns
`x ∖ {p}` (semantically a "remove"); if `p ∉ x` returns `x ∪ {p}`
(semantically an "add"). Errors on tokens not in `Σ_prob`.

This is the deterministic transition function underlying Q's strict
polynomial coalgebra σ : ListState → ListState^Σ_prob (defined in
`Polynomials.jl`). The op-distinction (add vs remove) is implicit in
the (state, direction) pair and recoverable at any tree-node of H.
"""
function toggle(p::Symbol, x::ListState)
    p in Σ_prob ||
        error("toggle: $(p) is not in Σ_prob (got non-Σ_prob token)")
    return p in x ? setdiff(x, Set([p])) : union(x, Set([p]))
end

"""
    op_for(p::Symbol, x::ListState) -> Symbol

Recover the implicit op for direction `p` at state `x`: `:add` if
`p ∉ x`, `:remove` if `p ∈ x`. Useful for rendering H-trajectories
in clinician-facing form (the polynomial structure no longer carries
the op label, but the semantic distinction is recoverable).
"""
op_for(p::Symbol, x::ListState) = (p in x) ? :remove : :add

# ============================================================
# Symmetric-difference helper for the Θ derivation (used in PR 1 #4)
# ============================================================

"""
    realize_symdiff(before::Set{Symbol}, after::Set{Symbol})
      -> Vector{Symbol}

Express the change from `before` to `after` (both subsets of Σ_prob)
as a sequence of toggle directions. Returns `sort(setdiff(before, after) ∪
setdiff(after, before))` — the symmetric-difference tokens in
deterministic (sorted) order.

Each token in the returned sequence is to be applied via `toggle`,
producing an H-morphism from `before` to `after`. With the toggle
reframe, `before` and `after` and the set of toggle-tokens determine
the H-morphism up to ordering of commuting toggles; sorted order is
the canonical representative.

If `before == after`, returns an empty vector (Θ-image is `id_h`).
"""
function realize_symdiff(before::Set{Symbol}, after::Set{Symbol})
    return sort(collect(symdiff(before, after)))
end

# ============================================================
# Token-disease classification  (v1.6.B PR 2)
# ============================================================
#
# The fiber predicate `is_h_compatible` (in Fiber.jl) needs to slice
# a list-state by disease-namespace. The naming convention from the
# §22 toggle-reframe header makes this mechanical:
#
#   * :considering_<Dk>           — disease k, active-DDx layer
#   * :Dk_suspected | _present | _absent  — disease k, state layer
#   * everything else (CC-provenance) belongs to no specific disease
#
# We hand-code per-disease token sets rather than parsing token names
# at runtime — fast, type-stable, easy to verify by inspection.

"All Σ_prob tokens namespaced to disease D1 (active-DDx + state layers)."
const Σ_prob_D1 = Set{Symbol}([
    :considering_D1,
    :D1_suspected, :D1_present, :D1_absent,
])

"All Σ_prob tokens namespaced to disease D2."
const Σ_prob_D2 = Set{Symbol}([
    :considering_D2,
    :D2_suspected, :D2_present, :D2_absent,
])

"""
    disease_namespace(d::Symbol) -> Set{Symbol}

The full Σ_prob slice belonging to disease `d`. Errors on unknown
disease symbols. Used by `restrict_to_disease` and the fiber
predicate.
"""
function disease_namespace(d::Symbol)
    d === :D1 && return Σ_prob_D1
    d === :D2 && return Σ_prob_D2
    error("disease_namespace: unknown disease $(d) — expected :D1 or :D2")
end

"""
    disease_of_token(p::Symbol) -> Union{Symbol,Nothing}

The disease a Σ_prob token belongs to (`:D1`, `:D2`), or `nothing`
for CC-provenance tokens (which don't belong to any specific disease).
Errors on tokens not in Σ_prob.
"""
function disease_of_token(p::Symbol)
    p in Σ_prob ||
        error("disease_of_token: $(p) is not in Σ_prob")
    p in Σ_prob_D1 && return :D1
    p in Σ_prob_D2 && return :D2
    return nothing  # CC-provenance layer
end

"""
    restrict_to_disease(h::ListState, d::Symbol) -> ListState

The disease-`d` slice of list-state `h`: `h ∩ disease_namespace(d)`.
This is the "h's clinical content for disease d" projection used by
the fiber predicate `is_h_compatible`. CC-provenance tokens do not
contribute and are dropped.
"""
function restrict_to_disease(h::ListState, d::Symbol)
    return intersect(h, disease_namespace(d))
end
