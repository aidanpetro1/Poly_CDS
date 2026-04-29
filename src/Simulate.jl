# ============================================================
# Simulation driver  (v1.1, joint-bicomodule)
# ============================================================
#
# Drives the joint bicomodule `A_joint` (= A_D1_bicomodule ⊗ A_D2_bicomodule,
# the formal Bicomodule tensor product from Poly.jl) until both per-disease
# components reach a terminal phenotype.
#
# Mode is the only knob: `:sequential` or `:panel`. Aligned semantics — mode
# applies BOTH at the per-disease axis (which A-direction within a side:
# `:seq_*` vs `:panel_*`) AND at the joint axis (one side at a time vs both
# sides simultaneously). Per the v1.1 settled design, those two axes move
# together.
#
# Recommendations come from `A_joint.right_coaction.on_positions` — formally
# load-bearing, not hand-written. Routing uses the per-disease `mbar_L`
# dicts directly (the joint left routing IS the Cartesian product of these,
# but the per-disease lookup is in scope and equivalent).
#
# (The off-protocol alarm feature was dropped along with the off-protocol
# phenotype when we moved to sub-cofree with ragged `T_root`. v1.2 may
# re-introduce it.)

using Printf: @printf

# ============================================================
# Order/obs translation
# ============================================================
#
# `obs_from_order` lives in Vocabulary.jl (it's a vocabulary-level helper
# now that ProtocolCompile.jl also needs it).

"True if `o` is `:disease_D{k}_present` or `:disease_D{k}_absent` — a clinical-conclusion (exit) recommendation. Updated for v1.2's split terminal vocabulary; replaces v1.1's lumped `no_further_workup_*` check."
is_exit_order(o::Symbol) = startswith(String(o), "disease_")

# ============================================================
# Halt detection
# ============================================================

"True if a per-disease phenotype is terminal (only `:stay` direction available)."
function _is_per_disease_terminal(disease::Symbol, s::Symbol)
    if disease == :D1
        return s in (:a_D1, :a_D1_absent_via_o1a, :a_D1_absent_via_o1b)
    else  # :D2
        return s in (:a_D2, :a_D2_absent_via_o2a, :a_D2_absent_via_o2b)
    end
end

"True if both per-disease components are at terminals (joint halt condition)."
_is_joint_terminal(state::Tuple{Symbol,Symbol}) =
    _is_per_disease_terminal(:D1, state[1]) && _is_per_disease_terminal(:D2, state[2])

# ============================================================
# Joint recommendation (via A_joint.right_coaction)
# ============================================================

"""
    joint_recommendation(state::Tuple{Symbol,Symbol})
        -> Tuple{Union{Symbol,Nothing}, Union{Symbol,Nothing}}

Read the joint right_coaction's `(:stay, :stay)` recommendation at `state`.
Returns `(p_D1, p_D2)` where each component is the per-disease P-position
the protocol recommends emitting while staying in `state`, OR `nothing`
if that side's recommendation is a clinical-conclusion exit order
(`:disease_Dk_present` or `:disease_Dk_absent`, i.e. the side has reached
a terminal phenotype).

Formally load-bearing: the recommendation comes from the bicomodule's
right coaction, not from hand-written tables.
"""
function joint_recommendation(state::Tuple{Symbol,Symbol})
    _, joint_jbar = A_joint.right_coaction.on_positions.f(state)
    # v1.3: per-disease A-directions are path tuples; the joint stay-stay
    # direction is the pair of empty paths.
    p_D1, p_D2 = joint_jbar[((), ())]
    return (
        is_exit_order(p_D1) ? nothing : p_D1,
        is_exit_order(p_D2) ? nothing : p_D2,
    )
end

# ============================================================
# Per-disease single-step advance
# ============================================================

