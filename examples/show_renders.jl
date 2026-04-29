"""
    examples/show_renders.jl

Exercise every render function and write each output to a file in the
`renders/` directory. The Mermaid outputs are wrapped in markdown
fenced blocks (.md files) so they render inline anywhere markdown +
Mermaid is supported (GitHub, VSCode preview, Obsidian, etc.).

Run:
    julia --project=. examples/show_renders.jl

Outputs (relative to repo root):
    renders/01_d1_protocol_tree.txt          (print_protocol — ASCII)
    renders/02_d1_compiled.txt               (print_compiled — ASCII)
    renders/03_joint_summary.txt             (print_joint — ASCII)
    renders/04_d1_bicomodule.txt             (print_bicomodule — ASCII)
    renders/05_d1_protocol.md                (mermaid in markdown)
    renders/06_d1_order_graph.md             (mermaid in markdown)
    renders/07_d1_overview.md                (combined: workflow + order graph)
    renders/08_d1_bicomodule.dot             (Catlab WiringDiagram → DOT)
    renders/09_joint_bicomodule.dot          (Catlab joint → DOT)
    renders/10_patient_d1_panel_trajectory.txt   (print_trajectory)

To view the .md files inline: open in VSCode (preview), GitHub, or any
markdown editor with Mermaid support. To render the .dot files:

    dot -Tsvg renders/08_d1_bicomodule.dot -o renders/08_d1_bicomodule.svg
"""

include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS

import .PolyCDS:
    print_protocol, print_compiled, print_joint, print_bicomodule,
    markdown_protocol, markdown_order_graph, markdown_overview,
    catlab_bicomodule, catlab_joint, render_catlab_to_dot,
    print_trajectory, simulate,
    D1_protocol, D1_compiled, A_joint, Patient_D1

const OUT_DIR = joinpath(@__DIR__, "..", "renders")
isdir(OUT_DIR) || mkpath(OUT_DIR)

function _write(filename::String, writer::Function)
    path = joinpath(OUT_DIR, filename)
    open(path, "w") do io
        writer(io)
    end
    println("  wrote $path")
end

function _write_string(filename::String, content::String)
    path = joinpath(OUT_DIR, filename)
    open(path, "w") do io
        write(io, content)
    end
    println("  wrote $path")
end

println("Writing renders to $OUT_DIR")
println()

# 1. Protocol IR tree (ASCII)
_write("01_d1_protocol_tree.txt", io -> print_protocol(D1_protocol; io=io))

# 2. Full compiled engine view (ASCII)
_write("02_d1_compiled.txt", io -> print_compiled(D1_compiled; io=io))

# 3. Joint bicomodule summary (ASCII)
_write("03_joint_summary.txt", io -> print_joint(A_joint; io=io))

# 4. Per-disease bicomodule summary (ASCII)
_write("04_d1_bicomodule.txt", io -> print_bicomodule(:D1; io=io))

# 5. Markdown with Mermaid: protocol workflow
_write_string("05_d1_protocol.md", markdown_protocol(D1_protocol))

# 6. Markdown with Mermaid: order graph
_write_string("06_d1_order_graph.md", markdown_order_graph(D1_compiled, :D1))

# 7. Combined markdown overview (workflow + order graph)
_write_string("07_d1_overview.md", markdown_overview(D1_protocol, D1_compiled))

# 8. Catlab per-disease bicomodule (GraphViz DOT)
_write("08_d1_bicomodule.dot", io -> render_catlab_to_dot(catlab_bicomodule(:D1); io=io))

# 9. Catlab joint bicomodule (GraphViz DOT)
_write("09_joint_bicomodule.dot", io -> render_catlab_to_dot(catlab_joint(A_joint); io=io))

# 10. Trajectory with the new dir column
_write("10_patient_d1_panel_trajectory.txt",
       io -> print_trajectory(simulate(Patient_D1; mode=:panel); io=io))

println()
println("done — 10 files written to $OUT_DIR")
println()
println("To preview the .md files inline (with rendered Mermaid diagrams):")
println("  • VSCode: open file → Cmd-Shift-V (or right-click → Open Preview)")
println("  • GitHub: just push and view in the repo")
println("  • https://mermaid.live for ad-hoc rendering of the raw Mermaid block")
