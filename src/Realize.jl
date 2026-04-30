# ============================================================
# realize / cc_realize — author-supplied maps to Σ_prob
# ============================================================
#
# Foundations doc §21, §25. These two maps are the *only* hand-
# authored connection between the per-disease S-world and the
# problem-list H-world. The S → H quotient Θ is mechanically
# derived from realize via realize_symdiff in `ProblemVocabulary.jl`.
#
#   realize    : (disease, per-disease-state) -> Set{Σ_prob token}
#   cc_realize : CC-vocab                     -> Set{Σ_prob token}
#
# Authoring level (settled 2026-04-30): realize is authored against
# A-phenotypes — the 5 per-disease clinically-recognizable states
# already in Vocabulary.jl (A_D1_states, A_D2_states). The
# framework lifts realize to the S-position level via the existing
# S→A projection in v1.x's compiled Bicomodule layer; that lifting
# happens in PR 1 #4 (Θ derivation).
#
# Layered Σ_prob convention (v1.6.B; see ProblemVocabulary.jl):
#   * CC-provenance tokens are added by cc_realize, never touched by Θ.
#   * Active-DDx tokens (`:considering_<Dk>`) are added by cc_realize
#     AND mirrored in realize(d, a_d_initial) so Θ removes them
#     cleanly when the disease moves off the initial phenotype.
#   * Per-disease state tokens are emitted exclusively by realize
#     for s past-initial.
#
# Coherence obligation (checked in PR 3 by validate_history_quotient):
#
#   ∀ c ∈ CC-vocab, d ∈ DDx_route(c) :
#     :considering_<d>  ∈  cc_realize(c)
#     :considering_<d>  ∈  realize(d, a_d_initial)
#
# i.e. cc_realize and realize agree on the active-DDx sub-alphabet
# at the handover from intake to per-disease workup.

# ============================================================
# DDx routing  (mirrors v1.6.A's CC → disease-set mapping)
# ============================================================
#
# This is the routing relation R ⊆ CC-vocab × Diseases that, together
# with cc_realize and realize, forms the span-with-agreement
# structure deferred in project_polycds_v16_design.md. v1.6.B keeps
# it as a flat lookup; categorical formalization arrives with v1.8's
# guideline-composition machinery.

"""
    DDx_route(c::Symbol) -> Vector{Symbol}

Diseases activated by chief complaint `c` — the routing function from
v1.6.A's CC infrastructure made explicit. Identical to the routing
encoded in `cc_realize` (which adds `:considering_<d>` for each
`d ∈ DDx_route(c)`); kept as a separate helper for use in coherence
checking and DDx projection.

Mapping (matches v1.6.A's CCResults comments in Vocabulary.jl):
  * `:chest_pain` -> [D1]
  * `:abd_pain`   -> [D2]
  * `:dyspnea`    -> [D1, D2]
  * `:fatigue`    -> [D1, D2]
  * `:well_visit` -> []
"""
function DDx_route(c::Symbol)
    c === :chest_pain && return [:D1]
    c === :abd_pain   && return [:D2]
    c === :dyspnea    && return [:D1, :D2]
    c === :fatigue    && return [:D1, :D2]
    c === :well_visit && return Symbol[]
    error("DDx_route: unknown CC value $(c) (expected one of CCResults)")
end

# ============================================================
# cc_realize — chief-complaint → problem-list tokens
# ============================================================
#
# Each non-trivial CC contributes:
#   1. its CC-provenance token (sticky, naming = bare CC name);
#   2. one `:considering_<d>` per disease in DDx_route(c).

const _cc_realize_table = Dict{Symbol,Set{Symbol}}(
    :chest_pain  => Set{Symbol}([:chest_pain,
                                 :considering_D1]),
    :abd_pain    => Set{Symbol}([:abd_pain,
                                 :considering_D2]),
    :dyspnea     => Set{Symbol}([:dyspnea,
                                 :considering_D1, :considering_D2]),
    :fatigue     => Set{Symbol}([:fatigue,
                                 :considering_D1, :considering_D2]),
    :well_visit  => Set{Symbol}(),  # no problem-list entry
)

"""
    cc_realize(c::Symbol) -> Set{Symbol}

The chief-complaint realization map: the set of Σ_prob tokens added
to the problem list when CC `c` fires at intake. See file header
for the structural conventions.

Errors on CC values not in `CCResults`. The empty result for
`:well_visit` is intentional (a routine check produces no provenance).
"""
function cc_realize(c::Symbol)
    haskey(_cc_realize_table, c) ||
        error("cc_realize: unknown CC value $(c) — not in CCResults")
    return _cc_realize_table[c]
end

