# ============================================================
# Vocabulary
# ============================================================
#
# All the symbol tables the rest of the codebase pulls from. Centralizing
# these here means the clinical content (which observations exist, what
# results they have, which diseases we're modeling, what orders the
# guideline can recommend) is in one place and the polynomial / comonoid /
# bicomodule construction stays mechanical.
#
# v1.1 toy:
#   * Two diseases D1 and D2 (abstract; clinical gloss in comments).
#     - D1 = "diabetes-shaped": two observations o1a, o1b
#       (think fasting glucose + HbA1c).
#     - D2 = "anemia-shaped": three observations o2a, o2b, o2c
#       (think hemoglobin + ferritin + MCV). Linear protocol screen-then-
#       confirm uses o2a + o2b; o2c is in the vocabulary but not in the
#       v1.1 protocol — headroom for a 2-of-3-confirmation extension.
#   * Each observation has two results: `:neg` and `:pos`.
#   * Per-disease orders: each disease has its own order vocabulary
#     (per-disease P_Dk in Bicomodule.jl). v1.2 splits the lumped
#     `:no_further_workup_Dk` terminal into clinically-distinct
#     `:disease_Dk_present` and `:disease_Dk_absent` so the free-P
#     length-2 composites `o1a → o1b → present/absent` are distinct
#     P-morphisms — required for `sharp_R` to be well-defined under
#     free-P (see project_polycds_coherence.md).

"The two possible result values for every per-disease observation in v1.1+."
const Results = FinPolySet([:neg, :pos])

# ============================================================
# Intake-stage vocabulary  (v1.6 — chief complaint)
# ============================================================
#
# v1.6 introduces an intake stage as a separate bicomodule (A_intake)
# composed with the workup-joint bicomodule via `compose(::Bicomodule,
# ::Bicomodule)` in Poly.jl. At intake the patient is asked for their
# chief complaint (CC); the response selects which diseases enter the
# active workup.
#
# CC has its own value set — the symptom alphabet — distinct from the
# {:neg, :pos} `Results` used for per-disease observations. The CC
# observation lives in `p_chief_complaint` (Polynomials.jl), NOT in
# any per-disease p_Dk_obs polynomial. CC stays orthogonal to the
# workup observation polynomials.

"Chief-complaint value set — the symptom alphabet patients walk in with."
const CCResults = FinPolySet([
    :chest_pain,    # → activates D1 only
    :abd_pain,      # → activates D2 only
    :dyspnea,       # → activates both D1 and D2
    :fatigue,       # → activates both D1 and D2
    :well_visit,    # → activates neither (routine check)
])

"Intake-stage observation symbols. Single observation in v1.6 (CC); future-proofed for additions like vitals."
const Intake_observations = [:chief_complaint]

"Observation names — positions of the per-observation polynomials."
const D1_observations = [:o1a, :o1b]
const D2_observations = [:o2a, :o2b, :o2c]
const All_observations = vcat(Intake_observations, D1_observations, D2_observations)

"""
    event_symbol(obs::Symbol, r::Symbol) -> Symbol

Mnemonic for an observation-result event: `event_symbol(:o1a, :pos)`
returns `:ev_o1a_pos`. Used by the simulation driver and tests when
talking about specific events; the bicomodule itself doesn't use these
symbols (events live as paths through cofree-S trees in v1.1).
"""
event_symbol(obs::Symbol, r::Symbol) = Symbol("ev_$(obs)_$(r)")

"""
    order_for(obs::Symbol) -> Symbol

The order whose execution would produce an observation event for `obs`.
`order_for(:o1a) = :order_o1a`.
"""
order_for(obs::Symbol) = Symbol("order_$(obs)")

"""
    obs_from_order(o::Symbol) -> Symbol

Inverse of `order_for`: strip the `order_` prefix.
`obs_from_order(:order_o1a) = :o1a`. Errors if `o` doesn't start with `order_`.
"""
function obs_from_order(o::Symbol)
    s = String(o)
    startswith(s, "order_") ||
        error("obs_from_order: $o is not a 'order_*' symbol")
    return Symbol(s[7:end])
end

# ============================================================
# Per-disease order vocabularies
# ============================================================
#
# In v1.2 each disease has its own free-P protocol-category. Per-disease
# orders are the OBJECTS of P_Dk: two "request observation" orders plus
# two clinically-distinct terminal conclusions (`disease_Dk_present` and
# `disease_Dk_absent`). The morphisms (the planned pathway, with length-2
# composites kept distinct) are defined in Bicomodule.jl.
#
# Why split the terminal: under free-P, `sharp_R(x, a, e)` extends `a`'s
# S-path by length(e) more steps, and the rule used to disambiguate
# competing extensions is "match cod(e)'s recommendation." A single
# lumped `:no_further_workup_Dk` would collapse the cods of competing
# length-2 P-morphisms (e.g. `o1a → o1b → present` and
# `o1a → o1b → absent`), making `sharp_R` ambiguous. Splitting by
# clinical conclusion (present/absent) restores well-definedness.
#
# `:refer_Dk` is still deferred — no phenotype currently recommends a
# referral so it would be structurally meaningless.

"D1's order vocabulary — objects of P_D1 (free protocol-category in v1.2)."
const D1_orders = [:order_o1a, :order_o1b, :disease_D1_present, :disease_D1_absent]

"D2's order vocabulary — objects of P_D2 (parallel structure)."
const D2_orders = [:order_o2a, :order_o2b, :disease_D2_present, :disease_D2_absent]

# ============================================================
# Per-disease phenotypes (positions of A_Dk_carrier)
# ============================================================
#
# These are *computable phenotypes* — clinically-recognizable patient
# states defined by combinations of observable evidence. Cofree-S's
# coassoc rigidity forced us to split each "ruled out" terminal by HOW
# we got there; that split turned out to be clinically meaningful
# (e.g. ruled-out-at-screen ≠ ruled-out-at-confirmation in terms of
# what re-screening makes sense at future visits). See
# `project_polycds_phenotypes.md` for the architectural rationale.
#
# 5 phenotypes per disease in v1.1; joint via bicomodule `⊗` gives 25.

"D1 phenotypes — positions of A_D1_carrier."
const A_D1_states = [
    :a_D1_initial,            # pre-workup, no D1-relevant data
    :a_D1_pending,            # positive screen (o1a-pos), awaiting confirmation
    :a_D1,                    # confirmed (o1a-pos AND o1b-pos)
    :a_D1_absent_via_o1a,     # ruled out at screen (o1a-neg)
    :a_D1_absent_via_o1b,     # ruled out at confirmation (o1a-pos, o1b-neg)
]

"D2 phenotypes — positions of A_D2_carrier (mirrors D1's structure)."
const A_D2_states = [
    :a_D2_initial,
    :a_D2_pending,            # positive screen (o2a-pos), awaiting confirmation
    :a_D2,                    # confirmed (o2a-pos AND o2b-pos)
    :a_D2_absent_via_o2a,
    :a_D2_absent_via_o2b,
]

"Per-disease 'absent' phenotypes (both screen-out and confirmation-out)."
const A_D1_absent_states = [:a_D1_absent_via_o1a, :a_D1_absent_via_o1b]
const A_D2_absent_states = [:a_D2_absent_via_o2a, :a_D2_absent_via_o2b]

"Convenience: is this per-disease phenotype terminal (no further workup expected)?"
is_terminal_D1(s::Symbol) = s == :a_D1 || s in A_D1_absent_states
is_terminal_D2(s::Symbol) = s == :a_D2 || s in A_D2_absent_states
