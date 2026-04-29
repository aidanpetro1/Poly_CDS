# Protocol D1 workflow



```mermaid
flowchart TD
    a_D1_initial["a_D1_initial<br/>order_o1a"]
    a_D1_absent_via_o1a[/"a_D1_absent_via_o1a<br/>⇒ disease_D1_absent"/]
    a_D1_pending["a_D1_pending<br/>order_o1b"]
    a_D1_absent_via_o1b[/"a_D1_absent_via_o1b<br/>⇒ disease_D1_absent"/]
    a_D1[/"a_D1<br/>⇒ disease_D1_present"/]

    a_D1_initial -->|neg| a_D1_absent_via_o1a
    a_D1_initial -->|pos| a_D1_pending
    a_D1_pending -->|neg| a_D1_absent_via_o1b
    a_D1_pending -->|pos| a_D1
```