# ============================================================
# realize — per-disease (d, A-phenotype) → problem-list tokens
# ============================================================
#
# Authored against A-phenotypes (A_D1_states, A_D2_states from
# Vocabulary.jl). For initial states, realize repeats the
# `:considering_<d>` token from cc_realize so Θ symmetric-diffs
# it away cleanly when the disease advances.
#
# v1.6.B clinical content for D1 (diabetes-shaped) and D2
# (anemia-shaped) — strawman approved by Aidan 2026-04-30; revise
# at clinical discretion.

const _realize_table = Dict{Tuple{Symbol,Symbol},Set{Symbol}}(
    # D1 — initial mirrors cc_realize's :considering_D1
    (:D1, :a_D1_initial)        => Set([:considering_D1]),
    (:D1, :a_D1_pending)        => Set([:D1_suspected]),
    (:D1, :a_D1)                => Set([:D1_present]),
    (:D1, :a_D1_absent_via_o1a) => Set([:D1_absent]),
    (:D1, :a_D1_absent_via_o1b) => Set([:D1_absent]),

    # D2 — mirrors D1 structure
    (:D2, :a_D2_initial)        => Set([:considering_D2]),
    (:D2, :a_D2_pending)        => Set([:D2_suspected]),
    (:D2, :a_D2)                => Set([:D2_present]),
    (:D2, :a_D2_absent_via_o2a) => Set([:D2_absent]),
    (:D2, :a_D2_absent_via_o2b) => Set([:D2_absent]),
)

"""
    realize(d::Symbol, s::Symbol) -> Set{Symbol}

The per-disease-state realization map: the set of Σ_prob tokens
that disease `d` instantiates on the problem list when the patient
is at per-disease A-phenotype `s`.

Authored at A-phenotype level (one entry per element of A_Dk_states
in Vocabulary.jl); the framework lifts to S-positions via the
existing S→A projection in PR 1 #4's Θ derivation.

The strawman content for D1 (diabetes-shaped) and D2 (anemia-shaped)
matches what's clinically reasonable for the toy structure — initial
states emit `:considering_<d>` (mirroring cc_realize for
Θ-handover), positive and negative outcomes emit
`:Dk_suspected` / `:Dk_present` / `:Dk_absent` summaries. Path-
through-screen vs. path-through-confirm both collapse to
`:Dk_absent` by design (foundations doc §11; coarsening is the
point of H).
"""
function realize(d::Symbol, s::Symbol)
    haskey(_realize_table, (d, s)) ||
        error("realize: undefined for ($d, $s) — not in A_D{k}_states")
    return _realize_table[(d, s)]
end

# ============================================================
# Coherence check: cc_realize / realize handover at intake
# ============================================================
#
# This is the substantive coherence the foundations doc § 25 +
# project_polycds_v16_design.md mandates. Lives here as a
# standalone predicate; `validate_history_quotient` in PR 3 calls
# it (alongside Θ-functoriality checks) and surfaces failures with
# a clinician-facing message.

"""
    cc_realize_handover_coherent() -> Bool

Verify the cc_realize / realize handover coherence:

  ∀ c ∈ keys(_cc_realize_table), d ∈ DDx_route(c) :
    :considering_<d> ∈ cc_realize(c)
    :considering_<d> ∈ realize(d, a_d_initial)

If the predicate fails, the protocol-author has an inconsistency
between the CC routing and the per-disease initial state's realize
output — at intake, cc_realize will leave a `:considering_<d>` token
that realize(d, a_d_initial) doesn't expect, and Θ won't sym-diff
it away cleanly when the disease moves off initial.
"""
function cc_realize_handover_coherent()
    for (c, ccr) in _cc_realize_table
        for d in DDx_route(c)
            considering_token = Symbol("considering_", d)
            considering_token in ccr ||
                return false
            initial_state = Symbol("a_", d, "_initial")
            considering_token in realize(d, initial_state) ||
                return false
        end
    end
    return true
end

"""
    cc_realize_handover_violations() -> Vector{NamedTuple}

Diagnostic: list every (c, d, kind) tuple where the handover
coherence fails. `kind ∈ {:cc_missing_considering, :realize_missing_considering}`.
Empty result iff `cc_realize_handover_coherent()`.
"""
function cc_realize_handover_violations()
    out = NamedTuple{(:cc, :disease, :kind),Tuple{Symbol,Symbol,Symbol}}[]
    for (c, ccr) in _cc_realize_table
        for d in DDx_route(c)
            considering_token = Symbol("considering_", d)
            if !(considering_token in ccr)
                push!(out, (cc=c, disease=d, kind=:cc_missing_considering))
            end
            initial_state = Symbol("a_", d, "_initial")
            if !(considering_token in realize(d, initial_state))
                push!(out, (cc=c, disease=d, kind=:realize_missing_considering))
            end
        end
    end
    return out
end
