# ============================================================
# Θ — the derived S → H quotient functor  (v1.6.B)
# ============================================================
#
# Foundations doc §25. Θ is *not* hand-authored — it is mechanically
# derived from `realize` (and `cc_realize` for the intake initial
# state). For an S-step `(d, s) -> (d, s')`:
#
#   Θ((d, s) -> (d, s')) =
#     id_h                        if realize(d, s) == realize(d, s')
#     realize_symdiff(...)        otherwise
#
# The resulting Path is a morphism in H_path (history-of-events
# reading); under the quotient π: H_path → H_quot it becomes the
# (h_before, h_after) pair canonically labeled by sorted-symdiff.
#
# This file provides Θ at three levels:
#   * `theta_phenotype(d, s, s')`       — single-disease A-phenotype-step
#   * `theta_joint(joint, joint')`      — joint A-phenotype-step
#   * `theta_advance(h, joint, joint')` — apply Θ to advance an H-state
#
# Plus initial-condition helpers for the intake stage:
#   * `initial_h_from_cc(cc)`           — h_0 after CC fires
#
# Per the v1.6.B settled design (project_polycds_v16_design.md):
# realize is authored at A-phenotype level; if the simulator works
# at S-position level (sub-cofree tree positions), the caller is
# responsible for projecting S-position → A-phenotype via the
# existing v1.x bicomodule λ-coaction before invoking Θ. Lifting
# Θ to S-positions directly is mechanical but deferred until the
# integration with Simulate.jl in PR 2.

# ============================================================
# Per-disease Θ at A-phenotype level
# ============================================================

"""
    theta_phenotype(d::Symbol, s_before::Symbol, s_after::Symbol) -> Path

Θ at the per-disease A-phenotype level. Computes the H_path morphism
(a `Path`, i.e. `Vector{Symbol}` of token-toggles) realizing the
S-step `(d, s_before) -> (d, s_after)`.

Returns `path_identity()` (= empty Path) iff
`realize(d, s_before) == realize(d, s_after)` — these are S-steps
that Θ collapses to id_h.
"""
function theta_phenotype(d::Symbol, s_before::Symbol, s_after::Symbol)
    r_before = realize(d, s_before)
    r_after  = realize(d, s_after)
    return realize_symdiff(r_before, r_after)
end

# ============================================================
# Joint-state Θ
# ============================================================
#
# In v1.x the joint state of the framework is (s_D1, s_D2) — a pair
# of per-disease A-phenotypes. The joint realize is the union of per-
# disease realizes (each per-disease realize emits tokens namespaced
# to its own disease, so the union is disjoint and unambiguous).

"""
    joint_realize(joint_state::Tuple{Symbol,Symbol}) -> Set{Symbol}

The joint realize: union of `realize(:D1, s_D1)` and
`realize(:D2, s_D2)` for `joint_state = (s_D1, s_D2)`. Disjoint by
construction (each disease's tokens are namespaced).

This is the lifted realize that takes a joint A-phenotype to its
problem-list-summary in Σ_prob.
"""
function joint_realize(joint_state::Tuple{Symbol,Symbol})
    s_D1, s_D2 = joint_state
    return union(realize(:D1, s_D1), realize(:D2, s_D2))
end

"""
    theta_joint(joint_before::Tuple{Symbol,Symbol},
                joint_after ::Tuple{Symbol,Symbol}) -> Path

Θ at the joint A-phenotype level. Equivalent to
`realize_symdiff(joint_realize(joint_before), joint_realize(joint_after))`.

Captures Θ for joint S-steps where one or both diseases advance.
Per-disease realize-sets are disjoint so the joint sym-diff
decomposes cleanly into per-disease contributions.
"""
function theta_joint(joint_before::Tuple{Symbol,Symbol},
                     joint_after ::Tuple{Symbol,Symbol})
    return realize_symdiff(joint_realize(joint_before),
                           joint_realize(joint_after))
end

"""
    theta_advance(h_before::ListState,
                  joint_before::Tuple{Symbol,Symbol},
                  joint_after ::Tuple{Symbol,Symbol}) -> ListState

Apply Θ at the joint level to advance an H-state. Equivalent to
`apply_path(h_before, theta_joint(joint_before, joint_after))`.

Used by the simulator (PR 2) to compute the next h_t after each
joint S-step. Note: this assumes `h_before` is consistent with
`joint_before` — i.e., `joint_realize(joint_before) ⊆ h_before`.
The non-realize-derived parts of h_before (CC-provenance tokens
and any from-other-disease realize tokens) are preserved.
"""
function theta_advance(h_before::ListState,
                       joint_before::Tuple{Symbol,Symbol},
                       joint_after ::Tuple{Symbol,Symbol})
    π = theta_joint(joint_before, joint_after)
    return apply_path(h_before, π)
end

