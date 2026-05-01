# ============================================================
# Render — V2 master-D renderers
# ============================================================
#
#   * mermaid_differential(D, workup_state) — D's f-graph
#   * mermaid_trajectory_v2(traj)           — V2 simulator trace

# ============================================================
# Helpers
# ============================================================

# Mermaid-safe id from an arbitrary value.
_mermaid_id(s) = replace(string(s), r"[^A-Za-z0-9_]" => "_")

# Mermaid-safe ID for a D-position (joins tuple components with `_`).
_diff_id(p::Tuple) = "d_" * join(string.(p), "_")
_diff_id(p) = "d_" * _mermaid_id(p)

# Multi-line node label: "(p)" / "(workup_state)".
function _diff_node_label(p, ws)
    p_str = "(" * join(string.(p), ", ") * ")"
    ws_str = "(" * join(string.(ws), ", ") * ")"
    return "$p_str<br/>━━━<br/>$ws_str"
end

# Joint-terminal predicate for the toy (hardcoded phenotype set).
function _is_diff_terminal(p::Tuple{Symbol,Symbol})
    s_D1, s_D2 = p
    s_D1 in (:a_D1, :a_D1_absent) && s_D2 in (:a_D2, :a_D2_absent)
end

# ============================================================
# mermaid_differential — D's f-graph
# ============================================================

"""
    mermaid_differential(D::Differential, workup_state::Function;
                         direction::String="LR",
                         show_terminals::Bool=true,
                         group_by::Union{Function,Nothing}=nothing) -> String

Mermaid flowchart of `D`'s f-graph. Nodes are D-positions labeled with
`(p)` and `workup_state(p)`; edges are σ-event transitions from `D.f`.
`direction` is `"LR"` or `"TD"`. When `show_terminals=true`,
joint-terminal positions render in green. When `group_by` is supplied,
D-positions are grouped into Mermaid `subgraph` blocks keyed by
`group_by(p)` (e.g., `p -> p[2]` to row by D2-state).
"""
function mermaid_differential(D, workup_state::Function;
                              direction::String="LR",
                              show_terminals::Bool=true,
                              group_by::Union{Function, Nothing}=nothing)
    lines = String["flowchart $(direction)"]

    # Nodes — flat or grouped via subgraphs
    terminals = String[]
    if group_by === nothing
        for p in D.positions
            id = _diff_id(p)
            ws = workup_state(p)
            push!(lines, "    $id[\"$(_diff_node_label(p, ws))\"]")
            if show_terminals && _is_diff_terminal(p)
                push!(terminals, id)
            end
        end
    else
        # Group positions by group_by(p), preserving D.positions order within each group
        groups = Dict{Any, Vector}()
        group_keys = Any[]
        for p in D.positions
            key = group_by(p)
            if !haskey(groups, key)
                groups[key] = []
                push!(group_keys, key)
            end
            push!(groups[key], p)
        end
        for key in group_keys
            grp_id = "grp_" * _mermaid_id(key)
            push!(lines, "    subgraph $grp_id [\"$(string(key))\"]")
            for p in groups[key]
                id = _diff_id(p)
                ws = workup_state(p)
                push!(lines, "        $id[\"$(_diff_node_label(p, ws))\"]")
                if show_terminals && _is_diff_terminal(p)
                    push!(terminals, id)
                end
            end
            push!(lines, "    end")
        end
    end
    push!(lines, "")

    # Edges (one per authored f entry)
    for ((p, σ), p_next) in D.f
        from_id = _diff_id(p)
        to_id   = _diff_id(p_next)
        push!(lines, "    $from_id -->|$σ| $to_id")
    end

    # Style terminals
    if show_terminals && !isempty(terminals)
        push!(lines, "")
        push!(lines, "    classDef terminal fill:#d4edda,stroke:#155724,stroke-width:2px")
        push!(lines, "    class $(join(terminals, ",")) terminal")
    end

    return join(lines, "\n")
end

# ============================================================
# mermaid_trajectory_v2 — V2 simulator trace
# ============================================================

"""
    mermaid_trajectory_v2(traj; direction::String="LR") -> String

Mermaid flowchart of a V2 simulator trajectory. `traj` is a
`Vector{TrajectoryStepV2}` (type annotation omitted because the type
loads after this file). Each step becomes a labeled node; edges
between consecutive steps are labeled with the σ events fired during
the transition (multi-σ steps stack labels via `<br/>`).
"""
function mermaid_trajectory_v2(traj; direction::String="LR")
    isempty(traj) && return "flowchart $direction"

    lines = String["flowchart $(direction)"]

    for s in traj
        id = "t$(s.step)"
        p_str = "(" * join(string.(s.p), ", ") * ")"
        ws_str = "(" * join(string.(s.workup_state), ", ") * ")"
        terminal_marker = _is_diff_terminal(s.p) ? " ✓" : ""
        label = "step $(s.step)$(terminal_marker)<br/>$p_str<br/>━━━<br/>$ws_str"
        push!(lines, "    $id[\"$label\"]")
    end
    push!(lines, "")

    for i in 2:length(traj)
        from_id = "t$(traj[i-1].step)"
        to_id   = "t$(traj[i].step)"
        σ_label = isempty(traj[i].sigma_events) ?
                    "—" :
                    join(string.(traj[i].sigma_events), "<br/>")
        push!(lines, "    $from_id -->|$σ_label| $to_id")
    end

    # Style terminal step
    final = traj[end]
    if _is_diff_terminal(final.p)
        push!(lines, "")
        push!(lines, "    classDef terminal fill:#d4edda,stroke:#155724,stroke-width:2px")
        push!(lines, "    class t$(final.step) terminal")
    end

    return join(lines, "\n")
end
