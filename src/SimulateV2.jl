# ============================================================
# SimulateV2 — V2 master-D simulator
# ============================================================
#
# Drives `D_v2_toy` via Σ_obs_v2 events. The patient's `:neg`/`:pos`
# responses are translated to Σ events; D's `f` advances the joint
# state; the trajectory halts when both per-disease components reach
# terminal phenotypes.

using Printf: @printf

# ============================================================
# Helpers
# ============================================================

"Translate (order, result) to a Σ_obs_v2 event."
_result_to_sigma_v2(order::Symbol, result::Symbol) =
    Symbol("result_$(obs_from_order(order))_$(result)")

"True if the per-disease phenotype `s` is terminal for disease `d`."
function _is_per_disease_terminal_v2(d::Symbol, s::Symbol)
    if d === :D1
        return s in (:a_D1, :a_D1_absent)
    elseif d === :D2
        return s in (:a_D2, :a_D2_absent)
    else
        error("_is_per_disease_terminal_v2: unknown disease $(d)")
    end
end

"True if both per-disease components are terminal."
_is_joint_terminal_v2(p::Tuple{Symbol, Symbol}) =
    _is_per_disease_terminal_v2(:D1, p[1]) && _is_per_disease_terminal_v2(:D2, p[2])

# ============================================================
# TrajectoryStepV2
# ============================================================

"""
    TrajectoryStepV2

One step of a `Differential`-driven trajectory.

  * `step`         — index (0 = initial, no transitions yet)
  * `p`            — D-position at this step
  * `workup_state` — joint workup-state pointer at p
  * `obs_issued`   — observations issued during the transition into this step
  * `results`      — patient responses (`:neg`/`:pos`) corresponding to `obs_issued`
  * `sigma_events` — Σ_obs_v2 events fired during the transition
  * `mode`         — `:sequential` or `:panel`
"""
struct TrajectoryStepV2
    step::Int
    p::Tuple{Symbol, Symbol}
    workup_state::Tuple{Symbol, Symbol}
    obs_issued::Vector{Symbol}
    results::Vector{Symbol}
    sigma_events::Vector{Symbol}
    mode::Symbol
end

# ============================================================
# Per-disease advance
# ============================================================

# Advance disease `d` by one screen-step (and immediate confirm in
# panel mode if the screen returns :pos and the new state isn't
# terminal). Returns (next_state, obs, results, σ events).
function _advance_v2_per_disease(d::Symbol,
                                  state::Tuple{Symbol, Symbol},
                                  patient::Patient,
                                  mode::Symbol)
    s_d = d === :D1 ? state[1] : state[2]
    if _is_per_disease_terminal_v2(d, s_d)
        return (state, Symbol[], Symbol[], Symbol[])
    end

    obs_issued = Symbol[]
    results = Symbol[]
    sigma_events = Symbol[]
    cur_state = state

    # Screen step
    ws_d = d === :D1 ? toy_v2_workup_state(cur_state)[1] : toy_v2_workup_state(cur_state)[2]
    screen_obs = obs_from_order(ws_d)
    screen_result = respond(patient, screen_obs)
    σ = _result_to_sigma_v2(ws_d, screen_result)
    cur_state = f_at(D_v2_toy, cur_state, σ)
    push!(obs_issued, screen_obs)
    push!(results, screen_result)
    push!(sigma_events, σ)

    # Panel + screen-positive: fire confirm immediately
    new_s_d = d === :D1 ? cur_state[1] : cur_state[2]
    if mode === :panel && screen_result === :pos &&
       !_is_per_disease_terminal_v2(d, new_s_d)
        ws_d_after = d === :D1 ? toy_v2_workup_state(cur_state)[1] : toy_v2_workup_state(cur_state)[2]
        confirm_obs = obs_from_order(ws_d_after)
        confirm_result = respond(patient, confirm_obs)
        σ_confirm = _result_to_sigma_v2(ws_d_after, confirm_result)
        cur_state = f_at(D_v2_toy, cur_state, σ_confirm)
        push!(obs_issued, confirm_obs)
        push!(results, confirm_result)
        push!(sigma_events, σ_confirm)
    end

    return (cur_state, obs_issued, results, sigma_events)
end

# ============================================================
# Simulator
# ============================================================

"""
    simulate_v2(patient::Patient;
                initial_state=(:a_D1_initial, :a_D2_initial),
                mode=:sequential,
                max_steps=10) -> Vector{TrajectoryStepV2}

Drive `D_v2_toy` from `initial_state` to a joint terminal (or until
`max_steps` is reached).

  * `:sequential` — one disease advances per step (D1 first while
                    non-terminal, then D2)
  * `:panel`      — both non-terminal diseases advance in the same step;
                    per-disease panel fires confirm immediately on
                    screen-positive (2 σ in one step)
"""
function simulate_v2(patient::Patient;
                     initial_state::Tuple{Symbol, Symbol}=(:a_D1_initial, :a_D2_initial),
                     mode::Symbol=:sequential,
                     max_steps::Int=10)
    mode in (:sequential, :panel) ||
        error("simulate_v2: mode must be :sequential or :panel, got :$mode")

    state = initial_state
    trajectory = TrajectoryStepV2[
        TrajectoryStepV2(
            0, state, toy_v2_workup_state(state),
            Symbol[], Symbol[], Symbol[], mode,
        ),
    ]

    for step in 1:max_steps
        _is_joint_terminal_v2(state) && break

        s_D1, s_D2 = state
        obs_issued = Symbol[]
        results = Symbol[]
        sigma_events = Symbol[]

        if mode === :sequential
            if !_is_per_disease_terminal_v2(:D1, s_D1)
                state, o, r, σs = _advance_v2_per_disease(:D1, state, patient, :sequential)
            else
                state, o, r, σs = _advance_v2_per_disease(:D2, state, patient, :sequential)
            end
            append!(obs_issued, o); append!(results, r); append!(sigma_events, σs)
        else  # :panel
            if !_is_per_disease_terminal_v2(:D1, s_D1)
                state, o, r, σs = _advance_v2_per_disease(:D1, state, patient, :panel)
                append!(obs_issued, o); append!(results, r); append!(sigma_events, σs)
            end
            s_D1_now, s_D2_now = state
            if !_is_per_disease_terminal_v2(:D2, s_D2_now)
                state, o, r, σs = _advance_v2_per_disease(:D2, state, patient, :panel)
                append!(obs_issued, o); append!(results, r); append!(sigma_events, σs)
            end
        end

        push!(trajectory, TrajectoryStepV2(
            step, state, toy_v2_workup_state(state),
            obs_issued, results, sigma_events, mode,
        ))
    end

    return trajectory
end

# ============================================================
# Trajectory pretty-printing
# ============================================================

_fmtlist_v2(xs::Vector{Symbol}) = isempty(xs) ? "—" : join(string.(xs), ", ")

"""
    print_trajectory_v2(traj; io=stdout)

Render a V2 trajectory as a readable table.
"""
function print_trajectory_v2(traj::Vector{TrajectoryStepV2}; io=stdout)
    println(io, "step │ p                                     │ workup_state                      │ σ events                                       │ mode")
    println(io, "─────┼───────────────────────────────────────┼───────────────────────────────────┼────────────────────────────────────────────────┼────────────")
    for s in traj
        @printf(io, " %2d  │ %-37s │ %-33s │ %-46s │ %s\n",
                s.step, string(s.p), string(s.workup_state),
                _fmtlist_v2(s.sigma_events), s.mode)
    end
end
