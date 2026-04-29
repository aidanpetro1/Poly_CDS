"""
    test/test_v14_protocoldoc.jl

Tests for the v1.4 ProtocolDoc parser (`src/ProtocolDoc.jl`).

What's covered:
  * Round-trip: parsing `protocols/D1.md` + `protocols/D2.md` produces
    Protocols whose IR tree (compiled) matches the in-Julia
    `D1_protocol` / `D2_protocol` consts behaviorally.
  * Front-matter and metadata blocks are preserved on the Protocol.
  * Parse-time strict cross-reference validation: typo in result
    symbol, missing order declaration, missing conclusion,
    duplicate phenotype all error out with the expected message.

Run standalone:
    julia C:/Poly_CDS/test/test_v14_protocoldoc.jl

Or via the suite:
    julia C:/Poly_CDS/test/runtests.jl
"""

using Test

@isdefined(PolyCDS) || include(joinpath(@__DIR__, "..", "src", "PolyCDS.jl"))
using .PolyCDS

import .PolyCDS:
    parse_protocol, compile_protocol,
    Protocol, ProtocolStep, ProtocolTerminal, ProtocolMetadata,
    D1_protocol, D2_protocol, D1_compiled, D2_compiled

const PROTOCOL_DIR = joinpath(@__DIR__, "..", "protocols")

