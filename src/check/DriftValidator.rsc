module check::DriftValidator

import lang::arch::AST;
import extract::M3Extractor;
import Relation;
import Set;
import List;
import String;

data Violation
  = forbiddenDependency(str source, str target)
  | unpermittedDependency(str source, str target)
  | missingDependency(str source, str target)
  | circularDependency(list[str] cycle)
  ;

data Severity = critical() | warning() | info();

data ValidationReport = validationReport(
  list[tuple[Violation violation, Severity severity]] findings,
  int debtScore
);

str normalize(str s) = toLowerCase(s);

ValidationReport validate(Architecture arch, ExtractionResult actual) =
  validateGraph(arch, actual.invocations);

ValidationReport validateFull(Architecture arch, ExtractionResult actual) =
  validateGraph(arch, actual.invocations +
    {<s, t> | <s, t> <- actual.typeDependencies,
              s in actual.services, t in actual.services});

ValidationReport validateGraph(Architecture arch, DependencyGraph actualDeps) {
  list[tuple[Violation, Severity]] findings =
    checkPermits(arch, actualDeps) +
    checkForbids(arch, actualDeps) +
    checkDependsOn(arch, actualDeps) +
    checkCycles(actualDeps);
  return validationReport(findings, computeDebt(findings));
}

list[tuple[Violation, Severity]] checkPermits(Architecture arch, DependencyGraph actual) =
  [<unpermittedDependency(name, target), warning()> |
    permits(str name, list[str] allowed) <- arch.decls,
    str target <- actual[normalize(name)],
    normalize(target) notin {normalize(a) | a <- allowed}];

list[tuple[Violation, Severity]] checkForbids(Architecture arch, DependencyGraph actual) =
  [<forbiddenDependency(name, f), critical()> |
    forbids(str name, list[str] forbidden) <- arch.decls,
    str f <- forbidden,
    normalize(f) in {normalize(t) | t <- actual[normalize(name)]}];

list[tuple[Violation, Severity]] checkDependsOn(Architecture arch, DependencyGraph actual) =
  [<missingDependency(name, expected), info()> |
    dependsOn(str name, list[str] deps) <- arch.decls,
    str expected <- deps,
    normalize(expected) notin {normalize(t) | t <- actual[normalize(name)]}];

list[tuple[Violation, Severity]] checkCycles(DependencyGraph graph) {
  if (isEmpty(graph)) return [];
  DependencyGraph closure = graph+;
  set[str] inCycle = {n | str n <- carrier(graph), <n, n> in closure};
  if (isEmpty(inCycle)) return [];
  return [<circularDependency(sort(toList(inCycle))), critical()>];
}

int computeDebt(list[tuple[Violation, Severity]] findings) =
  (0 | it + debtPoints(s) | <_, Severity s> <- findings);

int debtPoints(critical()) = 10;
int debtPoints(warning()) = 5;
int debtPoints(info()) = 1;
