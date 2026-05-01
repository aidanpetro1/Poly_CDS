# V2 trajectory — Patient_D1, panel mode

Panel mode advances both non-terminal diseases per step; per-disease
panel + screen-positive fires confirm immediately (2 σ in one step).
The trajectory reaches the same final state as sequential, in fewer
steps.

```mermaid
flowchart LR
    t0["step 0<br/>(a_D1_initial, a_D2_initial)<br/>━━━<br/>(order_o1a, order_o2a)"]
    t1["step 1 ✓<br/>(a_D1, a_D2_absent)<br/>━━━<br/>(disease_D1_present, disease_D2_absent)"]

    t0 -->|result_o1a_pos<br/>result_o1b_pos<br/>result_o2a_neg| t1

    classDef terminal fill:#d4edda,stroke:#155724,stroke-width:2px
    class t1 terminal
```
