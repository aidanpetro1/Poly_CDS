# ============================================================
# Compositional observation polynomials  (v1.1)
# ============================================================
#
# Compositional design as in v1, but using `coproduct(ps...)` from
# Poly.jl v0.2.0 instead of left-associated binary `+`. That gives flat
# `(k, x)` tags instead of the nested `(1, (1, …, x))` chains v1 had to
# navigate via `unwrap_obs_tag`. The helper is gone in v1.1 — flat tags
# don't need it.
#
# The interface readings stay the same:
#
#   p_o1a, p_o1b, ...     atomic — y² each (one position, two results)
#   p_D1_obs              = coproduct(p_o1a, p_o1b) — clinician picks
#   p_D2_obs              = coproduct(p_o2a, p_o2b, p_o2c)
#   p_obs                 = p_D1_obs * p_D2_obs (Cartesian — joint state,
#                            independent advancement)
#
# What's NEW conceptually in v1.1: these polynomials are now the input
# to `cofree_comonoid(p_D_obs, depth=1)` to derive S_Dk in
# `Bicomodule.jl`. The patient (a coalgebra for `p_obs`) plugs into
# the cofree-derived S via the universal property.

# ============================================================
# Atomic per-observation polynomials
# ============================================================

"Per-observation polynomial: `y²` with one position labeled by the obs name."
const p_o1a = monomial(FinPolySet([:o1a]), Results)
const p_o1b = monomial(FinPolySet([:o1b]), Results)
const p_o2a = monomial(FinPolySet([:o2a]), Results)
const p_o2b = monomial(FinPolySet([:o2b]), Results)
const p_o2c = monomial(FinPolySet([:o2c]), Results)

# ============================================================
# Intake-stage polynomial  (v1.6)
# ============================================================
#
# The intake stage's observation polynomial is orthogonal to the per-
# disease workup polynomials — chief complaint isn't asked again during
# workup, and workup observations aren't asked during intake. In the
# compose-based architecture (`A_intake ⊙ A_workup_joint`), the two
# polynomials underpin different bicomodules whose only contact is
# through the middle comonoid (`S_workup_joint`).

"Chief-complaint polynomial: `y^|CCResults|` with one position labeled `:chief_complaint`."
const p_chief_complaint = monomial(FinPolySet([:chief_complaint]), CCResults)

"Intake-stage observation polynomial. v1.6: alias for `p_chief_complaint` (single-observation intake)."
const p_intake = p_chief_complaint

# ============================================================
# Per-disease observation polynomials via `coproduct` (flat tags)
# ============================================================

"""
    p_D1_obs

D1's observation polynomial = `coproduct(p_o1a, p_o1b)`. Polynomial:
`2y²`. Positions are flat-tagged: `(1, :o1a)` and `(2, :o1b)`. Each has
two directions `{:neg, :pos}`. v0.2.0's `coproduct` skips the binary-`+`
nesting that v1 had to unwrap.
"""
const p_D1_obs = coproduct(p_o1a, p_o1b)

"D2's observation polynomial = `coproduct(p_o2a, p_o2b, p_o2c)`. Polynomial: `3y²`."
const p_D2_obs = coproduct(p_o2a, p_o2b, p_o2c)

# ============================================================
# Joint observation polynomial via `*` (Cartesian)
# ============================================================

"""
    p_obs

Joint observation polynomial `p_D1_obs * p_D2_obs`. Cartesian product:
positions are pairs `((k_D1, obs_D1), (k_D2, obs_D2))` — 6 joint
positions; directions at each are tagged-sum of the per-disease
direction-sets — 4 directions (two per side). Polynomial: `6y⁴`.

Used as the *interface* polynomial that the patient coalgebra responds
on. The bicomodule's S is derived from it via cofree.
"""
const p_obs = p_D1_obs * p_D2_obs

# ============================================================
# Helpers for navigating flat-tagged positions
# ============================================================
#
# With v0.2.0's flat coproduct tags, positions of `p_D1_obs` look like
# `(1, :o1a)` instead of nested `(1, (1, :o1a))`. The helpers below
# pull out the underlying obs-symbol and the joint-position breakdown.

"Underlying observation name from a per-disease polynomial position. `(1, :o1a) ↦ :o1a`."
obs_of(tagged) = tagged isa Tuple ? tagged[2]::Symbol : tagged::Symbol

"All (clinical-name, internal-tag) pairs for D1's polynomial positions."
obs_in_p_D1_obs() = [(obs_of(t), t) for t in p_D1_obs.positions.elements]

"All (clinical-name, internal-tag) pairs for D2's polynomial positions."
obs_in_p_D2_obs() = [(obs_of(t), t) for t in p_D2_obs.positions.elements]

"""
    obs_in_p_obs() -> Vector

For the joint polynomial: returns `((d1_obs_name, d2_obs_name), (d1_tag, d2_tag))`
for each joint position.
"""
function obs_in_p_obs()
    out = Tuple[]
    for pos in p_obs.positions.elements
        d1_tag, d2_tag = pos
        push!(out, ((obs_of(d1_tag), obs_of(d2_tag)), pos))
    end
    out
end

