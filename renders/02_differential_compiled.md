# V2 master-D (D_v2_compiled) — compiled from D1+D2 protocols

The Differential produced by `compile_protocol_v2` + `compose_differentials_2`
on the existing v1.x `D1_protocol` and `D2_protocol`. Distinct from
`D_v2_toy` — preserves the via_o1a/via_o1b distinction, giving 5
phenotypes per disease and 25 D-positions.

Grouped by D2-state. Larger graph than D_v2_toy; useful for
visualizing the full state space.

```mermaid
flowchart LR
    subgraph grp_a_D2_initial ["a_D2_initial"]
        d_a_D1_initial_a_D2_initial["(a_D1_initial, a_D2_initial)<br/>━━━<br/>(order_o1a, order_o2a)"]
        d_a_D1_absent_via_o1a_a_D2_initial["(a_D1_absent_via_o1a, a_D2_initial)<br/>━━━<br/>(disease_D1_absent, order_o2a)"]
        d_a_D1_pending_a_D2_initial["(a_D1_pending, a_D2_initial)<br/>━━━<br/>(order_o1b, order_o2a)"]
        d_a_D1_absent_via_o1b_a_D2_initial["(a_D1_absent_via_o1b, a_D2_initial)<br/>━━━<br/>(disease_D1_absent, order_o2a)"]
        d_a_D1_a_D2_initial["(a_D1, a_D2_initial)<br/>━━━<br/>(disease_D1_present, order_o2a)"]
    end
    subgraph grp_a_D2_absent_via_o2a ["a_D2_absent_via_o2a"]
        d_a_D1_initial_a_D2_absent_via_o2a["(a_D1_initial, a_D2_absent_via_o2a)<br/>━━━<br/>(order_o1a, disease_D2_absent)"]
        d_a_D1_absent_via_o1a_a_D2_absent_via_o2a["(a_D1_absent_via_o1a, a_D2_absent_via_o2a)<br/>━━━<br/>(disease_D1_absent, disease_D2_absent)"]
        d_a_D1_pending_a_D2_absent_via_o2a["(a_D1_pending, a_D2_absent_via_o2a)<br/>━━━<br/>(order_o1b, disease_D2_absent)"]
        d_a_D1_absent_via_o1b_a_D2_absent_via_o2a["(a_D1_absent_via_o1b, a_D2_absent_via_o2a)<br/>━━━<br/>(disease_D1_absent, disease_D2_absent)"]
        d_a_D1_a_D2_absent_via_o2a["(a_D1, a_D2_absent_via_o2a)<br/>━━━<br/>(disease_D1_present, disease_D2_absent)"]
    end
    subgraph grp_a_D2_pending ["a_D2_pending"]
        d_a_D1_initial_a_D2_pending["(a_D1_initial, a_D2_pending)<br/>━━━<br/>(order_o1a, order_o2b)"]
        d_a_D1_absent_via_o1a_a_D2_pending["(a_D1_absent_via_o1a, a_D2_pending)<br/>━━━<br/>(disease_D1_absent, order_o2b)"]
        d_a_D1_pending_a_D2_pending["(a_D1_pending, a_D2_pending)<br/>━━━<br/>(order_o1b, order_o2b)"]
        d_a_D1_absent_via_o1b_a_D2_pending["(a_D1_absent_via_o1b, a_D2_pending)<br/>━━━<br/>(disease_D1_absent, order_o2b)"]
        d_a_D1_a_D2_pending["(a_D1, a_D2_pending)<br/>━━━<br/>(disease_D1_present, order_o2b)"]
    end
    subgraph grp_a_D2_absent_via_o2b ["a_D2_absent_via_o2b"]
        d_a_D1_initial_a_D2_absent_via_o2b["(a_D1_initial, a_D2_absent_via_o2b)<br/>━━━<br/>(order_o1a, disease_D2_absent)"]
        d_a_D1_absent_via_o1a_a_D2_absent_via_o2b["(a_D1_absent_via_o1a, a_D2_absent_via_o2b)<br/>━━━<br/>(disease_D1_absent, disease_D2_absent)"]
        d_a_D1_pending_a_D2_absent_via_o2b["(a_D1_pending, a_D2_absent_via_o2b)<br/>━━━<br/>(order_o1b, disease_D2_absent)"]
        d_a_D1_absent_via_o1b_a_D2_absent_via_o2b["(a_D1_absent_via_o1b, a_D2_absent_via_o2b)<br/>━━━<br/>(disease_D1_absent, disease_D2_absent)"]
        d_a_D1_a_D2_absent_via_o2b["(a_D1, a_D2_absent_via_o2b)<br/>━━━<br/>(disease_D1_present, disease_D2_absent)"]
    end
    subgraph grp_a_D2 ["a_D2"]
        d_a_D1_initial_a_D2["(a_D1_initial, a_D2)<br/>━━━<br/>(order_o1a, disease_D2_present)"]
        d_a_D1_absent_via_o1a_a_D2["(a_D1_absent_via_o1a, a_D2)<br/>━━━<br/>(disease_D1_absent, disease_D2_present)"]
        d_a_D1_pending_a_D2["(a_D1_pending, a_D2)<br/>━━━<br/>(order_o1b, disease_D2_present)"]
        d_a_D1_absent_via_o1b_a_D2["(a_D1_absent_via_o1b, a_D2)<br/>━━━<br/>(disease_D1_absent, disease_D2_present)"]
        d_a_D1_a_D2["(a_D1, a_D2)<br/>━━━<br/>(disease_D1_present, disease_D2_present)"]
    end

    d_a_D1_absent_via_o1b_a_D2_initial -->|result_o2a_pos| d_a_D1_absent_via_o1b_a_D2_pending
    d_a_D1_initial_a_D2_initial -->|result_o2a_neg| d_a_D1_initial_a_D2_absent_via_o2a
    d_a_D1_pending_a_D2_absent_via_o2a -->|result_o1b_pos| d_a_D1_a_D2_absent_via_o2a
    d_a_D1_a_D2_pending -->|result_o2b_neg| d_a_D1_a_D2_absent_via_o2b
    d_a_D1_a_D2_initial -->|result_o2a_pos| d_a_D1_a_D2_pending
    d_a_D1_initial_a_D2_initial -->|result_o1a_neg| d_a_D1_absent_via_o1a_a_D2_initial
    d_a_D1_pending_a_D2_absent_via_o2a -->|result_o1b_neg| d_a_D1_absent_via_o1b_a_D2_absent_via_o2a
    d_a_D1_initial_a_D2_pending -->|result_o2b_pos| d_a_D1_initial_a_D2
    d_a_D1_absent_via_o1a_a_D2_pending -->|result_o2b_pos| d_a_D1_absent_via_o1a_a_D2
    d_a_D1_pending_a_D2_pending -->|result_o2b_neg| d_a_D1_pending_a_D2_absent_via_o2b
    d_a_D1_initial_a_D2_absent_via_o2a -->|result_o1a_neg| d_a_D1_absent_via_o1a_a_D2_absent_via_o2a
    d_a_D1_pending_a_D2_initial -->|result_o2a_neg| d_a_D1_pending_a_D2_absent_via_o2a
    d_a_D1_initial_a_D2_pending -->|result_o1a_pos| d_a_D1_pending_a_D2_pending
    d_a_D1_pending_a_D2_absent_via_o2b -->|result_o1b_pos| d_a_D1_a_D2_absent_via_o2b
    d_a_D1_pending_a_D2_pending -->|result_o1b_neg| d_a_D1_absent_via_o1b_a_D2_pending
    d_a_D1_initial_a_D2_absent_via_o2a -->|result_o1a_pos| d_a_D1_pending_a_D2_absent_via_o2a
    d_a_D1_pending_a_D2 -->|result_o1b_pos| d_a_D1_a_D2
    d_a_D1_initial_a_D2_initial -->|result_o1a_pos| d_a_D1_pending_a_D2_initial
    d_a_D1_initial_a_D2_pending -->|result_o1a_neg| d_a_D1_absent_via_o1a_a_D2_pending
    d_a_D1_absent_via_o1b_a_D2_initial -->|result_o2a_neg| d_a_D1_absent_via_o1b_a_D2_absent_via_o2a
    d_a_D1_initial_a_D2 -->|result_o1a_pos| d_a_D1_pending_a_D2
    d_a_D1_pending_a_D2 -->|result_o1b_neg| d_a_D1_absent_via_o1b_a_D2
    d_a_D1_initial_a_D2_pending -->|result_o2b_neg| d_a_D1_initial_a_D2_absent_via_o2b
    d_a_D1_a_D2_pending -->|result_o2b_pos| d_a_D1_a_D2
    d_a_D1_absent_via_o1a_a_D2_initial -->|result_o2a_pos| d_a_D1_absent_via_o1a_a_D2_pending
    d_a_D1_initial_a_D2_absent_via_o2b -->|result_o1a_neg| d_a_D1_absent_via_o1a_a_D2_absent_via_o2b
    d_a_D1_pending_a_D2_absent_via_o2b -->|result_o1b_neg| d_a_D1_absent_via_o1b_a_D2_absent_via_o2b
    d_a_D1_a_D2_initial -->|result_o2a_neg| d_a_D1_a_D2_absent_via_o2a
    d_a_D1_initial_a_D2 -->|result_o1a_neg| d_a_D1_absent_via_o1a_a_D2
    d_a_D1_initial_a_D2_initial -->|result_o2a_pos| d_a_D1_initial_a_D2_pending
    d_a_D1_pending_a_D2_pending -->|result_o1b_pos| d_a_D1_a_D2_pending
    d_a_D1_pending_a_D2_initial -->|result_o1b_pos| d_a_D1_a_D2_initial
    d_a_D1_absent_via_o1a_a_D2_initial -->|result_o2a_neg| d_a_D1_absent_via_o1a_a_D2_absent_via_o2a
    d_a_D1_absent_via_o1a_a_D2_pending -->|result_o2b_neg| d_a_D1_absent_via_o1a_a_D2_absent_via_o2b
    d_a_D1_pending_a_D2_initial -->|result_o1b_neg| d_a_D1_absent_via_o1b_a_D2_initial
    d_a_D1_pending_a_D2_initial -->|result_o2a_pos| d_a_D1_pending_a_D2_pending
    d_a_D1_absent_via_o1b_a_D2_pending -->|result_o2b_neg| d_a_D1_absent_via_o1b_a_D2_absent_via_o2b
    d_a_D1_initial_a_D2_absent_via_o2b -->|result_o1a_pos| d_a_D1_pending_a_D2_absent_via_o2b
    d_a_D1_pending_a_D2_pending -->|result_o2b_pos| d_a_D1_pending_a_D2
    d_a_D1_absent_via_o1b_a_D2_pending -->|result_o2b_pos| d_a_D1_absent_via_o1b_a_D2

    classDef terminal fill:#d4edda,stroke:#155724,stroke-width:2px
    class d_a_D1_a_D2 terminal
```
