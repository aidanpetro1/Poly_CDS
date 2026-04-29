# ============================================================
# The CDS bicomodule  A : S ⇸ P  (v1.3 — compiled)
# ============================================================
#
# Architectural rationale (see project_polycds_coherence.md and
# project_polycds_v12_design.md and project_polycds_phenotypes.md for
# the full settled design):
#
#   * S = sub-cofree per disease, derived from the per-disease Protocol
#     IR by the compiler (`build_subcofree_comonoid` in
#     ProtocolCompile.jl). The protocol-relevant trees are picked
#     mechanically from the IR rather than hand-typed.
#
#   * P = FREE protocol-category per disease, derived likewise from
#     the protocol's order graph. Length-≥2 composites kept distinct;
#     bicomodule axiom does substantive coherence work
#     (`validate_bicomodule_detailed` is the correctness criterion).
#
#   * A = per-disease phenotype carrier. A.positions = phenotype symbols,
#     A.directions(x) = path tuples through i_S(x). Lens decomposition
#     A.directions(x) ≅ S.directions(i_S(x)) — paths ARE the directions.
#     `pretty_label` in ProtocolCompile.jl gives mnemonic v1.2-style
#     symbols at the human-facing edge.
#
#   * mbar_L, mbar_R, i_S all sourced from the compiled output.
#
#   * Joint via `Bicomodule ⊗` from Poly.jl v0.2.0 (lazy-subst path).
#
# Bicomodule axiom = guideline coherence: the compatibility law requires
# that result-routing (left) agrees with planned-order pathway (right).
# Under v1.2's free-P this law constrains real P-morphism content;
# `validate_bicomodule_detailed` is a substantive correctness criterion.

# ============================================================
# Per-disease compiled pieces — bound from D{k}_compiled
# ============================================================
#
# These bind into module scope so the per-disease coactions and
# bicomodules can reference them without going through the full
# CompiledProtocol struct each time. The compiler is the source of
# truth; these are just convenience aliases.

"S_D1 — sub-cofree comonoid for D1 (compiled from D1_protocol)."
const S_D1 = D1_compiled.S
"S_D2 — sub-cofree comonoid for D2 (compiled from D2_protocol)."
const S_D2 = D2_compiled.S

"P_D1 — free protocol-category comonoid for D1 (compiled). 10 morphisms."
const P_D1 = D1_compiled.P
"P_D2 — free protocol-category comonoid for D2 (compiled)."
const P_D2 = D2_compiled.P

"D1: phenotype → behavior tree at that phenotype (compiled)."
const i_S_D1 = D1_compiled.i_S
"D2: phenotype → behavior tree at that phenotype (compiled)."
const i_S_D2 = D2_compiled.i_S

"D1 left routing: phenotype → (path-tuple → next-phenotype)."
const mbar_L_D1 = D1_compiled.mbar_L
"D2 left routing."
const mbar_L_D2 = D2_compiled.mbar_L

"D1 right recommendations: phenotype → (path-tuple → P-position)."
const mbar_R_D1 = D1_compiled.mbar_R
"D2 right recommendations."
const mbar_R_D2 = D2_compiled.mbar_R

"D1's planned-pathway edges (compiled)."
const D1_protocol_edges = D1_compiled.protocol_edges
"D2's planned-pathway edges (compiled)."
const D2_protocol_edges = D2_compiled.protocol_edges

# ============================================================
# ♯_L direction maps  (S-path × A-direction-at-next → A-direction-at-x)
# ============================================================
#
# Under paths-as-directions, sharp_L is literal path concatenation:
# given S-path b (from i_S[x] to i_S[mbar_L[x][b]]) and a path a through
# i_S[mbar_L[x][b]], the lifted A-direction at x is (b..., a...).
# The cofree coassoc rule guarantees the resulting path is valid
# at i_S[x].

"""
    sharp_L(disease, x, b, a) -> Tuple

The lifted A-direction at phenotype `x` given S-path `b` and a path `a`
through the next phenotype's tree. Literal path concatenation under the
v1.3 paths-as-directions encoding.
"""
function sharp_L(_disease::Symbol, _x::Symbol, b::Tuple, a::Tuple)
    return (b..., a...)
end

