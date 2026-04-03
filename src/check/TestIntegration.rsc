module check::TestIntegration

import ArchGuard;
import lang::arch::Parser;
import lang::arch::AST;
import extract::M3Extractor;
import extract::SpringBootAnalyzer;
import check::DriftValidator;
import check::Reporter;
import analysis::m3::Core;
import lang::java::m3::Core;
import Set;
import List;
import String;
import Relation;

M3 integrationModel() = m3(|project://integration|,
  containment = {
    <|java+package:///com/example/orders|,
     |java+compilationUnit:///com/example/orders/OrderController.java|>,
    <|java+package:///com/example/payments|,
     |java+compilationUnit:///com/example/payments/PaymentService.java|>,
    <|java+package:///com/example/inventory|,
     |java+compilationUnit:///com/example/inventory/StockManager.java|>,
    <|java+package:///com/example/analytics|,
     |java+compilationUnit:///com/example/analytics/Reporter.java|>
  },
  methodInvocation = {
    <|java+method:///com/example/orders/OrderController/create()|,
     |java+method:///com/example/payments/PaymentService/charge()|>,
    <|java+method:///com/example/orders/OrderController/fulfill()|,
     |java+method:///com/example/inventory/StockManager/reserve()|>,
    <|java+method:///com/example/orders/OrderController/track()|,
     |java+method:///com/example/analytics/Reporter/log()|>,
    <|java+method:///com/example/payments/PaymentService/refund()|,
     |java+method:///com/example/orders/OrderController/cancel()|>
  },
  typeDependency = {
    <|java+class:///com/example/orders/OrderController|,
     |java+class:///com/example/payments/PaymentService|>,
    <|java+class:///com/example/orders/OrderController|,
     |java+class:///com/example/inventory/StockManager|>
  },
  annotations = {
    <|java+method:///com/example/orders/OrderController/create()|,
     |java+class:///org/springframework/web/bind/annotation/PostMapping|>,
    <|java+method:///com/example/orders/OrderController/getAll()|,
     |java+class:///org/springframework/web/bind/annotation/GetMapping|>,
    <|java+class:///com/example/inventory/StockManager|,
     |java+class:///javax/persistence/Entity|>,
    <|java+class:///com/example/payments/PaymentRepository|,
     |java+class:///org/springframework/stereotype/Repository|>
  }
);

str sampleDSL() =
  "service \"Orders\" permits {\"Payments\", \"Inventory\"}
   service \"Orders\" forbids {\"Analytics\"}
   service \"Payments\" dependsOn {\"Database\"}
   service \"Payments\" forbids {\"Orders\"}";

test bool pipelineParsesToAST() {
  Architecture arch = loadArchitectureFromString(sampleDSL());
  return size(arch.decls) == 4;
}

test bool pipelineExtractsFromModel() {
  ExtractionResult result = extractFromModel(integrationModel(), 2);
  return result.services == {"orders", "payments", "inventory", "analytics"};
}

test bool pipelineDetectsInvocations() {
  ExtractionResult result = extractFromModel(integrationModel(), 2);
  return <"orders", "payments"> in result.invocations
      && <"orders", "inventory"> in result.invocations
      && <"orders", "analytics"> in result.invocations
      && <"payments", "orders"> in result.invocations;
}

test bool pipelineDetectsForbiddenDependency() {
  Architecture arch = loadArchitectureFromString(sampleDSL());
  ExtractionResult actual = extractFromModel(integrationModel(), 2);
  ValidationReport report = analyzeFromModels(arch, actual);
  set[Violation] vs = {v | <Violation v, _> <- report.findings};
  return forbiddenDependency("Orders", "Analytics") in vs;
}

test bool pipelineDetectsReverseForbidden() {
  Architecture arch = loadArchitectureFromString(sampleDSL());
  ExtractionResult actual = extractFromModel(integrationModel(), 2);
  ValidationReport report = analyzeFromModels(arch, actual);
  set[Violation] vs = {v | <Violation v, _> <- report.findings};
  return forbiddenDependency("Payments", "Orders") in vs;
}

test bool pipelineDetectsMissingDependency() {
  Architecture arch = loadArchitectureFromString(sampleDSL());
  ExtractionResult actual = extractFromModel(integrationModel(), 2);
  ValidationReport report = analyzeFromModels(arch, actual);
  set[Violation] vs = {v | <Violation v, _> <- report.findings};
  return missingDependency("Payments", "Database") in vs;
}

test bool pipelineDetectsUnpermittedDependency() {
  Architecture arch = loadArchitectureFromString(sampleDSL());
  ExtractionResult actual = extractFromModel(integrationModel(), 2);
  ValidationReport report = analyzeFromModels(arch, actual);
  set[Violation] vs = {v | <Violation v, _> <- report.findings};
  return unpermittedDependency("Orders", "analytics") in vs;
}

test bool pipelineDebtScoreNonZero() {
  Architecture arch = loadArchitectureFromString(sampleDSL());
  ExtractionResult actual = extractFromModel(integrationModel(), 2);
  ValidationReport report = analyzeFromModels(arch, actual);
  return report.debtScore > 0;
}

test bool reportContainsCritical() {
  Architecture arch = loadArchitectureFromString(sampleDSL());
  ExtractionResult actual = extractFromModel(integrationModel(), 2);
  ValidationReport report = analyzeFromModels(arch, actual);
  str text = formatReport(report);
  return /CRITICAL/ := text;
}

test bool reportContainsSummary() {
  Architecture arch = loadArchitectureFromString(sampleDSL());
  ExtractionResult actual = extractFromModel(integrationModel(), 2);
  ValidationReport report = analyzeFromModels(arch, actual);
  str text = formatReport(report);
  return /Technical Debt Score/ := text;
}

test bool reportFormatsCleanRun() {
  Architecture arch = architecture([permits("A", ["B"])]);
  ExtractionResult actual = extractionResult({"a", "b"}, {<"a", "b">}, {}, {}, {});
  ValidationReport report = analyzeFromModels(arch, actual);
  str text = formatReport(report);
  return /No violations detected/ := text;
}

test bool extractionSummaryFormats() {
  ExtractionResult result = extractFromModel(integrationModel(), 2);
  str text = formatExtractionSummary(result);
  return /Services discovered/ := text
      && /Cross-service invocations/ := text;
}

test bool springAnalyzerDetectsEndpoints() {
  SpringAnalysis spring = analyzeSpringBoot(integrationModel(), 2);
  return size(spring.base.endpoints) == 2;
}

test bool springAnalyzerDetectsRepositories() {
  SpringAnalysis spring = analyzeSpringBoot(integrationModel(), 2);
  return size(spring.repositories) > 0;
}

test bool springToDependencyGraphConverts() {
  set[SpringDependency] deps = {
    restCall("orders", "payments", "HTTP"),
    dbCrossAccess("orders", "/repo", "payments")
  };
  DependencyGraph graph = springToDependencyGraph(deps);
  return <"orders", "payments"> in graph;
}

test bool fullValidationIncludesTypeDeps() {
  Architecture arch = loadArchitectureFromString(
    "service \"Orders\" permits {\"Payments\"}"
  );
  ExtractionResult actual = extractionResult(
    {"orders", "payments", "inventory"},
    {<"orders", "payments">},
    {<"orders", "inventory">},
    {},
    {}
  );
  ValidationReport report = analyzeFullFromModels(arch, actual);
  set[Violation] vs = {v | <Violation v, _> <- report.findings};
  return unpermittedDependency("Orders", "inventory") in vs;
}
