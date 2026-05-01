# ============================================================
# ProtocolDoc parser — markdown + YAML → Protocol IR
# ============================================================
#
# Parse a clinician-authored protocol from a markdown file with
# embedded fenced YAML blocks into a `Protocol` struct.
#
# Block layout:
#   * YAML front-matter (`---`-delimited): protocol_id, title, version,
#     authors, disease, description
#   * Fenced YAML blocks:
#       yaml-vocab        — observations (required)
#       yaml-orders       — orders (required)
#       yaml-conclusions  — conclusions (required)
#       yaml-phenotypes   — phenotype display/description (optional)
#       yaml-protocol     — the workflow tree (required)
#
# Cross-reference validation runs at parse time; FHIR-style attributes
# (loinc, icd10, fhir.resource) are preserved in `ProtocolMetadata`.

using YAML

# ============================================================
# Markdown helpers
# ============================================================

"""
    read_markdown(path::String) -> (frontmatter::Dict, blocks::Dict{String,String})

Read a protocol markdown file. Returns the parsed YAML front-matter
and a dict of language-tagged fenced block contents (raw YAML strings,
not yet parsed). Block language tags map to keys (`yaml-vocab`,
`yaml-orders`, `yaml-conclusions`, `yaml-phenotypes`, `yaml-protocol`).
"""
function read_markdown(path::String)
    content = read(path, String)

    # Front-matter: between leading `---` and the next `---`
    frontmatter = Dict{String, Any}()
    fm_match = match(r"^---\s*\n(.*?)\n---\s*\n"s, content)
    if fm_match !== nothing
        fm_yaml = String(fm_match.captures[1])
        parsed = YAML.load(fm_yaml)
        if parsed isa AbstractDict
            frontmatter = parsed
        end
    end

    # Fenced blocks: ```<lang>\n<content>\n```
    blocks = Dict{String, String}()
    for m in eachmatch(r"```(yaml-[a-z]+)\s*\n(.*?)\n```"s, content)
        lang = String(m.captures[1])
        block_content = String(m.captures[2])
        if haskey(blocks, lang)
            error("read_markdown($path): duplicate `$lang` block — exactly one expected")
        end
        blocks[lang] = block_content
    end

    return (frontmatter, blocks)
end

# ============================================================
# Vocab → metadata Dict helpers
# ============================================================

"""
    build_meta_dict(items::Vector) -> Dict{Symbol, Dict{Symbol, Any}}

Convert a YAML list of vocabulary items (each with an `id` field plus
arbitrary attributes) into a Dict keyed by id-symbol. Result lists
under the `results` key are normalized to `Vector{Symbol}`.
"""
function build_meta_dict(items::Vector)::Dict{Symbol, Dict{Symbol, Any}}
    out = Dict{Symbol, Dict{Symbol, Any}}()
    for item in items
        item isa AbstractDict ||
            error("build_meta_dict: vocab item is not a Dict: $item")
        haskey(item, "id") ||
            error("build_meta_dict: vocab item missing `id`: $item")
        id = Symbol(item["id"])
        haskey(out, id) &&
            error("build_meta_dict: duplicate id `$id`")
        attrs = Dict{Symbol, Any}()
        for (k, v) in item
            k == "id" && continue
            key_sym = Symbol(k)
            if key_sym == :results && v isa Vector
                attrs[key_sym] = [Symbol(x) for x in v]
            else
                attrs[key_sym] = v
            end
        end
        out[id] = attrs
    end
    return out
end

"""
    build_meta_dict(items::Nothing) -> empty Dict

Convenience for an absent block (e.g. optional `yaml-phenotypes`).
"""
build_meta_dict(::Nothing) = Dict{Symbol, Dict{Symbol, Any}}()

# ============================================================
# Disease → observation polynomial lookup
# ============================================================