# ============================================================
# ♯_R direction maps  (A-direction × P-direction → A-direction)
# ============================================================
#
# v1.2 codomain-matching rule, restated in path encoding: extend `a`'s
# S-path by length(e) more steps to the unique extension whose terminal
# phenotype's mbar_R[()] equals `e[end]` (= cod of the P-morphism).
# Identity P-morphisms (`e == ()`) return `a` unchanged (Law 2).

"""
    sharp_R(disease, x, a, e) -> Tuple

At phenotype `x` of `disease`, given A-direction `a` (a path tuple) and
P-direction `e` (a path tuple — the codomain sequence of a P-morphism
out of `mbar_R^x[a]`), compute the lifted A-direction at `x`.

P-direction encoding (Cat# convention): `e == ()` for identity;
length-1 morphism `o → o'` is `(o',)`; length-2 composite `o → o' → o''`
is `(o', o'')`. Codomain is `e[end]`; length is `length(e)`.

Rule: extend `a`'s path by `length(e)` more steps, picking the unique
extension whose final phenotype recommends `e[end]`.

Errors with a diagnostic if uniqueness fails — that's a structural
problem with the protocol's order vocabulary, surfaced more clearly by
`validate_sharp_R_well_defined(disease)` which audits all triples at
construction time.
"""
function sharp_R(disease::Symbol, x::Symbol, a::Tuple, e::Tuple)
    isempty(e) && return a    # Law 2: identity P-morphism

    p_target = e[end]
    mbar_L_dict = disease == :D1 ? mbar_L_D1 : mbar_L_D2
    mbar_R_dict = disease == :D1 ? mbar_R_D1 : mbar_R_D2

    target_len = length(a) + length(e)

    candidates = Tuple[]
    for path in keys(mbar_L_dict[x])
        length(path) == target_len || continue
        all(i -> path[i] == a[i], 1:length(a)) || continue
        next_pos = mbar_L_dict[x][path]
        mbar_R_dict[next_pos][()] == p_target || continue
        push!(candidates, path)
    end

    length(candidates) == 1 ||
        error("sharp_R ambiguous at ($disease, $x, $a, $e): " *
              "$(length(candidates)) candidate extensions $(candidates). " *
              "Likely cause: terminal order vocabulary collapses distinct cods. " *
              "Run validate_sharp_R_well_defined($disease) for a full audit.")
    return candidates[1]
end

"""
    validate_sharp_R_well_defined(disease; verbose=true) -> Bool

Audit every `(x, a, e)` triple to assert `sharp_R` is uniquely defined.
Returns `true` on success; on failure prints all ambiguous/unmatched
triples and returns `false`.

Run at construction time (via `@assert` below) so a structural
ambiguity surfaces with a precise diagnostic before
`validate_bicomodule_detailed` even runs.
"""
function validate_sharp_R_well_defined(disease::Symbol; verbose::Bool=true)
    A_carrier   = disease == :D1 ? A_D1_carrier : A_D2_carrier
    P           = disease == :D1 ? P_D1         : P_D2
    mbar_L_dict = disease == :D1 ? mbar_L_D1    : mbar_L_D2
    mbar_R_dict = disease == :D1 ? mbar_R_D1    : mbar_R_D2

    issues = Tuple[]
    for x in A_carrier.positions.elements
        for a in A_carrier.direction_at(x).elements
            p_at_a = mbar_R_dict[x][a]
            for e in P.carrier.direction_at(p_at_a).elements
                isempty(e) && continue   # identity is trivially well-defined
                p_target = e[end]
                target_len = length(a) + length(e)
                candidates = Tuple[]
                for path in keys(mbar_L_dict[x])
                    length(path) == target_len || continue
                    all(i -> path[i] == a[i], 1:length(a)) || continue
                    next_pos = mbar_L_dict[x][path]
                    mbar_R_dict[next_pos][()] == p_target || continue
                    push!(candidates, path)
                end
                if length(candidates) != 1
                    push!(issues, (x, a, e, candidates))
                end
            end
        end
    end

    if isempty(issues)
        verbose && println("validate_sharp_R_well_defined($disease): all triples uniquely defined.")
        return true
    else
        if verbose
            println("validate_sharp_R_well_defined($disease): $(length(issues)) ambiguous/unmatched triples:")
            for (x, a, e, cs) in issues
                println("  ($x, $a, $e) → $(length(cs)) candidates: $cs")
            end
        end
        return false
    end
