# ============================================================
# Protocol → Bicomodule compiler  (v1.3)
# ============================================================
#
# Given a `Protocol` IR, derive everything the per-disease Bicomodule
# needs: phenotype set, behavior trees per phenotype (= sub-cofree
# carrier), order graph (= free-P), mbar_L, mbar_R, A_carrier with
# path-tuple direction sets, and ultimately a Bicomodule object.
#
# Direction encoding decision (v1.3 — see project_polycds_v12_design.md
# for v1.2 context, this builds on it):
#   * A.directions(x) are PATH TUPLES through i_S(x), not symbols.
#     The categorical lens decomposition λ_L : A → S ▷ A reads
#     A.directions(x) ≅ S.directions(i_S(x)) — they ARE the paths.
#   * `:stay` is now `()` (the empty path). Mnemonic surface is
#     preserved by `pretty_label` for human-facing output (tests,
#     trajectory printer, demos).
#   * `mbar_L` and `mbar_R` are Dict-keyed by path tuples.

# ============================================================
# SmallCategory builders (used by compile_protocol)
# ============================================================
#
# These were previously in Bicomodule.jl; moved here at v1.3 cutover so
# the compiler runs before Bicomodule.jl in the module include order.

"""
    build_free_protocol_category(objects, edges) -> SmallCategory

Build the **free** protocol-category over the directed graph defined by
`objects` (vertex set) and `edges` (single-step transition list). "Free"
means morphisms ARE paths (sequences of edges) and *distinct paths to
the same target are kept distinct*. This is the categorical setting in
which the bicomodule axiom does substantive work — see
project_polycds_coherence.md.

The graph must be **acyclic** (DAG); enumeration is via DFS with
no-revisit. With a DAG, every concatenation of simple paths is itself a
simple path, so composition closure is automatic.

Morphism encoding: `(src::Symbol, path::Tuple{Vararg{Symbol}})`. The
`path` tuple is the sequence of intermediate codomain-targets (so
`length(path)` is the morphism's edge-count). Identity at object `o` is
`(o, ())`. A length-1 generator `o → o'` is `(o, (o',))`. The length-2
composite `o → o' → o''` is `(o, (o', o''))`. Composition concatenates
path tuples: `(a, p) ∘ (cod_p, q) = (a, (p..., q...))`.
"""
function build_free_protocol_category(objects::Vector{Symbol},
                                       edges::Vector{<:Tuple{Symbol,Symbol}})
    obj_set = FinPolySet(objects)

    out_neighbors = Dict{Symbol, Vector{Symbol}}(o => Symbol[] for o in objects)
    for (src, tgt) in edges
        push!(out_neighbors[src], tgt)
    end

    MorphKey = Tuple{Symbol, Tuple{Vararg{Symbol}}}
    morphisms_list = MorphKey[]
    morphism_dom = Dict{MorphKey, Symbol}()
    morphism_cod = Dict{MorphKey, Symbol}()
    morphism_identity = Dict{Symbol, MorphKey}()

    function enumerate_from(start::Symbol, current::Symbol,
                            prefix::Vector{Symbol}, visited::Set{Symbol})
        morph = (start, Tuple(prefix))
        push!(morphisms_list, morph)
        morphism_dom[morph] = start
        morphism_cod[morph] = current
        if isempty(prefix)
            morphism_identity[start] = morph
        end
        for nxt in out_neighbors[current]
            nxt in visited && continue
            new_visited = Set{Symbol}(visited)
            push!(new_visited, nxt)
            enumerate_from(start, nxt, vcat(prefix, [nxt]), new_visited)
        end
    end

    for o in objects
        enumerate_from(o, o, Symbol[], Set{Symbol}([o]))
    end

    morphisms_set = FinPolySet(morphisms_list)

    composition = Dict{Tuple{MorphKey, MorphKey}, MorphKey}()
    for f in morphisms_list
        cod_f = morphism_cod[f]
        for g in morphisms_list
            morphism_dom[g] == cod_f || continue
            combined = (f[1], (f[2]..., g[2]...))
            haskey(morphism_dom, combined) ||
                error("build_free_protocol_category: composition closure violated " *
                      "for $combined — graph is likely not acyclic")
            composition[(f, g)] = combined
        end
    end

    SmallCategory(obj_set, morphisms_set, morphism_dom, morphism_cod,
                  morphism_identity, composition)
