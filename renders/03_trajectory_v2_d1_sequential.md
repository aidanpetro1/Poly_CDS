# V2 trajectory — Patient_D1, sequential mode

Simulator trace through `D_v2_toy` for `Patient_D1`. Each step shows
the D-position and joint workup state; edges are labeled with the σ
events fired during that transition.

```mermaid
flowchart LR
    t0["step 0<br/>(a_D1_initial, a_D2_initial)<br/>━━━<br/>(order_o1a, order_o2a)"]
    t1["step 1<br/>(a_D1_pending, a_D2_initial)<br/>━━━<br/>(order_o1b, order_o2a)"]
    t2["step 2<br/>(a_D1, a_D2_initial)<br/>━━━<br/>(disease_D1_present, order_o2a)"]
    t3["step 3 ✓<br/>(a_D1, a_D2_absent)<br/>━━━<br/>(disease_D1_present, disease_D2_absent)"]

    t0 -->|result_o1a_pos| t1
    t1 -->|result_o1b_pos| t2
    t2 -->|result_o2a_neg| t3

    classDef terminal fill:#d4edda,stroke:#155724,stroke-width:2px
    class t3 terminal
```