end

# ============================================================
# Building per-disease lenses (left and right coactions)
# ============================================================

"""
    build_left_coaction(disease) -> Lens

The left coaction λ_L : A_Dk_carrier → S_Dk.carrier ▷ A_Dk_carrier.
At each phenotype, picks the cofree subtree from `i_S_Dk` and the
routing function from `mbar_L_Dk`. Both come from the compiled output.
"""
function build_left_coaction(disease::Symbol)
    A_carrier   = disease == :D1 ? A_D1_carrier : A_D2_carrier
    S           = disease == :D1 ? S_D1         : S_D2
    i_S_dict    = disease == :D1 ? i_S_D1       : i_S_D2
    mbar_L_dict = disease == :D1 ? mbar_L_D1    : mbar_L_D2

    cod = subst(S.carrier, A_carrier)

    Lens(
        A_carrier, cod,
        x -> begin
            tree = i_S_dict[x]
            mbar = mbar_L_dict[x]
            (tree, Dict{Any,Any}(p => v for (p, v) in mbar))
        end,
        (x, ba_pair) -> begin
            b, a = ba_pair
            sharp_L(disease, x, b, a)
        end
    )
end

"""
    build_right_coaction(disease) -> Lens

The right coaction λ_R : A_Dk_carrier → A_Dk_carrier ▷ P_Dk.carrier.
At each phenotype, picks (x, mbar_R) from the compiled output.
"""
function build_right_coaction(disease::Symbol)
    A_carrier   = disease == :D1 ? A_D1_carrier : A_D2_carrier
    P           = disease == :D1 ? P_D1         : P_D2
    mbar_R_dict = disease == :D1 ? mbar_R_D1    : mbar_R_D2

    cod = subst(A_carrier, P.carrier)

    Lens(
        A_carrier, cod,
        x -> begin
            mbar = mbar_R_dict[x]
            (x, Dict{Any,Any}(d => p for (d, p) in mbar))
        end,
        (x, ae_pair) -> begin
            a, e = ae_pair
            sharp_R(disease, x, a, e)
        end
    )
end

# ============================================================
# The per-disease bicomodules
# ============================================================
#
# Construction-time check: under free-P, `sharp_R` must be uniquely
# defined for every `(x, a, e)`. We assert this BEFORE building the
# bicomodule so an ill-formed protocol's order vocabulary surfaces
# with a precise diagnostic, rather than as a generic axiom failure.

@assert validate_sharp_R_well_defined(:D1; verbose=false) "sharp_R is not well-defined for D1 — see validate_sharp_R_well_defined(:D1)"
@assert validate_sharp_R_well_defined(:D2; verbose=false) "sharp_R is not well-defined for D2 — see validate_sharp_R_well_defined(:D2)"

"D1 bicomodule: A_D1_carrier as a (S_D1, P_D1)-bicomodule."
const A_D1_bicomodule = Bicomodule(
    A_D1_carrier, S_D1, P_D1,
    build_left_coaction(:D1),
    build_right_coaction(:D1),
)

"D2 bicomodule: A_D2_carrier as a (S_D2, P_D2)-bicomodule."
const A_D2_bicomodule = Bicomodule(
    A_D2_carrier, S_D2, P_D2,
    build_left_coaction(:D2),
    build_right_coaction(:D2),
)

# ============================================================
# Joint bicomodule  —  A_joint  =  A_D1_bicomodule  ⊗  A_D2_bicomodule
# ============================================================
#
# The formal joint bicomodule, the categorical artifact representing
# the full joint CDS. Construction depends on the Poly.jl v0.2.0
# lazy-subst path (Lens.cod accepts AbstractPolynomial; the joint
# duplicator and joint coactions go through subst_lazy). Without
# lazy substitution the joint comonoid's duplicator's eager
# `subst(carrier, carrier)` would be combinatorially intractable.

"""
    A_joint :: Bicomodule

The joint bicomodule `A_joint : (S_D1 ⊗ S_D2) ⇸ (P_D1 ⊗ P_D2)`,
constructed as the formal `Bicomodule` tensor product of the
per-disease bicomodules. Categorical ground truth of the joint CDS.
"""
const A_joint = parallel(A_D1_bicomodule, A_D2_bicomodule)
