# Order graph — free-P for D1

The directed graph of the planned-pathway transitions. Order nodes are
rectangles; clinical-conclusion nodes (`disease_*_present`,
`disease_*_absent`) are parallelograms. Each edge is a free-P
generator; the bicomodule's `sharp_R` extends along these.

```mermaid
flowchart LR
    disease_D1_absent[/"disease_D1_absent"/]
    disease_D1_present[/"disease_D1_present"/]
    order_o1a["order_o1a"]
    order_o1b["order_o1b"]

    order_o1a --> disease_D1_absent
    order_o1a --> order_o1b
    order_o1b --> disease_D1_absent
    order_o1b --> disease_D1_present
```