"""
    lookup_p_obs(disease::Symbol) -> Polynomial

Look up the observation polynomial for a disease via the `p_<disease>_obs`
naming convention (e.g. `p_D1_obs`). Polynomials.jl must have already
defined the corresponding const at module-load time.
"""
function lookup_p_obs(disease::Symbol)
    obs_const = Symbol("p_", disease, "_obs")
    isdefined(@__MODULE__, obs_const) ||
        error("ProtocolDoc: no observation polynomial registered for $disease (expected `$obs_const` in Polynomials.jl)")
    return getfield(@__MODULE__, obs_const)
end

# ============================================================
# Cross-reference validation
# ============================================================

"""
    validate_xrefs(initial_block, obs_meta, orders_meta, conclusions_meta, phenotypes_meta)

Walk the workflow tree and assert all symbol references are valid:
  * Each step's `order` exists in `orders_meta`.
  * Each step's `order` resolves (via `obs_from_order`) to an obs in
    `obs_meta`, and every `on:` key matches that obs's declared results.
  * Each terminal's `conclusion` exists in `conclusions_meta`.
  * If `phenotypes_meta` is non-empty (i.e. an optional yaml-phenotypes
    block was present), every node's phenotype is declared there.
  * No phenotype symbol is reused across nodes (the IR is acyclic).

Errors at parse time with a precise diagnostic if any check fails.
"""
function validate_xrefs(initial_block, obs_meta, orders_meta,
                        conclusions_meta, phenotypes_meta)
    seen_phenotypes = Set{Symbol}()
    require_phenotype_decl = !isempty(phenotypes_meta)

    function check_node(block, parent_path::String)
        block isa AbstractDict ||
            error("validate_xrefs: node $parent_path is not a Dict: $block")

        if haskey(block, "terminal")
            phen = Symbol(block["terminal"])
            phen in seen_phenotypes &&
                error("validate_xrefs: phenotype `$phen` appears more than once (at $parent_path)")
            push!(seen_phenotypes, phen)

            haskey(block, "conclusion") ||
                error("validate_xrefs: terminal node at $parent_path missing `conclusion` field")
            conc = Symbol(block["conclusion"])
            haskey(conclusions_meta, conc) ||
                error("validate_xrefs: conclusion `$conc` (at terminal $phen) not declared in yaml-conclusions")

            if require_phenotype_decl
                haskey(phenotypes_meta, phen) ||
                    error("validate_xrefs: phenotype `$phen` not declared in yaml-phenotypes")
            end

        elseif haskey(block, "phenotype") && haskey(block, "order") && haskey(block, "on")
            phen = Symbol(block["phenotype"])
            phen in seen_phenotypes &&
                error("validate_xrefs: phenotype `$phen` appears more than once (at $parent_path)")
            push!(seen_phenotypes, phen)

            order = Symbol(block["order"])
            haskey(orders_meta, order) ||
                error("validate_xrefs: order `$order` (at step $phen) not declared in yaml-orders")

            obs_sym = obs_from_order(order)
            haskey(obs_meta, obs_sym) ||
                error("validate_xrefs: observation `$obs_sym` (derived from order `$order`) not declared in yaml-vocab")

            valid_results = Set{Symbol}(get(obs_meta[obs_sym], :results, Symbol[]))
            on_dict = block["on"]
            on_dict isa AbstractDict ||
                error("validate_xrefs: `on` at step $phen is not a Dict: $on_dict")
            for (result_key, _) in on_dict
                rsym = Symbol(result_key)
                rsym in valid_results ||
                    error("validate_xrefs: result `$rsym` in on: of step `$phen` does not match observation `$obs_sym`'s declared results $(collect(valid_results))")
            end

            if require_phenotype_decl
                haskey(phenotypes_meta, phen) ||
                    error("validate_xrefs: phenotype `$phen` not declared in yaml-phenotypes")
            end

            for (rk, child) in on_dict
                check_node(child, "$parent_path/$phen[$rk]")
            end

        else
            error("validate_xrefs: unrecognized node at $parent_path — must have either `terminal` (+ `conclusion`) or `phenotype` + `order` + `on`. Got: $block")
        end
    end

    check_node(initial_block, "")
    return seen_phenotypes
