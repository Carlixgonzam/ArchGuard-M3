module check::Reporter

import check::DriftValidator;
import extract::M3Extractor;
import lang::arch::AST;
import String;
import List;
import Set;
import IO;

str formatReport(ValidationReport report) =
  "=== ArchGuard-M3 Drift Report ===\n\n"
  + formatFindings(report.findings)
  + formatSummary(report);

str formatFindings(list[tuple[Violation violation, Severity severity]] findings) {
  if (isEmpty(findings)) return "No violations detected.\n\n";
  return intercalate("\n", [formatFinding(f.violation, f.severity) | f <- findings]) + "\n\n";
}

str formatFinding(Violation v, Severity s) =
  "[<formatSeverity(s)>] <formatViolation(v)>";

str formatSeverity(critical()) = "CRITICAL";
str formatSeverity(warning()) = "WARNING ";
str formatSeverity(info())     = "INFO    ";

str formatViolation(forbiddenDependency(str src, str tgt)) =
  "Forbidden dependency: <src> -\> <tgt>";

str formatViolation(unpermittedDependency(str src, str tgt)) =
  "Unpermitted dependency: <src> -\> <tgt>";

str formatViolation(missingDependency(str src, str tgt)) =
  "Missing expected dependency: <src> -/\> <tgt>";

str formatViolation(circularDependency(list[str] cycle)) =
  "Circular dependency detected: <intercalate(" -\> ", cycle)>";

str formatSummary(ValidationReport report) {
  int total = size(report.findings);
  int crits = size([1 | <_, critical()> <- report.findings]);
  int warns = size([1 | <_, warning()> <- report.findings]);
  int infos = size([1 | <_, info()> <- report.findings]);
  return "--- Summary ---\n"
    + "Findings: <total> (Critical: <crits>, Warning: <warns>, Info: <infos>)\n"
    + "Technical Debt Score: <report.debtScore>\n";
}

str formatExtractionSummary(ExtractionResult result) =
  "=== Extraction Summary ===\n"
  + "Services discovered: <intercalate(", ", sort(toList(result.services)))>\n"
  + "Cross-service invocations: <size(result.invocations)>\n"
  + "Cross-service type deps: <size(result.typeDependencies)>\n"
  + "HTTP endpoints: <size(result.endpoints)>\n"
  + "DB entities: <size(result.dbEntities)>\n"
  + "Feign clients: <size(result.feignClients)>\n"
  + "REST clients: <size(result.restClients)>\n"
  + "Repositories: <size(result.repositories)>\n";

void printReport(ValidationReport report) {
  println(formatReport(report));
}

void printExtractionSummary(ExtractionResult result) {
  println(formatExtractionSummary(result));
}
