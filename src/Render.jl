# ============================================================
# Wiring-diagram prints  (v1.4 — text-mode)
# ============================================================
#
# Text-mode renderers for the protocol IR, the compiled engine output,
# and bicomodules. ASCII tree-drawing for the workflow shape; flat
# bullet lists for vocabulary / direction tables.
#
# Aidan flagged that real visualization libraries (Mermaid, Catlab,
# Penrose) are the eventual target; this file is the text bridge.
# Format intent: dump-friendly REPL output that lines up enough to be
# scanned visually.
#
# Three top-level entry points:
#   * `print_protocol(prot; io=stdout)` — the IR tree alone.
#   * `print_compiled(c; io=stdout)`    — compiled phenotypes,
#                                         order graph, per-phenotype
#                                         direction tables.
#   * `print_joint(joint; io=stdout)`   — joint bicomodule summary.
#
# Plus `print_trajectory` (in Simulate.jl) gets enriched to use
# `pretty_label` on per-side direction columns.

# ============================================================
# print_protocol  — IR tree
# ============================================================

"""
    print_protocol(prot::Protocol; io::IO=stdout)

Render a `Protocol` IR tree as ASCII art. Shows the workflow's
phenotype/order/conclusion structure.
"""
function print_protocol(prot::Protocol; io::IO=stdout)
    n_obs = length(prot.metadata.observations)
    obs_note = n_obs == 0 ? "" : " ($n_obs observations)"
    println(io, "Protocol: ", prot.disease, obs_note)
    println(io, "  ", prot.initial.phenotype, "    ", prot.initial.order)
    _print_protocol_step_children(io, prot.initial, "  ")
end

function _print_protocol_step_children(io::IO, step::ProtocolStep, prefix::String)
    children = collect(step.on_result)
    n = length(children)
    for (i, (result, child)) in enumerate(children)
        is_last = (i == n)
        branch = is_last ? "└─" : "├─"
        if child isa ProtocolStep
            println(io, prefix, branch, "[", result, "]→ ",
                    child.phenotype, "    ", child.order)
            new_prefix = prefix * (is_last ? "    " : "│   ")
            _print_protocol_step_children(io, child, new_prefix)
        else  # ProtocolTerminal
            println(io, prefix, branch, "[", result, "]→ ",
                    child.phenotype, "   ⇒ ", child.conclusion)
        end
    end
end

# ============================================================
# print_compiled  —  compiled engine view
# ============================================================

"""
    print_compiled(c::CompiledProtocol; io::IO=stdout)

Render the compiled engine output: phenotype list with mbar_R[stay]
recommendations, full direction tables (using `pretty_label`), order
graph edges, and a one-line summary of S and P sizes.
"""
function print_compiled(c::CompiledProtocol; io::IO=stdout)
    # Header
    n_phen = length(c.A_states)
    n_S    = length(c.S.carrier.positions.elements)
    n_P_obj = length(c.P.carrier.positions.elements)
    n_P_mor = sum(length(c.P.carrier.direction_at(o).elements)
                  for o in c.P.carrier.positions.elements)
    println(io, "CompiledProtocol  ($n_phen phenotypes, $n_S trees in S, ",
                 "$n_P_obj orders / $n_P_mor morphisms in P)")
    println(io)

    # Order graph (just edges, grouped by source)
    println(io, "Order graph — $(length(c.protocol_edges)) edges:")
    by_src = Dict{Symbol, Vector{Symbol}}()
    for (src, tgt) in c.protocol_edges
        push!(get!(by_src, src, Symbol[]), tgt)
    end
    for src in sort(collect(keys(by_src)); by=string)
        println(io, "  ", src, ":")
        for tgt in sort(by_src[src]; by=string)
            println(io, "    └─→ ", tgt)
        end
    end
    println(io)

    # Per-phenotype direction tables
    println(io, "Phenotypes (with direction tables):")
    for x in c.A_states
        directions = collect(keys(c.mbar_R[x]))
        n_dir = length(directions)
        rec_at_stay = c.mbar_R[x][()]
        is_terminal = n_dir == 1   # only :stay
        marker = is_terminal ? "  (terminal)" : ""
        println(io, "  ", rpad(string(x), 24), " ⇒ ", rpad(string(rec_at_stay), 22),
                    "  ($n_dir direction$(n_dir == 1 ? "" : "s"))$marker")
        # Sort directions by length so :stay first, then seq_*, then panel_*
        sorted_dirs = sort(directions; by = p -> (length(p), p))
        for path in sorted_dirs
            isempty(path) && continue   # skip :stay row; already shown above
            label = pretty_label(path)
            next_pos = c.mbar_L[x][path]
            recommendation = c.mbar_R[x][path]
            println(io, "      ", rpad(string(label), 16), " → ",
                        rpad(string(next_pos), 24), " ⇒ ", recommendation)
        end
    end
