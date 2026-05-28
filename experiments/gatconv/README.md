# GATConv FX characterization

**Assessment: YELLOW** — `scatter`→sparse adapter required, structurally
expected.

The full pipeline `PyG GATConv → torch_mlir.fx.export_and_import →
torch-backend-to-linalg → mlir-opt --sparsifier` fails at sparsifier with
the same dialect-not-found error as fx-sparsity's a-gcn. The block is
identical in kind (`tm_tensor.scatter`); it differs only in multiplicity
— GAT lowers to **four** scatter sites where GCN had one, because the
edge-softmax decomposes into two segmented reductions in addition to the
final aggregation. PyG's `MessagePassing`-as-is is not a viable ingress
path; the unfused-GAT ingress will need to express the four segmented
operations directly in sparse-tensor IR.

Source artifacts: [run.py](run.py) and [dumps/](dumps/).
Pinned commits at characterization time:
[third_party/README.md](../../third_party/README.md).

---

## Procedure

Trace a single PyG `GATConv(in=4, out=2, heads=2, concat=True,
add_self_loops=False, bias=False)` over the same 3-node / 3-edge
synthetic graph used by fx-sparsity (`edge_index = [[0,1,0],[1,2,2]]`),
in `eval()` mode, no training. Three IR stages captured per the day-zero
pattern (raw torch / post torch-to-linalg / post `--sparsifier`). Run
script: [run.py](run.py).

GATConv config is picked for IR clarity, not realism: small in/out, two
heads is enough to expose the multi-head dimension through the lowered
IR, `concat=True` keeps the heads axis explicit through the output, and
`add_self_loops` / `bias` are disabled so the IR focuses on the
attention + message-pass core rather than bookkeeping.

---

## Findings

### Raw torch dialect ([gat.1-raw-torch.mlir](dumps/gat.1-raw-torch.mlir), 142 lines)

The FX importer captures PyG's `MessagePassing` decomposition directly.
Walking the op sequence, GAT's math maps onto torch-dialect ops as
follows:

| Math | Torch-dialect ops | SSA range |
|---|---|---|
| 1. Linear projection per head: `Wx ∈ ℝ^{N×H×D}` | `aten.linear`, `aten.view` | `%0`–`%3` |
| 2. Attention pre-compute: `α_src[N,H]`, `α_dst[N,H]` (the two halves of `a^T·[Wx_i;Wx_j]` per node) | `aten.mul`, `aten.sum.dim_IntList` | `%4`–`%11` |
| 3. **Per-edge attention** (SDDMM-shape): `e_ij = LeakyReLU(α_src[i] + α_dst[j])` | 2× `aten.index_select`, `aten.add`, `aten.leaky_relu` | `%12`–`%17` |
| 4. **Edge-softmax max**: `max_j(e_ij)` (segmented over destinations) | `aten.scatter_reduce.two` (`reduce="amax"`, `include_self=false`) | `%18`–`%25` |
| 5. Subtract + exp: `exp(e_ij − max[dst])` | `aten.index_select`, `aten.sub`, `aten.exp` | `%26`–`%28` |
| 6. **Edge-softmax sum**: `Σ_j exp(.)` (segmented over destinations) | `aten.scatter_add` | `%29`–`%36` |
| 7. Edge-softmax normalize: `α̂_ij = exp(.) / (sum[dst] + ε)` | `aten.index_select`, `aten.div`, `aten.add.Scalar` | `%37`–`%39` |
| 8. **Weighted aggregation** (SpMM-shape, attention-weighted): `out[j] = Σ_i α̂_ij · Wx[i]` | `aten.index_select`, `aten.mul`, `aten.scatter_add` (3D index) | `%40`–`%51` |
| 9. Concat heads: `[N,H,D] → [N,H·D]` | `aten.view` | `%52`–`%53` |

PyG's "additive attention" decomposition (`α_src[N,H]` + `α_dst[N,H]`
combined per-edge via two gathers) is structurally an SDDMM, expressed
as two `index_select`s + an `add` rather than a single op. The final
aggregation is SpMM-shape, expressed via gather + multiply +
`scatter_add` over a 3D index — same gather/scatter pattern GCN used,
just lifted into the `[N,H,D]` heads tensor.

### Post torch-to-linalg ([gat.2-linalg.mlir](dumps/gat.2-linalg.mlir), 249 lines)

Most of the IR lowers cleanly. Op-type histogram of the lowered module:

| Category | Count | Status |
|---|---|---|
| `linalg.matmul` + `linalg.transpose` (for `Wx`) | 1 + 1 | ✓ sparsifier-friendly |
| `linalg.generic` (per-edge gathers, expansions, elementwise softmax) | 24 | ✓ sparsifier-friendly |
| `math.exp`, `arith.divf`, `arith.subf`, `arith.maximumf` | scattered | ✓ sparsifier-friendly |
| **`tm_tensor.scatter`** | **4** | **blocks sparsifier** |

The four `tm_tensor.scatter` sites correspond exactly to the four
segmented operations identified in the raw torch:

