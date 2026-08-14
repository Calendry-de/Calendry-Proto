#!/usr/bin/env bash
#
# Generate TypeScript bindings from the .proto files.
#
# Run from packages/ts. Requires protoc on PATH and `npm ci` already done, so
# that node_modules/.bin/protoc-gen-ts_proto exists.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$(dirname "$HERE")"
ROOT="$(cd "$PKG/../.." && pwd)"

PROTO_ROOT="$ROOT/proto"
OUT="$PKG/src/generated"

rm -rf "$OUT"
mkdir -p "$OUT"

# ts-proto options.
#
# forceLong=string is a CORRECTNESS requirement, not a style choice. ts-proto
# defaults to forceLong=number, which represents 64-bit integers as JS numbers
# and silently loses precision above 2^53. `seed` is a full-range uint64 whose
# corruption would break the reproducibility contract StartRunResponse exists to
# provide; max_moves and moves_evaluated are the same shape. Proto3 JSON already
# encodes 64-bit integers as strings, so this also matches the wire format.
#
# importSuffix=.js is required for the emitted ESM to be loadable by Node:
# without it ts-proto emits extensionless relative imports, which Node's ESM
# resolver rejects at runtime even though tsc accepts them.
OPTS=(
  "esModuleInterop=true"
  "outputServices=grpc-js"
  "useOptionals=messages"
  "outputJsonMethods=true"
  "forceLong=string"
  "importSuffix=.js"
)

TS_PROTO_OPT=""
for o in "${OPTS[@]}"; do
  TS_PROTO_OPT="${TS_PROTO_OPT}--ts_proto_opt=${o} "
done

# shellcheck disable=SC2086
protoc \
  --plugin="protoc-gen-ts_proto=$PKG/node_modules/.bin/protoc-gen-ts_proto" \
  --proto_path="$PROTO_ROOT" \
  --ts_proto_out="$OUT" \
  $TS_PROTO_OPT \
  "$PROTO_ROOT"/calendry/solver/v1/constraints.proto \
  "$PROTO_ROOT"/calendry/solver/v1/model.proto \
  "$PROTO_ROOT"/calendry/solver/v1/service.proto

echo "generated:"
find "$OUT" -name '*.ts' | sed "s|$PKG/||" | sort
