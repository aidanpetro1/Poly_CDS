# ============================================================
# Differential diagnosis projection from ∫A  (v1.6.B PR 2)
# ============================================================
#
# Foundations doc §30. DDx is a projection from the patient's current
# point (h_t, a_t) ∈ ∫A to the set of diseases still being
# differentiated.
#
# Settled reading (Aidan, 2026-04-30): "active workup" semantics —
#
#   DDx(h, (s_D1, s_D2)) = { d : s_d ∈ active_workup_states(d) }
#
# i.e. d is on the differential iff s_d is at initial or pending
# (still being worked up); confirmed AND ruled-out states leave the
# DDx. Confirmed diagnoses go to the active-problem-list (h via
# realize), not the differential.
#
# The h argument is unused under (A) but kept in the signature for
# API consistency with §30 and forward compat with v1.7's FHIR
# substrate (where richer h-content might inform the projection).
#
# Two-level narrowing per §30 happens automatically:
#   * Vertical (within fiber): λ_h consumes obs and a_t refines —
#     transitions from a_d_pending → a_d (confirmed) remove d from
#     DDx; transitions to a_d_absent_* also remove d.
#   * Horizontal (between fibers): h grows and A_h shrinks — diseases
#     that fall out of A_h's positions never get a chance to be
#     differentiated further.

"""
    DDx(h::ListState, joint_pos::Tuple{Symbol,Symbol}) -> Vector{Symbol}

The differential diagnosis at point `(h, joint_pos) ∈ ∫A`. Returns
diseases `d ∈ {:D1, :D2}` whose per-disease state `s_d` is in
`active_workup_states(d)` = `[a_d_initial, a_d_pending]`.

The `h` argument is unused under v1.6.B's "active workup" reading
(§30 settled choice). Kept in signature for API consistency and
forward compat.

Examples (with v1.6.B's strawman content):
  * `DDx(∅, (a_D1_initial, a_D2_initial))` = `[:D1, :D2]`
  * `DDx(h_chest, (a_D1_pending, a_D2_initial))` = `[:D1, :D2]`
  * `DDx(h_chest, (a_D1, a_D2_initial))` = `[:D2]`  (D1 confirmed)
  * `DDx(h_chest, (a_D1_absent_via_o1a, a_D2))` = `[]` (D1 absent, D2 confirmed)
"""
function DDx(::ListState, joint_pos::Tuple{Symbol,Symbol})
    s_D1, s_D2 = joint_pos
    out = Symbol[]
    s_D1 in A_D1_active_workup && push!(out, :D1)
    s_D2 in A_D2_active_workup && push!(out, :D2)
    return out
end

"""
    DDx(int_A_object) -> Vector{Symbol}

Convenience: ∫A-object form. Same projection, accepts a single
`(h, joint_pos)` tuple as returned by `int_A`-object iteration.
"""
DDx(int_A_object::Tuple{ListState,Tuple{Symbol,Symbol}}) =
    DDx(int_A_object[1], int_A_object[2])

# ============================================================
# DDx narrowing predicates  (for trajectory analytics)
# ============================================================

"""
    DDx_narrowed(prev_h, prev_a, cur_h, cur_a) -> Set{Symbol}

The set of diseases that LEFT the differential between point
`(prev_h, prev_a)` and `(cur_h, cur_a)` in ∫A. A disease `d` left
the DDx iff it was in DDx at the prev step and not at the cur step.

Useful for trajectory-level audit: "what was ruled out / concluded
at this step?"
"""
function DDx_narrowed(prev_h::ListState, prev_a::Tuple{Symbol,Symbol},
                      cur_h::ListState, cur_a::Tuple{Symbol,Symbol})
    return setdiff(Set(DDx(prev_h, prev_a)), Set(DDx(cur_h, cur_a)))
end

"""
    DDx_concluded_disease(prev_a::Tuple{Symbol,Symbol},
                          cur_a::Tuple{Symbol,Symbol}) -> Vector{Symbol}

Diseases concluded (confirmed OR ruled out) by the transition
prev_a → cur_a, regardless of which side of the conclusion. A
disease is "concluded" iff it was in active workup before and isn't
after.
"""
function DDx_concluded_disease(prev_a::Tuple{Symbol,Symbol},
                                cur_a::Tuple{Symbol,Symbol})
    out = Symbol[]
    if prev_a[1] in A_D1_active_workup && !(cur_a[1] in A_D1_active_workup)
        push!(out, :D1)
    end
    if prev_a[2] in A_D2_active_workup && !(cur_a[2] in A_D2_active_workup)
        push!(out, :D2)
    end
    return out
end