end

# ============================================================
# IR builder (post-validation)
# ============================================================

"""
    build_protocol_node(block) -> ProtocolNode

Recursively build a `ProtocolStep` or `ProtocolTerminal` from a parsed
YAML block. Assumes `validate_xrefs` already passed; doesn't re-check.
"""
function build_protocol_node(block::AbstractDict)::ProtocolNode
    if haskey(block, "terminal")
        return ProtocolTerminal(
            Symbol(block["terminal"]),
            Symbol(block["conclusion"]),
        )
    else
        on_result = Dict{Symbol, ProtocolNode}()
        for (result_key, child) in block["on"]
            on_result[Symbol(result_key)] = build_protocol_node(child)
        end
        return ProtocolStep(
            Symbol(block["phenotype"]),
            Symbol(block["order"]),
            on_result,
        )
    end
end

# ============================================================
# Top-level entry point
# ============================================================

"""
    parse_protocol(path::String) -> Protocol

Parse a markdown ProtocolDoc file at `path` into a `Protocol` IR struct
with full FHIR metadata preserved. Performs parse-time strict
cross-reference validation; errors with a precise diagnostic on any
schema violation.

The disease symbol comes from the front-matter's `disease:` field. The
parser looks up the corresponding observation polynomial via the
`p_<disease>_obs` naming convention (so the disease must have a
polynomial registered in Polynomials.jl).
"""
function parse_protocol(path::String)::Protocol
    isfile(path) || error("parse_protocol: file not found: $path")

    frontmatter, blocks = read_markdown(path)

    # Required blocks
    for required in ["yaml-vocab", "yaml-orders", "yaml-conclusions", "yaml-protocol"]
        haskey(blocks, required) ||
            error("parse_protocol($path): missing required `$required` block")
    end

    # Parse YAML in each block
    obs_block         = YAML.load(blocks["yaml-vocab"])
    orders_block      = YAML.load(blocks["yaml-orders"])
    conclusions_block = YAML.load(blocks["yaml-conclusions"])
    protocol_block    = YAML.load(blocks["yaml-protocol"])
    phenotypes_block  = haskey(blocks, "yaml-phenotypes") ?
                          YAML.load(blocks["yaml-phenotypes"]) :
                          Dict("phenotypes" => nothing)

    # Build vocab metadata dicts
    obs_meta         = build_meta_dict(get(obs_block, "observations", nothing))
    orders_meta      = build_meta_dict(get(orders_block, "orders", nothing))
    conclusions_meta = build_meta_dict(get(conclusions_block, "conclusions", nothing))
    phenotypes_meta  = build_meta_dict(get(phenotypes_block, "phenotypes", nothing))

    # Cross-reference validation (parse-time strict)
    haskey(protocol_block, "initial") ||
        error("parse_protocol($path): yaml-protocol block missing `initial:` entry")
    initial_block = protocol_block["initial"]
    validate_xrefs(initial_block, obs_meta, orders_meta, conclusions_meta, phenotypes_meta)

    # Build the IR tree
    initial = build_protocol_node(initial_block)
    initial isa ProtocolStep ||
        error("parse_protocol($path): initial node must be a ProtocolStep (has phenotype + order), not a terminal")

    # Disease + p_obs lookup
    haskey(frontmatter, "disease") ||
        error("parse_protocol($path): front-matter missing `disease:` field")
    disease = Symbol(frontmatter["disease"])
    p_obs = lookup_p_obs(disease)

    metadata = ProtocolMetadata(
        get(frontmatter, "title", "")       |> string,
        get(frontmatter, "version", "")     |> string,
        get(frontmatter, "description", "") |> string,
        obs_meta,
        orders_meta,
        conclusions_meta,
        phenotypes_meta,
    )

    return Protocol(disease, p_obs, initial, metadata)
end
