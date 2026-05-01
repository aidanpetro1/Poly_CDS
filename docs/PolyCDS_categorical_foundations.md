# PolyCDS — Category-Theoretic Foundations

*Ground-truth reference for the V2 master-D architecture. Captures the category theory underlying PolyCDS.*

---

## 0. Preamble

This document records the category-theoretic structure underlying PolyCDS. It covers (i) the underlying polynomial-functor machinery, (ii) the V2 master-D bicomodule architecture, (iii) the post-σ readout convention and the structural form of the coherence axiom, (iv) the observation alphabet and the encounter-log comonoid, (v) the compiler from `Protocol` IR to `Differential`, (vi) the simulator and renderers, (vii) coherence properties, (viii) the authoring surface, and (ix) implementation status and deferred work.

Each abstract construction is accompanied by a clinical interpretation so the structure can be checked against clinical reality. Notation: comonoids/categories use script font ($\mathcal{O}, \mathcal{P}, \mathcal{Q}$), polynomials/bicomodules use capitals ($D, P, O$), Greek letters denote structure maps ($\lambda, \rho, \delta, \varepsilon$).

**Conventions.** $\mathbf{Poly}$ denotes the category of polynomial functors $\mathbf{Set} \to \mathbf{Set}$. The two monoidal structures used are $\triangleleft$ (composition / substitution) and $\otimes$ (Dirichlet product). $y$ denotes the identity polynomial (one position, one direction). For a polynomial $p$, we write $p(1)$ for its position-set and $p[i]$ for its direction-set at position $i$, so $p \cong \sum_{i \in p(1)} y^{p[i]}$.

---

## Part I — Underlying Machinery

### 1. Polynomial functors

A polynomial functor $p \in \mathbf{Poly}$ is a coproduct of representables, $p = \sum_{i \in p(1)} y^{p[i]}$. A morphism $f: p \to q$ in $\mathbf{Poly}$ consists of:

- a forward map on positions $f_1: p(1) \to q(1)$, and
- a backward map on directions $f^\sharp_i: q[f_1(i)] \to p[i]$ for each $i \in p(1)$.

The double-direction structure means $\mathbf{Poly}$-morphisms model interaction patterns: a position is a state-or-question; a direction is a response-or-answer.

**Sections.** A *section* of $p$ is a morphism $p \to y$. Concretely it picks one direction $d_i \in p[i]$ at each position $i \in p(1)$.

### 2. Composition tensor and comonoids

The composition tensor $\triangleleft$ is defined by

$$(p \triangleleft q)(X) = p(q(X)).$$

It is associative but not symmetric. The unit is $y$.

**Comonoids in $(\mathbf{Poly}, \triangleleft)$ are small categories** (Ahman–Uustalu). A comonoid $\mathcal{C} = (C, \varepsilon, \delta)$ with $\varepsilon: C \to y$ and $\delta: C \to C \triangleleft C$ is the same data as a small category whose object-set is $C(1)$, morphism-set out of object $i$ is $C[i]$, with $\varepsilon$ picking identities and $\delta$ encoding factorization (associativity = coassociativity, identity laws = counit laws).

A morphism of comonoids in $(\mathbf{Poly}, \triangleleft)$ is exactly a functor between the corresponding categories.

### 3. Bicomodules

Given comonoids $\mathcal{S}$ and $\mathcal{P}$ — i.e., small categories — an $(\mathcal{S}, \mathcal{P})$-bicomodule is a polynomial $A$ equipped with:

- a left $\mathcal{S}$-coaction $\lambda: A \to S \triangleleft A$, and
- a right $\mathcal{P}$-coaction $\rho: A \to A \triangleleft P$,

satisfying counit laws and coassociativity laws on each side, plus the **bicomodule compatibility axiom**:

$$(\mathrm{id}_S \triangleleft \rho) \circ \lambda \;=\; (\lambda \triangleleft \mathrm{id}_P) \circ \rho.$$

Operationally: stepping left through $\mathcal{S}$ then right through $\mathcal{P}$ agrees with stepping right then left. The load-bearing axiom for guideline coherence — see §11.