"""
    _advance_disease(disease, state, patient, mode)
        -> (next_state::Symbol, obs_issued::Vector{Symbol},
            results::Vector{Symbol})

Advance one disease one A-direction. Returns the post-state plus the obs
list and results list issued during the advance. Lengths:

  * 1   — sequential mode, OR panel mode with screen-`:neg`
          (no `:panel_neg_*` direction exists, so panel mode auto-degenerates
          to `:seq_neg`).
  * 2   — panel mode with screen-`:pos` (issues confirmation in same step,
          takes a `:panel_pos_*` direction).
  * 0/0 — `state` is already terminal; no advance happened.

The auto-degeneracies are handled silently here; the caller's `mode`
field in the trajectory still records the requested mode.
"""
function _advance_disease(disease::Symbol, state::Symbol, patient::Patient, mode::Symbol)
    if _is_per_disease_terminal(disease, state)
        return (state, Symbol[], Symbol[])
    end

    mbar_L = disease == :D1 ? mbar_L_D1 : mbar_L_D2
    mbar_R = disease == :D1 ? mbar_R_D1 : mbar_R_D2

    # Issue the screen — the empty-path (stay) slot of the right coaction.
    screen_order = mbar_R[state][()]
    screen_obs = obs_from_order(screen_order)
    screen_result = respond(patient, screen_obs)

    # Sequential, OR panel-degenerated-on-screen-neg → single length-1 direction.
    if mode == :sequential || screen_result == :neg
        next_state = mbar_L[state][(screen_result,)]
        return (next_state, [screen_obs], [screen_result])
    end

    # Panel + screen-positive → length-2 path direction.
    # Issue the confirmation order in the same step.
    intermediate_state = mbar_L[state][(screen_result,)]
    confirm_order = mbar_R[intermediate_state][()]
    confirm_obs = obs_from_order(confirm_order)
    confirm_result = respond(patient, confirm_obs)

    next_state = mbar_L[state][(screen_result, confirm_result)]
    return (next_state, [screen_obs, confirm_obs], [screen_result, confirm_result])
end

# ============================================================
# TrajectoryStep
# ============================================================

"""
    TrajectoryStep

One step of a joint-bicomodule trajectory. Six columns:

  * `step::Int` — index. Step 0 is the initial state with no transitions yet;
    step k>0 records the joint state AFTER transition k.
  * `joint_pos::Tuple{Symbol,Symbol}` — the joint phenotype at this step.
  * `joint_order::Tuple{Union{Symbol,Nothing}, Union{Symbol,Nothing}}` —
    the right_coaction's stay-stay (empty-path) recommendation at `joint_pos`.
    Each side is `nothing` when that side is terminal.
  * `obs_issued::Tuple{Vector{Symbol}, Vector{Symbol}}` — the obs lists
    issued during the transition that LED to this step. 0/1/2 obs per side.
    Empty at step 0.
  * `result::Tuple{Vector{Symbol}, Vector{Symbol}}` — corresponding patient
    responses, parallel shape with `obs_issued`.
  * `mode::Symbol` — the requested mode (`:sequential` or `:panel`).
    Recorded as-requested even when degeneracies were applied.

To recover the post-state of transition k, read step k's `joint_pos`.
The trajectory's last entry has `joint_pos` at the halt state.
"""
struct TrajectoryStep
    step::Int
    joint_pos::Tuple{Symbol, Symbol}
    joint_order::Tuple{Union{Symbol, Nothing}, Union{Symbol, Nothing}}
    obs_issued::Tuple{Vector{Symbol}, Vector{Symbol}}
    result::Tuple{Vector{Symbol}, Vector{Symbol}}
    mode::Symbol
end

# ============================================================
# Simulator
# ============================================================

