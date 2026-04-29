# ============================================================
# Per-disease and joint phenotype carriers  (v1.1, post-sub-cofree)
# ============================================================
#
# A.positions are computable phenotypes (see project_polycds_phenotypes.md
# for the architectural rationale).
#
# With sub-cofree (see Bicomodule.jl), we control the tree shape — the
# `:neg`-branch of `T_root_D1` is a depth-0 leaf (workup ends right
# there), so there's NO off-protocol phenotype. Per-disease A drops
# from 6 to 5 positions; joint via `⊗` from 36 to 25.
#
# Direction labels at each phenotype follow the (S-path, P-morphism)
# consistent-pair structure (see project_polycds_coherence.md):
#
#   :stay           — identity (no event, stay in this phenotype)
#   :seq_neg        — sequential single-step, negative result
#   :seq_pos        — sequential single-step, positive result
#   :panel_pos_neg  — length-2 panel path, pos then neg
#   :panel_pos_pos  — length-2 panel path, both positives

# ============================================================
# Per-disease A_D1_carrier
# ============================================================

"""
    a_D1_dir_at(state)

Direction-set at each D1 phenotype. Direction count matches the path
count of the cofree subtree picked at that position by the bicomodule's
left coaction in `Bicomodule.jl`.
"""
function a_D1_dir_at(state)
    if state == :a_D1_initial
        # T_root_D1 is ragged-depth: 5 paths
        # ()              :stay
        # (:neg,)         :seq_neg          → a_D1_absent_via_o1a
        # (:pos,)         :seq_pos          → a_D1_pending
        # (:pos, :neg)    :panel_pos_neg    → a_D1_absent_via_o1b
        # (:pos, :pos)    :panel_pos_pos    → a_D1
        return FinPolySet([:stay, :seq_neg, :seq_pos, :panel_pos_neg, :panel_pos_pos])
    elseif state == :a_D1_pending
        # T_pos_D1 is depth-1: 3 paths
        # ()       :stay
        # (:neg,)  :seq_neg → a_D1_absent_via_o1b
        # (:pos,)  :seq_pos → a_D1
        return FinPolySet([:stay, :seq_neg, :seq_pos])
    elseif state in (:a_D1, :a_D1_absent_via_o1a, :a_D1_absent_via_o1b)
        # Depth-0 leaf: 1 path (:stay)
        return FinPolySet([:stay])
    else
        error("a_D1_dir_at: unknown D1 phenotype $state")
    end
end

const A_D1_carrier = Polynomial(FinPolySet(A_D1_states), a_D1_dir_at)

# ============================================================
# Per-disease A_D2_carrier (parallel structure)
# ============================================================

function a_D2_dir_at(state)
    if state == :a_D2_initial
        return FinPolySet([:stay, :seq_neg, :seq_pos, :panel_pos_neg, :panel_pos_pos])
    elseif state == :a_D2_pending
        return FinPolySet([:stay, :seq_neg, :seq_pos])
    elseif state in (:a_D2, :a_D2_absent_via_o2a, :a_D2_absent_via_o2b)
        return FinPolySet([:stay])
    else
        error("a_D2_dir_at: unknown D2 phenotype $state")
    end
end

const A_D2_carrier = Polynomial(FinPolySet(A_D2_states), a_D2_dir_at)

# ============================================================
# Joint carrier — bicomodule ⊗ in Bicomodule.jl produces the same shape
# ============================================================

"Convenience: the *polynomial* `A_D1_carrier ⊗ A_D2_carrier` (Dirichlet/parallel)."
const A_carrier = A_D1_carrier ⊗ A_D2_carrier
