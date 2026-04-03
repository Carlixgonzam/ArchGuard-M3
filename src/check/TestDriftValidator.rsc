module check::TestDriftValidator

import check::DriftValidator;
import lang::arch::AST;
import extract::M3Extractor;
import List;
import Set;
import Relation;

ExtractionResult mockResult(DependencyGraph invocations) =
  extractionResult(
    domain(invocations) + range(invocations),
    invocations,
    {},
    {},
    {}
  );

ExtractionResult mockFullResult(set[str] services, DependencyGraph invocations, DependencyGraph typeDeps) =
  extractionResult(services, invocations, typeDeps, {}, {});

test bool permitsAllowedNoDrift() {
  Architecture arch = architecture([permits("Orders", ["Payments", "Inventory"])]);
  ExtractionResult actual = mockResult({<"orders", "payments">, <"orders", "inventory">});
  ValidationReport r = validate(arch, actual);
  return r.findings == [] && r.debtScore == 0;
}

test bool permitsUnpermittedDependency() {
  Architecture arch = architecture([permits("Orders", ["Payments"])]);
  ExtractionResult actual = mockResult({<"orders", "payments">, <"orders", "analytics">});
  ValidationReport r = validate(arch, actual);
  return size(r.findings) == 1
      && r.findings[0].violation == unpermittedDependency("Orders", "analytics")
      && r.findings[0].severity == warning();
}

test bool permitsMultipleViolations() {
  Architecture arch = architecture([permits("Orders", ["Payments"])]);
  ExtractionResult actual = mockResult({<"orders", "payments">, <"orders", "analytics">, <"orders", "shipping">});
  ValidationReport r = validate(arch, actual);
  return size(r.findings) == 2;
}

test bool forbidsNoViolation() {
  Architecture arch = architecture([forbids("Orders", ["Analytics"])]);
  ExtractionResult actual = mockResult({<"orders", "payments">});
  ValidationReport r = validate(arch, actual);
  return r.findings == [] && r.debtScore == 0;
}

test bool forbidsDetectsViolation() {
  Architecture arch = architecture([forbids("Orders", ["Analytics"])]);
  ExtractionResult actual = mockResult({<"orders", "analytics">});
  ValidationReport r = validate(arch, actual);
  return size(r.findings) == 1
      && r.findings[0].violation == forbiddenDependency("Orders", "Analytics")
      && r.findings[0].severity == critical();
}

test bool forbidsCaseInsensitive() {
  Architecture arch = architecture([forbids("Orders", ["ANALYTICS"])]);
  ExtractionResult actual = mockResult({<"orders", "analytics">});
  ValidationReport r = validate(arch, actual);
  return size(r.findings) == 1
      && r.findings[0].severity == critical();
}

test bool dependsOnSatisfied() {
  Architecture arch = architecture([dependsOn("Orders", ["Payments"])]);
  ExtractionResult actual = mockResult({<"orders", "payments">});
  ValidationReport r = validate(arch, actual);
  return r.findings == [] && r.debtScore == 0;
}

test bool dependsOnMissing() {
  Architecture arch = architecture([dependsOn("Orders", ["Payments", "Cache"])]);
  ExtractionResult actual = mockResult({<"orders", "payments">});
  ValidationReport r = validate(arch, actual);
  return size(r.findings) == 1
      && r.findings[0].violation == missingDependency("Orders", "Cache")
      && r.findings[0].severity == info();
}

test bool dependsOnAllMissing() {
  Architecture arch = architecture([dependsOn("Orders", ["Database", "Cache"])]);
  ExtractionResult actual = mockResult({<"payments", "inventory">});
  ValidationReport r = validate(arch, actual);
  return size(r.findings) == 2;
}

test bool circularDependencyDetected() {
  ExtractionResult actual = mockResult({<"orders", "payments">, <"payments", "orders">});
  Architecture arch = architecture([]);
  ValidationReport r = validate(arch, actual);
  return size(r.findings) == 1
      && r.findings[0].severity == critical();
}

