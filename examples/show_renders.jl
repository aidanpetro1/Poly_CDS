"""
    examples/show_renders.jl  (v1.6 — V2 master-D)

Exercise the V2 renderers and write each output to `renders/`. Phase 3
(2026-05-01) removed v1.x renders 1-11 along with their generators; this
file now produces only V2 master-D artifacts:

    renders/01_differential.md                (Mermaid: D_v2_toy f-graph,
                                                grouped by D2-state)
    renders/02_differential_compiled.md       (Mermaid: D_v2_compiled
                                                from D1+D2 protocols)
    renders/03_trajectory_v2_d1_sequential.md (Mermaid: V2 simulator
                                                trace, sequential)
    renders/04_trajectory_v2_d1_panel.md      (Mermaid: V2 simulator
                                                trace, panel mode)

Run:
    julia --project=. examples/show_renders.jl

Preview the .md files in VSCode (Cmd-Shift-V), GitHub, or
https://mermaid.live for ad-hoc rendering of the Mermaid blocks.
"""

include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS

import .PolyCDS:
    mermaid_differential, mermaid_trajectory_v2,
    D_v2_toy, toy_v2_workup_state,
    D_v2_compiled, D_v2_compiled_workup,
    simulate_v2, Patient_D1

const OUT_DIR = joinpath(@__DIR__, "..", "renders")
isdir(OUT_DIR) || mkpath(OUT_DIR)

function _write_string(filename::String, content::String)
    path = joinpath(OUT_DIR, filename)
    open(path, "w") do io
        write(io, content)
    end
    println("  wrote $path")
end

println("Writing V2 renders to $OUT_DIR")
println()

# 1. D_v2_toy structure (manually-authored 16-position toy)
_write_string("01_differential.md",
    """
    # V2 master-D (D_v2_toy) — transition structure

    The V2 master bicomodule `D : O ⇸ P` for the D1/D2 toy. Each node is
    a D-position (joint per-disease phenotype tuple) labeled with its
    workup-state pointer (= recommendation under post-σ readout). Edges
    are σ event firings drawn from `Σ_obs_v2`. Joint-terminal positions
    (both diseases at `:a_Dk` or `:a_Dk_absent`) styled in green.

    Grouped into Mermaid subgraphs by D2-state: each subgraph contains
    the four D-positions sharing that D2 component, organizing the
    4×4 grid visually. 16 D-positions, ~32 σ-event transitions.

    ```mermaid
    $(mermaid_differential(D_v2_toy, toy_v2_workup_state;
                            direction="LR", group_by=p -> p[2]))
    ```
    """)

# 2. D_v2_compiled structure (from D1+D2 protocols, 25 positions)
_write_string("02_differential_compiled.md",
    """
    # V2 master-D (D_v2_compiled) — compiled from D1+D2 protocols

    The Differential produced by `compile_protocol_v2` + `compose_differentials_2`
    on the existing v1.x `D1_protocol` and `D2_protocol`. Distinct from
    `D_v2_toy` — preserves the via_o1a/via_o1b distinction, giving 5
    phenotypes per disease and 25 D-positions.

    Grouped by D2-state. Larger graph than D_v2_toy; useful for
    visualizing the full state space.

    ```mermaid
    $(mermaid_differential(D_v2_compiled, D_v2_compiled_workup;
                            direction="LR", group_by=p -> p[2]))
    ```
    """)

# 3. V2 simulator trajectory (Patient_D1 sequential)
_traj_seq = simulate_v2(Patient_D1; mode=:sequential)
_write_string("03_trajectory_v2_d1_sequential.md",
    """
    # V2 trajectory — Patient_D1, sequential mode

    Simulator trace through `D_v2_toy` for `Patient_D1`. Each step shows
    the D-position and joint workup state; edges are labeled with the σ
    events fired during that transition.

    ```mermaid
    $(mermaid_trajectory_v2(_traj_seq))
    ```
    """)

# 4. V2 simulator trajectory (Patient_D1 panel)
_traj_pan = simulate_v2(Patient_D1; mode=:panel)
_write_string("04_trajectory_v2_d1_panel.md",
    """
    # V2 trajectory — Patient_D1, panel mode

    Panel mode advances both non-terminal diseases per step; per-disease
    panel + screen-positive fires confirm immediately (2 σ in one step).
    The trajectory reaches the same final state as sequential, in fewer
    steps.

    ```mermaid
    $(mermaid_trajectory_v2(_traj_pan))
    ```
    """)

println()
println("done — 4 files written to $OUT_DIR")
println()
println("To preview the .md files inline (with rendered Mermaid diagrams):")
println("  • VSCode: open file → Cmd-Shift-V (or right-click → Open Preview)")
println("  • GitHub: just push and view in the repo")
println("  • https://mermaid.live for ad-hoc rendering of the raw Mermaid block")