### 4. Cofree comonoids

For a polynomial $Q$, the cofree comonoid $\mathrm{Cof}(Q)$ is the universal comonoid mapping into $Q$. Concretely, $\mathrm{Cof}(Q)$ is the polynomial whose positions are $Q$-trees (each branching node labeled by a $Q$-position, with branches indexed by directions of that position). $\mathrm{Cof}(Q)$ is a category whose objects are $Q$-trees and whose morphisms are extensions.

**Free vs. cofree.** Two distinct "free" constructions appear in PolyCDS:

- **Cofree comonoid on a polynomial.** Right adjoint to the forgetful $\mathrm{Comon}(\mathbf{Poly}) \to \mathbf{Poly}$. Tree-shaped, coalgebraic; receives input.
- **Free category on a graph.** Left adjoint to $\mathbf{Cat} \to \mathbf{Graph}$. Path-shaped, algebraic; emits sequences.

The cofree-input / free-output asymmetry mirrors the chain $\mathrm{cofree} \dashv U \dashv \mathrm{free}$. PolyCDS uses **cofree on the left** (the observation comonoid $\mathcal{O}$) and **free on the right** (the joint protocol comonoid $\mathcal{P}$).

---

## Part II — The V2 master-D bicomodule

### 5. Architectural pivot

The clinical decision support system is modeled as a single bicomodule

$$D : \mathcal{O} \nrightarrow \mathcal{P}$$

named the **Differential** (since its positions encode the joint differential diagnosis at any point in time). $\mathcal{O}$ is the encounter-log comonoid; $\mathcal{P}$ is the joint protocol comonoid; $D$ mediates between them via two coactions. The pre-V2 architecture (per-disease $A_d : \mathcal{S}_d \nrightarrow \mathcal{P}_d$, joined via formal $\otimes$) has been demoted: $A$ now appears only as a derived family of temporal-evolution 2-cells along trajectories through $D$.

### 6. The observation comonoid $\mathcal{O}$

$\mathcal{O} = \mathrm{cofree}(Q, \mathrm{depth})$ where $Q = y^{\Sigma_{\mathrm{obs}}}$, the representable polynomial whose single position has $\Sigma_{\mathrm{obs}}$-many directions. The observation-event alphabet $\Sigma_{\mathrm{obs}}$ contains atomic events received from the patient/EHR/lab — for the toy, results like `:result_o1a_pos`, `:result_o1a_neg`, …

**$\mathcal{O}$-positions** are encounter logs $w \in \Sigma_{\mathrm{obs}}^{\le \mathrm{depth}}$ — finite sequences of observation events of bounded length. The empty log $w = \emptyset$ is the universal root. **$\mathcal{O}$-directions at log $w$** are $\Sigma_{\mathrm{obs}}$ when $|w| < \mathrm{depth}$, else empty.

In code, $\mathcal{O}$ is materialized as the `OComonoid` struct (parameter wrapper carrying $\Sigma$ and depth, with `O_positions` / `O_directions_at` enumeration helpers). Full Poly.jl-backed cofree materialization is deferred to v1.7+ where Kan-extension queries (audit/likelihood arm) require it.

**Clinical interpretation.** An $\mathcal{O}$-position is the patient's encounter as a record: an ordered log of every observation event that has arrived. The cofree structure makes this the universal "nothing else exists" comonoid — every trajectory through the encounter is a valid $\mathcal{O}$-direction sequence, and the comult expresses the obvious "any prefix-suffix split of a trajectory is also valid" coherence.

### 7. The protocol comonoid $\mathcal{P}$

$\mathcal{P}$ is a joint protocol comonoid built from per-disease components: $\mathcal{P} = \bigotimes_d \mathcal{P}_d$. Each $\mathcal{P}_d = \mathrm{Free}(G_d)$ is the free category on the per-disease protocol graph $G_d$, whose objects are workup-states (orders to issue, conclusions) and edges are recommendation-edges (transitions).

