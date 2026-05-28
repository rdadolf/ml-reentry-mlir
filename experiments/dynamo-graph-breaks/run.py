"""Where do Dynamo graph breaks land on PyG GATConv, can they be eliminated,
and what can a backend see across them?

Two questions, both empirical:

1. **Break inventory.** For (single GATConv, 2-layer GAT) × (add_self_loops
   True, False) × (default fullgraph, fullgraph=True), how many FX graphs
   does Dynamo emit, and what specifically triggers each break? Uses
   `torch._dynamo.explain` for break reasons and stack frames.

2. **Backend visibility.** Does the backend that `torch.compile` calls
   receive the unbroken graph, or does it see only one shard per
   invocation? Uses a custom "spy backend" that records every
   GraphModule it is handed.

Companion to experiments/inductor-fusion (which measures what Inductor
does *given* an unbroken graph; this experiment measures whether the
graph is unbroken in the first place).

Dumps:
  * `dumps/breaks.txt`   — full break-inventory output across the 4 configs
  * `dumps/visibility.txt` — spy-backend invocation log for the breaking and
                             non-breaking cases
"""

from __future__ import annotations

import io
import sys
from contextlib import redirect_stdout
from pathlib import Path

import torch
import torch._dynamo as dynamo
import torch.nn.functional as F
from torch_geometric.nn import GATConv, GCNConv, SAGEConv


def make_inputs(nodes=100, edges=500, in_channels=16, device="cuda"):
    torch.manual_seed(0)
    x = torch.randn(nodes, in_channels, device=device)
    src = torch.randint(0, nodes, (edges,), device=device)
    dst = torch.randint(0, nodes, (edges,), device=device)
    return x, torch.stack([src, dst], dim=0)


class GAT2(torch.nn.Module):
    """2-layer GAT — Cora-shaped (heads=8 on layer 1, concat into layer 2)."""

    def __init__(self, in_c=16, hid=8, out_c=7, heads=8, add_self_loops=True):
        super().__init__()
        self.conv1 = GATConv(in_c, hid, heads=heads, add_self_loops=add_self_loops)
        self.conv2 = GATConv(
            hid * heads, out_c, heads=1, concat=False, add_self_loops=add_self_loops
        )

    def forward(self, x, edge_index):
        x = self.conv1(x, edge_index)
        x = F.elu(x)
        return self.conv2(x, edge_index)


class GCN2(torch.nn.Module):
    """2-layer GCN."""

    def __init__(self, in_c=16, hid=16, out_c=7, add_self_loops=True, normalize=True):
        super().__init__()
        self.conv1 = GCNConv(in_c, hid, add_self_loops=add_self_loops, normalize=normalize)
        self.conv2 = GCNConv(hid, out_c, add_self_loops=add_self_loops, normalize=normalize)

    def forward(self, x, edge_index):
        x = self.conv1(x, edge_index)
        x = F.relu(x)
        return self.conv2(x, edge_index)


class SAGE2(torch.nn.Module):
    """2-layer SAGE."""

    def __init__(self, in_c=16, hid=16, out_c=7):
        super().__init__()
        self.conv1 = SAGEConv(in_c, hid)
        self.conv2 = SAGEConv(hid, out_c)

    def forward(self, x, edge_index):
        x = self.conv1(x, edge_index)
        x = F.relu(x)
        return self.conv2(x, edge_index)


def report_breaks(label, fn, x, ei):
    print()
    print("=" * 72)
    print(label)
    print("=" * 72)
    dynamo.reset()
    explained = dynamo.explain(fn)(x, ei)
    print(f"graph_count        = {explained.graph_count}")
    print(f"graph_break_count  = {explained.graph_break_count}")
    print(f"op_count           = {explained.op_count}")
    for i, br in enumerate(explained.break_reasons or []):
        first_line = (br.reason or "").splitlines()[0]
        print(f"--- break {i}: {first_line}")
        for fr in (br.user_stack or [])[:3]:
            print(f"  at {fr.filename}:{fr.lineno} in {fr.name}")
    # Cross-check: can fullgraph=True trace it as a single graph?
    dynamo.reset()
    try:
        torch.compile(fn, fullgraph=True, backend="eager")(x, ei)
        print("fullgraph=True : traces as single graph")
    except Exception as exc:  # noqa: BLE001
        print(f"fullgraph=True : {type(exc).__name__}: {str(exc)[:200]}")


# --- backend-visibility test ---
class SpyBackend:
    """Records each GraphModule torch.compile hands to a backend.

    The Dynamo backend API is `(GraphModule, example_inputs) -> Callable`.
    Each FX subgraph is delivered as one invocation; the backend has no
    parameter through which to request sibling subgraphs. If
    `len(spy.calls) > 1`, the backend cannot perform any optimization
    that spans those subgraphs — they are different MLIR modules at
    different Python invocation sites.
    """

    def __init__(self):
        self.calls = []

    def __call__(self, gm: torch.fx.GraphModule, example_inputs):
        self.calls.append(
            {
                "n_nodes": len(list(gm.graph.nodes)),
                "n_call_function": sum(1 for n in gm.graph.nodes if n.op == "call_function"),
                "first_ops": [
                    str(n.target).split(".")[-1] for n in gm.graph.nodes if n.op == "call_function"
                ][:6],
                "input_shapes": [
                    tuple(t.shape) if hasattr(t, "shape") else None for t in example_inputs
                ],
            }
        )
        return gm.forward


