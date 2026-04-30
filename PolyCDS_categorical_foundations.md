# PolyCDS — Category-Theoretic Foundations

*Ground-truth reference document. Captures the category theory underlying PolyCDS through v1.6.B (architecture settled 2026-04-30; not yet implemented).*

---

## 0. Preamble

This document records, in technical and clinically-translated detail, the category-theoretic structure underlying PolyCDS. It covers (i) the underlying polynomial-functor machinery, (ii) the v1.x disease-level bicomodule architecture (already implemented through v1.5), (iii) the foundational insights connecting bicomodule structure to clinical guideline coherence, (iv) the v1.6.B patient-history fibration (architecture settled, not yet coded), (v) the design rationale behind load-bearing v1.x choices, (vi) the authoring surface (ProtocolDoc), and (vii) implementation status and future categorical wiring directions.

Each abstract construction is accompanied by a clinical interpretation so that the structure can be checked against clinical reality. Notation is consistent throughout: comonoids/categories use script font ($\mathcal{S}, \mathcal{P}, \mathcal{H}, \mathcal{Q}$), polynomials/bicomodules use capitals ($A, P, S$), and Greek letters denote structure maps ($\lambda, \rho, \delta, \varepsilon$).

**Conventions.** $\mathbf{Poly}$ denotes the category of polynomial functors $\mathbf{Set} \to \mathbf{Set}$. The two monoidal structures used are $\triangleleft$ (composition / substitution) and $\otimes$ (Dirichlet product). $y$ denotes the identity polynomial (one position, one direction). For a polynomial $p$, we write $p(1)$ for its position-set and $p[i]$ for its direction-set at position $i$, so $p \cong \sum_{i \in p(1)} y^{p[i]}$.

---

## Part I — Underlying Machinery

### 1. Polynomial functors

A polynomial functor $p \in \mathbf{Poly}$ is a coproduct of representables, written $p = \sum_{i \in p(1)} y^{p[i]}$. A morphism $f: p \to q$ in $\mathbf{Poly}$ consists of:

- a forward map on positions $f_1: p(1) \to q(1)$, and
- a backward map on directions $f^\sharp_i: q[f_1(i)] \to p[i]$ for each $i \in p(1)$.

The double-direction structure means $\mathbf{Poly}$-morphisms model "interaction patterns": a position is a state-or-question, a direction is a response-or-answer.

**Sections.** A *section* of $p$ is a morphism $p \to y$ in $\mathbf{Poly}$. Concretely it picks one direction $d_i \in p[i]$ at each position $i \in p(1)$ — equivalently, an element of $\prod_{i \in p(1)} p[i]$.

### 2. Composition tensor and comonoids

The composition tensor $\triangleleft$ is defined by

$$(p \triangleleft q)(X) = p(q(X)).$$

It is associative but not symmetric. The unit is $y$.

**Comonoids in $(\mathbf{Poly}, \triangleleft)$ are small categories.** Specifically, a comonoid $\mathcal{C} = (C, \varepsilon, \delta)$ with $\varepsilon: C \to y$ and $\delta: C \to C \triangleleft C$ is the same data as a small category whose object-set is $C(1)$, whose morphism-set out of object $i$ is $C[i]$, with $\varepsilon$ picking the identity at each object and $\delta$ encoding morphism factorization (associativity = coassociativity of $\delta$; identity laws = counit laws of $\varepsilon$).

**Comonoid morphisms.** A morphism of comonoids in $(\mathbf{Poly}, \triangleleft)$ is exactly a functor between the corresponding small categories.

### 3. Bicomodules

Given comonoids $\mathcal{S}$ and $\mathcal{P}$ in $(\mathbf{Poly}, \triangleleft)$ — i.e., categories — an $(\mathcal{S}, \mathcal{P})$-bicomodule is a polynomial $A$ equipped with:

- a left $\mathcal{S}$-coaction $\lambda: A \to S \triangleleft A$, and
- a right $\mathcal{P}$-coaction $\rho: A \to A \triangleleft P$,

satisfying counit laws (one application of $\varepsilon$ recovers $A$) and coassociativity laws (composing coactions on the same side respects $\delta$), plus the **bicomodule compatibility axiom**:

$$(\mathrm{id}_S \triangleleft \rho) \circ \lambda \;=\; (\lambda \triangleleft \mathrm{id}_P) \circ \rho.$$

This is the equation that says "stepping left through $\mathcal{S}$, then right through $\mathcal{P}$" agrees with "stepping right through $\mathcal{P}$, then left through $\mathcal{S}$." It is the load-bearing axiom — see §10 for its clinical content.

Equivalently, a bicomodule $A: \mathcal{S} \nrightarrow \mathcal{P}$ is a parametrized family of "interaction patterns" between objects of $\mathcal{S}$ and objects of $\mathcal{P}$, in a way that respects the categorical structure of both.

### 4. Cofree comonoids and sub-cofree

For a polynomial $Q$, the cofree comonoid $\mathrm{Cof}(Q)$ in $(\mathbf{Poly}, \triangleleft)$ is the universal comonoid mapping into $Q$. Concretely, $\mathrm{Cof}(Q)$ is the polynomial whose positions are *trees of $Q$-positions* (each branching node labeled by a $Q$-position, with branches indexed by directions of that position). $\mathrm{Cof}(Q)$ is a category whose objects are $Q$-trees and whose morphisms are sub-tree relations.

**Sub-cofree.** A *sub-cofree* comonoid on $Q$ is a sub-comonoid of $\mathrm{Cof}(Q)$ — a category whose objects are restricted to a chosen subset of $Q$-trees, closed under the comonoid structure. PolyCDS uses sub-cofree constructions to derive comonoid structure from authored polynomial data, trading the universal property of full cofree for combinatorial tractability and for the ability to drop clinically-irrelevant trees.

---

## Part II — Disease-Level Bicomodules (v1.x, already implemented)

### 5. The patient-state comonoid $\mathcal{S}_d$ (per disease $d$)

For each disease $d$ in a protocol's disease-vocabulary, the protocol declares a comonoid $\mathcal{S}_d$ in $(\mathbf{Poly}, \triangleleft)$. Concretely:

- $S_d(1)$ — patient-states for disease $d$ (currently 5 per disease in v1.x).
- $S_d[s]$ — observation-questions available at patient-state $s$.
- $\delta_{\mathcal{S}_d}: S_d \to S_d \triangleleft S_d$ — sequencing of observations.
- $\varepsilon_{\mathcal{S}_d}: S_d \to y$ — the trivial "no observation" at each state.

**Clinical interpretation.** $\mathcal{S}_d$ is the disease-trajectory state-machine. Objects are states the patient can be in within the disease's natural course; morphisms are sequences of clinical observations that move the patient between states (or that the protocol cares about while in a state).

$\mathcal{S}_d$ is constructed *sub-cofree* on a polynomial of authored observation-events: the protocol-author lists which observation-events matter for $d$, and $\mathcal{S}_d$ is derived as the sub-comonoid containing just the trees of clinically-realizable observation sequences.

### 6. The protocol algebra $\mathcal{P}_d$ (per disease)

Likewise the protocol declares a comonoid $\mathcal{P}_d$:

- $P_d(1)$ — recommendation-slots / orders available for disease $d$.
- $P_d[p]$ — branches/responses at recommendation-slot $p$.

In v1.2 $\mathcal{P}_d$ was made *free* on the protocol's authored order-graph, so composing recommendations is just sequencing them along the free monoidal structure. Length-≥2 composites are kept distinct (collapsing them broke `sharp_R` associativity in earlier "thin-P" prototypes — see §16).

**Clinical interpretation.** $\mathcal{P}_d$ is the recommendation algebra — the protocol-actions the system can recommend. Each $P_d$-position is a candidate intervention; directions branch on patient response or on conditional sub-recommendations. **The orders ARE the protocol** — the sequence of recommended actions is the substance of what a CDS encodes.