**$\mathcal{P}_d$-positions** are objects of $G_d$ (e.g. `:order_o1a`, `:disease_D1_present`). **$\mathcal{P}_d$-directions at object $o$** are paths starting at $o$ (sequences of recommendation-edges, encoded as path-tuples with `()` the identity).

**$\mathcal{P}$-positions** are tuples of per-disease workup-states; **$\mathcal{P}$-directions** at a tuple are tuples of per-disease paths.

**Clinical interpretation.** A $\mathcal{P}$-position is a snapshot of "what the protocol's workup-state pointer is for each disease right now" — equivalent to the recommendation the system would emit if asked at that moment. A $\mathcal{P}$-direction is a recommendation trajectory: how the workup advances from one state to another.

### 8. The Differential $D$

The Differential is a polynomial $D$ equipped with left and right coactions:

$$\lambda_L : D \to \mathcal{O} \triangleleft D, \quad \lambda_R : D \to D \triangleleft \mathcal{P}.$$

**$D$-positions** are joint disease-frame states. For the toy:

$$D(1) \;=\; \mathrm{Diseases} \to \{\mathrm{ruled\text{-}out}\} \cup \{\mathrm{considering}(\varphi_d) \mid \varphi_d \in \Phi_d\} \cup \{\mathrm{ruled\text{-}in}(\varphi_d) \mid \varphi_d \in \Phi_d\}$$

— a function from each disease to its current epistemic+phenotype tag. $\Phi_d$ is the per-disease phenotype state space (e.g. `:a_D1_initial`, `:a_D1_pending`, `:a_D1`, `:a_D1_absent` for the 4-state toy).

**$D$-directions at $p$** are paths through $\mathcal{O}$ starting at the encounter-log projection of $p$ — finite $\Sigma_{\mathrm{obs}}$-sequences. Atomic events are length-1 paths; the empty sequence is the identity.

**Sufficient-statistic property.** $D$-positions summarize everything the protocol cares about: two trajectories ending at the same $D$-position are CDS-equivalent going forward. Anything not encoded in a $D$-position lives only in $\mathcal{O}$ and can be queried by $\lambda_R$ or by support computations (v1.7+ explainability) but doesn't influence protocol branching.

**Clinical interpretation.** A $D$-position is the joint differential at any instant: which diseases are on the differential, which have been ruled out, and what per-disease phenotype state each is in. A $D$-direction at $p$ is a possible trajectory of observation events that could fire from $p$.

### 9. Authoring surface

The protocol author's data per Differential consists of:

