# ============================================================
# Differential — V2 master-D bicomodule  D : O ⇸ P
# ============================================================
#
# Defines the data shape of the master bicomodule, the V2
# coherence-axiom validator, and a hand-authored toy D for
# the D1/D2 protocol.

# ============================================================
# OComonoid — the left base
# ============================================================

"""
    OComonoid

Observation comonoid `O = cofree(Q, depth)`. Carries the observation-
event alphabet `Σ` and the depth bound. O-positions are encounter logs
`w ∈ Σ^{≤depth}`; O-directions at log `w` are `Σ` if `|w| < depth`,
else empty.

The struct is a parameter wrapper; `as_polynomial(O)` materializes
`Q = y^Σ` as a Poly.Polynomial, and `as_comonoid(O)` materializes
`cofree_comonoid(Q, depth)` as a real Poly.Comonoid (for use with
Poly.jl's categorical machinery — `validate_comonoid`, comodule
construction, Kan-extension queries in v1.7+).

Materialization is on-demand because cofree comonoid carriers grow
fast in `(|Σ|, depth)` (tree count is a tower of exponentials) — the
toy uses `depth=10` for trajectory bookkeeping, but materialization
should typically use `depth ≤ 3`.
"""
struct OComonoid
    Σ::Set{Symbol}
    depth::Int
end

"""
    as_polynomial(O::OComonoid) -> Polynomial

Build the representable polynomial `Q = y^Σ` (single position `:pt`,
directions = `Σ`) underlying `O = cofree(Q, depth)`.
"""
as_polynomial(O::OComonoid) = representable(FinPolySet(sort(collect(O.Σ))))

"""
    as_comonoid(O::OComonoid; depth=O.depth) -> Comonoid

Materialize `O` as a real Poly.jl `Comonoid` via `cofree_comonoid(Q, depth)`.
Pass a smaller `depth` than `O.depth` to avoid the tower-of-exponentials
cost when Poly.jl machinery is invoked (`validate_comonoid`, Kan
extensions, etc.).
"""
function as_comonoid(O::OComonoid; depth::Int=O.depth)
    cofree_comonoid(as_polynomial(O), depth)
end

"""
    O_positions(O::OComonoid) -> Vector{Vector{Symbol}}

Enumerate all O-positions (encounter logs) up to depth.
"""
function O_positions(O::OComonoid)
    positions = Vector{Symbol}[Symbol[]]
    frontier = positions
    for _d in 1:O.depth
        new_frontier = Vector{Symbol}[]
        for w in frontier, σ in O.Σ
            push!(new_frontier, vcat(w, σ))
        end
        append!(positions, new_frontier)
        frontier = new_frontier
    end
    return positions
end

"""
    O_directions_at(O::OComonoid, w::Vector{Symbol}) -> Vector{Symbol}

O-directions at log `w`: `Σ` if below the depth bound, else empty.
"""
O_directions_at(O::OComonoid, w::Vector{Symbol}) =
    length(w) < O.depth ? sort(collect(O.Σ)) : Symbol[]

# ============================================================
# Differential — the master bicomodule
# ============================================================

"""
    Differential{P_typ, Q_typ}

Master bicomodule `D : O ⇸ P` as authored data tables.

  * `O`           — `OComonoid`, the left base
  * `positions`   — D-positions (joint disease frame for the toy)
  * `P_positions` — joint workup-state pointers
  * `f`           — `(p, σ) → next D-position`; missing entries are identity
  * `emit`        — `(p, σ) → P-position`; under post-σ readout,
                     `emit[(p, σ)] == workup_state(f_p(σ))`
  * `sharp_L`     — back-direction of λ_L; vestigial under post-σ readout
                     (path concatenation is implicit) but kept for
                     non-canonical authoring

`D.Σ` resolves to `D.O.Σ` via a `getproperty` shim.
"""
struct Differential{P_typ, Q_typ}
    O::OComonoid
    positions::Vector{P_typ}
    P_positions::Vector{Q_typ}
    f::Dict{Tuple{P_typ, Symbol}, P_typ}
    emit::Dict{Tuple{P_typ, Symbol}, Q_typ}
    sharp_L::Dict{Tuple{P_typ, Symbol, Symbol}, Symbol}
end

function Base.getproperty(D::Differential, name::Symbol)
    if name === :Σ
        return getfield(D, :O).Σ
    else
        return getfield(D, name)
    end
end