end

"""
    build_subcofree_comonoid(roots::Vector{BehaviorTree}, p::Polynomial) -> Comonoid

Build a sub-cofree comonoid containing the given root behavior trees
(plus any subtrees reachable via tree_walk). Morphisms are paths through
each tree; composition is path concatenation; codomains are
subtree-walks. The compiler picks `roots` from a Protocol so that
closure under tree_walk is automatic (every subtree reached by walking
a root tree is itself a root tree of some terminal phenotype).
"""
function build_subcofree_comonoid(roots::Vector{BehaviorTree}, p::Polynomial)
    objects_set = Set{BehaviorTree}()
    queue = collect(roots)
    while !isempty(queue)
        t = pop!(queue)
        if !(t in objects_set)
            push!(objects_set, t)
            for child in values(t.children)
                push!(queue, child)
            end
        end
    end
    obj_list = collect(objects_set)
    obj_polyset = FinPolySet(obj_list)

    morphisms_list = Tuple[]
    morphism_dom = Dict()
    morphism_cod = Dict()
    morphism_identity = Dict()
    for t in obj_list
        for path in tree_paths(t)
            morph = (t, path)
            push!(morphisms_list, morph)
            morphism_dom[morph] = t
            morphism_cod[morph] = tree_walk(t, path)
            if isempty(path)
                morphism_identity[t] = morph
            end
        end
    end
    morphisms_polyset = FinPolySet(morphisms_list)

    composition = Dict()
    for f in morphisms_list
        t_f, path_f = f
        cod_f = morphism_cod[f]
        for g in morphisms_list
            t_g, path_g = g
            t_g == cod_f || continue
            combined = (t_f, (path_f..., path_g...))
            haskey(morphism_dom, combined) ||
                error("build_subcofree: composition closure violated; $combined not in set")
            composition[(f, g)] = combined
        end
    end

    cat = SmallCategory(obj_polyset, morphisms_polyset,
                        morphism_dom, morphism_cod,
                        morphism_identity, composition)
    return from_category(cat)
end

"""
    pretty_label(path::Tuple) -> Symbol

Map a path tuple to a mnemonic symbol for human-facing output. NOT
load-bearing — internal data uses paths directly. Output:
  * `()`              → `:stay`
  * `(:r,)`           → `:seq_r`
  * `(:r1, :r2)`      → `:panel_r1_r2`
  * `(:r1, …, :rn)`   → `:step_r1_…_rn`  (length-≥3 fallback)
"""
function pretty_label(path::Tuple)
    isempty(path) && return :stay
    length(path) == 1 && return Symbol("seq_", path[1])
    length(path) == 2 && return Symbol("panel_", path[1], "_", path[2])
    Symbol("step_", join(path, "_"))
end

# ============================================================
# Compiled output
# ============================================================

"""
    CompiledProtocol

Everything derived from a `Protocol` IR. The fields parallel the
hand-typed structures in v1.2's `Bicomodule.jl` — once cutover is
complete, those constants ARE these fields.

Fields:
  * `A_states` — phenotype symbols, ordered by depth-first walk of
    the protocol tree.
  * `A_carrier` — the per-disease phenotype polynomial. Directions at
    each phenotype are path tuples through that phenotype's subtree.
  * `S` — sub-cofree comonoid, carrier = the protocol-relevant trees.
  * `P` — free protocol-category comonoid over the order graph.
  * `i_S` — phenotype → behavior tree at that phenotype.
  * `mbar_L` — phenotype → (path-tuple → next-phenotype) routing.
  * `mbar_R` — phenotype → (path-tuple → P-position) recommendations.
  * `protocol_edges` — the directed graph (vertex pairs) the free-P
    is built from.
"""
struct CompiledProtocol
    A_states::Vector{Symbol}
    A_carrier::Polynomial
    S::Comonoid
    P::Comonoid
    i_S::Dict{Symbol, BehaviorTree}
    mbar_L::Dict{Symbol, Dict{Tuple, Symbol}}
    mbar_R::Dict{Symbol, Dict{Tuple, Symbol}}
    protocol_edges::Vector{Tuple{Symbol, Symbol}}
