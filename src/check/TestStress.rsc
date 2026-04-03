module check::TestStress

import ArchGuard;
import check::DriftValidator;
import check::Reporter;
import extract::M3Extractor;
import lang::arch::AST;
import vis::DotExporter;
import Relation;
import Set;
import List;
import String;
import IO;

DependencyGraph mockFullGraph() =
  {<"gateway", "orders">,
   <"gateway", "payments">,
   <"orders", "payments">,
   <"orders", "inventory">,
   <"payments", "ledger">,
   <"inventory", "warehouse">,
   <"warehouse", "orders">};

Architecture stressArch() = loadArchitectureFromString(
  "service \"Gateway\" permits {\"Orders\", \"Auth\"}
   service \"Orders\" permits {\"Payments\", \"Inventory\"}
   service \"Payments\" permits {\"Ledger\"}
   service \"Inventory\" permits {\"Warehouse\"}
   service \"Warehouse\" permits {\"Orders\"}
   service \"Gateway\" forbids {\"Payments\"}");

test bool testDeepCycle() {
  DependencyGraph closure = mockFullGraph()+;
  return <"orders", "orders"> in closure
      && <"inventory", "inventory"> in closure
      && <"warehouse", "warehouse"> in closure;
}

test bool testGatewayNotInCycle() {
  DependencyGraph closure = mockFullGraph()+;
  return <"gateway", "gateway"> notin closure;
}

test bool testCycleDetectedAsViolation() {
  ValidationReport r = validateGraph(stressArch(), mockFullGraph());
  set[Violation] vs = {v | <Violation v, _> <- r.findings};
  return size({v | v <- vs, circularDependency(_) := v}) > 0;
}

test bool testCycleIsCritical() {
  ValidationReport r = validateGraph(stressArch(), mockFullGraph());
  return critical() in {s | <Violation v, Severity s> <- r.findings, circularDependency(_) := v};
}

test bool testCycleContainsAllThreeNodes() {
  ValidationReport r = validateGraph(stressArch(), mockFullGraph());
  for (<circularDependency(list[str] cycle), _> <- r.findings) {
    set[str] nodes = toSet(cycle);
    return "orders" in nodes && "inventory" in nodes && "warehouse" in nodes;
  }
  return false;
}

test bool testForbiddenGatewayToPayments() {
  ValidationReport r = validateGraph(stressArch(), mockFullGraph());
  set[Violation] vs = {v | <Violation v, _> <- r.findings};
  return forbiddenDependency("Gateway", "Payments") in vs;
}

test bool testUnpermittedGatewayToPayments() {
  ValidationReport r = validateGraph(stressArch(), mockFullGraph());
  set[Violation] vs = {v | <Violation v, _> <- r.findings};
  return unpermittedDependency("Gateway", "payments") in vs;
}

test bool testDebtScoreIncludesCycleAndForbidden() {
  ValidationReport r = validateGraph(stressArch(), mockFullGraph());
  int criticals = size([1 | <_, critical()> <- r.findings]);
  return criticals >= 2 && r.debtScore >= 20;
}

test bool testDebtScoreExact() {
  ValidationReport r = validateGraph(stressArch(), mockFullGraph());
  int expectedCriticals = size([1 | <_, critical()> <- r.findings]);
  int expectedWarnings = size([1 | <_, warning()> <- r.findings]);
  int expectedInfos = size([1 | <_, info()> <- r.findings]);
  return r.debtScore == (expectedCriticals * 10) + (expectedWarnings * 5) + (expectedInfos * 1);
}

test bool testReportContainsCycleAndForbidden() {
  ValidationReport r = validateGraph(stressArch(), mockFullGraph());
  str text = formatReport(r);
  return /Circular/ := text && /Forbidden/ := text;
}

test bool testDotExportRuns() {
  ValidationReport r = validateGraph(stressArch(), mockFullGraph());
  str dot = generateDot(r, mockFullGraph());
  return /digraph/ := dot
      && /red/ := dot
      && /green/ := dot
      && /grey/ := dot;
}

test bool testExportDotFile() {
  ValidationReport r = validateGraph(stressArch(), mockFullGraph());
  loc output = |file:///Users/carlagonzalez/Desktop/ArchGuard-M3/examples/stress_test_graph.dot|;
  exportDot(r, mockFullGraph(), output);
  return true;
}