def report_visibility(label, fn, x, ei, *, fullgraph: bool):
    print()
    print("=" * 72)
    print(f"{label} (fullgraph={fullgraph})")
    print("=" * 72)
    spy = SpyBackend()
    dynamo.reset()
    compiled = torch.compile(fn, backend=spy, fullgraph=fullgraph)
    with torch.no_grad():
        compiled(x, ei)
    print(f"backend invoked {len(spy.calls)} time(s):")
    for i, c in enumerate(spy.calls):
        print(
            f"  call {i}: nodes={c['n_nodes']:>3} "
            f"call_function={c['n_call_function']:>2}  "
            f"first_ops={c['first_ops']}"
        )


def main():
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"torch={torch.__version__}  device={device}")

    x, ei = make_inputs(device=device)
    dump_dir = Path(__file__).parent / "dumps"
    dump_dir.mkdir(exist_ok=True)

    # ===== Question 1: break inventory ================================
    buf = io.StringIO()
    with redirect_stdout(buf):
        print(f"torch={torch.__version__}  device={device}")

        conv_T = GATConv(16, 8, heads=4, add_self_loops=True).to(device).eval()
        report_breaks("A. single GATConv, add_self_loops=True", lambda x, ei: conv_T(x, ei), x, ei)

        conv_F = GATConv(16, 8, heads=4, add_self_loops=False).to(device).eval()
        report_breaks("B. single GATConv, add_self_loops=False", lambda x, ei: conv_F(x, ei), x, ei)

        gat2_T = GAT2(add_self_loops=True).to(device).eval()
        report_breaks("C. 2-layer GAT, add_self_loops=True", lambda x, ei: gat2_T(x, ei), x, ei)

        gat2_F = GAT2(add_self_loops=False).to(device).eval()
        report_breaks("D. 2-layer GAT, add_self_loops=False", lambda x, ei: gat2_F(x, ei), x, ei)

        # GCN — same self-loops / normalize structure as GAT around
        # remove_self_loops + add_remaining_self_loops + gcn_norm.
        gcn1_T = GCNConv(16, 8, add_self_loops=True, normalize=True).to(device).eval()
        report_breaks(
            "E. single GCNConv, add_self_loops=True, normalize=True",
            lambda x, ei: gcn1_T(x, ei),
            x,
            ei,
        )

        gcn1_F = GCNConv(16, 8, add_self_loops=False, normalize=False).to(device).eval()
        report_breaks(
            "F. single GCNConv, add_self_loops=False, normalize=False",
            lambda x, ei: gcn1_F(x, ei),
            x,
            ei,
        )

        gcn2_T = GCN2(add_self_loops=True, normalize=True).to(device).eval()
        report_breaks(
            "G. 2-layer GCN, defaults (self_loops + normalize)",
            lambda x, ei: gcn2_T(x, ei),
            x,
            ei,
        )

        gcn2_F = GCN2(add_self_loops=False, normalize=False).to(device).eval()
        report_breaks(
            "H. 2-layer GCN, compile-friendly",
            lambda x, ei: gcn2_F(x, ei),
            x,
            ei,
        )

        # SAGE — no self-loops, no normalize, no edge-softmax. Expected clean.
        sage1 = SAGEConv(16, 8).to(device).eval()
        report_breaks("I. single SAGEConv (defaults)", lambda x, ei: sage1(x, ei), x, ei)

        sage2 = SAGE2().to(device).eval()
        report_breaks("J. 2-layer SAGE", lambda x, ei: sage2(x, ei), x, ei)
    out = buf.getvalue()
    print(out, end="")
    (dump_dir / "breaks.txt").write_text(out)

    # ===== Question 2: backend visibility ============================
    buf = io.StringIO()
    with redirect_stdout(buf):
        print(f"torch={torch.__version__}  device={device}")
        conv_T = GATConv(16, 8, heads=4, add_self_loops=True).to(device).eval()
        # Default fullgraph=False: backend should be called N times for N
        # subgraphs (i.e., it cannot see the whole function).
        report_visibility(
            "single GATConv, add_self_loops=True",
            lambda x, ei: conv_T(x, ei),
            x,
            ei,
            fullgraph=False,
        )
        # fullgraph=True: backend gets the single unbroken graph.
        report_visibility(
            "single GATConv, add_self_loops=True",
            lambda x, ei: conv_T(x, ei),
            x,
            ei,
            fullgraph=True,
        )
        # self_loops=False is the structural alternative.
        conv_F = GATConv(16, 8, heads=4, add_self_loops=False).to(device).eval()
        report_visibility(
            "single GATConv, add_self_loops=False",
            lambda x, ei: conv_F(x, ei),
            x,
            ei,
            fullgraph=False,
        )
    out = buf.getvalue()
    print(out, end="")
    (dump_dir / "visibility.txt").write_text(out)

    return 0


if __name__ == "__main__":
    sys.exit(main())
