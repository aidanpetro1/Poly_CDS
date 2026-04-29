# ============================================================
# Protocol IR  (v1.3 — mechanical sub-cofree derivation)
# ============================================================
#
# A clinical protocol is a tree of decision points. Each node is either:
#   * a `ProtocolStep` — issue an order, branch on result,
#   * or a `ProtocolTerminal` — the workup ends with a clinical conclusion.
#
# This is the engine-side IR: a Julia struct DSL that the bicomodule
# compiler (`ProtocolCompile.jl`) consumes to derive A_carrier, S, P,
# mbar_L, mbar_R, and the per-disease bicomodule. Going forward it's
# also the parse target of the markdown-based ProtocolDoc format
# (deferred to the standalone authoring library — see
# project_polycds_authoring.md).
#
# Design notes:
#   * Phenotypes are named explicitly per node so the IR retains the
#     clinical vocabulary the bicomodule's A.positions exposes.
#   * Result symbols are arbitrary (`:neg`/`:pos` for v1.x, but the
#     compiler doesn't hardcode them — multi-valued result alphabets
#     work the same way).
#   * Acyclic by construction: the recursion in compile_protocol
#     assumes no node is its own ancestor. If a future protocol needs
#     loops, the IR + compiler need a re-think.

"Abstract supertype of protocol-tree nodes."
abstract type ProtocolNode end

"""
    ProtocolStep(phenotype, order, on_result)

A protocol step. `phenotype` is the A-position the bicomodule will be at
when this step is current; `order` is what mbar_R[stay] recommends here;
`on_result[r]` is the next ProtocolNode reached if the patient's result
to this step's observation is `r`.
"""
struct ProtocolStep <: ProtocolNode
    phenotype::Symbol
    order::Symbol
    on_result::Dict{Symbol, ProtocolNode}
end

"""
    ProtocolTerminal(phenotype, conclusion)

A protocol terminal. `phenotype` is the A-position the bicomodule lands
at when the workup concludes here; `conclusion` is the clinical-conclusion
order recommended at stay (e.g. `:disease_D1_present`, `:disease_D1_absent`).
"""
struct ProtocolTerminal <: ProtocolNode
    phenotype::Symbol
    conclusion::Symbol
end

"""
    ProtocolMetadata

Vocabulary-level metadata carried alongside the IR. Engine-side compiler
ignores this; it's preserved for downstream consumers (v2 FHIR substrate,
clinician-facing UI, parsers/serializers). All fields default to empty.

Each inner Dict maps an IR symbol (an observation id, order id,
conclusion id, or phenotype id) to a Dict of attributes parsed from the
corresponding `yaml-vocab` / `yaml-orders` / `yaml-conclusions` /
`yaml-phenotypes` blocks of a ProtocolDoc markdown file.

Examples of attributes:
  * observations: `loinc::String`, `results::Vector{Symbol}`, `display::String`
  * orders:       `fhir::Dict` (e.g. `{resource: "ServiceRequest", code: "..."}`),
                  `display::String`
  * conclusions:  `icd10::String`, `display::String`
  * phenotypes:   `display::String`, `description::String`
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

"Empty ProtocolMetadata — used as default when a Protocol is constructed in code without parsed markdown."
ProtocolMetadata() = ProtocolMetadata(
    "", "", "",
    Dict{Symbol, Dict{Symbol, Any}}(),
    Dict{Symbol, Dict{Symbol, Any}}(),
    Dict{Symbol, Dict{Symbol, Any}}(),
    Dict{Symbol, Dict{Symbol, Any}}(),
)

"""
    Protocol(disease, p_obs, initial; metadata=ProtocolMetadata())

A complete per-disease protocol. `disease` is the disease symbol (`:D1`,
`:D2`, …). `p_obs` is the observation polynomial the protocol's
observations live in. `initial` is the entry-point ProtocolStep (the
phenotype and order assumed when the patient enters workup). `metadata`
is the optional vocabulary-level annotation block (parser-populated;
empty when constructed in code).
"""
struct Protocol
    disease::Symbol
    p_obs::Polynomial
    initial::ProtocolStep
    metadata::ProtocolMetadata
end

# Convenience constructor — backward-compatible 3-arg form for in-code
# Protocol consts that don't carry FHIR metadata.
Protocol(disease::Symbol, p_obs::Polynomial, initial::ProtocolStep) =
    Protocol(disease, p_obs, initial, ProtocolMetadata())

# ============================================================
# Per-disease protocol definitions
# ============================================================
#
# These ARE the per-disease guidelines. The compiler in
# ProtocolCompile.jl derives all of A_carrier, S, P, mbar_L, mbar_R from
# these — the eight hand-typed dicts in Bicomodule.jl collapse into
# these structs.

"""
D1 toy protocol — two-step screen-then-confirm.

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

"D2 toy protocol — parallel structure to D1."
const D2_protocol = Protocol(:D2, p_D2_obs,
    ProtocolStep(:a_D2_initial, :order_o2a, Dict{Symbol, ProtocolNode}(
        :neg => ProtocolTerminal(:a_D2_absent_via_o2a, :disease_D2_absent),
        :pos => ProtocolStep(:a_D2_pending, :order_o2b, Dict{Symbol, ProtocolNode}(
            :neg => ProtocolTerminal(:a_D2_absent_via_o2b, :disease_D2_absent),
            :pos => ProtocolTerminal(:a_D2, :disease_D2_present),
        )),
    ))
)
