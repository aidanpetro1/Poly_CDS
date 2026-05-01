# V2 master-D (D_v2_toy) — transition structure

The V2 master bicomodule `D : O ⇸ P` for the D1/D2 toy. Each node is
a D-position (joint per-disease phenotype tuple) labeled with its
workup-state pointer (= recommendation under post-σ readout). Edges
are σ event firings drawn from `Σ_obs_v2`. Joint-terminal positions
(both diseases at `:a_Dk` or `:a_Dk_absent`) styled in green.

Grouped into Mermaid subgraphs by D2-state: each subgraph contains
the four D-positions sharing that D2 component, organizing the
4×4 grid visually. 16 D-positions, ~32 σ-event transitions.

```mermaid
flowchart LR
    subgraph grp_a_D2_initial ["a_D2_initial"]
        d_a_D1_initial_a_D2_initial["(a_D1_initial, a_D2_initial)<br/>━━━<br/>(order_o1a, order_o2a)"]
        d_a_D1_pending_a_D2_initial["(a_D1_pending, a_D2_initial)<br/>━━━<br/>(order_o1b, order_o2a)"]
        d_a_D1_a_D2_initial["(a_D1, a_D2_initial)<br/>━━━<br/>(disease_D1_present, order_o2a)"]
        d_a_D1_absent_a_D2_initial["(a_D1_absent, a_D2_initial)<br/>━━━<br/>(disease_D1_absent, order_o2a)"]
    end
    subgraph grp_a_D2_pending ["a_D2_pending"]
        d_a_D1_initial_a_D2_pending["(a_D1_initial, a_D2_pending)<br/>━━━<br/>(order_o1a, order_o2b)"]
        d_a_D1_pending_a_D2_pending["(a_D1_pending, a_D2_pending)<br/>━━━<br/>(order_o1b, order_o2b)"]
        d_a_D1_a_D2_pending["(a_D1, a_D2_pending)<br/>━━━<br/>(disease_D1_present, order_o2b)"]
        d_a_D1_absent_a_D2_pending["(a_D1_absent, a_D2_pending)<br/>━━━<br/>(disease_D1_absent, order_o2b)"]
    end
    subgraph grp_a_D2 ["a_D2"]
        d_a_D1_initial_a_D2["(a_D1_initial, a_D2)<br/>━━━<br/>(order_o1a, disease_D2_present)"]
        d_a_D1_pending_a_D2["(a_D1_pending, a_D2)<br/>━━━<br/>(order_o1b, disease_D2_present)"]
        d_a_D1_a_D2["(a_D1, a_D2)<br/>━━━<br/>(disease_D1_present, disease_D2_present)"]
        d_a_D1_absent_a_D2["(a_D1_absent, a_D2)<br/>━━━<br/>(disease_D1_absent, disease_D2_present)"]
    end
    subgraph grp_a_D2_absent ["a_D2_absent"]
        d_a_D1_initial_a_D2_absent["(a_D1_initial, a_D2_absent)<br/>━━━<br/>(order_o1a, disease_D2_absent)"]
        d_a_D1_pending_a_D2_absent["(a_D1_pending, a_D2_absent)<br/>━━━<br/>(order_o1b, disease_D2_absent)"]
        d_a_D1_a_D2_absent["(a_D1, a_D2_absent)<br/>━━━<br/>(disease_D1_present, disease_D2_absent)"]
        d_a_D1_absent_a_D2_absent["(a_D1_absent, a_D2_absent)<br/>━━━<br/>(disease_D1_absent, disease_D2_absent)"]
    end

    d_a_D1_pending_a_D2_absent -->|result_o1b_neg| d_a_D1_absent_a_D2_absent
    d_a_D1_a_D2_pending -->|result_o2b_neg| d_a_D1_a_D2_absent
    d_a_D1_initial_a_D2_initial -->|result_o2a_neg| d_a_D1_initial_a_D2_absent
    d_a_D1_a_D2_initial -->|result_o2a_pos| d_a_D1_a_D2_pending
    d_a_D1_initial_a_D2_initial -->|result_o1a_neg| d_a_D1_absent_a_D2_initial
    d_a_D1_initial_a_D2_pending -->|result_o2b_pos| d_a_D1_initial_a_D2
    d_a_D1_pending_a_D2_pending -->|result_o2b_neg| d_a_D1_pending_a_D2_absent
    d_a_D1_absent_a_D2_pending -->|result_o2b_pos| d_a_D1_absent_a_D2
    d_a_D1_pending_a_D2_initial -->|result_o2a_neg| d_a_D1_pending_a_D2_absent
    d_a_D1_initial_a_D2_pending -->|result_o1a_pos| d_a_D1_pending_a_D2_pending
    d_a_D1_pending_a_D2_pending -->|result_o1b_neg| d_a_D1_absent_a_D2_pending
    d_a_D1_pending_a_D2 -->|result_o1b_pos| d_a_D1_a_D2
    d_a_D1_initial_a_D2_initial -->|result_o1a_pos| d_a_D1_pending_a_D2_initial
    d_a_D1_initial_a_D2_pending -->|result_o1a_neg| d_a_D1_absent_a_D2_pending
    d_a_D1_pending_a_D2 -->|result_o1b_neg| d_a_D1_absent_a_D2
    d_a_D1_initial_a_D2 -->|result_o1a_pos| d_a_D1_pending_a_D2
    d_a_D1_initial_a_D2_pending -->|result_o2b_neg| d_a_D1_initial_a_D2_absent
    d_a_D1_a_D2_pending -->|result_o2b_pos| d_a_D1_a_D2
    d_a_D1_a_D2_initial -->|result_o2a_neg| d_a_D1_a_D2_absent
    d_a_D1_initial_a_D2 -->|result_o1a_neg| d_a_D1_absent_a_D2
    d_a_D1_initial_a_D2_initial -->|result_o2a_pos| d_a_D1_initial_a_D2_pending
    d_a_D1_absent_a_D2_initial -->|result_o2a_pos| d_a_D1_absent_a_D2_pending
    d_a_D1_pending_a_D2_pending -->|result_o1b_pos| d_a_D1_a_D2_pending
    d_a_D1_pending_a_D2_initial -->|result_o1b_pos| d_a_D1_a_D2_initial
    d_a_D1_pending_a_D2_initial -->|result_o1b_neg| d_a_D1_absent_a_D2_initial
    d_a_D1_pending_a_D2_initial -->|result_o2a_pos| d_a_D1_pending_a_D2_pending
    d_a_D1_pending_a_D2_absent -->|result_o1b_pos| d_a_D1_a_D2_absent
    d_a_D1_absent_a_D2_pending -->|result_o2b_neg| d_a_D1_absent_a_D2_absent
    d_a_D1_absent_a_D2_initial -->|result_o2a_neg| d_a_D1_absent_a_D2_absent
    d_a_D1_pending_a_D2_pending -->|result_o2b_pos| d_a_D1_pending_a_D2
    d_a_D1_initial_a_D2_absent -->|result_o1a_neg| d_a_D1_absent_a_D2_absent
    d_a_D1_initial_a_D2_absent -->|result_o1a_pos| d_a_D1_pending_a_D2_absent

    classDef terminal fill:#d4edda,stroke:#155724,stroke-width:2px
    class d_a_D1_a_D2,d_a_D1_absent_a_D2,d_a_D1_a_D2_absent,d_a_D1_absent_a_D2_absent terminal
```