"""
    simulate(patient::Patient;
             initial_state::Tuple{Symbol,Symbol}=(:a_D1_initial, :a_D2_initial),
             mode::Symbol=:sequential,
             max_steps::Int=10) -> Vector{TrajectoryStep}

Drive the joint bicomodule `A_joint` from `initial_state` until both
per-disease components are terminal (or `max_steps` is reached as a
safety cap).

`mode` controls the workup style — both per-disease and joint-level
together (aligned-mode semantics):

  * `:sequential` — per-disease takes single-test `:seq_*` directions;
    joint advances D1 first while non-terminal, then D2. Typical
    realisation: 3-4 trajectory steps for a non-degenerate patient.

  * `:panel` — per-disease takes length-2 `:panel_pos_*` directions when
    the screen is positive; joint advances both sides simultaneously per
    step. Typical realisation: 1-2 trajectory steps.

Auto-degeneracies handled silently:

  * Per-disease panel + screen-`:neg` → take `:seq_neg` (no `:panel_neg_*`
    direction exists in the carrier).
  * Joint panel + one side already terminal → that side stays, other
    side panels.

The trajectory's `mode` field records the *requested* mode regardless
of any degeneracies.
"""
function simulate(patient::Patient;
                  initial_state::Tuple{Symbol,Symbol}=(:a_D1_initial, :a_D2_initial),
                  mode::Symbol=:sequential,
                  max_steps::Int=10)
    mode in (:sequential, :panel) ||
        error("simulate: mode must be :sequential or :panel, got :$mode")

    state = initial_state
    trajectory = TrajectoryStep[
        TrajectoryStep(
            0, state, joint_recommendation(state),
            (Symbol[], Symbol[]), (Symbol[], Symbol[]), mode,
        ),
    ]

    for step in 1:max_steps
        if _is_joint_terminal(state)
            break
        end

        s_D1, s_D2 = state

        if mode == :sequential
            # Joint sequential: advance D1 if non-terminal, else D2.
            # (Joint-direction taken: ((d_D1,), ()) or ((), (d_D2,)).)
            if !_is_per_disease_terminal(:D1, s_D1)
                next_D1, obs_D1, res_D1 = _advance_disease(:D1, s_D1, patient, :sequential)
                next_state = (next_D1, s_D2)
                obs_issued = (obs_D1, Symbol[])
                results = (res_D1, Symbol[])
            else
                next_D2, obs_D2, res_D2 = _advance_disease(:D2, s_D2, patient, :sequential)
                next_state = (s_D1, next_D2)
                obs_issued = (Symbol[], obs_D2)
                results = (Symbol[], res_D2)
            end
        else  # mode == :panel
            # Joint panel: advance both sides (auto-degenerates per side).
            # (Joint-direction taken: (d_D1, d_D2) where each may be a
            # length-1 :seq_* or length-2 :panel_*; if a side was already
            # terminal, _advance_disease returns ([], []) and that
            # component is :stay.)
            next_D1, obs_D1, res_D1 = _advance_disease(:D1, s_D1, patient, :panel)
            next_D2, obs_D2, res_D2 = _advance_disease(:D2, s_D2, patient, :panel)
            next_state = (next_D1, next_D2)
            obs_issued = (obs_D1, obs_D2)
            results = (res_D1, res_D2)
        end

        state = next_state
        push!(trajectory, TrajectoryStep(
            step, state, joint_recommendation(state),
            obs_issued, results, mode,
        ))
    end

    return trajectory
end

# ============================================================
# Trajectory pretty-printing
# ============================================================

_or_dash(x::Nothing) = "—"
_or_dash(x::Symbol)  = string(x)
_listfmt(xs::Vector{Symbol}) = isempty(xs) ? "—" : join(xs, "+")

"Per-side A-direction label derived from the result-list at that side. v1.4 enrichment — uses pretty_label over the path tuple."
_dir_label(results::Vector{Symbol}) = pretty_label(Tuple(results))

"""
    print_trajectory(trajectory; io=stdout)

Render a trajectory as a readable table. v1.4: seven columns — adds a
`dir (D1│D2)` column showing the per-side A-direction labels
(`:stay`, `:seq_pos`, `:panel_pos_pos`, …) derived via `pretty_label`
from the results path tuple at each step.

`nothing` entries shown as `—`; empty obs/result lists shown as `—`.
"""
function print_trajectory(trajectory::Vector{TrajectoryStep}; io=stdout)
    println(io, "step │ joint_pos                                          │ joint_order                          │ dir (D1│D2)                  │ obs (D1│D2)            │ result (D1│D2)         │ mode")
    println(io, "─────┼────────────────────────────────────────────────────┼──────────────────────────────────────┼──────────────────────────────┼────────────────────────┼────────────────────────┼────────────")
    for s in trajectory
        pos = string(s.joint_pos)
        ord = "(" * _or_dash(s.joint_order[1]) * ", " * _or_dash(s.joint_order[2]) * ")"
        dir = string(_dir_label(s.result[1])) * " │ " * string(_dir_label(s.result[2]))
        obs = _listfmt(s.obs_issued[1]) * " │ " * _listfmt(s.obs_issued[2])
        res = _listfmt(s.result[1]) * " │ " * _listfmt(s.result[2])
        @printf(io, " %2d  │ %-50s │ %-36s │ %-28s │ %-22s │ %-22s │ %s\n",
                s.step, pos, ord, dir, obs, res, s.mode)
    end
end
