# Music Career Simulator

Single-player, statistics-driven music career simulation for iOS and Android (Flutter).

- Design docs (Turkish): [docs/README.md](docs/README.md)
- Current status: [docs/phase0-status.md](docs/phase0-status.md)

## Layout

```
packages/simulation_core/   pure Dart simulation engine (no Flutter, no database)
tools/sim_cli/              headless runner for calibration and benchmarks
docs/                       game design, simulation, data model, architecture
```

## Running

Requires the Dart SDK (3.6+).

```bash
dart pub get
cd packages/simulation_core && dart test
cd tools/sim_cli && dart run bin/sim_cli.dart --start 2005 --years 20 --seed 42
```