| # | Line | Body | What it does |
|---|---|---|---|
| 1 | [126](dumps/gat.2-linalg.mlir#L126) | `tm_tensor.yield %arg2` (overwrite) | Init half of segmented amax — torch's `scatter_reduce(include_self=false)` lowers to a two-step pattern |
| 2 | [130](dumps/gat.2-linalg.mlir#L130) | `arith.maximumf` | Accumulate half of segmented amax — edge-softmax max-per-destination |
| 3 | [165](dumps/gat.2-linalg.mlir#L165) | `arith.addf` | Segmented sum for the edge-softmax denominator |
| 4 | [230](dumps/gat.2-linalg.mlir#L230) | `arith.addf`, `dimension_map = [0,1,2]` (3D) | Weighted SpMM aggregation: scatters `[E,H,D]` weighted messages into the `[N,H,D]` accumulator |

The dense matmul for `Wx` and all the per-edge gather/elementwise
operations sit between the scatter sites and would lower cleanly on
their own. The edge-softmax bookkeeping triples the scatter count vs.
plain GCN (1 scatter → 4 scatters for GAT) but introduces no new
categories of obstruction.

### Post `--sparsifier` ([gat.3-sparsifier-error.txt](dumps/gat.3-sparsifier-error.txt))

```
error: Dialect `tm_tensor' not found for custom op 'tm_tensor.scatter'
```

Plain `mlir-opt --sparsifier` doesn't load the `tm_tensor` dialect.
This is the same dialect-not-found failure mode as fx-sparsity/a-gcn —
not a sparsifier-logic error, a registration error. Discussed at length
in [the fx-sparsity writeup](../fx-sparsity/README.md). The
takeaway is unchanged: even if `tm_tensor` were registered (e.g. via
`torch-mlir-opt --sparsifier`), the sparsifier has no rule for
sparsifying scatter-with-reduction-body. The structural fix is to never
emit the scatter form in the first place.

---

## Strategy implication

**The obstruction is `tm_tensor.scatter`, not anything GAT-specific.**
Every op above and below the four scatter sites — the linear projection,
the per-head attention pre-compute, the per-edge SDDMM-shape, the
softmax exp/sub/div, the per-edge gathers — lowers cleanly to
sparsifier-consumable linalg. The scatter sites are the only obstacle,
and they appear precisely where the math requires a reduction grouped
by destination node.

The unfused-GAT ingress (downstream work) will need to re-express the
four segmented operations directly in sparse-tensor IR, bypassing
`MessagePassing`'s gather/scatter entirely:

1. **SDDMM** (per-edge attention): `linalg.generic` over a sparse
   adjacency operand with a body computing
   `LeakyReLU(α_src[i] + α_dst[j])`. Yields a sparse tensor
   `α[E,heads]` with the same nonzero structure as A.
2. **Segmented amax**: `linalg.generic` (or pair, depending on how the
   sparsifier prefers init handled) with `arith.maximumf` body,
   reducing along the destination axis of the sparse encoding.
3. **Segmented sum**: same shape with `arith.addf` body, over the
   `exp(α - max[dst])` intermediate.
4. **Weighted aggregation**: SpMM-shape `linalg.generic` over the
   softmax-normalized sparse attention tensor and dense `Wx`.

All four are expressible at the `sparse_tensor` abstraction; the
day-zero gpu-sparsifier characterization established that segmented
sum-reductions over CSR lower through gpu-codegen to NVVM cleanly,
so this is structurally believed to hold. The unknowns the unfused-GAT
work will hit are (a) whether `linalg.generic` with `arith.maximumf` body
sparsifies as cleanly as `addf` does, and (b) whether the two-pass
softmax (max then sum) can express the destination-grouping with a
single sparse encoding or needs a CSR/CSC pair.

---

## Verdict

**Adapter-need: `scatter`→sparse adapter (mandatory).**

The "adapter" is structurally the green-path rewrite — a sparse-tensor
expression of the four segmented operations above — not a localized
substitution. Same finding as fx-sparsity/a-gcn for GCN, with three
additional scatter sites for the edge-softmax that don't change the
nature of the rewrite, only its surface area.

---

## Open follow-ups

- **The `include_self=false` two-step lowering** (scatters #1 + #2 for the
  amax) is a torch-aten → tm_tensor quirk, not a fundamental
  requirement. In the sparse-tensor rewrite the amax can be a single
  `linalg.generic` with the initial value `-∞` baked into the output
  `linalg.fill`. Noting this so the rewrite doesn't carry the two-step
  pattern over.
- **`bias=True` and `add_self_loops=True` were both disabled here for IR
  clarity.** Enabling them is purely additive structurally (bias adds
  a `linalg.generic` after the matmul; self-loops augment edge_index
  before the gather). Worth confirming once during the rewrite but not
  expected to change the verdict.
- **Multi-head config**: `heads=2` was sufficient to expose the
  `[N,H,D]` dimension through the IR. Larger heads (4, 8) should just
  scale the inner dims — confirm during the realistic-width run, not
  here.
