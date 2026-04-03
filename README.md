# ArchGuard-M3: Architectural Drift Detector for Microservices
ArchGuard-M3 is a static analysis tool developed using the Rascal Meta Programming Language. Its primary objective is to identify "architectural drift" by automatically comparing a planned microservices architecture against the actual implementation found in Java or Kotlin source code.

Project Overview
In complex distributed systems, the original architectural design often degrades over time due to delivery pressures or lack of visibility. This project leverages Rascal's M3 model to extract fine-grained dependencies and validate them against a set of rules defined in a custom Domain-Specific Language (DSL).

Core Capabilities
Automatic Extraction: Recovery of dependency graphs, including HTTP calls and database injections, using the M3 library.

Rule-Based DSL: A streamlined language for defining permitted and forbidden communication paths between services.

Violation Detection: Identification of prohibited couplings, circular dependencies, and cross-service database access.

Severity Reporting: Generation of technical debt metrics based on the gravity of the detected deviations.

System Architecture
The solution is structured into three main phases:

Analyzer (Rascal): Parses the source code to construct a comprehensive relationship model.

Oracle (DSL): Defines the architectural "ground truth" through compliance rules.

Comparator: Executes relational algebra within Rascal to determine the delta between implementation and design.

Repository Structure
/src/lang/: Grammar and parser for the architectural DSL.

/src/extract/: Rascal scripts for M3 model extraction.

/src/check/: Comparison logic and drift detection algorithms.

/examples/: Test cases featuring Java/Kotlin microservices.


Phase 1: Definition of the DSL grammar.

Phase 2: Implementation of M3 extractors for Spring Boot environments.

Phase 3: Empirical validation using real-world project data.
