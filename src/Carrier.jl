# ============================================================
# Per-disease and joint phenotype carriers  (v1.3 — compiled)
# ============================================================
#
# A_Dk_carrier are derived from the protocol IR via the compiler in
# ProtocolCompile.jl. The hand-typed direction-symbol scheme of v1.1/1.2
# was retired at v1.3 cutover — direction-sets are now path tuples
# through the per-phenotype behavior tree (see project_polycds_v12_design.md
# for the v1.2 context that preceded this; cofree's lens decomposition
# A.directions(x) ≅ S.directions(i_S(x)) is the categorical reading).
#
# Mnemonic surface: `pretty_label(path)` in ProtocolCompile.jl maps
# path tuples to v1.2-style symbols (`:stay`, `:seq_pos`,
# `:panel_pos_neg`, …) for human-facing output.

"D1's phenotype polynomial — derived from `D1_protocol`."
const A_D1_carrier = D1_compiled.A_carrier

"D2's phenotype polynomial — derived from `D2_protocol`."
const A_D2_carrier = D2_compiled.A_carrier

"Joint phenotype polynomial via Dirichlet/parallel of per-disease carriers."
const A_carrier = A_D1_carrier ⊗ A_D2_carrier
