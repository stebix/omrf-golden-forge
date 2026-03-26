# JSON Schema: A Pydantic-User's Guide

> Reference for `packages/omrf-mlab-golden-schema/src/omrf_mlab_golden_schema/golden_record.schema.json`
>
> Prerequisites: familiarity with JSON and Pydantic v2.

---

## Core Idea

Pydantic validates Python dicts against a model class — at runtime, in Python only.
JSON Schema is the language-agnostic equivalent: a JSON document that describes the
shape of other JSON documents. Any language, any tool can validate against it.

```
Pydantic model  →  validates Python dicts  (Python, runtime)
JSON Schema     →  validates JSON anywhere (any language, any tool)
```

---

## Where the `.schema.json` File Comes From

Pydantic can export its internal contract as JSON Schema:

```python
import json
from omrf_mlab_golden_schema.models import GoldenRecord

print(json.dumps(GoldenRecord.model_json_schema(), indent=2))
```

`golden_record.schema.json` is a **committed snapshot** of that export. The Pydantic
models are the source of truth; the JSON Schema file is a derived artifact that CI
verifies stays in sync.

---

## Document Structure

A JSON Schema file has two main sections.

### `$defs` — reusable named sub-schemas

```json
"$defs": {
  "ComplexEncoding":       { ... },
  "ComplexMatrixEncoding": { ... },
  "GoldenMetadata":        { ... },
  "GoldenTestCase":        { ... },
  "ParamValue":            { ... }
}
```

Each entry maps directly to a Pydantic class (or type alias). They are defined once
and referenced elsewhere with `$ref` — same as Pydantic model nesting.

### Root object — the top-level schema

The root of the document *is* a schema, corresponding to `GoldenRecord`:

```json
{
  "title": "GoldenRecord",
  "type": "object",
  "required": ["operator", "metadata", "test_cases"],
  "properties": {
    "operator":   { "type": "string" },
    "metadata":   { "$ref": "#/$defs/GoldenMetadata" },
    "test_cases": { "type": "array", "items": { "$ref": "#/$defs/GoldenTestCase" } }
  }
}
```

`$ref` is a JSON Pointer: `#/$defs/GoldenMetadata` means "root → `$defs` → `GoldenMetadata`".

---

## Keyword Reference

| JSON Schema keyword          | Meaning                                   | Pydantic equivalent            |
|------------------------------|-------------------------------------------|--------------------------------|
| `"type": "object"`           | Must be a JSON object                     | `BaseModel` or `dict`          |
| `"type": "string"`           | Must be a string                          | `str`                          |
| `"type": "integer"`          | Must be an integer                        | `int`                          |
| `"type": "number"`           | Integer or float                          | `float`                        |
| `"type": "boolean"`          | `true` or `false`                         | `bool`                         |
| `"type": "array"`            | JSON array                                | `list`                         |
| `"required": [...]`          | These keys must be present                | Non-optional fields            |
| `"properties": {...}`        | Defines allowed keys on an object         | Field declarations             |
| `"items": {...}`             | Schema for each array element             | `list[T]`                      |
| `"prefixItems": [...]`       | Per-position schemas for a fixed-length array | `tuple[A, B]`              |
| `"minItems"/"maxItems"`      | Array length bounds                       | `tuple[int, int]` → exactly 2  |
| `"additionalProperties": {}` | Schema for any key not in `properties`    | `dict[str, T]`                 |
| `"anyOf": [...]`             | Must match at least one sub-schema        | `A \| B \| C`                  |
| `"$ref": "..."`              | Reference another schema by path          | Nested `BaseModel` type        |

---

## Concrete Traces

### `ComplexMatrixEncoding`

**Pydantic** (`models.py`):
```python
class ComplexMatrixEncoding(BaseModel):
    shape: tuple[int, int]
    real: list[list[float]]
    imag: list[list[float]]
```

**JSON Schema** (`golden_record.schema.json`):
```json
"ComplexMatrixEncoding": {
  "type": "object",
  "required": ["shape", "real", "imag"],
  "properties": {
    "shape": {
      "type": "array",
      "minItems": 2, "maxItems": 2,
      "prefixItems": [{"type": "integer"}, {"type": "integer"}]
    },
    "real": {
      "type": "array",
      "items": { "type": "array", "items": {"type": "number"} }
    },
    "imag": { "... same as real ..." }
  }
}
```

`tuple[int, int]` → `prefixItems` with length constraints.
`list[list[float]]` → nested `"items"`.

**What gets lost:** the `@model_validator` that checks row/column counts against `shape`
has no JSON Schema equivalent. JSON Schema is structural only — it cannot express
relational constraints between field values. Pydantic is strictly richer.

---

### `ParamValue`

**Pydantic** (`models.py`):
```python
type ParamValue = float | int | bool | ComplexEncoding
```

**JSON Schema**:
```json
"ParamValue": {
  "anyOf": [
    {"type": "number"},
    {"type": "integer"},
    {"type": "boolean"},
    {"$ref": "#/$defs/ComplexEncoding"}
  ]
}
```

`anyOf` = union type. Each branch is tried in order; the value is accepted if any
branch matches. This is how Pydantic's left-to-right union resolution maps to JSON
Schema.

---

## What You Get from a Committed `.schema.json`

| Benefit | Detail |
|---|---|
| **Cross-language validation** | Go, Rust, TypeScript, Java consumers can validate files without the Python package. `jsonschema` (Python), `ajv` (JS), `serde_json` (Rust) all speak JSON Schema. |
| **Editor tooling** | VS Code / JetBrains can use a `$schema` pointer in a JSON file to provide autocompletion and inline validation. |
| **Readable documentation** | The schema is self-describing. Pydantic docstrings become `"description"` fields in the exported schema. |
| **Contract pinning** | Committing the file + testing sync gives a hard guarantee that the Python models and the exported contract are never out of step. |

---

## The Sync Problem — Why CI Tests It

The risk is silent drift:

```
models.py changes → schema.json NOT regenerated → consumers use stale contract
```

The CI check is essentially:

```python
assert GoldenRecord.model_json_schema() == json.load(open("golden_record.schema.json"))
```

If they diverge the test fails, prompting a regeneration. The Pydantic models are
always authoritative; the JSON Schema file must be explicitly kept up to date.
