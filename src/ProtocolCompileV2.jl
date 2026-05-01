# ============================================================
# ProtocolCompileV2 — Protocol IR → Differential
# ============================================================
#
# Walks a `Protocol` IR, extracts per-disease V2 data, and composes
# multiple per-disease records into a joint `Differential`.

"""
    PerDiseaseV2

Per-disease V2 data extracted from a `Protocol` IR.

  * `disease`      — disease symbol
  * `phenotypes`   — phenotypes encountered during the IR walk
  * `workup_state` — `phenotype → P_d-position` (order at internal
                     steps, conclusion at terminals)
  * `transitions`  — `(phenotype, σ) → next phenotype` per `on_result`
                     branch
  * `sigma_obs`    — Σ_obs events contributed by this disease
"""
struct PerDiseaseV2
    disease::Symbol
    phenotypes::Vector{Symbol}
    workup_state::Dict{Symbol, Symbol}
    transitions::Dict{Tuple{Symbol, Symbol}, Symbol}
    sigma_obs::Set{Symbol}
end

"""
    compile_protocol_v2(prot::Protocol) -> PerDiseaseV2

Walk a `Protocol` IR and extract per-disease V2 data. Each
`ProtocolStep` contributes a phenotype + outgoing transitions; each
`ProtocolTerminal` contributes a terminal phenotype with no
transitions. Σ_obs events are named `:result_<obs>_<result>`.
"""
function compile_protocol_v2(prot::Protocol)::PerDiseaseV2
    phenotypes = Symbol[]
    workup_state = Dict{Symbol, Symbol}()
    transitions = Dict{Tuple{Symbol, Symbol}, Symbol}()
    sigma_obs = Set{Symbol}()

    function walk(node::ProtocolNode)
        if node isa ProtocolStep
            push!(phenotypes, node.phenotype)
            workup_state[node.phenotype] = node.order
            obs = obs_from_order(node.order)
            for (result, child) in node.on_result
                σ = Symbol("result_$(obs)_$(result)")
                push!(sigma_obs, σ)
                transitions[(node.phenotype, σ)] =
                    child isa ProtocolStep ? child.phenotype : child.phenotype
                walk(child)
            end
        else  # ProtocolTerminal
            push!(phenotypes, node.phenotype)
            workup_state[node.phenotype] = node.conclusion
        end
    end

    walk(prot.initial)

    return PerDiseaseV2(prot.disease, phenotypes, workup_state, transitions, sigma_obs)
end

"""
    compose_differentials_2(pd1::PerDiseaseV2, pd2::PerDiseaseV2)
        -> NamedTuple{(:D, :workup_state)}

Compose two per-disease records into a joint `Differential`. Joint
D-positions are the cartesian product of per-disease phenotypes;
joint Σ is the union of per-disease Σ_obs; transitions operate on the
disease component the σ targets; emit follows post-σ readout.

Returns `(D, workup_state)` where `workup_state` is the joint
projection function suitable for passing to `validate_v2_axiom`.
"""
function compose_differentials_2(pd1::PerDiseaseV2, pd2::PerDiseaseV2)
    positions = vec([(s1, s2) for s1 in pd1.phenotypes, s2 in pd2.phenotypes])
    Σ = union(pd1.sigma_obs, pd2.sigma_obs)

    function joint_workup(p::Tuple{Symbol, Symbol})
        return (pd1.workup_state[p[1]], pd2.workup_state[p[2]])
    end

    P_positions = unique([joint_workup(p) for p in positions])

    f = Dict{Tuple{Tuple{Symbol, Symbol}, Symbol}, Tuple{Symbol, Symbol}}()
    for p in positions, σ in Σ
        s1, s2 = p
        if σ in pd1.sigma_obs && haskey(pd1.transitions, (s1, σ))
            f[(p, σ)] = (pd1.transitions[(s1, σ)], s2)
        elseif σ in pd2.sigma_obs && haskey(pd2.transitions, (s2, σ))
            f[(p, σ)] = (s1, pd2.transitions[(s2, σ)])
        end
    end

    emit = Dict{Tuple{Tuple{Symbol, Symbol}, Symbol}, Tuple{Symbol, Symbol}}()
    for p in positions, σ in Σ
        emit[(p, σ)] = joint_workup(get(f, (p, σ), p))
    end

    sharp_L = Dict{Tuple{Tuple{Symbol, Symbol}, Symbol, Symbol}, Symbol}()
    O = OComonoid(Σ, 10)

    D = Differential{Tuple{Symbol, Symbol}, Tuple{Symbol, Symbol}}(
        O, positions, P_positions, f, emit, sharp_L,
    )

    return (D=D, workup_state=joint_workup)
end

# ============================================================
# Compiled D from D1_protocol + D2_protocol
# ============================================================

"PerDiseaseV2 for D1 compiled from `D1_protocol`."
const D1_v2 = compile_protocol_v2(D1_protocol)

"PerDiseaseV2 for D2 compiled from `D2_protocol`."
const D2_v2 = compile_protocol_v2(D2_protocol)

const D_v2_compiled_data = compose_differentials_2(D1_v2, D2_v2)

"Compiled joint Differential from D1+D2 protocols (25 D-positions; preserves via_o1a/via_o1b)."
const D_v2_compiled = D_v2_compiled_data.D

