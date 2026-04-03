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
  validateGraph(arch, mergeAllDependencies(actual));

ValidationReport validateGraph(Architecture arch, DependencyGraph actualDeps) {
  list[tuple[Violation, Severity]] findings =
    checkForbids(arch, actualDeps) +
    checkPermits(arch, actualDeps) +
    checkDependsOn(arch, actualDeps) +
    checkCycles(actualDeps);
  return validationReport(findings, computeDebt(findings));
}

list[tuple[Violation, Severity]] checkForbids(Architecture arch, DependencyGraph actual) {
  list[tuple[Violation, Severity]] results = [];
  for (forbids(str name, list[str] forbidden) <- arch.decls) {
    set[str] actualNorm = {normalize(t) | t <- actual[normalize(name)]};
    set[str] forbiddenNorm = {normalize(f) | f <- forbidden};
    set[str] delta = actualNorm & forbiddenNorm;
    results += [<forbiddenDependency(name, f), critical()> | f <- forbidden, normalize(f) in delta];
  }
  return results;
}

list[tuple[Violation, Severity]] checkPermits(Architecture arch, DependencyGraph actual) {
  list[tuple[Violation, Severity]] results = [];
  for (permits(str name, list[str] allowed) <- arch.decls) {
    set[str] actualTargets = actual[normalize(name)];
    set[str] allowedNorm = {normalize(a) | a <- allowed};
    set[str] delta = {t | t <- actualTargets, normalize(t) notin allowedNorm};
    results += [<unpermittedDependency(name, t), warning()> | t <- delta];
  }
  return results;
}

list[tuple[Violation, Severity]] checkDependsOn(Architecture arch, DependencyGraph actual) {
  list[tuple[Violation, Severity]] results = [];
  for (dependsOn(str name, list[str] deps) <- arch.decls) {
    set[str] actualNorm = {normalize(t) | t <- actual[normalize(name)]};
    set[str] expectedNorm = {normalize(e) | e <- deps};
    set[str] delta = expectedNorm - actualNorm;
    results += [<missingDependency(name, e), info()> | e <- deps, normalize(e) in delta];
  }
  return results;
}

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