end

# ============================================================
# print_joint  —  joint bicomodule summary
# ============================================================

"""
    print_joint(joint::Bicomodule; io::IO=stdout)

One-screen summary of a joint bicomodule: shape, sizes, and the
per-disease building blocks. Doesn't enumerate the 25 joint phenotypes
(too noisy at the REPL) — see `print_compiled(D{k}_compiled)` for the
per-disease detail.
"""
function print_joint(joint::Bicomodule; io::IO=stdout)
    n_joint_phen = length(joint.carrier.positions.elements)
    n_joint_S    = length(joint.left_base.carrier.positions.elements)
    n_joint_P    = length(joint.right_base.carrier.positions.elements)
    println(io, "Joint bicomodule")
    println(io, "  carrier  : ", n_joint_phen, " joint phenotypes")
    println(io, "  S-side   : ", n_joint_S,    " S-objects (S_D1 ⊗ S_D2)")
    println(io, "  P-side   : ", n_joint_P,    " P-objects (P_D1 ⊗ P_D2)")
    println(io)
    println(io, "Per-disease building blocks:")
    println(io, "  A_D1 : S_D1 ⇸ P_D1")
    println(io, "      ", length(D1_compiled.A_states), " phenotypes, ",
                length(D1_compiled.protocol_edges), " protocol edges")
    println(io, "  A_D2 : S_D2 ⇸ P_D2")
    println(io, "      ", length(D2_compiled.A_states), " phenotypes, ",
                length(D2_compiled.protocol_edges), " protocol edges")
    println(io)
    println(io, "Categorical reading: A_∅ = A_D1 ⊗ A_D2")
    println(io, "                            : (S_D1 ⊗ S_D2) ⇸ (P_D1 ⊗ P_D2)")
end

# ============================================================
# Mermaid generators  —  clinician-facing flowchart syntax
# ============================================================
#
# Returns Mermaid-syntax strings that render in any markdown viewer
# (GitHub, VSCode, Obsidian, etc.). Designed for the clinician audience:
# protocol workflow + order graph as labeled flowcharts. The categorical
# bicomodule wiring goes through Catlab (see catlab_* functions below).

"""
    mermaid_protocol(prot::Protocol; direction="TD") -> String

Mermaid flowchart syntax for the protocol's workflow tree. Steps render
as rectangles (phenotype + recommended order); terminals render as
parallelograms (phenotype ⇒ clinical conclusion). Edges are labeled by
the result symbol that triggers the transition.

`direction` is the Mermaid layout direction — `"TD"` (top-down,
default), `"LR"` (left-right), `"BT"`, or `"RL"`.
"""
function mermaid_protocol(prot::Protocol; direction::String="TD")::String
    lines = String["flowchart $direction"]
    edges = Tuple{Symbol, Symbol, Symbol}[]

    function visit(node::ProtocolNode)
        if node isa ProtocolStep
            label = "$(node.phenotype)<br/>$(node.order)"
            push!(lines, "    $(node.phenotype)[\"$label\"]")
            for r in sort(collect(keys(node.on_result)); by=string)
                child = node.on_result[r]
                push!(edges, (node.phenotype, node_phenotype(child), r))
                visit(child)
            end
        else  # ProtocolTerminal
            label = "$(node.phenotype)<br/>⇒ $(node.conclusion)"
            push!(lines, "    $(node.phenotype)[/\"$label\"/]")
        end
    end

    visit(prot.initial)
    push!(lines, "")
    for (from, to, label) in edges
        push!(lines, "    $from -->|$label| $to")
    end

    return join(lines, "\n")
