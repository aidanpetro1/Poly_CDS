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