- **$f$** — the position-forward of $\lambda_L$, keyed by atomic $\sigma \in \Sigma_{\mathrm{obs}}$. For each $D$-position $p$ and each $\sigma$, $f_p(\sigma)$ is the next $D$-position when $\sigma$ fires at $p$. Missing entries default to identity (σ doesn't apply at p).
- **$\mathrm{workup\_state}$** — a function $D(1) \to \mathcal{P}(1)$ projecting each $D$-position to a joint workup-state pointer.
- **$\Sigma_{\mathrm{obs}}$** and **depth** — the parameters of $\mathcal{O}$.

The `emit` table (the position-forward of $\lambda_R$) is *derived*, not authored: under the post-σ readout convention (§11), $\mathrm{emit}_p(\sigma) \equiv \mathrm{workup\_state}(f_p(\sigma))$. `sharp_L` (the back-direction of $\lambda_L$) is *implicit*: it is path concatenation, not a separately-authored table.

In code, the `Differential` struct in `Differential.jl` carries $\mathcal{O}$, $D$-positions, $\mathcal{P}$-positions, the $f$ table, the (derived) `emit` table, and a vestigial `sharp_L` field kept for non-canonical authoring conventions.

---

## Part III — The (b) interpretation and post-σ readout

### 10. Direction-shape interpretation (b)

A choice point in the V2 design: are $D$-directions atomic Σ-events or paths through $\mathcal{O}$?

We adopt **interpretation (b)**: $D$-directions at $p$ are paths through $\mathcal{O}$ starting at the encounter-log projection of $p$ — finite Σ-sequences under cofree($Q$, depth)'s natural structure. Atomic events $\sigma \in \Sigma_{\mathrm{obs}}$ are length-1 paths; the empty sequence is the identity.

Under (b):

- `sharp_L`, the back-direction of $\lambda_L$, is **path concatenation**: $\mathrm{sharp\_L}(p, \sigma, \sigma') = \sigma \cdot \sigma'$. Not authored as separate data.
- $f$ for paths is **sequential composition** of atomic-σ tables: $f_p(\sigma_1, \ldots, \sigma_k) = f_{f_{\cdots}(p)}(\sigma_k)$ recursively.
- `emit` for paths follows post-σ readout (§11).

The alternative (a) — $D$-directions at $p$ are atomic Σ-events — was rejected because it requires the alphabet to admit a single-event representative for every multi-step trajectory, which is unrealistic for real clinical protocols (a screen-then-confirm workup forbids skipping intermediate states). Under (b), multi-step paths are first-class direction objects; sharp_L is no longer load-bearing as authored data.

### 11. Post-σ readout

$\lambda_R$ is **fire-and-forget**: emitting a recommendation does not move $D$'s position. The forward of $\lambda_R$ at $p$ has $\sigma_R(p) = p$ (D-position component is identity); the back-direction of $\lambda_R$ collapses to projection $(d, e) \mapsto d$. Under fire-and-forget, the loop between system output and patient state closes externally — the system's emitted orders enter the encounter log as Σ-events, which $\lambda_L$ then absorbs.

The post-σ readout convention defines `emit`:

$$\mathrm{emit}_p(\sigma) \;:=\; \mathrm{workup\_state}(f_p(\sigma)).$$

The recommendation emitted along direction $\sigma$ at position $p$ is the workup-state at the position $\sigma$ would advance us to. This makes recommendations a transparent function of the evidence-trajectory: each $\sigma$ → emission chain reads as "this evidence, therefore this recommendation."

**Clinical interpretation.** Post-σ readout makes the system a clinical *support* tool, not a closed-loop decision machine. The system informs and recommends; the world (clinician + EHR + lab + patient) decides and acts; the action manifests as a Σ-event that re-enters via $\lambda_L$. State stays purely observation-driven; the recommendation is a read-out from the post-evidence position.

### 12. The compatibility axiom under (b) + post-σ readout

The bicomodule compatibility axiom

$$(\mathrm{id}_O \triangleleft \rho) \circ \lambda \;=\; (\lambda \triangleleft \mathrm{id}_P) \circ \rho$$

reduces, on $D$-position-and-direction data, to

$$\mathrm{emit}_p(\mathrm{sharp\_L}(p, \sigma, \sigma')) \;=\; \mathrm{emit}_{f_p(\sigma)}(\sigma').$$

Under the (b) interpretation (sharp_L = concatenation) and the post-σ readout convention ($\mathrm{emit} = \mathrm{workup\_state} \circ f$), the equation reduces further to

$$\mathrm{workup\_state}(f_p(\sigma \cdot \sigma')) \;=\; \mathrm{workup\_state}(f_{f_p(\sigma)}(\sigma')),$$

which is a **tautology** by sequential composition of $f$ — the path-evaluation of $f$ at the concatenated path equals the iterated evaluation. **The axiom holds automatically** whenever path-$f$ is derived from atomic-σ tables (always true if the protocol author follows the convention).

The validator's job is therefore not to check the categorical axiom directly but to confirm the **structural property** that defines the convention: every authored `emit[(p, σ)]` agrees with `workup_state(f_at(D, p, σ))`. Any drift in the authored emit table (a protocol that emits something other than the post-σ workup state) is what the validator catches.

This is the V2 form of "guideline coherence = bicomodule axiom": coherence is the post-σ readout convention, structurally checked. The clinical content of the coherence check lives one level down — in the protocol-author's hand-authored `f` table, where each `(p, σ) → next p` entry is a clinically meaningful state transition. If the per-disease state machine is correct, the joint Differential is automatically a coherent bicomodule.

### 13. Hidden state and named order-dependence

The axiom forbids *hidden* order-dependence — recommendations that vary at the same $D$-position based on temporal context the position doesn't capture. If two histories produce different recommendations, the protocol must give them different $D$-positions.

It does not forbid *clinically* order-dependent reasoning. Order-dependent behavior (rising-troponin vs falling-troponin yielding different recommendations) is fully expressible: route the two trajectories to *different* $D$-positions by encoding the distinction in $\Phi_d$. Phenotype-refinement is the V2 unlock — it surfaces clinical state-distinctions in the named protocol structure, where the axiom can verify coherence around them.

This is the V2 generalization of v1.2's "vocabulary refinement is the unlock" insight: under v1.2, terminal-vocabulary refinement (e.g. `:disease_Dk_present` vs `:disease_Dk_absent`) was forced by free-P's well-definedness condition on `sharp_R`. Under V2, *phenotype* refinement is forced by the post-σ readout axiom on the `emit` table. The mechanism differs; the discipline is the same: clinical state distinctions must be named explicitly.

---

## Part IV — The observation alphabet $\Sigma_{\mathrm{obs}}$

### 14. The alphabet

$\Sigma_{\mathrm{obs}}$ is the alphabet of observation events that arrive in the encounter log. For the V2 toy: 8 result-events covering per-disease screen and confirm × pos/neg. The alphabet is per-protocol; the framework only requires that $\Sigma_{\mathrm{obs}}$ exist.

Naming convention: `:result_<obs>_<value>` (e.g. `:result_o1a_pos`). The per-disease event prefix is namespaced for the v1.7+ typed-recommendation refactor, where `R(y) = \sum_t y^{\mathrm{params}(t)}` extracts `(type=result, params=\{obs, value\})` from these atomic symbols.

### 15. Subjective vs. objective

$\Sigma_{\mathrm{obs}}$ subsumes the SOAP "S" and "O" of clinical notation under a single ontology: an observation is an observation, regardless of whether it was patient-reported (subjective) or instrument-measured (objective). This aligns with FHIR's `Observation` resource and OMOP's `observation` table, which both lump patient-reported items (pain scale, mood) and measured items (BP, troponin) under one type.

The naming choice — calling the comonoid $\mathcal{O}$ for "Observation" — uses the term in its broad scientific sense, not the SOAP-narrow "Objective." Redefining $\mathcal{O}$ to subsume S+O makes the ontological position visible: there is no real subjective/objective distinction in the patient-encounter-log structure.

### 16. The encounter log

An $\mathcal{O}$-position $w \in \Sigma_{\mathrm{obs}}^{\le \mathrm{depth}}$ is a finite sequence — the patient's encounter as a record. The first event is the universal root (empty log); each subsequent event extends the log by one symbol. Trajectory through $\mathcal{O}$ is exactly trajectory through the encounter.

The depth bound is a finiteness parameter: in principle the encounter can be arbitrarily long, but for a given protocol depth a max-trajectory-length bound is sufficient to enumerate everything reachable. For the toy, depth = 10 covers any reachable trajectory.

---

## Part V — The compiler

### 17. From Protocol IR to PerDiseaseV2

The `Protocol` IR in `Protocol.jl` is a per-disease tree of `ProtocolStep` and `ProtocolTerminal` nodes — the parse target of the markdown ProtocolDoc format. The V2 compiler `compile_protocol_v2(prot)` walks the IR and extracts a `PerDiseaseV2` record:

- Each `ProtocolStep(phenotype, order, on_result)` contributes a phenotype to `phenotypes`, a `phenotype → order` entry to `workup_state`, and `(phenotype, σ) → next_phenotype` entries to `transitions` for each branch in `on_result` (with $\sigma = $ `:result_<obs>_<result>`).
- Each `ProtocolTerminal(phenotype, conclusion)` contributes a phenotype with `workup_state[phenotype] = conclusion` and no outgoing transitions.

`Σ_obs` is built up as the union of all $\sigma$-events seen during the walk.

### 18. Composing per-disease Differentials

`compose_differentials_2(pd1, pd2)` takes two `PerDiseaseV2` records and assembles a joint `Differential`:

- Joint $D$-positions are the cartesian product of per-disease phenotype sets.
- Joint $\Sigma$ is the union of per-disease $\Sigma_{\mathrm{obs}}$ contributions.
- Joint workup-state is the per-disease projection followed by tupling.
- Joint $f$: for each $(p, \sigma)$, the per-disease component the σ targets gets transitioned per its per-disease table; the other component is held identity.
- Joint emit follows post-σ readout from joint $f$.

The compiled Differential `D_v2_compiled` is the joint over `D1_v2` and `D2_v2`, which compile from the in-code `D1_protocol` and `D2_protocol`. It has 25 $D$-positions (5 phenotypes per disease × 5) — distinct from the manually-authored `D_v2_toy` (16 positions, via_o1a/via_o1b collapsed to a single `:a_Dk_absent`).

### 19. The two toys

Two valid V2 Differentials coexist in the codebase:

- **`D_v2_toy`** — manually authored, 16 positions, 4 phenotypes per disease. The deliberate simplification: collapses the v1.x via_o1a/via_o1b distinction into a single `:a_Dk_absent`. Used in tests and demos as the canonical illustrative example.
- **`D_v2_compiled`** — produced by the compiler, 25 positions, 5 phenotypes per disease (preserves via_o1a/via_o1b). Demonstrates that existing per-disease ProtocolDoc files compile to a coherent V2 Differential without rewriting.

Both pass the V2 axiom. The two-toy coexistence verifies that hand-authoring and compilation produce consistent V2 structure.

---

## Part VI — The simulator and renderers

### 20. The simulator

`simulate_v2(patient; mode, max_steps)` drives `D_v2_toy` from an initial $D$-position to a joint terminal. The `Patient` coalgebra responds with `:neg`/`:pos` to each issued observation; the simulator translates the response into a Σ-event (`_result_to_sigma_v2`), advances $D$ via $f$, and records the trajectory.

Two modes:

- **`:sequential`** — one disease advances per step (D1 first while non-terminal, then D2). Each step fires exactly one σ-event.
- **`:panel`** — both non-terminal diseases advance per step. Per-disease panel fires the screen event; if the screen returns `:pos` and the new state is non-terminal, the confirm event fires immediately (2 σ in one step). Joint panel = both per-disease panels in the same trajectory step.

A `TrajectoryStepV2` records `step`, `p`, `workup_state`, `obs_issued`, `results`, `sigma_events` (the σ events fired during the transition into this step), and `mode`. The σ events are recorded explicitly — no implicit mode-typing of edges.

### 21. The renderers

Two Mermaid renderers in `Render.jl`:

- **`mermaid_differential(D, workup_state; direction, show_terminals, group_by)`** — D's f-graph: $D$-positions as nodes labeled with `(p)` and `(workup_state(p))`; edges are σ-event transitions from `D.f`. Joint-terminal positions render in green. The `group_by` parameter wraps positions in Mermaid `subgraph` blocks (e.g. `p -> p[2]` to row by D2-state, useful for visualizing the n×m grid).
- **`mermaid_trajectory_v2(traj)`** — a V2 simulator trajectory as a flowchart. Each step is a labeled node; edges between consecutive steps are labeled with the σ events fired (multi-σ panel steps stack labels via `<br/>`). Terminal step renders in green.

The pre-V2 v1.x renderers (mermaid_protocol, mermaid_order_graph, markdown_*, catlab_*, print_*) were removed in Phase 3 deletion along with the v1.x scaffolding they rendered.

---

## Part VII — Coherence Properties

### 22. The structural axiom

The V2 coherence axiom is the post-σ readout consistency condition (§11–12):

$$\forall (p, \sigma) \text{ authored in } D.\mathrm{emit}: \quad \mathrm{emit}[(p, \sigma)] \;=\; \mathrm{workup\_state}(f_p(\sigma)).$$

`validate_v2_axiom(D, workup_state)` walks every authored `emit` entry and reports the first violation. The function passes iff every entry agrees with `workup_state ∘ f`.

This is structural because under (b) + post-σ readout the categorical compatibility axiom holds by tautology (§12); the validator confirms the protocol author followed the convention rather than verifying the equation directly.

### 23. Per-protocol coherence content

The clinical-coherence content of a protocol lives in the per-disease $f$ table — each `(phenotype, σ) → next_phenotype` entry is a clinically meaningful state transition. The compiler's `compile_protocol_v2` derives this from the `Protocol` IR mechanically; the protocol author's authoring task is exactly that of writing a clinically correct per-disease state machine.

The joint coherence story (when multiple diseases interact) lives in the joint $f$ assembled by `compose_differentials_2`. For the toy with disjoint per-disease σ-events, joint $f$ is the obvious tensor of per-disease $f$'s — no cross-disease coherence to check. When future extensions introduce σ-events that affect multiple diseases simultaneously (e.g. anticoagulation status affecting PE workup AND GI-bleed workup), each affected disease's per-disease table contributes; joint coherence becomes the structural agreement of those contributions at shared σ.

### 24. Failure diagnostics

A failure of `validate_v2_axiom` is interpreted as authoring drift from the post-σ readout convention — specifically, the authored `emit` differs from what `workup_state ∘ f` predicts. The validator reports the offending `(p, σ)` triple plus the actual vs expected emission. The diagnostic is local (per-triple) and points directly at the inconsistency.

A failure of the per-disease state machine itself (logically impossible transitions, missing `on_result` branches, etc.) surfaces at parse time — `validate_xrefs` in `ProtocolDoc.jl` checks that all symbol references in the markdown are valid before the IR is built.

---

## Part VIII — Authoring Surface

### 25. The ProtocolDoc format

Per-disease protocols are authored in markdown with embedded YAML blocks. Format:

- YAML front-matter (between `---` markers) carries `protocol_id`, `title`, `version`, `authors`, `disease`, `description`.
- Fenced YAML blocks tagged by language:
  - ` ```yaml-vocab ` — observations vocabulary (required)
  - ` ```yaml-orders ` — orders vocabulary (required)
  - ` ```yaml-conclusions ` — conclusions vocabulary (required)
  - ` ```yaml-phenotypes ` — phenotype display/description (optional)
  - ` ```yaml-protocol ` — the workflow tree (required)
- Markdown body around the blocks carries clinical narrative.

`parse_protocol(path)` in `ProtocolDoc.jl` reads a markdown file, parses each YAML block, runs cross-reference validation (`validate_xrefs`), and returns a `Protocol` IR struct. Cross-reference validation enforces: every `order` exists in `yaml-orders`; the obs derived from each order (via `obs_from_order`) exists in `yaml-vocab`; every `on:` key is a declared result for that observation; every `conclusion` exists in `yaml-conclusions`; phenotypes are not reused; if `yaml-phenotypes` is present, every phenotype is declared there.

### 26. Sample protocols

The toy uses two protocols, `protocols/D1.md` and `protocols/D2.md`, each defining a screen-then-confirm workup over a single per-disease observation pair. The IR resulting from parsing each is also defined directly as Julia consts (`D1_protocol`, `D2_protocol` in `Protocol.jl`) — the two paths produce equivalent results, which the v1.6.B PR1 round-trip tests verified before being subsumed into the V2 compiler tests.

### 27. From ProtocolDoc to running CDS

The full pipeline:

1. Author markdown ProtocolDoc → `parse_protocol(path)` → `Protocol` IR
2. `compile_protocol_v2(prot)` → `PerDiseaseV2` record (per disease)
3. `compose_differentials_2(pd1, pd2)` → joint `Differential` plus its `workup_state` callback
4. `validate_v2_axiom(D, workup_state)` confirms post-σ readout consistency
5. `simulate_v2(patient; mode)` produces a trajectory; `mermaid_*` renders for inspection

Step 4 is invariant under Phase 2 conventions (always passes if the compiler did its job); explicit checking is included as a defensive guard against future authoring conventions that drift from post-σ readout.

---

## Part IX — Implementation status and deferred work

### 28. Current state

V2 master-D is the canonical architecture, implemented end-to-end:

- `Differential.jl`: `OComonoid`, `Differential` struct, axiom validator, `tiny_D`, `D_v2_toy`
- `ProtocolCompileV2.jl`: `PerDiseaseV2`, `compile_protocol_v2`, `compose_differentials_2`, `D_v2_compiled`
- `SimulateV2.jl`: simulator with sequential and panel modes
- `Render.jl`: V2 Mermaid renderers
- `Protocol.jl`, `ProtocolDoc.jl`: per-disease IR + markdown parser (carry-over from v1.4)
- `Patient.jl`, `Vocabulary.jl`, `Polynomials.jl`: minimal supporting infrastructure

The pre-V2 scaffolding (per-disease A bicomodules, joint $A_{\mathrm{joint}}$ via formal $\otimes$, the compiled $\mathcal{S}_d$/$\mathcal{P}_d$/`mbar_*` machinery, the v1.6.B H-fibration and `realize`/`Θ` parallel maps) was deleted in Phase 3 cleanup (2026-05-01). The repo is V2-only.

### 29. Deferred to v1.7+

- **Σ_prob (probability layer).** A separate construction (note the naming collision with the v1.6.B Σ_prob, now retired) capturing weighted/Bayesian reasoning over $D$-positions. Composes with V2 cleanly: probability lives on top of the deterministic $f$.
- **Typed recommendation polynomial $R$.** Refactor recommendation alphabet labels (currently flat namespaced atoms like `:order_o1a`) into structured `R(y) = \sum_t y^{\mathrm{params}(t)}` form. Buys typed-R for FHIR mapping and structured emission output.
- **Supports-as-explainability.** From the Set-sets blog post (Fairbanks): for any fired recommendation at a $D$-position, compute the minimal observation-set the recommendation actually depends on. Falls out of $D$'s polynomial structure mechanically. Implementation: walk $D$ backward from a fired P-event to the supporting σ-events.
- **Kan-extension audit/likelihood arm.** $D : \mathcal{O} \nrightarrow \mathcal{P}$ canonically gives both inference (observations → recommendations) and likelihood (recommendation hypothesis → expected observations) via different Kan extensions. Same authored $D$, different traversal.
- **Materialized $\mathcal{O}$ comonoid.** Replace the parameter-wrapper `OComonoid` with a Poly.jl-backed `cofree_comonoid(Q, depth)` once Kan-extension queries need it.

### 30. Deferred to v2

- **Topological generalization.** Comonads on Set generalize categories AND topological spaces (Carlson/Fairbanks/Spivak forthcoming). Generalizing $\mathcal{O}$ from a polynomial comonad to a general comonad-on-Set buys continuous patient state, sheaf-coherence robustness, and local-to-global protocol coherence.
- **D_0 / chief-complaint routing.** Currently the initial $D$-position is hand-authored ad hoc per scenario. A first-class CC-routing layer would parameterize $D_0$ by the CC observation and provide structural coherence between the CC alphabet and $\Sigma_{\mathrm{obs}}$.
- **`clinician_override` semantics.** Formalize first-class `clinician_override(d, ruled-in | ruled-out)` σ-events with bypass semantics for the per-disease state machine.

---

## References

- Niu and Spivak, [*Polynomial Functors: A Mathematical Theory of Interaction*](https://topos.site/poly-book.pdf).
- Ahman and Uustalu, *Categories of Containers* and follow-up work establishing the comonoid-in-Poly = small category equivalence.
- Fairbanks, *Bicomodules in Poly* (Topos Institute blog post). The bicomodule-as-data-migration reading and the Kan-extension bidirectionality story.
- Fairbanks, *Set-sets* (Topos Institute blog post). The supports construction underlying v1.7+ explainability.
- Friedman, C.P. (2009). [*A "Fundamental Theorem" of Biomedical Informatics*](https://academic.oup.com/jamia/article-pdf/16/2/169/49951/16-2-169.pdf). JAMIA 16(2): 169–170. The structural inspiration for representing CDS as an interaction trajectory rather than a snapshot.