end

"""
    mermaid_order_graph(c::CompiledProtocol; direction="LR") -> String

Mermaid flowchart for the free-P order graph. Order nodes render as
rectangles; clinical-conclusion nodes (`disease_*_present` / `_absent`)
render as parallelograms. Edges are unlabeled (the graph encodes the
planned-pathway transitions structurally).
"""
function mermaid_order_graph(c::CompiledProtocol; direction::String="LR")::String
    lines = String["flowchart $direction"]

    # Collect all nodes from the edges
    nodes = Set{Symbol}()
    for (src, tgt) in c.protocol_edges
        push!(nodes, src)
        push!(nodes, tgt)
    end

    # Render nodes — clinical conclusions get parallelogram shape
    for n in sort(collect(nodes); by=string)
        if startswith(string(n), "disease_")
            push!(lines, "    $n[/\"$n\"/]")
        else
            push!(lines, "    $n[\"$n\"]")
        end
    end

    push!(lines, "")
    for (src, tgt) in sort(c.protocol_edges; by = e -> (string(e[1]), string(e[2])))
        push!(lines, "    $src --> $tgt")
    end

    return join(lines, "\n")
end

# ============================================================
# Markdown wrappers  —  embed Mermaid blocks for inline rendering
# ============================================================
#
# Wrap the raw Mermaid syntax in markdown ```mermaid fenced blocks
# so the file renders inline anywhere markdown + Mermaid is supported
# (GitHub, VSCode preview, Obsidian, etc.). The markdown also carries
# explanatory prose so the rendered file is self-documenting.

"""
    markdown_protocol(prot::Protocol; direction="TD") -> String

Markdown rendering of the protocol workflow tree, with the Mermaid
syntax embedded in a fenced ```mermaid block. Open the resulting file
in any markdown viewer with Mermaid support to see the diagram inline.
"""
function markdown_protocol(prot::Protocol; direction::String="TD")::String
    title = isempty(prot.metadata.title) ?
                "Protocol $(prot.disease) workflow" :
                "$(prot.metadata.title) — workflow"

    body = """
# $title

$(isempty(prot.metadata.description) ? "" : prot.metadata.description)

```mermaid
$(mermaid_protocol(prot; direction=direction))
```
"""
    return body
end

"""
    markdown_order_graph(c::CompiledProtocol, disease::Symbol; direction="LR") -> String

Markdown rendering of the free-P order graph for a disease, embedded as
a Mermaid flowchart.
"""
function markdown_order_graph(c::CompiledProtocol, disease::Symbol;
                              direction::String="LR")::String
    body = """
# Order graph — free-P for $disease

The directed graph of the planned-pathway transitions. Order nodes are
rectangles; clinical-conclusion nodes (`disease_*_present`,
`disease_*_absent`) are parallelograms. Each edge is a free-P
generator; the bicomodule's `sharp_R` extends along these.

```mermaid
$(mermaid_order_graph(c; direction=direction))
```
"""
    return body
end

"""
    markdown_overview(prot::Protocol, c::CompiledProtocol) -> String

Combined markdown view: protocol workflow tree AND free-P order graph
in a single document. The natural one-stop file for documenting a
disease protocol.
"""
function markdown_overview(prot::Protocol, c::CompiledProtocol)::String
    title = isempty(prot.metadata.title) ?
                "Protocol $(prot.disease) — overview" :
                "$(prot.metadata.title) — overview"

    body = """
# $title

$(isempty(prot.metadata.description) ? "" : prot.metadata.description)

## Workflow

```mermaid
$(mermaid_protocol(prot))
```

## Free-P order graph

```mermaid
$(mermaid_order_graph(c))
```
"""
    return body
end

# ============================================================
# Catlab WiringDiagrams  —  categorical native bicomodule rendering
# ============================================================
#
# Use Catlab's WiringDiagrams to render a bicomodule as a single-box
# diagram with S-input on the left and P-output on the right; the joint
# bicomodule renders as the parallel (otimes) composition of the two
# per-disease boxes. Rendering to SVG/PNG goes through Catlab.Graphics.
#
# This is the categorical-native counterpart to the Mermaid functions
# above — Mermaid for clinician-facing flowcharts (workflow + order
# graph), Catlab for the structural bicomodule diagram.

