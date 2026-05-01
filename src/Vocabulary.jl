# ============================================================
# Vocabulary — symbol tables for the toy protocols
# ============================================================

"Possible per-observation results."
const Results = FinPolySet([:neg, :pos])

"Chief-complaint values (the symptom alphabet)."
const CCResults = FinPolySet([
    :chest_pain,
    :abd_pain,
    :dyspnea,
    :fatigue,
    :well_visit,
])

"Intake-stage observations."
const Intake_observations = [:chief_complaint]

"Per-disease observation names."
const D1_observations = [:o1a, :o1b]
const D2_observations = [:o2a, :o2b, :o2c]
const All_observations = vcat(Intake_observations, D1_observations, D2_observations)

"""
    event_symbol(obs, result) -> Symbol

Mnemonic for an observation-result pair: `event_symbol(:o1a, :pos) = :ev_o1a_pos`.
"""
event_symbol(obs::Symbol, r::Symbol) = Symbol("ev_$(obs)_$(r)")

"`order_for(:o1a) = :order_o1a`."
order_for(obs::Symbol) = Symbol("order_$(obs)")

"""
    obs_from_order(o) -> Symbol

Inverse of `order_for`: strips the `order_` prefix.
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

"D1 orders: screen, confirm, and the two terminal conclusions."
const D1_orders = [:order_o1a, :order_o1b, :disease_D1_present, :disease_D1_absent]

"D2 orders (parallel structure to D1)."
const D2_orders = [:order_o2a, :order_o2b, :disease_D2_present, :disease_D2_absent]

# ============================================================
# Per-disease phenotypes
# ============================================================

"D1 phenotypes — full 5-state set used by the v1.x protocol IR."
const A_D1_states = [
    :a_D1_initial,
    :a_D1_pending,
    :a_D1,
    :a_D1_absent_via_o1a,
    :a_D1_absent_via_o1b,
]

"D2 phenotypes — parallel structure to D1."
const A_D2_states = [
    :a_D2_initial,
    :a_D2_pending,
    :a_D2,
    :a_D2_absent_via_o2a,
    :a_D2_absent_via_o2b,
]

const A_D1_absent_states = [:a_D1_absent_via_o1a, :a_D1_absent_via_o1b]
const A_D2_absent_states = [:a_D2_absent_via_o2a, :a_D2_absent_via_o2b]

"True if `s` is a terminal D1 phenotype."
is_terminal_D1(s::Symbol) = s == :a_D1 || s in A_D1_absent_states

"True if `s` is a terminal D2 phenotype."
is_terminal_D2(s::Symbol) = s == :a_D2 || s in A_D2_absent_states
