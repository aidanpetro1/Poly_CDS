# ============================================================
# Patient — the observation responder
# ============================================================
#
# Stateless deterministic patient: a `response_table` mapping each
# observation to its result. `respond(p, obs)` is the section of
# `p_obs` plugged into the simulator.

"""
    Patient(label, response_table)

Stateless patient: `label` describes the latent truth (e.g. `:D1`);
`response_table` maps observation symbols to result symbols.
"""
struct Patient
    label::Symbol
    response_table::Dict{Symbol, Symbol}
end

"""
    respond(p::Patient, obs::Symbol) -> Symbol

The patient's response to an observation. Errors if `obs` isn't in
`p.response_table`.
"""
function respond(p::Patient, obs::Symbol)
    haskey(p.response_table, obs) ||
        error("Patient(:$(p.label)) has no response for observation $obs")
    return p.response_table[obs]
end

# ============================================================
# Demo patients
# ============================================================

"All D1 obs return :pos; all D2 obs return :neg."
const Patient_D1 = Patient(:D1, Dict(
    :o1a => :pos,  :o1b => :pos,
    :o2a => :neg,  :o2b => :neg,  :o2c => :neg,
))

"Mirror of Patient_D1: D1 obs return :neg, D2 obs return :pos."
const Patient_D2 = Patient(:D2, Dict(
    :o1a => :neg,  :o1b => :neg,
    :o2a => :pos,  :o2b => :pos,  :o2c => :pos,
))

"All observations return :neg."
const Patient_neither = Patient(:neither, Dict(
    :o1a => :neg,  :o1b => :neg,
    :o2a => :neg,  :o2b => :neg,  :o2c => :neg,
))