Base.propertynames(D::Differential, private::Bool=false) =
    (fieldnames(typeof(D))..., :Σ)

"""
    f_at(D::Differential, p, σ) -> position

Look up `f_p(σ)`. Missing entries default to identity (returns `p`).
"""
function f_at(D::Differential, p, σ::Symbol)
    σ in D.O.Σ ||
        error("f_at: $(σ) is not in Σ")
    return get(D.f, (p, σ), p)
end

"""
    emit_at(D::Differential, p, σ) -> P-position

Look up `emit_p(σ)`. Errors if no emission is authored for `(p, σ)`.
"""
function emit_at(D::Differential, p, σ::Symbol)
    haskey(D.emit, (p, σ)) ||
        error("emit_at: no emission authored for ($(p), $(σ))")
    return D.emit[(p, σ)]
end

"""
    sharp_L_at(D::Differential, p, σ, σ′) -> Σ-event

Look up `sharp_L(p, σ, σ′)`. Default is `σ′`.
"""
function sharp_L_at(D::Differential, p, σ::Symbol, σ′::Symbol)
    return get(D.sharp_L, (p, σ, σ′), σ′)
end

# ============================================================
# Coherence-axiom validator (post-σ readout consistency)
# ============================================================

"""
    validate_v2_axiom(D::Differential, workup_state::Function; verbose=false) -> Bool

Verify that for every authored `emit[(p, σ)]`,

    emit[(p, σ)]  ==  workup_state(f_at(D, p, σ))

This is the post-σ readout convention; under it, the bicomodule
compatibility axiom holds by construction. Returns `true` on full
agreement; `verbose=true` prints offending entries.
"""
function validate_v2_axiom(D::Differential, workup_state::Function; verbose::Bool=false)
    issues = Tuple[]
    for ((p, σ), emit_val) in D.emit
        p_next = get(D.f, (p, σ), p)
        expected = workup_state(p_next)
        if emit_val != expected
            push!(issues, (p, σ, emit_val, expected))
        end
    end
    if isempty(issues)
        verbose && println("validate_v2_axiom: all $(length(D.emit)) emit entries follow post-σ readout.")
        return true
    else
        if verbose
            println("validate_v2_axiom: $(length(issues)) post-σ readout violations:")
            for (p, σ, actual, expected) in issues
                println("  emit($(p), $(σ)) = $(actual), expected $(expected) = workup_state(f_p(σ))")
            end
        end
        return false
    end
end

# ============================================================
# Tiny illustrative example (smoke-tests the data shape)
# ============================================================

const _TINY_D_POSITIONS = [:p0, :p1]
const _TINY_D_P_POSITIONS = [:q0, :q1]
const _TINY_D_SIGMA = Set([:σa, :σb])

const _TINY_D_F = Dict{Tuple{Symbol, Symbol}, Symbol}(
    (:p0, :σa) => :p1,
)

"workup_state map for tiny_D."
tiny_D_workup_state(p::Symbol) = p == :p0 ? :q0 : :q1

const _TINY_D_EMIT = Dict{Tuple{Symbol, Symbol}, Symbol}(
    (:p0, :σa) => :q1,
    (:p0, :σb) => :q0,
    (:p1, :σa) => :q1,
    (:p1, :σb) => :q1,
)

const _TINY_D_SHARP_L = Dict{Tuple{Symbol, Symbol, Symbol}, Symbol}()
const _TINY_D_O = OComonoid(_TINY_D_SIGMA, 5)

const tiny_D = Differential{Symbol, Symbol}(
    _TINY_D_O,
    _TINY_D_POSITIONS,
    _TINY_D_P_POSITIONS,
    _TINY_D_F,
    _TINY_D_EMIT,
    _TINY_D_SHARP_L,
)

# ============================================================
# D1/D2 toy — hand-authored Differential
# ============================================================
#
# 4 phenotypes per disease (collapsed via_o1a/via_o1b), 16 D-positions,
# 8 Σ_obs_v2 events.

const TOY_V2_PHENOTYPES_D1 = [:a_D1_initial, :a_D1_pending, :a_D1, :a_D1_absent]
const TOY_V2_PHENOTYPES_D2 = [:a_D2_initial, :a_D2_pending, :a_D2, :a_D2_absent]

const TOY_V2_POSITIONS = vec([(s1, s2) for s1 in TOY_V2_PHENOTYPES_D1,
                                          s2 in TOY_V2_PHENOTYPES_D2])