# ============================================================
# Problem-list polynomial Q  (v1.6.B — H-fibration, toggle reframe)
# ============================================================
#
# Q encodes problem-list events at the list-state level (foundations
# doc §22, post-2026-04-30 toggle reframe). Q is REPRESENTABLE:
#
#   Q = y^Σ_prob
#
# i.e. one position (labeled `:step`) with |Σ_prob| directions
# (one per problem-token). The Q-coalgebra σ : ListState → Q(ListState)
# = ListState → ListState^Σ_prob is the strict, total **toggle**
# function:
#
#   σ(x)(p) = (x ∖ {p}) if p ∈ x else (x ∪ {p}).
#
# Each token-direction p is always usable at every state x; the
# `add` / `remove` distinction is recoverable from context (`p ∉ x`
# means direction p performs an add at x; `p ∈ x` means it performs
# a remove). The polynomial structure no longer carries op-labels —
# they are NOT needed: all the categorical content is in the
# directions of y^Σ_prob.
#
# Why this beats the earlier (op-as-position) draft:
#   * σ is single-valued and total — no enabled-relation handwaving.
#   * cofree_comonoid(Q, depth) IS H directly under §23-24's path-
#     category reading; no custom build needed in History.jl.
#   * The op-set discussion vanishes; future per-problem status
#     transitions arrive as direction-set extensions of per-problem
#     polynomials, not as op-extensions of Q.
#
# Polynomial cardinality: 1 position, |Σ_prob| directions. For v1.6.B
# (|Σ_prob| = 13) that's y^13.

"""
    Q :: Polynomial

The problem-list-event polynomial, `y^Σ_prob`. One position labeled
`:step`; directions are problem-tokens. The strict toggle coalgebra
σ (defined below) is the unique map `ListState → Q(ListState)` driving
the patient-history category H = cofree(Q, depth) rooted at ∅.

The op-distinction (add vs remove) is implicit in the (state, direction)
pair — recoverable via `op_for(p, x)` in `ProblemVocabulary.jl`.
"""
const Q = representable(FinPolySet(sort(collect(Σ_prob))))

# ============================================================
# σ — the strict toggle coalgebra
# ============================================================
#
# σ : ListState → Q(ListState) = ListState → ListState^Σ_prob.
# Single-valued and total. Concretely: at each list-state x, σ(x)
# is the function `p ↦ toggle(p, x)`. We expose it both as a Julia
# function (`sigma_Q(x)(p)`) and as a tabulated form for use in
# building H's cofree structure.

"""
    sigma_Q(x::ListState) -> Function

The strict polynomial coalgebra σ at list-state `x`. Returns a
function `Σ_prob → ListState` defined by direction-toggle: for each
`p ∈ Σ_prob`, `sigma_Q(x)(p) = toggle(p, x)`.

This is total (every direction is defined) and single-valued — under
Q = y^Σ_prob, an element of Q(ListState) is exactly a function
Σ_prob → ListState.

Used by `History.jl` (PR 1 #7) to construct H = cofree(Q, depth)
rooted at ∅: the cofree-universal lens of σ produces H's carrier and
the H-morphism structure directly.
"""
function sigma_Q(x::ListState)
    valid_liststate(x) ||
        error("sigma_Q: foreign tokens in $(x); not a v1.6.B ListState")
    return p -> toggle(p, x)
end

"""
    sigma_Q_table(x::ListState) -> Dict{Symbol,ListState}

Tabulated form of σ at `x` — a Dict from each token-direction to its
post-toggle list-state. Convenient for building behavior-trees and
for direct equality testing in unit tests.
"""
function sigma_Q_table(x::ListState)
    valid_liststate(x) ||
        error("sigma_Q_table: foreign tokens in $(x); not a v1.6.B ListState")
    return Dict{Symbol,ListState}(p => toggle(p, x) for p in Σ_prob)
end

"""
    reachable_liststates(root::ListState=ListState_empty;
                         depth::Union{Int,Nothing}=nothing)
      -> Set{ListState}

All list-states reachable from `root` under σ — i.e., closure under
toggle by directions in Σ_prob. Optionally truncated at `depth`
(default: full closure, finite since `|reachable| ≤ 2^|Σ_prob|`).

Under the toggle reframe, the reachable closure from ∅ is exactly
`2^Σ_prob` (every subset is reachable in `|subset|` toggles), but
the runtime cofree carrier is depth-bounded — see `History.jl`.

Used by `History.jl` to enumerate H's objects and by
`validate_history_quotient` (PR 3) to check Θ's image lands inside
the reachable closure.
"""
function reachable_liststates(root::ListState=ListState_empty;
                              depth::Union{Int,Nothing}=nothing)
    seen = Set{ListState}([root])
    frontier = Set{ListState}([root])
    d = 0
    while !isempty(frontier) && (depth === nothing || d < depth)
        next_frontier = Set{ListState}()
        for x in frontier
            for p in Σ_prob
                x′ = toggle(p, x)
                if !(x′ in seen)
                    push!(seen, x′)
                    push!(next_frontier, x′)
                end
            end
        end
        frontier = next_frontier
        d += 1
    end
    return seen
end
