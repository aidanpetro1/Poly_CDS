"""
    test/test_v15_viz.jl

Smoke tests for the v1.5 viz layer:
  * Mermaid generators (`mermaid_protocol`, `mermaid_order_graph`) emit
    well-formed flowchart syntax containing the expected node ids and
    edge labels.
  * Catlab generators (`catlab_bicomodule`, `catlab_joint`) construct
    WiringDiagram objects without error and survive a round-trip through
    `to_graphviz`.

Doesn't rasterize SVG/PNG — the test suite stays binary-free.
"""

using Test

@isdefined(PolyCDS) || include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS

import .PolyCDS:
    mermaid_protocol, mermaid_order_graph,
    catlab_bicomodule, catlab_joint, render_catlab_to_dot,
    D1_protocol, D2_protocol, D1_compiled, D2_compiled, A_joint

@testset "v1.5 — viz generators" begin

    # ----------------------------------------------------------------
    # 1. Mermaid: protocol workflow tree
    # ----------------------------------------------------------------
    @testset "mermaid_protocol(D1) — flowchart syntax" begin
        m = mermaid_protocol(D1_protocol)

        # Header
        @test occursin("flowchart TD", m)

        # All 5 phenotype nodes appear
        @test occursin("a_D1_initial", m)
        @test occursin("a_D1_pending", m)
        @test occursin("a_D1_absent_via_o1a", m)
        @test occursin("a_D1_absent_via_o1b", m)

        # Steps render with order labels
        @test occursin("order_o1a", m)
        @test occursin("order_o1b", m)

        # Terminals reference clinical conclusions
        @test occursin("disease_D1_present", m)
        @test occursin("disease_D1_absent", m)

        # Edges labeled by result symbol
        @test occursin("|pos|", m)
        @test occursin("|neg|", m)

        # Edge format
        @test occursin("a_D1_initial -->|pos| a_D1_pending", m)
        @test occursin("a_D1_initial -->|neg| a_D1_absent_via_o1a", m)
    end

    # ----------------------------------------------------------------
    # 2. Mermaid: order graph (free-P)
    # ----------------------------------------------------------------
    @testset "mermaid_order_graph(D1_compiled) — flowchart syntax" begin
        m = mermaid_order_graph(D1_compiled)
        @test occursin("flowchart LR", m)
        @test occursin("order_o1a", m)
        @test occursin("order_o1b", m)
        @test occursin("disease_D1_present", m)
        @test occursin("disease_D1_absent", m)
        # Each protocol_edge becomes a `src --> tgt` line
        @test occursin("order_o1a --> order_o1b", m)
        @test occursin("order_o1a --> disease_D1_absent", m)
        @test occursin("order_o1b --> disease_D1_present", m)
        @test occursin("order_o1b --> disease_D1_absent", m)
    end

    # ----------------------------------------------------------------
    # 3. Mermaid: D2 parallel structure
    # ----------------------------------------------------------------
    @testset "mermaid for D2 (parallel)" begin
        m = mermaid_protocol(D2_protocol)
        @test occursin("a_D2_initial", m)
        @test occursin("disease_D2_present", m)

        m2 = mermaid_order_graph(D2_compiled)
        @test occursin("order_o2a --> order_o2b", m2)
    end

    # ----------------------------------------------------------------
    # 4. Catlab: per-disease bicomodule diagram
    # ----------------------------------------------------------------
    @testset "catlab_bicomodule(:D1)" begin
        d = catlab_bicomodule(:D1)
        # WiringDiagram-ness: the value should round-trip through
        # to_graphviz without error.
        io = IOBuffer()
        render_catlab_to_dot(d; io=io)
        dot = String(take!(io))
        @test !isempty(dot)
        @test occursin("A_D1", dot)
    end

    # ----------------------------------------------------------------
    # 5. Catlab: joint diagram (parallel composition)
    # ----------------------------------------------------------------
    @testset "catlab_joint(A_joint)" begin
        d = catlab_joint(A_joint)
        io = IOBuffer()
        render_catlab_to_dot(d; io=io)
        dot = String(take!(io))
        @test !isempty(dot)
        @test occursin("A_D1", dot)
        @test occursin("A_D2", dot)
    end
end
