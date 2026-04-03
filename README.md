# ArchGuard-M3: Architectural Drift Detector for Microservices

**ArchGuard-M3** is a static analysis tool built with the **Rascal Meta Programming Language**. It detects architectural drift in microservices by comparing a planned architecture — defined in a custom DSL — against the actual implementation extracted from Java source code using Rascal's **M3** model.

## Core Capabilities

* **Architecture DSL** — Define permitted, forbidden, and expected service dependencies using a simple rule language.
* **M3 Extraction** — Automatically recover dependency graphs from Java source code, including method invocations, type dependencies, Spring Boot annotations, and database access patterns.
* **Drift Validation** — Detect forbidden couplings, unpermitted dependencies, missing expected links, and circular dependencies.
* **Spring Boot Analysis** — Identify `@FeignClient` bindings, `RestTemplate`/`WebClient` calls, and cross-service `@Repository` access.
* **Technical Debt Scoring** — Quantify drift severity with weighted scores (Critical: 10, Warning: 5, Info: 1).

## System Architecture

The tool operates in three phases:

1. **Oracle (DSL)** — Parse `.arch` rule files into an AST defining the intended architecture.
2. **Analyzer (M3)** — Extract an M3 model from Java source code and derive a service dependency graph.
3. **Comparator** — Perform relational algebra to compute the delta between design and implementation.

## Repository Structure

```
src/
├── ArchGuard.rsc                        # Main pipeline orchestrator
├── lang/arch/
│   ├── Syntax.rsc                       # DSL grammar (concrete syntax)
│   ├── Parser.rsc                       # String → parse tree
│   ├── AST.rsc                          # Abstract syntax + conversion
│   ├── TestParser.rsc                   # Parser tests (14 cases)
│   └── TestAST.rsc                      # AST conversion tests (10 cases)
├── extract/
│   ├── M3Extractor.rsc                  # M3 model extraction
│   ├── SpringBootAnalyzer.rsc           # Spring Boot-specific analysis
│   └── TestM3Extractor.rsc              # Extraction tests (16 cases)
├── check/
│   ├── DriftValidator.rsc               # Validation logic
│   ├── Reporter.rsc                     # Human-readable report formatting
│   ├── TestDriftValidator.rsc           # Validation tests (22 cases)
│   └── TestIntegration.rsc              # End-to-end pipeline tests (16 cases)
examples/
├── sample.arch                          # Example DSL rules file
└── sample-ms/                           # Sample Java microservices project
    └── com/example/{orders,payments,inventory}/
```

## DSL Syntax

Architecture rules are defined in `.arch` files using three keywords:

```
service "Orders" permits {"Payments", "Inventory"}
service "Orders" forbids {"Analytics"}
service "Payments" dependsOn {"Database"}
```

* **permits** — The service is allowed to depend only on the listed targets. Any other dependency is flagged as a warning.
* **forbids** — The service must not depend on the listed targets. Violations are flagged as critical.
* **dependsOn** — The service is expected to depend on the listed targets. Missing dependencies are flagged as info.

## Prerequisites

* **Java 11+** (required to run the Rascal shell)
* **Rascal shell JAR** (`rascal-shell-stable.jar`) — place it in the project root

## Quick Start

### 1. Launch the Rascal REPL

```bash
java -jar rascal-shell-stable.jar
```

> The `src/` directory must be in the Rascal search path. If modules fail to import, ensure you launch from the project root.

### 2. Run the test suite

```rascal
import check::TestIntegration;
:test
```

This runs all 78 tests across all modules (parser, AST, extraction, validation, integration).

### 3. Analyze a Java project

```rascal
import ArchGuard;

// From a DSL file and Java project directory
printAnalysis(
  |file:///path/to/rules.arch|,
  |file:///path/to/java/project|,
  2  // package depth for service name extraction
);
```

The `serviceDepth` parameter controls how service names are derived from Java package paths. For `com.example.orders.controller`, depth `2` yields `"orders"`.

### 4. Analyze from a DSL string

```rascal
import ArchGuard;
import extract::M3Extractor;
import check::Reporter;

arch = loadArchitectureFromString(
  "service \"Orders\" permits {\"Payments\", \"Inventory\"}
   service \"Orders\" forbids {\"Analytics\"}"
);

actual = extractArchitecture(|file:///path/to/project|, 2);
report = analyzeFromModels(arch, actual);
printReport(report);
```

### 5. Spring Boot enhanced analysis

```rascal
import ArchGuard;

println(runSpringAnalysis(
  |file:///path/to/rules.arch|,
  |file:///path/to/project|,
  2
));
```

This additionally detects `@FeignClient`, `RestTemplate`/`WebClient` usage, and cross-service `@Repository` access.

## Sample Report Output

```
=== Extraction Summary ===
Services discovered: analytics, inventory, orders, payments
Cross-service invocations: 4
Cross-service type deps: 2
HTTP endpoints: 2
DB entities: 2

=== ArchGuard-M3 Drift Report ===

[CRITICAL] Forbidden dependency: Orders -> Analytics
[CRITICAL] Forbidden dependency: Payments -> Orders
[WARNING ] Unpermitted dependency: Orders -> analytics
[INFO    ] Missing expected dependency: Payments -/> Database

--- Summary ---
Findings: 4 (Critical: 2, Warning: 1, Info: 1)
Technical Debt Score: 26
```

## Module Reference

* **`ArchGuard`** — Main entry point. Functions: `analyze`, `analyzeFromString`, `runAnalysis`, `runSpringAnalysis`, `printAnalysis`, `loadArchitecture`.
* **`lang::arch::Syntax`** — Concrete syntax grammar for the architecture DSL.
* **`lang::arch::Parser`** — `parseArchitecture(str)` → parse tree.
* **`lang::arch::AST`** — `buildAST(parseTree)` → `Architecture` ADT.
* **`extract::M3Extractor`** — `extractArchitecture(loc, int)` → `ExtractionResult` with services, invocations, type deps, endpoints, DB entities.
* **`extract::SpringBootAnalyzer`** — `analyzeSpringBoot(loc, int)` → `SpringAnalysis` with Feign, REST client, and cross-DB detection.
* **`check::DriftValidator`** — `validate(arch, actual)` → `ValidationReport` with findings and debt score.
* **`check::Reporter`** — `formatReport(report)` → human-readable string.

---
Developed using Rascal by carlix