@testset "v1.4 — ProtocolDoc parser" begin

    # ----------------------------------------------------------------
    # 1. Round-trip: parse D1.md, compile, compare to D1_compiled.
    #    Behavioral equivalence: the parsed-then-compiled result has
    #    the same A_states, mbar_L, mbar_R, protocol_edges as the
    #    in-Julia D1_protocol's compiled output.
    # ----------------------------------------------------------------
    @testset "round-trip: D1.md → Protocol → CompiledProtocol matches D1_compiled" begin
        d1_path = joinpath(PROTOCOL_DIR, "D1.md")
        @test isfile(d1_path)

        d1_parsed = parse_protocol(d1_path)
        @test d1_parsed isa Protocol
        @test d1_parsed.disease == :D1
        @test d1_parsed.initial isa ProtocolStep
        @test d1_parsed.initial.phenotype == :a_D1_initial
        @test d1_parsed.initial.order == :order_o1a

        d1_parsed_compiled = compile_protocol(d1_parsed)

        # Set equality on phenotypes
        @test Set(d1_parsed_compiled.A_states) == Set(D1_compiled.A_states)
        # mbar_R agrees pointwise (sample a few entries)
        @test d1_parsed_compiled.mbar_R[:a_D1_initial][()]              == :order_o1a
        @test d1_parsed_compiled.mbar_R[:a_D1_initial][(:pos, :pos)]    == :disease_D1_present
        @test d1_parsed_compiled.mbar_R[:a_D1_initial][(:pos, :neg)]    == :disease_D1_absent
        @test d1_parsed_compiled.mbar_R[:a_D1][()]                      == :disease_D1_present
        # mbar_L agrees
        @test d1_parsed_compiled.mbar_L[:a_D1_initial][(:pos, :pos)]    == :a_D1
        @test d1_parsed_compiled.mbar_L[:a_D1_initial][(:neg,)]         == :a_D1_absent_via_o1a
        # protocol_edges match as a set
        @test Set(d1_parsed_compiled.protocol_edges) == Set(D1_compiled.protocol_edges)
    end

    @testset "round-trip: D2.md (parallel)" begin
        d2_path = joinpath(PROTOCOL_DIR, "D2.md")
        @test isfile(d2_path)

        d2_parsed = parse_protocol(d2_path)
        d2_parsed_compiled = compile_protocol(d2_parsed)

        @test d2_parsed.disease == :D2
        @test Set(d2_parsed_compiled.A_states) == Set(D2_compiled.A_states)
        @test d2_parsed_compiled.mbar_R[:a_D2_initial][()] == :order_o2a
        @test d2_parsed_compiled.mbar_R[:a_D2][()]         == :disease_D2_present
        @test Set(d2_parsed_compiled.protocol_edges) == Set(D2_compiled.protocol_edges)
    end

    # ----------------------------------------------------------------
    # 2. Metadata preservation. FHIR fields, displays, and clinical
    #    descriptions land on the Protocol's `metadata` field.
    # ----------------------------------------------------------------
    @testset "metadata preserved on parsed Protocol" begin
        d1_parsed = parse_protocol(joinpath(PROTOCOL_DIR, "D1.md"))
        m = d1_parsed.metadata

        @test m.title    == "Simple D1 workup (toy)"
        @test m.version  == "0.1"
        @test occursin("screen-then-confirm", m.description)

        # Observations: o1a should have its loinc and results preserved.
        @test haskey(m.observations, :o1a)
        @test m.observations[:o1a][:loinc] == "00000-1"
        @test m.observations[:o1a][:results] == [:neg, :pos]

        # Orders: order_o1a's FHIR mapping preserved.
        @test haskey(m.orders, :order_o1a)
        fhir = m.orders[:order_o1a][:fhir]
        @test fhir isa Dict
        @test fhir["resource"] == "ServiceRequest"

        # Conclusions: ICD10.
        @test haskey(m.conclusions, :disease_D1_present)
        @test m.conclusions[:disease_D1_present][:icd10] == "E00.0"

        # Phenotypes: display + description.
        @test haskey(m.phenotypes, :a_D1_initial)
        @test m.phenotypes[:a_D1_initial][:display] == "Pre-workup"
    end

    # ----------------------------------------------------------------
    # 3. Parse-time validation errors: typo / missing / duplicate.
    #    Each test writes a deliberately-broken markdown to a tmp file
    #    and asserts parse_protocol throws.
    # ----------------------------------------------------------------
    @testset "parse-time strict cross-reference validation" begin
        function tmpfile(content::String)
            path, io = mktemp()
            write(io, content)
            close(io)
            return path
        end

        # Helper: build a minimal-but-broken markdown variant
        function broken_d1(; bad_result_key=nothing, omit_order=false,
                            omit_conclusion=false, dup_phenotype=false)
            base = read(joinpath(PROTOCOL_DIR, "D1.md"), String)
            if bad_result_key !== nothing
                # Replace `pos:` with the bad result key in the workflow
                # block (limited replacement so we don't touch obs results).
                base = replace(base,
                    "    pos:\n      phenotype: a_D1_pending" =>
                    "    $(bad_result_key):\n      phenotype: a_D1_pending";
                    count=1)
            end
            if omit_order
                # Remove the order_o1a declaration from yaml-orders block.
                base = replace(base,
                    "  - id: order_o1a\n    display: Order D1 screen\n    fhir:\n      resource: ServiceRequest\n      code: \"00000-1\"\n" => "")
            end
            if omit_conclusion
                # Remove disease_D1_present from yaml-conclusions
                base = replace(base,
                    "  - id: disease_D1_present\n    display: D1 confirmed present\n    icd10: E00.0\n" => "")
            end
            if dup_phenotype
                # Reuse :a_D1_initial as a terminal phenotype too
                base = replace(base,
                    "      terminal: a_D1_absent_via_o1a" =>
                    "      terminal: a_D1_initial";
                    count=1)
            end
            return base
        end

        # Bad result key: `weak_pos` not in observation o1a's results [:neg, :pos]
        bad1 = tmpfile(broken_d1(bad_result_key="weak_pos"))
        @test_throws ErrorException parse_protocol(bad1)

        # Missing order declaration
        bad2 = tmpfile(broken_d1(omit_order=true))
        @test_throws ErrorException parse_protocol(bad2)

        # Missing conclusion declaration
        bad3 = tmpfile(broken_d1(omit_conclusion=true))
        @test_throws ErrorException parse_protocol(bad3)

        # Duplicate phenotype
        bad4 = tmpfile(broken_d1(dup_phenotype=true))
        @test_throws ErrorException parse_protocol(bad4)
    end

    # ----------------------------------------------------------------
    # 4. Bare-bones sanity: missing required block fails clearly.
    # ----------------------------------------------------------------
    @testset "missing required block fails parse" begin
        bare = """
        ---
        disease: D1
        title: Bare
        ---

        # Bare protocol — no blocks!
        """
        path, io = mktemp()
        write(io, bare); close(io)
        @test_throws ErrorException parse_protocol(path)
    end
end
