# ============================================================
# Patient coalgebras (v1.1)
# ============================================================
#
# Categorical note: a v0.2.0 `Coalgebra` is for coalgebras of an
# endofunctor — `X → p(X)` where the system outputs a position of `p`
# at each state. Our patient is a *responder*: it doesn't output
# observations on its own, it answers observation requests. The
# natural categorical home for that is either
#   (a) a section of `p_obs` (a function from positions to directions),
#       which the library exposes via `sections` / `section_lens`, or
#   (b) a comodule over `cofree_comonoid(p_obs, depth)` (a behavior
#       tree saying "for each query path, here's the answer").
#
# For v1.1 we keep the Patient as a simple struct with a `respond`
# function. The cofree-comonoid-backed S in `Bicomodule.jl` IS the
# universal home where this responder plugs in formally — the
# `respond` function is the data of a section of `p_obs`. We don't
# wrap it in `Coalgebra` because that would be a forced fit.

"""
    Patient(label::Symbol, response_table::Dict{Symbol, Symbol})

A v1.1 patient — stateless, deterministic. `label` describes the latent
"truth" (e.g. `:D1` for "has D1"). `response_table` maps observation
names (e.g. `:o1a`) to result symbols (e.g. `:pos`).
"""
struct Patient
    label::Symbol
    response_table::Dict{Symbol, Symbol}
end

"""
    respond(p::Patient, obs::Symbol) -> Symbol

The patient's response to an observation request. This function is the
data of a section of `p_obs` — viewed categorically, the patient is
the "responder side" of an interaction with the bicomodule's left
coaction.
"""
function respond(p::Patient, obs::Symbol)
    haskey(p.response_table, obs) ||
        error("Patient(:$(p.label)) has no response for observation $obs")
    return p.response_table[obs]
end

# ============================================================
# Three canonical demo patients
# ============================================================

"Patient with latent truth = D1. All D1 obs return :pos; all D2 obs return :neg."
const Patient_D1 = Patient(:D1, Dict(
    :o1a => :pos,  :o1b => :pos,
    :o2a => :neg,  :o2b => :neg,  :o2c => :neg,
))

"Patient with latent truth = D2. Mirror of Patient_D1."
const Patient_D2 = Patient(:D2, Dict(
    :o1a => :neg,  :o1b => :neg,
    :o2a => :pos,  :o2b => :pos,  :o2c => :pos,
))

"Patient with neither D1 nor D2. All observations return :neg."
const Patient_neither = Patient(:neither, Dict(
    :o1a => :neg,  :o1b => :neg,
    :o2a => :neg,  :o2b => :neg,  :o2c => :neg,
))

# ============================================================
# Coalgebra (formal, optional)
# ============================================================
#
# For users who want the formal categorical wrapper: a stateless
# patient as a behavior tree in cofree-S corresponds to a "constant
# strategy" — the patient's response at each observation is fixed and
# doesn't depend on history. We don't construct this explicitly in v1.1
# (it would require building the depth-2 behavior tree by hand), but
# documenting the connection here for the v1.2/v2 work that needs it
# (FHIR-substrate patients with state).