### 7. The assessment bicomodule $A_d$ (computable phenotypes)

Per disease, the assessment is an $(\mathcal{S}_d, \mathcal{P}_d)$-bicomodule:

$$A_d : \mathcal{S}_d \nrightarrow \mathcal{P}_d.$$

- $A_d(1)$ — **computable phenotypes** for disease $d$ (see §11 for what this term means precisely).
- $A_d[a]$ — outgoing structure of phenotype $a$ (consumed by the bicomodule's coactions; technically *path tuples* through the cofree subtree — see §12).

The 5 phenotypes per disease in v1.x are derived sub-cofree on the disease's protocol structure — they are not arbitrary choices but the minimal set forced by the bicomodule's coassociativity rigidity to capture clinically-distinct evidence-states.

For the canonical v1.x example (D1, screen-then-confirm two-step protocol), the 5 phenotypes are:

| Phenotype | Clinical meaning |
|---|---|
| `a_D1_initial` | pre-workup, no D1-relevant data yet |
| `a_D1_pending` | positive screen, awaiting confirmation |
| `a_D1` | confirmed (positive screen + positive confirmation) |
| `a_D1_absent_via_o1a` | ruled out at screen (single negative test) |
| `a_D1_absent_via_o1b` | ruled out at confirmation (false-positive screen — discordant results) |

Each is a distinct clinical state. `a_D1_absent_via_o1b` in particular is *not the same* as `a_D1_absent_via_o1a`, because future visits may handle them differently (re-screening one but not the other). Cofree-S forces the structural distinction; the distinction matches clinical reality.

### 8. The two coactions: $\lambda$ and $\rho$

The bicomodule structure on $A_d$ consists of two structure maps with cleanly distinct semantics:

**Left $\mathcal{S}_d$-coaction $\lambda: A_d \to S_d \triangleleft A_d$.** Consumes observations as they arrive. For a phenotype $a$, $\lambda(a) = (s, k_s)$ where $s \in S_d(1)$ is the observation-type the phenotype is currently sensitive to, and $k_s: S_d[s] \to A_d(1)$ is a continuation function: given any answer $o \in S_d[s]$, $k_s(o)$ is the new phenotype after consuming that observation. **$\lambda$ does not "ask" questions; it processes information that arrives.**

**Right $\mathcal{P}_d$-coaction $\rho: A_d \to A_d \triangleleft P_d$.** Emits recommendations. For a phenotype $a$, $\rho(a) = (a', k')$ specifies a new phenotype $a'$ together with a continuation $k': A_d[a'] \to P_d(1)$ that, for each branch the phenotype anticipates, picks a $\mathcal{P}_d$-recommendation. **$\rho$ recommends actions, including diagnostic-workup recommendations whose purpose is to acquire observations that $\lambda$ will later consume.**

The clean separation is crucial: information-acquisition is on the $\rho$-side (provider acts), observation-consumption is on the $\lambda$-side (information arrives).

### 9. The S/P/A asymmetry — coalgebraic, algebraic, bridge

A clinical guideline (Protocol IR) shears into two structurally dual parts plus a bridge. This asymmetry is not aesthetic — it tracks what each side *does*.

**$\mathcal{S}$ is the coalgebraic structure of the guideline.** Built sub-cofree on a polynomial of observations $p_{\mathrm{obs}}$. *Coalgebraic* because the patient-response side **branches** — at every state, asking an observation produces one of several next states, indexed by the result. The cofree comonoid is the universal coalgebra-tracker; sub-cofree is its restriction to the protocol-named subtrees. $\mathcal{S}$-positions are *behavior trees* ("decision-tree-from-here"); $\mathcal{S}$-directions are *paths of (question, answer) pairs* the protocol has authored a response to.

**$\mathcal{P}$ is the algebraic structure of the guideline.** Built free on the order-graph. *Algebraic* because the recommendation side **composes** — orders chain via authored "after this, that" edges, and the relevant operation is path-concatenation, not branching. The free category on the directed order-graph is the universal path-composer. $\mathcal{P}$-positions are *orders/conclusions*; $\mathcal{P}$-directions are *paths through the order graph* (legal recommendation-sequences).

**$A$ is the bridge, hand-crafted.** The bicomodule $A: \mathcal{S} \nrightarrow \mathcal{P}$ with phenotypes-as-positions. $\lambda$ routes a heard observation to a phenotype transition; $\rho$ emits the spoken recommendation at each phenotype. The bicomodule axiom (next section) is the equation that says listener and speaker agree.

**The free/cofree asymmetry tracks what each side does:**

- Patient responses are coalgebraic data — futures unfold by branching, so the carrier has to be the branching structure itself (trees). Cofree closure → $\mathcal{S}$-positions are entire decision-trees-from-here.
- Order chains are algebraic data — sequences compose, so the carrier is flat (just orders) and the morphisms are paths. Free closure → $\mathcal{P}$-morphisms are every legal sequence.

**The protocol is $(\mathcal{S}, \mathcal{P}, A)$ together, plus the bicomodule structure.** Neither $\mathcal{S}$ nor $\mathcal{P}$ alone *is* the protocol; the IR carries no information loss, while $\mathcal{S}, \mathcal{P}, A$ are three lossy projections that recover everything together.

### 10. Bicomodule axioms = guideline coherence (KEY INSIGHT)

The bicomodule compatibility axiom

$$(\mathrm{id}_S \triangleleft \rho) \circ \lambda \;=\; (\lambda \triangleleft \mathrm{id}_P) \circ \rho$$

requires that "stepping left through $\mathcal{S}$, then right through $\mathcal{P}$" agrees with "stepping right through $\mathcal{P}$, then left through $\mathcal{S}$." With $\mathcal{S}$ as raw observations and $\mathcal{P}$ as the planned-pathway, this axiom says:

> **The result-driven interpretation update must be consistent with the planned order sequence.**

That is: if a result routes you to a new phenotype, the order recommended at that new phenotype must be consistent with what $\mathcal{P}$'s protocol says comes next after the previously-recommended order. The bicomodule literally formalizes "the guideline must be internally coherent."

**Why this matters.** Existing CDS authoring formats (CQL, Arden, GLIF, ProtocolDoc-when-we-build-it) have no formal handle on internal coherence. They can let an author write a guideline that says "if A then B" and "if A then C" simultaneously without flagging the contradiction. **Bicomodule compatibility validation gives this for free** — `validate_bicomodule_detailed` returning false means the guideline is incoherent in a precise, debuggable sense, with `minimal_failing_triple` (Poly.jl v0.2.0) surfacing the failing case.

**Connection to chief complaint.** The $\mathcal{S}$-path × $\mathcal{P}$-morphism compatibility relation is what makes chief complaint work formally. A CC is a specific $\mathcal{S}$-event from the intake phenotype that determines an initial differential (the next phenotype) AND the initial workup order (the first $\mathcal{P}$-pathway step). The bicomodule compatibility axiom forces these to align — the order recommended at the post-CC phenotype must be consistent with what $\mathcal{P}$'s protocol says starts the relevant disease's workup. CC routing is just the first instance of the general coherence requirement, applied at the initial state.

**Vocabulary refinement as coherence-driven design.** The v1.2 unlock — splitting `:no_further_workup_Dk` into `:disease_Dk_present` / `:disease_Dk_absent` — was forced by the bicomodule axiom: without it, the codomains of competing length-2 $\mathcal{P}$-morphisms collapsed and `sharp_R` became ambiguous. **The bicomodule axiom forces clinically-meaningful naming of terminal orders.** The formalism makes the right thing the natural thing.

### 11. Computable phenotypes (what $A$.positions actually are)

When cofree-$\mathcal{S}$ forces $A$ to expand from 4 to 5 per-disease positions (path-tracking the terminal states by *how* they were reached), what we'd been calling "interpretations" reveal themselves as something more specific.

**$A$.positions are computable phenotypes** — distinct combinations of observable evidence that define clinically-recognizable patient states. This terminology is not informal: it connects PolyCDS to the *computable phenotyping* literature (eMERGE Network, PheKB, OHDSI's CohortDefinition), all of which formalize phenotypes as combinations of observable data.

**Implications:**

1. **Cofree-S does real informatics work.** It's not just imposing math rigidity — it's forcing $A$ to capture phenotypes that clinical practice already distinguishes. If two paths through observations yield clinically-different next-action recommendations, the math forces them to be different phenotypes.

2. **$A$ for a disease is a phenotype lattice** — phenotypes partially ordered by evidence accumulation. The lattice structure (when present) is the algebraic shadow of "more evidence ⇒ more committed phenotype." See §28 for the lattice-as-coherence discussion.

3. **Per-disease 5-phenotype set is forced**, not chosen. Sub-cofree-$\mathcal{S}$ on a 2-step screen-then-confirm protocol yields exactly the 5 phenotypes listed in §7 — no fewer (fewer would violate associativity), no more (more would not correspond to any reachable evidence-state).

**Phenotype direction-shapes (D1, sub-cofree on screen-then-confirm):**

| Phenotype | Directions |
|---|---|
| `a_D1_initial` | 5 (1 stay + 2 sequential + 2 panel) |
| `a_D1_pending` | 3 (1 stay + 2 sequential confirmation results) |
| `a_D1` | 1 (stay) |
| `a_D1_absent_via_o1a` | 1 (stay) |
| `a_D1_absent_via_o1b` | 1 (stay) |

The 5 directions at `a_D1_initial` give a key clinical insight (next subsection).

**Dual-mode operation as a free byproduct.** The cofree depth-2 structure naturally gives the bicomodule both clinical operating modes as different morphisms in $\mathcal{S}$:

- *Stepwise diagnostic workup* — clinician orders one test, waits for result, then orders next. Single-step $\mathcal{S}$-paths.
- *Comprehensive intake panel* — clinician orders both tests at intake, gets both results back. Length-2 $\mathcal{S}$-paths.

**Same guideline, two operating modes.** The simulation driver chooses which to issue at each step. Mode is a *simulator-driver policy*, not a structural distinction at the bicomodule layer — both modes are valid trajectories through the same joint bicomodule. We didn't have to design this in; it's free from the cofree depth-2 structure.

### 12. Paths-as-directions (the lens-decomposition payoff)

The bicomodule lens decomposition $\lambda: A \to S \triangleleft A$ implies $A.\mathrm{directions}(x) \cong S.\mathrm{directions}(i_S(x))$ — $A$-directions at phenotype $x$ ARE paths through the cofree subtree at $x$'s associated $\mathcal{S}$-position.

This was not exploited in v1.0–v1.2 (where directions were carried as *symbolic* names like `:seq_pos`, `:panel_pos_neg`, with parallel `dir_to_path` / `path_to_dir` translation tables). v1.3 cut over to **paths-as-directions natively**: $A$.directions(x) are *path tuples* (e.g. `()`, `(:neg,)`, `(:pos, :pos)`), `mbar_L`/`mbar_R` keyed by paths, $\mathrm{sharp}_L$ becomes literal path concatenation $(b \dots, a \dots)$, and translation tables are eliminated.

**The insight.** Direction labels are *nicknames*; paths are the data. Maintaining a parallel symbolic encoding was redundant — the math says paths are already the right thing.

A `pretty_label(path)` overlay maps paths to mnemonic v1.2-style symbols (`()` → `:stay`, `(:r,)` → `:seq_r`, `(:r1, :r2)` → `:panel_r1_r2`) for human-facing edges (trajectory printer, Render diagrams), but is not load-bearing internally. This is the layered way to expose direction-naming: structure underneath, names on top.

### 13. The joint assessment $A_{\mathrm{joint}}$ (v1.1 construction)

For a multi-disease protocol, the per-disease bicomodules $A_d$ are combined into a *joint* assessment bicomodule via a formal tensor construction over diseases, supporting two simulator modes:

- **Sequential mode** ($A^{\mathrm{seq}}_{\mathrm{joint}}$): diseases worked up in sequence; the simulator picks joint directions where exactly one side is `:stay` (advance one disease at a time).
- **Panel mode** ($A^{\mathrm{panel}}_{\mathrm{joint}}$): diseases evaluated in parallel; the simulator picks joint directions where neither side is `:stay` (both advance simultaneously).

**Mode is a simulator-driver policy.** Both modes are valid trajectories through the *same* joint bicomodule — there is no structural distinction between them at the categorical level. The same guideline supports both clinical operating modes.

In both modes:

- $A_{\mathrm{joint}}(1)$ contains positions corresponding to multi-disease phenotype-states (with the disease-committed phenotypes $A_d$ as the fine end). 5 × 5 = 25 joint phenotypes for 2-disease v1.x.
- The bicomodule structure makes $A_{\mathrm{joint}}$ a $\left( \prod_d \mathcal{S}_d, \prod_d \mathcal{P}_d \right)$-bicomodule.
- v1.1 implementation: shipped, 31/31 tests green, ⊗-construction documented.

The maximally-permissive $A_{\mathrm{joint}}$-state is the one with every disease at its initial state — every disease still in play, no commitment yet.

---

## Part III — v1.x Design Rationale (load-bearing choices)

These choices look like simplifications but are *load-bearing*. Don't undo them without re-running the trade-off. Each is paired with the failure mode that motivated the choice.

### 14. Memory lives in $A$, not in $\mathcal{S}$

The bicomodule's left coaction must be associative: $(s_1 \triangleleft s_2) \cdot a = s_1 \cdot (s_2 \cdot a)$. This forces "the next phenotype depends only on the current phenotype, not on history." If we tried to put memory into $\mathcal{S}$ — having $\mathcal{S}$ track history-of-observations — coassociativity of $\delta_{\mathcal{S}}$ would fail in non-trivial ways.

**Solution:** memory lives in $A$, via intermediate `*_pending` phenotypes that encode "we've heard this, awaiting that." The 5 (rather than 4) per-disease phenotypes in v1.x exist precisely because we need to retain enough history *as a phenotype* to make the next routing decision. Cofree-$\mathcal{S}$ does *not* solve the memory problem — adding intermediate phenotypes is the right answer.

**Don't undo:** if you're tempted to collapse the 5 phenotypes to 4, you'll re-discover that 4 can't route correctly under the bicomodule axioms.

### 15. Sub-cofree $\mathcal{S}$ vs. full cofree, with off-protocol-alarm trade-off

Full cofree on $p_{\mathrm{obs}}$ at depth 2 has hundreds of tree-positions; $\mathrm{subst}(\mathrm{Cof}(p_{\mathrm{obs}}), A)$ blows up combinatorially. The practical v1 path is **sub-cofree** (a sub-comonoid of cofree restricted to the trees the protocol actually uses).

**Trade-off:** lose the universal property of full cofree; gain combinatorial tractability and the ability to drop clinically-irrelevant trees.

**Off-protocol-alarm trade-off (v1.1 cost).** When using full cofree depth-2 (or sub-cofree with depth-1 `T_neg`), the off-protocol terminals served as a built-in alarm for *saturating the clinical course with no new information* — detecting when a clinician orders a redundant test that doesn't advance the workup. This maps to a known clinical-informatics concern: low-value care, redundant testing, alarm fatigue from over-ordering.

**Status (v1.1):** dropped via ragged-`T_root` sub-cofree (`:neg`-child = depth-0 leaf instead of depth-1 subtree), which drops `T_neg` and thus the off-protocol terminal. Recovered 1 phenotype per disease (5 instead of 6) and made the architecture cleaner. The alarm feature was the cost.

**v1.2+ direction:** if explicit redundant-test detection becomes a feature priority, re-introduce by either (a) keeping `T_neg` as depth-1 (returning to 6 phenotypes per disease), or (b) decorating the simulation driver with an "off-bicomodule" event detector that watches for observation requests not in the bicomodule's recommended order set. (b) is cleaner because it decouples the alarm from the categorical structure.

### 16. The codomain-matching rule for `sharp_R`

Given an $A$-direction $a$ at phenotype $x$ and a $\mathcal{P}$-direction $e$ (a path tuple of length $m$), `sharp_R` extends $a$'s $\mathcal{S}$-path by $m$ more steps to the unique extension whose terminal phenotype's `mbar_R[:stay]` equals $e[\mathrm{end}]$ (= cod of $e$). Identity $\mathcal{P}$-morphisms ($e = ()$) return $a$ unchanged (Law 2). Uniqueness comes from the protocol vocabulary, not from tree-design tricks.

**Why kept distinct:** earlier "thin-$\mathcal{P}$" attempts collapsed length-≥2 composites (e.g. lumping `o1a → o1b → present` and `o1a → o1b → absent` into a single morphism with shared codomain `:no_further_workup`) and broke `sharp_R` associativity. Length-2 composites are kept distinct in the free $\mathcal{P}$ category to preserve the codomain structure that `sharp_R` depends on.

**`sharp_R` is validation-time, not runtime.** The simulator only consults `mbar_R[:stay]` (recommendations) and `mbar_L` (routing). `sharp_R`'s job is to make the bicomodule axiom well-defined; it is only called inside `validate_bicomodule_detailed`. This decouples the determinism of `sharp_R` from any future stochastic / FHIR-substrate patient model.

### 17. Joint sub-comonoid via lazy substitution

For v1.x's 2-disease joint, the obvious construction $\mathrm{Cof}(p_{\mathrm{obs}}^{D_1}) \otimes \mathrm{Cof}(p_{\mathrm{obs}}^{D_2})$ has positions with up to $5 \times 5 = 25$ directions; eager $\mathrm{subst}(\mathrm{carrier}, \mathrm{carrier})$ for the duplicator would enumerate $\Sigma_i 16^{|\mathrm{carrier}[i]|} \approx 16^{25} \approx 10^{30}$ entries. Untenable.

**Fix (Poly.jl v0.2.0):** widen `Lens.cod` from `Polynomial` to `AbstractPolynomial` (the supertype including both eager `Polynomial` and lazy `LazySubst`); swap the three eager `subst(...)` calls in `parallel(::Bicomodule, ::Bicomodule)` and `_comonoid_carrier_tensor` to `subst_lazy(...)`. Type-checking via `is_subst_of` is shape-only and doesn't enumerate.

**Result:** $A_{D_1}^{\mathrm{bicomodule}} \otimes A_{D_2}^{\mathrm{bicomodule}}$ now constructs in ~1.4s cold (JIT) → 2ms warm; `validate_bicomodule_detailed` ≈ 7.7s cold → 4.3s warm. The hand-built `S_{\mathrm{joint}}` plan was retired — formal $\otimes$ via the lazy path is the categorical ground truth.

### 18. Disease combination uses polynomial $\times$ (v1.0) → formal $\otimes$ (v1.1+)

For combining disease bicomodules, **v1.0 used polynomial $\times$** (giving $\mathrm{directions}((i,j)) = \mathrm{directions}(p,i) + \mathrm{directions}(q,j)$ — sum) — exactly the "advance one side at a time" interface where D1 and D2 progress independently. This is **not** the categorical product of comonoids (that would be $\otimes$); but the carrier $A_{D_1} \times A_{D_2}$ doesn't need to be a comonoid, only a polynomial. The bases $\mathcal{S}, \mathcal{P}$ stay as separate flat comonoids.

**v1.1 upgraded to formal $\otimes$** via the joint-bicomodule construction (§13) — the proper categorical product on bicomodules, with directions Cartesian-product (`paths(t_{D_1}) \times paths(t_{D_2})`). Sequential workup becomes the special case where one side picks the `:stay` path. Mode is a simulator-driver policy on top of this.

**The "compositionality" in v1.0 was at the polynomial layer, not the comonoid layer.** v1.1's formal $\otimes$ promotes this to bicomodule-level composition.

### 19. IR + compiler architecture (v1.3)

Per-disease bicomodules are not hand-coded but *derived* from a Julia-struct DSL:

- **Protocol IR** (`Protocol.jl`): `ProtocolNode` abstract type with `ProtocolStep` and `ProtocolTerminal` concrete types; per-disease consts `D1_protocol`, `D2_protocol` define each guideline as a tree of decision nodes.
- **Protocol compiler** (`ProtocolCompile.jl`): `compile_protocol(p::Protocol) → CompiledProtocol` derives EVERYTHING — phenotype set, per-phenotype behavior trees ($i_S$), `mbar_L`, `mbar_R`, free-$\mathcal{P}$ edges, $A$-carrier polynomial, sub-cofree $\mathcal{S}$, free-cat $\mathcal{P}$.
- Carrier and Bicomodule modules are **slimmed dramatically** — they alias compiled output rather than hand-typing trees, mbar tables, or polynomials.

**The IR struct is the parse target for ProtocolDoc.** When a markdown ProtocolDoc is parsed, the YAML-protocol fenced block deserializes into `ProtocolStep`/`ProtocolTerminal`/`Protocol` structs — and the compiler is unchanged. **The compiler is the back-end of authoring; the parser is the front-end.**

---

## Part IV — Patient History (v1.6.B addition)

### 20. Disease vs problem ontology

A *disease* is a pathophysiological commitment with diagnostic criteria — confirmable, ICD-codable, has a known etiology. A *problem* is anything a clinician chooses to track and address: a confirmed disease, a sign without a diagnosis yet ("elevated BP, not yet HTN"), a risk factor, a goal, a social determinant, a medication issue.

**Therefore problem ⊋ disease.** Every disease can be a problem, but problems include things that aren't diseases.

The defining feature of a problem (versus a disease) is that it's *stateful*: it lives on a list, has a status (active / resolved / chronic / …), evolves, gets re-encountered each visit. A disease is a *label*; a problem is a *tracked concern*.

This carve-out is consistent with industry practice: SNOMED conflates both under "Clinical finding" (loses the distinction); FHIR's `Condition.category` (`problem-list-item` / `encounter-diagnosis` / `health-concern`) tags the *role* without trying to ontologize the type.

**Design principles for PolyCDS:**

1. **Don't bake the distinction into per-disease $A_d$.** $A_d$.positions are *disease workup states* (phenotypes). Don't muddy by trying to make them dual-purpose.
2. **Use SNOMED/LOINC codes as opaque labels** for vocabulary, not as carriers of ontological structure.
3. **Defer the disease-vs-problem typing to FHIR `Condition.category`** when FHIR substrate (v1.7) lands.
4. **Problem-list lives at the patient-history layer** — alongside the per-disease bicomodule, not inside it. v1.6.B realizes this as the category $\mathcal{H}$ over a problem-list coalgebra $\mathcal{Q}$.

### 21. The problem vocabulary $\Sigma_{\mathrm{prob}}$

A protocol declares a *problem vocabulary* $\Sigma_{\mathrm{prob}}$ — a set of problem-tokens. Tokens are bare names (e.g., `chest_pain_undifferentiated`, `acute_MI`, `CKD_stage_3`); status information is *not* in the token.

$\Sigma_{\mathrm{prob}}$ is authored independently from the existing CC-vocabulary and disease-vocabulary. Two explicit maps relate them (set-valued, since one CC or one (disease, state) can realize multiple problem-tokens simultaneously):

$$\mathrm{cc\_realize} : \mathrm{CC\text{-}vocab} \to 2^{\Sigma_{\mathrm{prob}}}$$
$$\mathrm{realize} : (d, s) \mapsto 2^{\Sigma_{\mathrm{prob}}}, \qquad \text{ranging over diseases } d \text{ and per-disease states } s.$$

**Clinical interpretation.** $\mathrm{cc\_realize}(\text{"chest pain"})$ might be $\{\mathrm{chest\_pain\_undifferentiated}, \mathrm{needs\_workup}\}$ — one CC instantiates two problems on presentation. $\mathrm{realize}(\mathrm{MI}, \mathrm{acute\_active})$ might be $\{\mathrm{MI\_acute}, \mathrm{ischemic\_pain}, \mathrm{hemodynamic\_risk}\}$, while $\mathrm{realize}(\mathrm{MI}, \mathrm{recovered})$ might be $\{\mathrm{MI\_history}\}$.

### 22. The list-state and the problem-list coalgebra $\mathcal{Q}$

A *list-state* $x$ is a subset $x \subseteq \Sigma_{\mathrm{prob}}$ — the set of problem-tokens currently on the patient's problem list. (For v1.6.B, list-states are membership-only; per-problem status enums are deferred along with the problem-internal coalgebra.)

The polynomial $Q$ encoding list-events is **representable**:

$$Q = y^{\,\Sigma_{\mathrm{prob}}}.$$

A single position with $|\Sigma_{\mathrm{prob}}|$ directions, one per problem-token. Token $p$ as a *direction* of $Q$ means "the next event toggles $p$ on the problem list." There is no separate op-vocabulary in $Q$'s structure: the `add` / `remove` distinction is recoverable from context (at state $x$, direction $p$ is an `add` if $p \notin x$ and a `remove` if $p \in x$).

**Coalgebra structure.** $\mathcal{Q}$ is realized as a *strict* polynomial coalgebra:

$$\sigma: \mathrm{ListState} \to Q(\mathrm{ListState}) = \mathrm{ListState}^{\,\Sigma_{\mathrm{prob}}}$$

defined by toggle:

$$\sigma(x)(p) = \begin{cases} x \setminus \{p\} & \text{if } p \in x \\ x \cup \{p\} & \text{if } p \notin x. \end{cases}$$

This is total (every direction is defined) and single-valued. There is no validity-restriction machinery — toggle is a total function on $2^{\Sigma_{\mathrm{prob}}}$. The "validity" question of the older op-as-position framing dissolves: every direction is admissible at every state, and the (state, direction) pair determines which clinical operation has occurred.

> **Note (toggle reframe, 2026-04-30).** An earlier draft positioned ops $\{\mathrm{add}, \mathrm{remove}, \mathrm{escalate}, \mathrm{resolve}\}$ as $Q$-positions, treating $Q = \sum_{(\mathrm{op},p)} y^{\,1}$ and $\sigma$ as a *validity-restricted enabled relation* (multi-valued at each state). The $y^{\Sigma_{\mathrm{prob}}}$ framing is strictly cleaner: $\sigma$ becomes a total polynomial coalgebra, the cofree-on-$Q$ construction yields $\mathcal{H}$ directly without a custom restricted path-category build, and per-problem status transitions ($\mathrm{escalate}$, $\mathrm{resolve}$) move to where they belong — direction-set extensions of *per-problem* polynomials in the deferred problem-internal coalgebra, not as op-extensions of $Q$.

### 23. The derived comonoid $\mathcal{C}_x$

For each list-state $x$, the *cofree comonoid* on $\mathcal{Q}$ rooted at $x$ is

$$\mathcal{C}_x := \mathrm{Cof}(\mathcal{Q})|_x.$$

Concretely $\mathcal{C}_x$ is the comonoid in $(\mathbf{Poly}, \triangleleft)$ — i.e., a category — whose objects are list-states *reachable from $x$* via $\mathcal{Q}$-event-paths and whose morphisms are event-paths between them. Under the toggle reframe (§22), every $Q$-direction is admissible at every state, so the cofree comonoid on $Q$ rooted at $x$ has carrier exactly the reachable list-states (a subset of $2^{\Sigma_{\mathrm{prob}}}$) with morphisms = sequences of token-toggles.

**Clinical interpretation.** $\mathcal{C}_x$ is "all valid problem-list evolutions for a patient starting at configuration $x$." It is internal structure carried by the patient-context $x$.

### 24. The history category $\mathcal{H}$

The patient-history category $\mathcal{H}$ is a 1-categorical structure whose objects are abstract clinical-context states (one per reachable list-configuration), and whose morphisms are problem-events composing those states. Each object $x \in \mathrm{Ob}(\mathcal{H})$ carries the derived comonoid $\mathcal{C}_x$ via a *labeling functor*:

$$U: \mathcal{H} \to \mathrm{Comon}(\mathbf{Poly}, \triangleleft).$$

We avoid 2-categorical complexity by keeping $\mathcal{H}$ itself 1-categorical and treating the comonoid-decoration as a separate functor.

**Universal root.** The theoretical root of $\mathcal{H}$ is $\emptyset$ (the empty problem-list); every patient-state is reachable from $\emptyset$ via some composed $\mathcal{H}$-morphism. **Operationally** the runtime does not recompute trajectories from $\emptyset$ — it snapshots the patient's current $x_t$ and continues from there. The two views are equivalent.

**Clinical interpretation.** Objects of $\mathcal{H}$ are problem-list snapshots; morphisms are histories of problem-events. The labeling functor $U$ records the problem-list-evolution structure available from each snapshot.

---

## Part V — The Fibration

### 25. $\mathrm{realize}$ and $\mathrm{cc\_realize}$, and the $\mathcal{S} \to \mathcal{H}$ quotient

Recall the per-disease-state map $\mathrm{realize}: (d, s) \to 2^{\Sigma_{\mathrm{prob}}}$ from §21. From this, the framework *derives* a comonoid map

$$\Theta: \mathcal{S} \to \mathcal{H}$$

(where $\mathcal{S} = \prod_d \mathcal{S}_d$ or an appropriate joint S-comonoid) that is a *quotient functor*: most $\mathcal{S}$-events collapse to identities in $\mathcal{H}$; only those that change $\mathrm{realize}$ map to non-trivial $\mathcal{H}$-morphisms.

Precisely, an $\mathcal{S}$-step $(d, s) \to (d, s')$ maps to:

- $\mathrm{id}_h$ in $\mathcal{H}$ if $\mathrm{realize}(d, s) = \mathrm{realize}(d, s')$;
- otherwise, the $\mathcal{H}$-morphism realizing the symmetric-difference change to the problem-list (i.e., $\mathrm{remove}$ ops for problems leaving $\mathrm{realize}(d, s) \setminus \mathrm{realize}(d, s')$ and $\mathrm{add}$ ops for problems entering $\mathrm{realize}(d, s') \setminus \mathrm{realize}(d, s)$).

The protocol-author authors $\mathrm{realize}$; the categorical quotient is mechanical. **One authoring surface, two derived structures (clinical content + quotient functor).**

### 26. The fibration $A: \mathcal{H}^{\mathrm{op}} \to \mathbf{Bicomod}$

The assessment is a contravariant pseudofunctor

$$A: \mathcal{H}^{\mathrm{op}} \to \mathbf{Bicomod}(\mathcal{S}, \mathcal{P}),$$

assigning to each context $h \in \mathrm{Ob}(\mathcal{H})$ an $(\mathcal{S}, \mathcal{P})$-bicomodule $A_h$, and to each $\mathcal{H}$-morphism $f: h_1 \to h_2$ a bicomodule morphism

$$f^*: A_{h_2} \to A_{h_1}$$

(reindexing in the *opposite* direction — extending history yields a *smaller* fiber, embedded into a larger one).

**Filtration semantics (v1.6.B choice).** Each $A_h$ is a *sub-bicomodule* of the top fiber $A_\emptyset$, defined by a predicate on $A_\emptyset(1)$. The fibration is determined by the family of sub-objects $\{A_h \subseteq A_\emptyset \mid h \in \mathrm{Ob}(\mathcal{H})\}$. Reindexing $f^*$ is the natural inclusion.

**The top fiber.** $A_\emptyset \cong A_{\mathrm{joint}}$ (v1.1's construction) with all diseases at their initial states. The fibration provides context-narrowing as $h$ grows; no separate "undifferentiated head" construction beyond $A_{\mathrm{joint}}$ is required.

**No new $\rho$.** All $\mathcal{P}$-side recommendations live in the global $\rho_\emptyset: A_\emptyset \to A_\emptyset \triangleleft P$. Per-context $A_h$ *restricts* which $\mathcal{P}$-positions are reachable but introduces no new ones — protocol authorship remains the single source of truth for $\rho$.

### 27. The Grothendieck total space $\int A$

The Grothendieck construction gives a category $\int A$ whose:

- objects are pairs $(h, a)$ with $h \in \mathrm{Ob}(\mathcal{H})$ and $a \in A_h(1)$;
- morphisms $(h_1, a_1) \to (h_2, a_2)$ are pairs $(f, \beta)$ with $f: h_1 \to h_2$ in $\mathcal{H}$ and $\beta: a_1 \to (f^*)(a_2)$ a witness in $A_{h_1}$.

The projection $\pi: \int A \to \mathcal{H}$ forgets the $A$-component on objects and is the fibration. A patient at time $t$ is at a point $(h_t, a_t) \in \int A$.

### 28. Two-level dynamics

Movement in $\int A$ decomposes into two flavors of morphisms, corresponding to clinically-distinct event types:

**Vertical movement (within a fiber, $h$ fixed).** Observations during a visit, processed by $\lambda_h$. The fiber $A_h$ stays constant; the position $a$ refines along $A_h$'s internal structure. **Differential-diagnosis narrowing under labs/exam findings happens here.** All v1.x machinery (sub-cofree-S, free-P, $\lambda$, $\rho$) operates unchanged inside each fiber. The bicomodule axioms hold inside each fiber, so each fiber is a coherent guideline-restriction of the protocol.

**Horizontal movement (between fibers, $h$ changes).** Problem-list updates — chief-complaint events, new diagnoses confirmed, problems resolved, longitudinal context changes. Movement along an $\mathcal{H}$-morphism $f: h_1 \to h_2$ takes $(h_1, a_1)$ to $(h_2, a_2)$ via $a_2 = a_1 \in A_{h_2} \subseteq A_{h_1}$.

This structural separation (vertical = within-visit, horizontal = problem-list-changing) was not visible in earlier v1.x architecture. It earns its keep by aligning categorical structure with clinical event-types.

**Strict coherence on fiber-crossings.** When $h$ grows from $h_1$ to $h_2$, the current within-fiber position $a$ *must* already lie in the smaller $A_{h_2}$. If $a \notin A_{h_2}(1)$, the framework rejects the update as a coherence violation. Out-of-band updates ("oh, the patient also has CKD that wasn't on our radar") are protocol-author bugs — to be either anticipated by the protocol or treated as out-of-scope for the framework. **No silent rebase.**

---

## Part VI — Chief Complaints and Differential Diagnosis

### 29. Chief complaint as $\mathcal{H}$-generator

A chief complaint event is a generator of $\mathcal{H}$. Concretely: when a CC token $c \in \mathrm{CC\text{-}vocab}$ fires at a patient's current state $h_t$, the induced $\mathcal{H}$-morphism is

$$h_t \xrightarrow{\;\;\;f_c\;\;\;} h_{t+1}$$

where $f_c$ is the composition of $\mathrm{add}$ ops applied at $h_t$ for each problem-token in $\mathrm{cc\_realize}(c)$ (filtered to those not already in $h_t$, since validity-restricted ops would otherwise reject). The CC-vocabulary thereby becomes a *named-pattern library* over generators of $\mathcal{H}$ — clinically meaningful aggregates of low-level $\mathcal{Q}$-ops.

**There is no $P_{\mathrm{CC}}$ polynomial section construction** as proposed in earlier design discussions. Chief complaints are simply $\mathcal{H}$-generators with set-valued semantic content.

### 30. Differential diagnosis as projection from $\int A$

The differential diagnosis at time $t$ is a projection from the patient's current point $(h_t, a_t) \in \int A$:

$$\mathrm{DDx}(h_t, a_t) := \{ d \in \mathrm{disease\text{-}vocab} \mid \exists s.\ a_t \text{ is consistent with disease-state } (d, s) \text{ in } A_{h_t} \}.$$

Equivalently, $\mathrm{DDx}(h_t, a_t)$ is the set of diseases whose disease-fiber is non-trivially intersected by $a_t$ in the joint structure of $A_{h_t}$.

**Two-level narrowing.** $\mathrm{DDx}$ narrows under both kinds of movement:

- Vertically, as $\lambda_h$ consumes observations and $a_t$ refines (some disease-states in $A_h$ become inaccessible from the new position).
- Horizontally, as $h$ grows and $A_h$ shrinks (the problem-list update may render entire disease-paths inconsistent with the patient's now-richer context).

The CC ↔ DDx connection: both flow through $\int A$'s two-level dynamics. Chief complaints move the patient horizontally (changing which $\mathrm{DDx}$-universe applies); observations move the patient vertically (refining $\mathrm{DDx}$ within the current fiber).

### 31. "Considered & ruled out" vs "never on DDx"

A subtle but clinically-important distinction: at any time $t$, for a disease $d \notin \mathrm{DDx}(h_t, a_t)$, the question is *why* $d$ is not in the differential. Two cases:

- **Considered & ruled out:** $d$ was on the differential at some prior time $t' < t$ (i.e., $d \in \mathrm{DDx}(h_{t'}, a_{t'})$ for some $t'$), and a subsequent observation or problem-event removed it. The patient has a workup-record for $d$.
- **Never on DDx:** $d$ was never on the differential — ruled out by the initial CC-routing or by patient context, without any disease-specific workup.

These are *clinically distinct*: "we ruled out HF after a TTE" $\neq$ "HF was never on the differential." Future-visit implications differ (the TTE-ruled-out HF might be re-screened later; the never-considered HF might never be considered).

In the H-fibration framework, the distinction lives in the *trajectory through $\int A$*: a patient's history-path records *which fibers* they've visited and *which positions* they've held. Querying the trajectory recovers "considered & ruled out" vs "never on DDx" without needing to encode the distinction at the bicomodule layer.

This was originally the rationale for the per-disease 5-state set including a distinct `a_*_n_a` ("never on DDx") position separate from `a_*_absent` ("ruled out via workup"). In v1.x, that distinction was deferred (4 → 5 states landed without `a_*_n_a`); in v1.6.B, it is supplied by the trajectory record over $\int A$.

---

## Part VII — Coherence Properties

A protocol's *coherence* is captured at two distinct strata. The first is foundational and non-negotiable; the second is optional and per-protocol.

### 32. Foundational coherence (the bicomodule axioms — non-optional)

The bicomodule axioms (counit laws, coassociativity laws, and the compatibility law from §3 / §10) **are not optional**. A protocol that violates them is *internally incoherent in a precise, debuggable sense* — a guideline that says "if A then B" and "if A then C" simultaneously. The framework's job is to enforce these and refuse to compile/ship a protocol that fails them.

`validate_bicomodule_detailed` is the implementation surface for this enforcement: it runs the compatibility law on every $(s, a, p)$ triple and surfaces failing cases via `minimal_failing_triple` (Poly.jl v0.2.0). The bicomodule axiom *being true of a protocol* is equivalent to the protocol *being internally coherent as a clinical guideline*.

This is the load-bearing insight that makes PolyCDS structurally different from CQL/Arden/GLIF: those formats cannot detect internal incoherence as a category-theoretic invariant; PolyCDS can.

### 33. Optional coherence (per-guideline, checkable but not enforced)

Beyond the foundational axioms, three further coherence properties may or may not hold for a given protocol. They are useful when present but not required.

**Lattice-ness on $A$'s refinement order.** The positions of $A$ (or each fiber $A_h$) carry a natural refinement partial order: $a \leq a'$ iff $a'$ is a refinement of $a$ (more committed phenotype). Under sub-cofree-S construction, this partial order is a *tree* (poset), generically *not a lattice*. Lattice-ness corresponds to *path-independence of assessment*: two patients reaching the same $\mathrm{DDx}$ via different observation-orders get assessment-equivalent positions. **Default:** poset (no lattice promise). **Optional:** declare lattice-coherent and verify.

**Cross-protocol universality of $\mathrm{realize}$.** Different protocols sharing the same disease $d$ may declare different $\mathrm{realize}_P(d, s)$, leading to different $\Theta_P: \mathcal{S}_d \to \mathcal{H}_P$ quotients. Universality asserts $\mathrm{realize}_{P_1}(d, s) = \mathrm{realize}_{P_2}(d, s)$ for all protocols $P_1, P_2$ referencing $d$. **Default:** per-protocol authoring. **Optional:** verify across a collection.

**Cross-protocol $\Sigma_{\mathrm{prob}}$-vocabulary equivalence.** Different protocols may declare different problem-vocabularies. Vocabulary-equivalence asserts that semantically-identical problem-tokens are named identically across protocols (e.g., `:CKD_stage_3` means the same thing in two different guidelines). **Default:** per-protocol $\Sigma_{\mathrm{prob}}$ with no enforced cross-protocol agreement. **Optional:** verify across a collection.

---

## Part VIII — Authoring Surface (ProtocolDoc) and Layered Architecture

### 34. Audience and intent

Clinical protocols in PolyCDS are authored by **clinicians, not technical people**. The format (ProtocolDoc) is designed accordingly:

- **Markdown body with embedded fenced structured blocks** ("MDX/RFC pattern"). Prose carries clinical rationale, evidence, edge cases. Structured blocks carry the parseable rules.
- **YAML inside fenced blocks** for v1, with strict schema validation (string-vs-number, indentation gotchas).
- **One protocol per file** for v1; multi-protocol bundles deferred.
- **Composition in separate wiring-diagram files** that reference protocol files; protocols stay self-contained.
- **Two distinct vocabulary blocks:** observation vocab is the *FHIR-in surface* (each obs entry carries LOINC/SNOMED code); order vocab is the *FHIR-out surface* (each order entry carries FHIR action type + code).

**FHIR clarification:** in PolyCDS, "FHIR" means *patient data flow* — input observations and output orders are FHIR resources. The protocol authoring format is **not** FHIR; it references FHIR codes inline but lives in its own markdown format. This separation is deliberate.

### 35. Layered architecture (format / IR / engine)

ProtocolDoc has three logical layers:

1. **Format spec** — pure data-format definition (markdown structure + YAML schema). Could exist as a spec document with no code.
2. **Parser/serializer/validator** — engine-agnostic. Reads ProtocolDoc files into the IR; validates cross-references at parse time (transitions referencing nonexistent states, recommendations referencing nonexistent orders); (eventually) emits ProtocolDocs from IR for round-trip.
3. **Engine compiler** — engine-specific. Compiles IR to engine values (PolyCDS bicomodule, or other CDS engine targets).

Layers 1 and 2 belong in a **standalone library** (working name `ProtocolDoc.jl` or `ClinicalProtocol.jl`). Layer 3 lives inside PolyCDS as a `PolyCDS.ProtocolDoc` module. This positions ProtocolDoc as a format with multiple potential implementations — community adoption at the format level is decoupled from engine choice.

### 36. v1.6.B authoring surface

For v1.6.B, a protocol-doc declares:

1. **Disease-vocabulary** $\{d_1, \ldots, d_n\}$ with per-disease $\mathcal{S}_d$, $\mathcal{P}_d$, and $A_d$ (per v1.x).
2. **CC-vocabulary** (per v1.6.A).
3. **Problem-vocabulary** $\Sigma_{\mathrm{prob}}$ (new in v1.6.B).
4. **The disease-state realization map** $\mathrm{realize}: (d, s) \to 2^{\Sigma_{\mathrm{prob}}}$.
5. **The CC realization map** $\mathrm{cc\_realize}: \mathrm{CC\text{-}vocab} \to 2^{\Sigma_{\mathrm{prob}}}$.
6. *(No op-set declaration needed — under the toggle reframe of §22, $Q = y^{\Sigma_{\mathrm{prob}}}$ is determined by $\Sigma_{\mathrm{prob}}$ alone. The clinical `add`/`remove`/`escalate`/`resolve` distinctions are recovered from context (state + direction) at the list level, and from per-problem polynomials at the deferred problem-internal level.)*

### 37. What the framework derives

From the authoring surface, the framework computes:

1. **The polynomial $Q = y^{\Sigma_{\mathrm{prob}}}$** from $\Sigma_{\mathrm{prob}}$.
2. **The strict toggle coalgebra** $\sigma: \mathrm{ListState} \to Q(\mathrm{ListState}) = \mathrm{ListState}^{\Sigma_{\mathrm{prob}}}$, defined by $\sigma(x)(p) = x \triangle \{p\}$ (set-symmetric-difference).
3. **The history category $\mathcal{H}$**, with $U: \mathcal{H} \to \mathrm{Comon}(\mathbf{Poly}, \triangleleft)$, as the cofree comonoid on $\mathcal{Q}$ rooted at $\emptyset$.
4. **The $\mathcal{S} \to \mathcal{H}$ quotient $\Theta$** via $\mathrm{realize}$.
5. **The top fiber $A_\emptyset \cong A_{\mathrm{joint}}$** via v1.1's $\otimes$-construction over the per-disease $A_d$.
6. **The fiber family $\{A_h \subseteq A_\emptyset \mid h \in \mathrm{Ob}(\mathcal{H})\}$** as filtration of $A_\emptyset$ by $h$-compatibility predicates.
7. **The total space $\int A$** as the Grothendieck construction.
8. **Foundational coherence verification** via `validate_bicomodule_detailed` (non-optional; enforced).
9. **Optional coherence properties** (lattice-ness, universality, op-equivalence) checkable on demand.

---

## Part IX — Implementation Status

Brief implementation history of the framework (as of 2026-04-30):

- **v1.0:** baseline 2-disease bicomodule simulator. Discrete $\mathcal{S}$, joint via polynomial $\times$. Memory in $A$ via `*_pending` phenotypes.
- **v1.1 (pushed 2026-04-28):** sub-cofree $\mathcal{S}$ per disease (4 trees, ragged $T_{\mathrm{root}}$); 5 phenotypes per disease; joint via formal $\otimes$ using Poly.jl v0.2.0's `LazySubst` to avoid $16^{25}$ blowup; mode parameter (`:sequential`/`:panel`) as simulator policy. 31/31 tests green.
- **v1.2 (local 2026-04-29):** free-$\mathcal{P}$ via `build_free_protocol_category`; codomain-matching `sharp_R`; vocabulary refinement (`:no_further_workup_Dk` → `:disease_Dk_present`/`:disease_Dk_absent`); `validate_bicomodule_detailed` becomes substantive. +5 tests.
- **v1.3 (local 2026-04-29):** Protocol IR + compiler; paths-as-directions cutover; per-disease bicomodules slimmed to aliases of compiled output. Same test count, leaner code.
- **v1.4 (local 2026-04-29):** ProtocolDoc parser (markdown + YAML); sample protocols `protocols/D1.md`, `protocols/D2.md`; round-trip parse/compile. ~96 tests.
- **v1.5 (local 2026-04-29):** two-tier viz layer — Mermaid for clinician-facing flowcharts, Catlab.jl for categorical wiring diagrams. ~112 tests.
- **v1.6.A (pushed 2026-04-29):** CC-vocabulary infrastructure (5-symptom alphabet: `chest_pain`, `abd_pain`, `dyspnea`, `fatigue`, `well_visit`); `p_chief_complaint`, `p_intake` polynomials. Additive only.
- **v1.6.B (architecture settled 2026-04-30, NOT YET CODED):** the H-fibration architecture described in this document.

**v1.7 (planned):** FHIR substrate. 4-object category $C = \{\mathrm{Patient}, \mathrm{Observation}, \mathrm{Practitioner}, \mathrm{Condition}\}$. Phenotype migrates from `Bool` tuple into `Condition` instances. Patient state $= (\mathrm{patient\_id}, \mathrm{running}\_F, \mathrm{ground\_truth}\_F^*)$ with the coalgebra revealing slices of $F^*$ into running $F$ as observations are issued.

**v1.8 (planned):** Shared objective library + cross-linked workup composition. Split each disease into screen+confirm objectives plus shared `obj_basic_labs`. CC selects a sub-library; `compose_workup(cc): \mathrm{Bicomodule}` builds the per-CC composition via $\odot$ (cross-linked composition).

---

## Open questions and future categorical wiring directions

The following are explicitly *not* settled in v1.6.B and are deferred to future work.

### Future categorical wiring (deferred categorical structures)

Three composition / wiring constructs are flagged as next-version targets after v1.6.B lands:

**Cross-linked bicomodules via $M \odot_{\mathcal{D}} N$.** The proper sequential / horizontal composition over a shared middle base $\mathcal{D}$. For $M: \mathcal{C} \nrightarrow \mathcal{D}$ and $N: \mathcal{D} \nrightarrow \mathcal{E}$, $M \odot_{\mathcal{D}} N: \mathcal{C} \nrightarrow \mathcal{E}$ integrates out the middle $\mathcal{D}$ via a coequalizer. **Clinical use:** confirming a primary disease triggers a sub-workup for its etiology or complications (HF confirmed → consider HFrEF vs HFpEF workup → consider underlying CAD). The chain of "diagnosis → next workup → next diagnosis" composes via $\odot$. Requires designing what the shared middle base is — probably a "diagnostic conclusion" comonoid that sits between two layers of bicomodules. **This is the right tool for v1.8's shared-objective library.**

**Wiring diagrams.** Spivak's syntactic/diagrammatic language for composing dynamical systems and bicomodules by routing outputs to inputs. **The cleanest long-term home for "CDS as data"** — a CDS guideline becomes a literal *wiring-diagram artifact* (a graph of bicomodules with explicit input/output connections) that can be shipped, re-wired, versioned, and inspected. v2+ headline structure once the per-bicomodule pieces stabilize. Catlab.jl already provides this primitively in v1.5; full wiring-diagram-as-authoring-surface deferred.

**Markov categories for probability-weighted differentials.** Aidan floated using $[0, 1]$ as direction-sets in $A$ to model probability. Real critique: this conflates "probability of a transition" with "probability of a state," loses combinatorial tractability (continuum cardinality), and isn't quite formally well-typed (probability of *what*?). Right paths to add probability are (a) decorate polynomial structure with a probability layer on top — keep $\mathbf{Set}$-based polynomials, add measures separately — or (b) graduate to Markov categories (Fritz/Spivak/Patterson work) which extend the polynomial framework to stochastic morphisms. Stuffing $[0, 1]$ into direction-sets directly is appealing but probably not the right structural move. **Defer to v2+** when probability becomes the headline feature.

### v1.6.B-specific deferrals

- **Problem-internal coalgebra (second tier).** Each problem-token $p \in \Sigma_{\mathrm{prob}}$ may carry its own internal sub-state-machine (active → improving → resolved with its own branching). Currently deferred; only list-level $\mathcal{Q}$ is in v1.6.B.
- **Demographic stratification of $x_0$.** The universal-empty root $x_0 = \emptyset$ may be replaced by demographic-stratified roots (adult vs pediatric, sex-specific baselines). Future.
- **Lax fibration.** Currently $A: \mathcal{H}^{\mathrm{op}} \to \mathbf{Bicomod}$ is *strict* — reindexing maps are deterministic inclusions. A *lax* version would let history *suggest* but not mechanically determine the contextualized $A$. Future, for modeling clinical judgment.
- **Cross-disease constraints.** Currently each disease's bicomodule $A_d$ is independent; cross-disease constraints (e.g., "if HR < 40, the orthostatic branch dies and arrhythmia gets weight") are not first-class. Future.
- **CC firing with pre-existing problems.** When $\mathrm{cc\_realize}(c) \cap \mathrm{dom}(h_t) \neq \emptyset$, validity-restricted $\mathrm{add}$ would reject. The intended semantics is "filter to missing problems" — fire $\mathrm{add}$ only for $\mathrm{cc\_realize}(c) \setminus \mathrm{dom}(h_t)$, log the filtering. Not yet implemented.
- **Antipode / Hopf structure on $\mathcal{H}$.** $\mathcal{H}$ as a category has comonoid structure; whether it deserves additional algebraic structure (resolution-events as antipodes of acquisition-events) is open.
- **Off-protocol alarm reintroduction.** Dropped in v1.1 (§15) for tractability; if explicit redundant-test detection becomes a feature priority, reintroduce via simulation-driver decoration rather than restoring $T_{\mathrm{neg}}$ at the categorical level.
- **Mechanical sub-cofree derivation from ProtocolDoc.** Currently sub-cofree trees are hand-picked per disease (5 per D in v1.x). A formal procedure that walks the protocol-graph and enumerates the unique cofree-positions visited would auto-derive the minimal sub-cofree, eliminating manual tree-picking errors. Worth designing once ProtocolDoc work is up.

---

## Glossary of symbols

| Symbol | Meaning |
|---|---|
| $\mathbf{Poly}$ | category of polynomial functors $\mathbf{Set} \to \mathbf{Set}$ |
| $\triangleleft$ | composition / substitution tensor on $\mathbf{Poly}$ |
| $\otimes$ | Dirichlet (parallel) tensor on $\mathbf{Poly}$ |
| $\odot$ | cross-linked / horizontal composition of bicomodules over a shared middle base (deferred) |
| $y$ | identity polynomial |
| $\mathcal{S}, \mathcal{S}_d$ | patient-state comonoid (joint, per-disease) — *coalgebraic side* |
| $\mathcal{P}, \mathcal{P}_d$ | protocol/recommendation comonoid — *algebraic side* |
| $A, A_d, A_{\mathrm{joint}}, A_h, A_\emptyset$ | assessment bicomodules — *the bridge* |
| $\lambda$ | left $\mathcal{S}$-coaction on $A$ (observation consumer) |
| $\rho$ | right $\mathcal{P}$-coaction on $A$ (recommendation emitter) |
| $\Sigma_{\mathrm{prob}}$ | problem vocabulary |
| $\mathcal{Q}$ | problem-list coalgebra (post-2026-04-30: $Q = y^{\Sigma_{\mathrm{prob}}}$, $\sigma$ = strict toggle) |
| toggle | $\mathrm{toggle}(p, x) = x \triangle \{p\}$ — the total transition function defining $\sigma$ |
| $\mathcal{C}_x$ | derived comonoid at list-state $x$ (= $\mathrm{Cof}(\mathcal{Q})|_x$) |
| $\mathcal{H}$ | patient-history category |
| $U$ | labeling functor $\mathcal{H} \to \mathrm{Comon}(\mathbf{Poly}, \triangleleft)$ |
| $\mathrm{realize}$ | per-disease-state realization map |
| $\mathrm{cc\_realize}$ | chief-complaint realization map |
| $\Theta$ | $\mathcal{S} \to \mathcal{H}$ derived quotient functor |
| $\int A$ | Grothendieck total space of the fibration |
| $\mathrm{DDx}(h, a)$ | differential diagnosis at point $(h, a) \in \int A$ |
| $\mathrm{Cof}(Q)$ | cofree comonoid on polynomial $Q$ |
| $\mathrm{sharp}_L, \mathrm{sharp}_R$ | bicomodule axiom-extension functions (codomain-matching for $\mathrm{sharp}_R$) |
| `mbar_L, mbar_R` | per-position route/emit dictionaries on the bicomodule |
| $i_S$ | per-phenotype behavior tree (cofree subtree associated with a phenotype) |