"workup_state callback for D_v2_compiled."
const D_v2_compiled_workup = D_v2_compiled_data.workup_state

# ============================================================
# Poly.jl substrate — per-disease P_d as a real Comonoid
# ============================================================

"""
    as_protocol_smallcategory(pd::PerDiseaseV2) -> SmallCategory

Build the per-disease protocol category as a Poly.jl `SmallCategory`.
Objects are workup-state pointers (the values of `pd.workup_state`);
generating morphisms are the per-disease transitions in
`pd.transitions`, viewed as edges between the source phenotype's
workup-state and the target phenotype's workup-state. The category is
freely generated: morphisms are sequences of those edges, including
identities.

Used by [`as_protocol_comonoid`](@ref) to produce the per-disease
`P_d::Comonoid`. For more than minimal toy graphs the full closure can
explode; we cap path length at `max_path_length` (default 3).
"""
function as_protocol_smallcategory(pd::PerDiseaseV2; max_path_length::Int=3)
    # Objects = workup-state pointers (deduplicated)
    object_set = Set{Symbol}(values(pd.workup_state))
    objects = sort(collect(object_set))

    # Generators: each (phenotype, σ) → next_phenotype yields an edge
    # workup_state[phenotype] → workup_state[next_phenotype], labeled by σ.
    # Two generators between the same pair of objects but with different
    # labels stay distinct. We encode generators as `(label, src_obj)`
    # so that Poly.jl's SmallCategory morphism representation
    # `(domain, direction)` keeps them separable.
    generators = Tuple{Symbol, Symbol, Symbol}[]   # (label, src_obj, dst_obj)
    for ((phen, σ), next_phen) in pd.transitions
        src = pd.workup_state[phen]
        dst = pd.workup_state[next_phen]
        push!(generators, (σ, src, dst))
    end

    # Build morphisms by closure under composition up to max_path_length.
    # Each morphism is a Vector of generator-labels representing a path.
    # Identities are the empty path at each object.
    morphisms_by_src = Dict{Symbol, Vector{Vector{Symbol}}}()
    for o in objects
        morphisms_by_src[o] = Vector{Symbol}[Symbol[]]   # identity = empty path
    end
    # Add length-1 generators
    for (σ, src, _dst) in generators
        push!(morphisms_by_src[src], [σ])
    end
    # Extend up to max_path_length
    for _len in 2:max_path_length
        for o in objects
            existing = copy(morphisms_by_src[o])
            for path in existing
                # Compute the codomain of `path` from `o`
                cur = o
                ok = true
                for σ in path
                    matches = filter(g -> g[1] === σ && g[2] === cur, generators)
                    if isempty(matches)
                        ok = false
                        break
                    end
                    cur = matches[1][3]
                end
                ok || continue
                # Try to extend with each outgoing generator from `cur`
                for (σ, src, _) in generators
                    src === cur || continue
                    extended = vcat(path, [σ])
                    if length(extended) <= max_path_length &&
                       !(extended in morphisms_by_src[o])
                        push!(morphisms_by_src[o], extended)
                    end
                end
            end
        end
    end

    # Assemble the SmallCategory tables. Morphisms are `(src, path)` pairs.
    morphism_keys = Tuple{Symbol, Vector{Symbol}}[]
    dom = Dict{Tuple{Symbol, Vector{Symbol}}, Symbol}()
    cod = Dict{Tuple{Symbol, Vector{Symbol}}, Symbol}()
    identity_dict = Dict{Symbol, Tuple{Symbol, Vector{Symbol}}}()

    for o in objects
        for path in morphisms_by_src[o]
            morph = (o, path)
            push!(morphism_keys, morph)
            dom[morph] = o
            # Walk the path to find codomain
            cur = o
            for σ in path
                matches = filter(g -> g[1] === σ && g[2] === cur, generators)
                cur = matches[1][3]
            end
            cod[morph] = cur
            if isempty(path)
                identity_dict[o] = morph
            end
        end
    end

    # Composition table: (f, g) ↦ fg when cod(f) == dom(g), result by concat.
    composition = Dict{Tuple{Tuple{Symbol, Vector{Symbol}}, Tuple{Symbol, Vector{Symbol}}}, Tuple{Symbol, Vector{Symbol}}}()
    for f in morphism_keys, g in morphism_keys
        cod[f] === dom[g] || continue
        f_src, f_path = f
        _,    g_path = g
        composite_path = vcat(f_path, g_path)
        # Composite must also be a known morphism (truncation may exclude long paths)
        composite = (f_src, composite_path)
        composite in morphism_keys || continue
        composition[(f, g)] = composite
    end

    return SmallCategory(
        FinPolySet(objects),
        FinPolySet(morphism_keys),
        dom, cod, identity_dict, composition,
    )
end

"""
    as_protocol_comonoid(pd::PerDiseaseV2; max_path_length=3) -> Comonoid

Materialize the per-disease protocol category as a real Poly.jl
`Comonoid` — the free category on the per-disease workup graph, with
path-tuple directions per the v1.2 free-P convention. Suitable for
`validate_comonoid` and Poly.jl's bicomodule machinery.
"""
function as_protocol_comonoid(pd::PerDiseaseV2; max_path_length::Int=3)
    from_category(as_protocol_smallcategory(pd; max_path_length))
end