end

# ============================================================
# Helpers
# ============================================================

"Order or conclusion that a node represents on the P side."
node_recommendation(s::ProtocolStep)     = s.order
node_recommendation(t::ProtocolTerminal) = t.conclusion

"The phenotype symbol of a node."
node_phenotype(s::ProtocolStep)     = s.phenotype
node_phenotype(t::ProtocolTerminal) = t.phenotype

"""
    pos_for_obs(obs, p_obs) -> position

The flat-tagged position in `p_obs.positions` whose underlying
observation symbol is `obs`. E.g., `pos_for_obs(:o1a, p_D1_obs)` returns
`(1, :o1a)`.
"""
function pos_for_obs(obs::Symbol, p_obs::Polynomial)
    for pos in p_obs.positions.elements
        obs_of(pos) == obs && return pos
    end
    error("pos_for_obs: $obs not found in p_obs (positions: $(p_obs.positions.elements))")
end

# ============================================================
# Tree builders
# ============================================================

"""
    build_subtree(node, p_obs, parent) -> BehaviorTree

The behavior tree at `node`. For a step, recurse into the result-children.
For a terminal, return a depth-0 leaf labeled with the parent's
observation (the deterministic rule — see the leaf-labeling note below).

Leaf-labeling rule. A terminal phenotype's behavior tree is a depth-0
leaf. The leaf's label has to be SOME `p_obs` position; we pick the
parent step's observation. This is the simplest deterministic rule
that works — sub-cofree closure (every tree-walk lands inside the
chosen tree set) is automatic, and behavioral equivalence with the v1.2
hand-typed bicomodule holds (validate_bicomodule passes; simulation
trajectories match). The label has no clinical meaning at terminals;
it's just structurally required.
"""
function build_subtree(child::ProtocolStep, p_obs::Polynomial, ::ProtocolStep)
    return build_tree(child, p_obs)
end

function build_subtree(terminal::ProtocolTerminal, p_obs::Polynomial, parent::ProtocolStep)
    obs = obs_from_order(parent.order)
    label = pos_for_obs(obs, p_obs)
    return BehaviorTree(label, Dict{Any, BehaviorTree}())
end

"Build the behavior tree at a step."
function build_tree(step::ProtocolStep, p_obs::Polynomial)
    obs = obs_from_order(step.order)
    label = pos_for_obs(obs, p_obs)
    children = Dict{Any, BehaviorTree}()
    for (r, child) in step.on_result
        children[r] = build_subtree(child, p_obs, step)
    end
    return BehaviorTree(label, children)
end

# ============================================================
# Main compile pass
# ============================================================

"""
    compile_protocol(prot::Protocol) -> CompiledProtocol

Walk `prot`'s tree once and derive everything: phenotype set, trees,
mbar_L, mbar_R, protocol edges, and the comonoid/polynomial objects.

Acyclic-protocol assumption: no phenotype appears twice in the tree.
We assert this — duplicates would mean the protocol revisits a state,
which the IR doesn't currently support (would need looping semantics).
"""
function compile_protocol(prot::Protocol)::CompiledProtocol
    A_states = Symbol[]
    i_S = Dict{Symbol, BehaviorTree}()
    mbar_L = Dict{Symbol, Dict{Tuple, Symbol}}()
    mbar_R = Dict{Symbol, Dict{Tuple, Symbol}}()
    edges_set = Set{Tuple{Symbol, Symbol}}()

    process_node!(prot.initial, prot.p_obs,
                  A_states, i_S, mbar_L, mbar_R, edges_set,
                  nothing)

    # Order graph objects: every order/conclusion that appears anywhere.
    objects_set = Set{Symbol}()
    for (s, t) in edges_set
        push!(objects_set, s); push!(objects_set, t)
    end
    push!(objects_set, prot.initial.order)
    objects_list = sort(collect(objects_set); by=string)
    edges_list = collect(edges_set)

    # P = free protocol-category over the order graph.
    P = from_category(build_free_protocol_category(objects_list, edges_list))

    # S = sub-cofree containing exactly the protocol-relevant trees.
    root_trees = unique(values(i_S))
    S = build_subcofree_comonoid(collect(root_trees), prot.p_obs)

    # A_carrier — directions at phenotype x are path tuples through i_S[x].
    function a_dir_at(state)
        haskey(i_S, state) || error("a_dir_at: unknown phenotype $state")
        return FinPolySet(collect(tree_paths(i_S[state])))
    end
    A_carrier = Polynomial(FinPolySet(A_states), a_dir_at)

    return CompiledProtocol(A_states, A_carrier, S, P,
                            i_S, mbar_L, mbar_R, edges_list)
