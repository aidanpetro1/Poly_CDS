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
#     (per-disease P_Dk in Bicomodule.jl). 4 orders per disease:
#     two `order_*` requests + `no_further_workup_Dk` + `refer_Dk`.

"The two possible result values for every observation in v1.1."
const Results = FinPolySet([:neg, :pos])

"Observation names — positions of the per-observation polynomials."
const D1_observations = [:o1a, :o1b]
const D2_observations = [:o2a, :o2b, :o2c]
const All_observations = vcat(D1_observations, D2_observations)

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

# ============================================================
# Per-disease order vocabularies
# ============================================================
#
# In v1.1 each disease has its own P_Dk protocol-category (NOT a shared
# discrete P). Per-disease orders are: two "request observation"
# orders for the disease's protocol-active observations, plus
# `no_further_workup_Dk` and `refer_Dk` exit actions. The order vocabulary
# defines the OBJECTS of P_Dk; the morphisms (the planned pathway) are
# defined in Bicomodule.jl.

"D1's order vocabulary — objects of P_D1. v1.1 drops :refer_D1 (no refer-recommending phenotype yet); deferred to v1.2."
const D1_orders = [:order_o1a, :order_o1b, :no_further_workup_D1]

"D2's order vocabulary — objects of P_D2. Same simplification."
const D2_orders = [:order_o2a, :order_o2b, :no_further_workup_D2]

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
