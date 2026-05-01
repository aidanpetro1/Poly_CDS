# ============================================================
# Protocol IR
# ============================================================
#
# A clinical protocol is a tree of decision points: each node is a
# `ProtocolStep` (issue an order, branch on result) or a
# `ProtocolTerminal` (workup ends with a clinical conclusion). The IR
# is the parse target of `ProtocolDoc.jl` and the input to
# `ProtocolCompileV2.jl`.

"Abstract supertype of protocol-tree nodes."
abstract type ProtocolNode end

"""
    ProtocolStep(phenotype, order, on_result)

A step in the protocol tree. `phenotype` is the per-disease state at
this step; `order` is the recommendation issued; `on_result[r]` is the
next node reached when the patient returns result `r`.
"""
struct ProtocolStep <: ProtocolNode
    phenotype::Symbol
    order::Symbol
    on_result::Dict{Symbol, ProtocolNode}
end

"""
    ProtocolTerminal(phenotype, conclusion)

A terminal node: the workup ends here with a clinical conclusion
(e.g. `:disease_D1_present`, `:disease_D1_absent`).
"""
struct ProtocolTerminal <: ProtocolNode
    phenotype::Symbol
    conclusion::Symbol
end

"""
    ProtocolMetadata

Vocabulary-level metadata carried alongside the IR — observation,
order, conclusion, and phenotype attribute dicts populated by
`ProtocolDoc.jl` when parsing markdown. Each inner Dict maps an IR
symbol to a Dict of attributes (e.g. `loinc`, `display`, `fhir`,
`icd10`).
"""
struct ProtocolMetadata
    title::String
    version::String
    description::String
    observations::Dict{Symbol, Dict{Symbol, Any}}
    orders::Dict{Symbol, Dict{Symbol, Any}}
    conclusions::Dict{Symbol, Dict{Symbol, Any}}
    phenotypes::Dict{Symbol, Dict{Symbol, Any}}
end

"Empty ProtocolMetadata default."
ProtocolMetadata() = ProtocolMetadata(
    "", "", "",
    Dict{Symbol, Dict{Symbol, Any}}(),
    Dict{Symbol, Dict{Symbol, Any}}(),
    Dict{Symbol, Dict{Symbol, Any}}(),
    Dict{Symbol, Dict{Symbol, Any}}(),
)

"""
    Protocol(disease, p_obs, initial; metadata=ProtocolMetadata())

A per-disease protocol. `disease` is the disease symbol; `p_obs` is the
observation polynomial; `initial` is the entry-point step; `metadata`
holds the parsed vocabulary attributes.
"""
struct Protocol
    disease::Symbol
    p_obs::Polynomial
    initial::ProtocolStep
    metadata::ProtocolMetadata
end

Protocol(disease::Symbol, p_obs::Polynomial, initial::ProtocolStep) =
    Protocol(disease, p_obs, initial, ProtocolMetadata())

# ============================================================
# Per-disease protocol definitions
# ============================================================

"""
D1 toy protocol — screen (`o1a`), then confirm (`o1b`) on positive screen.

  initial: a_D1_initial, order_o1a
    on :neg → terminal a_D1_absent_via_o1a (disease_D1_absent)
    on :pos → step a_D1_pending, order_o1b
      on :neg → terminal a_D1_absent_via_o1b (disease_D1_absent)
      on :pos → terminal a_D1 (disease_D1_present)
"""
const D1_protocol = Protocol(:D1, p_D1_obs,
    ProtocolStep(:a_D1_initial, :order_o1a, Dict{Symbol, ProtocolNode}(
        :neg => ProtocolTerminal(:a_D1_absent_via_o1a, :disease_D1_absent),
        :pos => ProtocolStep(:a_D1_pending, :order_o1b, Dict{Symbol, ProtocolNode}(
            :neg => ProtocolTerminal(:a_D1_absent_via_o1b, :disease_D1_absent),
            :pos => ProtocolTerminal(:a_D1, :disease_D1_present),
        )),
    ))
)

"D2 toy protocol — parallel structure to D1 over `o2a`/`o2b`."
const D2_protocol = Protocol(:D2, p_D2_obs,
    ProtocolStep(:a_D2_initial, :order_o2a, Dict{Symbol, ProtocolNode}(
        :neg => ProtocolTerminal(:a_D2_absent_via_o2a, :disease_D2_absent),
        :pos => ProtocolStep(:a_D2_pending, :order_o2b, Dict{Symbol, ProtocolNode}(
            :neg => ProtocolTerminal(:a_D2_absent_via_o2b, :disease_D2_absent),
            :pos => ProtocolTerminal(:a_D2, :disease_D2_present),
        )),
    ))
)