# ============================================================
# Intake initial condition  (CC-firing → h_0)
# ============================================================
#
# Foundations doc §29: chief complaint is an H-generator. The
# initial H-state h_0 after CC `c` fires is precisely cc_realize(c) —
# the universal-empty root ∅ extended by the cc_realize tokens.

"""
    cc_fire(c::Symbol, h_current::ListState=ListState_empty)
      -> Tuple{Vector{Symbol}, ListState}

The general CC-firing operation per foundations doc §29: chief
complaint `c` is an H-generator that takes the current state
`h_current` to a new state by *adding* each token in `cc_realize(c)`
that isn't already present.

Under the toggle reframe: f_c is the canonical (sorted) path of
toggles for the symdiff from `h_current` to `h_current ∪ cc_realize(c)`.
Since the precondition requires no overlap (see below), this
simplifies to "toggle each new token to add it" — never a remove.

Returns `(f_c, h_next)`:
  * `f_c::Vector{Symbol}` — sorted list of toggle-tokens to apply
  * `h_next::ListState` — the resulting H-state

**v1.6.B PRECONDITION:** `cc_realize(c) ∩ h_current = ∅`. The patient
has no problems on the list yet that overlap with the CC-provenance
or considering tokens this CC would produce. This rules out scenarios
like a chest-pain re-presentation where `:chest_pain` and
`:considering_D1` are already on the list. v1.6.C will lift this to
the "filter to missing problems, log filtering" semantics from §29.

For `:well_visit` (cc_realize = ∅), returns `(Symbol[], h_current)` —
no problem-list change; H stays put.

For `h_current = ∅` (the typical intake case), `h_next = cc_realize(c)`
and `f_c = sorted(cc_realize(c))`.
"""
function cc_fire(c::Symbol, h_current::ListState=ListState_empty)
    realized = cc_realize(c)

    # v1.6.B precondition: no overlap with existing tokens. Surface a
    # clean error rather than silently absorbing.
    overlap = intersect(realized, h_current)
    isempty(overlap) ||
        error("cc_fire: cc_realize($(c)) overlaps existing h_current at tokens $(overlap). " *
              "v1.6.B precondition is empty intersection (no pre-existing problems matching the CC). " *
              "v1.6.C will lift this to filter-to-missing semantics.")

    # Symdiff under no overlap = realized \ h_current = realized
    f_c = sort(collect(realized))
    h_next = union(h_current, realized)
    return f_c, h_next
end

"""
    initial_h_from_cc(cc::Symbol) -> ListState

The initial H-state h_0 after firing chief complaint `cc` from the
universal-empty root. Equivalent to `cc_fire(cc, ListState_empty)[2]`.

Convenience for the typical intake case where the patient is at h=∅
and CC firing is the first event.
"""
initial_h_from_cc(cc::Symbol) = cc_fire(cc, ListState_empty)[2]

# ============================================================
# Functoriality predicates  (called by validate_history_quotient in PR 3)
# ============================================================
#
# Θ should commute with composition of S-steps: for an S-trajectory
# (d, s_0) -> (d, s_1) -> (d, s_2), the Θ-image of the composite
# step (d, s_0) -> (d, s_2) should equal the H_quot composition of
# the per-step Θ-images.
#
# Under H_quot (state-quotient), the predicate is straightforward:
# both sides reduce to realize_symdiff(realize(d, s_0), realize(d, s_2)),
# which is automatically equal. Functoriality is built-in by
# construction of Θ via realize_symdiff. This is more a sanity check
# than a substantive validation, but worth having for protocol-author
# debugging.

"""
    theta_phenotype_functorial(d::Symbol, trajectory::Vector{Symbol}) -> Bool

Verify Θ-functoriality on a per-disease A-phenotype trajectory:
the composite Θ-image of the trajectory equals the per-step Θ-image
composition under H_quot's state-quotient.

By construction, Θ via realize_symdiff makes this hold for any
sequence (Θ commutes with composition trivially in H_quot since
both sides depend only on (start, end) realize-sets). The check is
a no-op in the well-typed case but lives here for symmetry with
PR 3's validate_history_quotient and to surface any future
inconsistency if the lifting changes.
"""
function theta_phenotype_functorial(d::Symbol, trajectory::Vector{Symbol})
    length(trajectory) ≥ 2 || return true  # trivially functorial

    # Composite: from start to end
    s_start = first(trajectory)
    s_end   = last(trajectory)
    composite_path = theta_phenotype(d, s_start, s_end)
    composite_dom_realize = realize(d, s_start)
    composite_cod = apply_path(composite_dom_realize, composite_path)

    # Step-by-step: walk through trajectory, accumulating H-state
    cur = composite_dom_realize
    for k in 2:length(trajectory)
        step = theta_phenotype(d, trajectory[k-1], trajectory[k])
        cur = apply_path(cur, step)
    end

    return cur == composite_cod
end