end

"""
    process_node!(node, p_obs, A_states, i_S, mbar_L, mbar_R, edges, parent)

Walk a single node, populate the per-phenotype dicts, recurse into
step-children. `parent` is the step that contains this node (or
`nothing` at the root); used so terminals know which obs to label
their leaf with.
"""
function process_node!(step::ProtocolStep, p_obs::Polynomial,
                       A_states, i_S, mbar_L, mbar_R, edges,
                       _parent)
    step.phenotype in A_states &&
        error("compile_protocol: phenotype $(step.phenotype) appears twice — protocol must be acyclic / non-repeating")
    push!(A_states, step.phenotype)

    i_S[step.phenotype] = build_tree(step, p_obs)

    step_mbar_L = Dict{Tuple, Symbol}()
    step_mbar_R = Dict{Tuple, Symbol}()

    # () = the stay slot
    step_mbar_L[()] = step.phenotype
    step_mbar_R[()] = step.order

    for (r, child) in step.on_result
        push!(edges, (step.order, node_recommendation(child)))

        # length-1 direction — single-step path
        step_mbar_L[(r,)] = node_phenotype(child)
        step_mbar_R[(r,)] = node_recommendation(child)

        # length-2 panel directions auto-derived where the child is itself
        # a step (per A3 — no flag, structural).
        if child isa ProtocolStep
            for (r2, grandchild) in child.on_result
                step_mbar_L[(r, r2)] = node_phenotype(grandchild)
                step_mbar_R[(r, r2)] = node_recommendation(grandchild)
            end
        end
    end

    mbar_L[step.phenotype] = step_mbar_L
    mbar_R[step.phenotype] = step_mbar_R

    # Recurse
    for (_, child) in step.on_result
        process_node!(child, p_obs, A_states, i_S, mbar_L, mbar_R, edges, step)
    end
end

function process_node!(term::ProtocolTerminal, p_obs::Polynomial,
                       A_states, i_S, mbar_L, mbar_R, edges,
                       parent)
    term.phenotype in A_states &&
        error("compile_protocol: phenotype $(term.phenotype) appears twice — protocol must be acyclic / non-repeating")
    push!(A_states, term.phenotype)

    parent isa ProtocolStep ||
        error("compile_protocol: terminal $(term.phenotype) has no parent step (top-level terminals not supported)")

    obs = obs_from_order(parent.order)
    label = pos_for_obs(obs, p_obs)
    i_S[term.phenotype] = BehaviorTree(label, Dict{Any, BehaviorTree}())

    mbar_L[term.phenotype] = Dict{Tuple, Symbol}(() => term.phenotype)
    mbar_R[term.phenotype] = Dict{Tuple, Symbol}(() => term.conclusion)
end

# ============================================================
# Compiled per-disease protocols
# ============================================================
#
# These are the engine-level objects derived from the per-disease
# Protocol IR. Bicomodule.jl pulls per-disease structures out of these.

"D1 compiled. See `D1_protocol` in Protocol.jl for the input IR."
const D1_compiled = compile_protocol(D1_protocol)

"D2 compiled."
const D2_compiled = compile_protocol(D2_protocol)