using Catlab.WiringDiagrams
using Catlab.Graphics
using Catlab.Graphics.Graphviz: pprint as _gv_pprint

"""
    catlab_bicomodule(disease::Symbol) -> WiringDiagram

A WiringDiagram for the per-disease bicomodule `A_disease : S_disease ⇸
P_disease`. One box labeled `A_<disease>` with one input port (S_<disease>)
and one output port (P_<disease>), wired through the diagram's outer
input/output.
"""
function catlab_bicomodule(disease::Symbol)
    s_label = Symbol("S_", disease)
    p_label = Symbol("P_", disease)
    a_label = Symbol("A_", disease)

    d = WiringDiagram([s_label], [p_label])
    b = add_box!(d, Box(a_label, [s_label], [p_label]))
    add_wires!(d, [
        (input_id(d), 1) => (b, 1),
        (b, 1) => (output_id(d), 1),
    ])
    return d
end

"""
    catlab_joint(joint::Bicomodule) -> WiringDiagram

A WiringDiagram for the joint bicomodule
`A_∅ : (S_D1 ⊗ S_D2) ⇸ (P_D1 ⊗ P_D2)`. Two parallel boxes (A_D1
above, A_D2 below) with their respective S-inputs and P-outputs.
Constructed directly so the two-port-per-side input/output structure
is explicit; equivalent to `otimes(catlab_bicomodule(:D1),
catlab_bicomodule(:D2))`.

(The `joint` parameter is unused — we read the structure from the
known per-disease setup. A future cross-linked composition `M ⊙ N`
would consult the joint object's data.)
"""
function catlab_joint(::Bicomodule)
    d = WiringDiagram([:S_D1, :S_D2], [:P_D1, :P_D2])
    b1 = add_box!(d, Box(:A_D1, [:S_D1], [:P_D1]))
    b2 = add_box!(d, Box(:A_D2, [:S_D2], [:P_D2]))
    add_wires!(d, [
        (input_id(d), 1) => (b1, 1),
        (input_id(d), 2) => (b2, 1),
        (b1, 1) => (output_id(d), 1),
        (b2, 1) => (output_id(d), 2),
    ])
    return d
end

"""
    render_catlab_to_dot(diagram; io=stdout) -> Nothing

Render a WiringDiagram to GraphViz DOT format and write to `io`. Pipe
the result through `dot -Tsvg -o file.svg` (or any GraphViz format) to
produce a rendered image.

For inline display in Jupyter / VSCode notebooks, just `display(diagram)`
in a Catlab-aware environment.
"""
function render_catlab_to_dot(diagram; io::IO=stdout, labels::Bool=true)
    # `labels=true` makes the wire labels (S_D1, P_D1, etc.) render
    # visibly, not just as SVG metadata.
    g = to_graphviz(diagram; labels=labels)
    # Catlab's Graphviz.Graph needs `pprint` to emit DOT syntax;
    # the default `print`/`show` falls through to a generic path
    # that doesn't dispatch correctly for it.
    _gv_pprint(io, g)
    return nothing
end

# ============================================================
# print_bicomodule  —  per-disease bicomodule summary
# ============================================================

"""
    print_bicomodule(disease::Symbol; io::IO=stdout)

Per-disease bicomodule summary, sourced from the compiled output. Use
this for a quick REPL look at A_D1 / A_D2's shape; for the full
per-phenotype direction table see `print_compiled(D{k}_compiled)`.
"""
function print_bicomodule(disease::Symbol; io::IO=stdout)
    c = disease == :D1 ? D1_compiled : D2_compiled
    println(io, "A_", disease, " : S_", disease, " ⇸ P_", disease)
    println(io, "  ", length(c.A_states), " phenotypes")
    println(io, "  S-side  : ", length(c.S.carrier.positions.elements), " trees in sub-cofree")
    n_P_mor = sum(length(c.P.carrier.direction_at(o).elements)
                  for o in c.P.carrier.positions.elements)
    println(io, "  P-side  : ",
                length(c.P.carrier.positions.elements), " orders / ",
                n_P_mor, " morphisms in free-P")
    println(io, "  edges   : ", length(c.protocol_edges))
end
