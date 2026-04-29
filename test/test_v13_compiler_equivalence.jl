# RETIRED 2026-04-29.
#
# This file validated the v1.3 compiler's output against the hand-typed
# bicomodule structures during the Phase-2 equivalence check. After
# Phase-3 cutover (also 2026-04-29), the hand-typed structures are
# gone — `mbar_R_D1`, `mbar_L_D1`, etc. in Bicomodule.jl ARE just
# aliases to `D1_compiled.mbar_R`, `D1_compiled.mbar_L`. Comparing
# compiled to compiled is vacuous.
#
# The substantive checks moved into `test_v12_freep.jl` (sharp_R
# well-definedness, validate_bicomodule passing) and into the existing
# tests in `runtests.jl` (mbar_R values exercised through simulation
# trajectories).
#
# Safe to delete this file.
