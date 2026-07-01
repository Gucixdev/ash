# ash

Mojo libraries — fast, low-level, zero-dependency.

## Libraries

| Library | Description |
|---------|-------------|
| [ashcore](ashcore/) | Arena allocator, thread pool, DAG schedulers, sync primitives, lock-free queues |
| [ashparser](ashparser/) | Parser combinator library with stateful parsing and source-map error reporting |
| [ashllmtools](ashllmtools/) | 8-layer LLM agent framework: state machine, decision contract, skills, workflow engine, memory, context engine, RAG, tool layer |

## Requirements

- [Mojo / MAX](https://docs.modular.com/mojo/) ≥ 26.4 via [Magic](https://docs.modular.com/magic/)
- linux-64

## Install

```bash
git clone https://github.com/Gucixdev/ash.git
cd ash/ashcore && magic install   # or cd ash/ashparser
```

## Getting started

```bash
# ashcore
cd ashcore && ./test

# ashparser
cd ashparser && ./test

# ashllmtools (requires Mojo)
cd ashllmtools && mojo run test_llmtools.mojo
```

## Structure

```
ash/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── ashcore/
│   ├── README.md
│   ├── pixi.toml
│   ├── conda.recipe/
│   ├── ashcore/          ← source package
│   │   ├── arena.mojo
│   │   ├── shared_arena.mojo
│   │   ├── sync.mojo
│   │   ├── threadpool.mojo
│   │   ├── taskgraph.mojo
│   │   ├── reactivegraph.mojo
│   │   ├── parallel.mojo
│   │   ├── queue.mojo
│   │   ├── debug.mojo
│   │   └── gpu.mojo
│   ├── benchmarks/
│   ├── tests/
│   ├── example/
│   ├── bench
│   ├── compare
│   ├── stresstest
│   └── test
├── ashparser/
│   ├── README.md
│   ├── pixi.toml
│   ├── conda.recipe/
│   ├── ashparser/        ← source package
│   │   ├── input.mojo
│   │   ├── result.mojo
│   │   ├── sourcemap.mojo
│   │   ├── prim.mojo
│   │   ├── comb.mojo
│   │   ├── state.mojo
│   │   ├── statecomb.mojo
│   │   └── p.mojo
│   ├── benchmarks/
│   ├── tests/
│   ├── example/
│   ├── bench
│   ├── compare
│   ├── stresstest
│   └── test
└── ashllmtools/
    ├── README.md
    ├── agent_state.mojo      ← layer 1: state machine
    ├── skills.mojo           ← layer 2: 15 built-in skills
    ├── workflow.mojo         ← layer 3: decision loop + task engine
    ├── memory.mojo           ← layer 4: note/episodic/semantic/LTM
    ├── context_engine.mojo   ← layer 5: priority-ranked context window
    ├── decision_contract.mojo← layer 7: risk-rated action firewall
    ├── world_model.mojo      ← layer 8: environment snapshot
    ├── rag/                  ← layer 6: retrieve → rank → inject
    ├── tools/
    │   ├── sys/              ← shell, fs, git
    │   ├── code/             ← diff, search
    │   └── web/              ← fetch
    └── test_llmtools.mojo
```

## License

[MIT](LICENSE)