"V2 observation-event alphabet: 8 result-events (per-disease screen + confirm)."
const Σ_obs_v2 = Set{Symbol}([
    :result_o1a_pos, :result_o1a_neg,
    :result_o1b_pos, :result_o1b_neg,
    :result_o2a_pos, :result_o2a_neg,
    :result_o2b_pos, :result_o2b_neg,
])

const _toy_v2_workup_D1 = Dict{Symbol, Symbol}(
    :a_D1_initial => :order_o1a,
    :a_D1_pending => :order_o1b,
    :a_D1         => :disease_D1_present,
    :a_D1_absent  => :disease_D1_absent,
)

const _toy_v2_workup_D2 = Dict{Symbol, Symbol}(
    :a_D2_initial => :order_o2a,
    :a_D2_pending => :order_o2b,
    :a_D2         => :disease_D2_present,
    :a_D2_absent  => :disease_D2_absent,
)

"""
    toy_v2_workup_state(p) -> Tuple{Symbol, Symbol}

Joint workup-state pointer for the toy: per-disease lookup followed by
tupling.
"""
function toy_v2_workup_state(p::Tuple{Symbol, Symbol})
    s_D1, s_D2 = p
    return (_toy_v2_workup_D1[s_D1], _toy_v2_workup_D2[s_D2])
end

const TOY_V2_P_POSITIONS = vec([toy_v2_workup_state((s1, s2))
                                 for s1 in TOY_V2_PHENOTYPES_D1,
                                     s2 in TOY_V2_PHENOTYPES_D2])

# Per-disease (phenotype, σ) → next phenotype. Substantive authoring lives here.
const _toy_v2_per_disease_f = Dict{Tuple{Symbol, Symbol}, Symbol}(
    (:a_D1_initial, :result_o1a_pos) => :a_D1_pending,
    (:a_D1_initial, :result_o1a_neg) => :a_D1_absent,
    (:a_D1_pending, :result_o1b_pos) => :a_D1,
    (:a_D1_pending, :result_o1b_neg) => :a_D1_absent,
    (:a_D2_initial, :result_o2a_pos) => :a_D2_pending,
    (:a_D2_initial, :result_o2a_neg) => :a_D2_absent,
    (:a_D2_pending, :result_o2b_pos) => :a_D2,
    (:a_D2_pending, :result_o2b_neg) => :a_D2_absent,
)

# Which disease component does an event apply to?
function _toy_v2_disease_of(σ::Symbol)
    s = String(σ)
    occursin("o1", s) && return :D1
    occursin("o2", s) && return :D2
    return nothing
end

# Build joint f from per-disease transitions.
function _build_toy_v2_f()
    f = Dict{Tuple{Tuple{Symbol, Symbol}, Symbol}, Tuple{Symbol, Symbol}}()
    for p in TOY_V2_POSITIONS, σ in Σ_obs_v2
        s_D1, s_D2 = p
        d = _toy_v2_disease_of(σ)
        if d === :D1 && haskey(_toy_v2_per_disease_f, (s_D1, σ))
            f[(p, σ)] = (_toy_v2_per_disease_f[(s_D1, σ)], s_D2)
        elseif d === :D2 && haskey(_toy_v2_per_disease_f, (s_D2, σ))
            f[(p, σ)] = (s_D1, _toy_v2_per_disease_f[(s_D2, σ)])
        end
    end
    return f
end

# Build emit via post-σ readout.
function _build_toy_v2_emit(f::Dict)
    emit = Dict{Tuple{Tuple{Symbol, Symbol}, Symbol}, Tuple{Symbol, Symbol}}()
    for p in TOY_V2_POSITIONS, σ in Σ_obs_v2
        emit[(p, σ)] = toy_v2_workup_state(get(f, (p, σ), p))
    end
    return emit
end

const _TOY_V2_F = _build_toy_v2_f()
const _TOY_V2_EMIT = _build_toy_v2_emit(_TOY_V2_F)
const _TOY_V2_SHARP_L = Dict{Tuple{Tuple{Symbol, Symbol}, Symbol, Symbol}, Symbol}()
const _TOY_V2_O = OComonoid(Σ_obs_v2, 10)

const D_v2_toy = Differential{Tuple{Symbol, Symbol}, Tuple{Symbol, Symbol}}(
    _TOY_V2_O,
    TOY_V2_POSITIONS,
    TOY_V2_P_POSITIONS,
    _TOY_V2_F,
    _TOY_V2_EMIT,
    _TOY_V2_SHARP_L,
)