test bool circularDependencyThreeNodes() {
  ExtractionResult actual = mockResult({<"a", "b">, <"b", "c">, <"c", "a">});
  Architecture arch = architecture([]);
  ValidationReport r = validate(arch, actual);
  return size(r.findings) == 1
      && circularDependency(_) := r.findings[0].violation;
}

test bool noCycleInDag() {
  ExtractionResult actual = mockResult({<"a", "b">, <"b", "c">, <"a", "c">});
  Architecture arch = architecture([]);
  ValidationReport r = validate(arch, actual);
  return r.findings == [];
}

test bool mixedRulesMultipleViolations() {
  Architecture arch = architecture([
    permits("Orders", ["Payments"]),
    forbids("Orders", ["Analytics"]),
    dependsOn("Orders", ["Cache"])
  ]);
  ExtractionResult actual = mockResult({<"orders", "payments">, <"orders", "analytics">});
  ValidationReport r = validate(arch, actual);
  set[Violation] violations = {v | <Violation v, _> <- r.findings};
  return forbiddenDependency("Orders", "Analytics") in violations
      && missingDependency("Orders", "Cache") in violations;
}

test bool debtScoreCritical() {
  Architecture arch = architecture([forbids("A", ["B"])]);
  ExtractionResult actual = mockResult({<"a", "b">});
  return validate(arch, actual).debtScore == 10;
}

test bool debtScoreWarning() {
  Architecture arch = architecture([permits("A", ["C"])]);
  ExtractionResult actual = mockResult({<"a", "b">});
  return validate(arch, actual).debtScore == 5;
}

test bool debtScoreInfo() {
  Architecture arch = architecture([dependsOn("A", ["B"])]);
  ExtractionResult actual = mockResult({<"x", "y">});
  return validate(arch, actual).debtScore == 1;
}

test bool debtScoreAccumulates() {
  Architecture arch = architecture([
    forbids("A", ["B"]),
    permits("A", ["C"]),
    dependsOn("A", ["D"])
  ]);
  ExtractionResult actual = mockResult({<"a", "b">});
  ValidationReport r = validate(arch, actual);
  return r.debtScore == (10 + 5 + 1);
}

test bool emptyArchitectureNoDrift() {
  Architecture arch = architecture([]);
  ExtractionResult actual = mockResult({<"a", "b">});
  return validate(arch, actual).findings == [];
}

test bool emptyGraphNoDrift() {
  Architecture arch = architecture([permits("Orders", ["Payments"])]);
  ExtractionResult actual = mockResult({});
  return validate(arch, actual).findings == [];
}

test bool validateFullIncludesFilteredTypeDeps() {
  Architecture arch = architecture([forbids("Orders", ["Inventory"])]);
  DependencyGraph inv = {<"orders", "payments">};
  DependencyGraph typeDeps = {<"orders", "inventory">, <"orders", "String">};
  ExtractionResult actual = mockFullResult({"orders", "payments", "inventory"}, inv, typeDeps);
  ValidationReport r = validateFull(arch, actual);
  set[Violation] violations = {v | <Violation v, _> <- r.findings};
  return forbiddenDependency("Orders", "Inventory") in violations;
}

test bool validateFullFiltersNonServices() {
  Architecture arch = architecture([permits("Orders", ["Payments"])]);
  DependencyGraph inv = {<"orders", "payments">};
  DependencyGraph typeDeps = {<"orders", "String">};
  ExtractionResult actual = mockFullResult({"orders", "payments"}, inv, typeDeps);
  ValidationReport r = validateFull(arch, actual);
  return r.findings == [];
}

test bool multipleServicesIndependent() {
  Architecture arch = architecture([
    permits("Orders", ["Payments"]),
    permits("Auth", ["Users"])
  ]);
  ExtractionResult actual = mockResult({<"orders", "payments">, <"auth", "users">});
  ValidationReport r = validate(arch, actual);
  return r.findings == [] && r.debtScore == 0;
}
