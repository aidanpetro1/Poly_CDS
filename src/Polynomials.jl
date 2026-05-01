# ============================================================
# Per-disease observation polynomials
# ============================================================
#
# Used by the `Protocol` IR's `p_obs::Polynomial` field. Atomic
# observations combine via `coproduct` per disease and via Cartesian
# `*` for the joint.

"`y²` per atomic observation, one position labeled by the obs name."
const p_o1a = monomial(FinPolySet([:o1a]), Results)
const p_o1b = monomial(FinPolySet([:o1b]), Results)
const p_o2a = monomial(FinPolySet([:o2a]), Results)
const p_o2b = monomial(FinPolySet([:o2b]), Results)
const p_o2c = monomial(FinPolySet([:o2c]), Results)

"Chief-complaint polynomial."
const p_chief_complaint = monomial(FinPolySet([:chief_complaint]), CCResults)

"Intake-stage observation polynomial (alias for `p_chief_complaint`)."
const p_intake = p_chief_complaint

"D1 observation polynomial = coproduct of D1's atomic observations."
const p_D1_obs = coproduct(p_o1a, p_o1b)

"D2 observation polynomial = coproduct of D2's atomic observations."
const p_D2_obs = coproduct(p_o2a, p_o2b, p_o2c)

"Joint observation polynomial."
const p_obs = p_D1_obs * p_D2_obs
