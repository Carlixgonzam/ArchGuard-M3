module ArchGuard

import lang::arch::Syntax;
import lang::arch::Parser;
import lang::arch::AST;
import extract::M3Extractor;
import extract::SpringBootAnalyzer;
import check::DriftValidator;
import check::Reporter;
import analysis::m3::Core;
import lang::java::m3::Core;
import IO;
import String;

ValidationReport analyze(loc dslFile, loc projectDir, int serviceDepth) {
  Architecture arch = loadArchitecture(dslFile);
  ExtractionResult actual = extractArchitecture(projectDir, serviceDepth);
  return validate(arch, actual);
}

ValidationReport analyzeFromString(str dslContent, loc projectDir, int serviceDepth) {
  Architecture arch = buildAST(parseArchitecture(dslContent));
  ExtractionResult actual = extractArchitecture(projectDir, serviceDepth);
  return validate(arch, actual);
}

ValidationReport analyzeFromModels(Architecture arch, ExtractionResult actual) =
  validate(arch, actual);

ValidationReport analyzeFullFromModels(Architecture arch, ExtractionResult actual) =
  validateFull(arch, actual);

str runAnalysis(loc dslFile, loc projectDir, int serviceDepth) {
  ExtractionResult extraction = extractArchitecture(projectDir, serviceDepth);
  Architecture arch = loadArchitecture(dslFile);
  ValidationReport report = validate(arch, extraction);
  return formatExtractionSummary(extraction)
    + "\n"
    + formatReport(report);
}

str runSpringAnalysis(loc dslFile, loc projectDir, int serviceDepth) {
  M3 model = buildModel(projectDir);
  SpringAnalysis spring = analyzeSpringBoot(model, serviceDepth);
  Architecture arch = loadArchitecture(dslFile);

  DependencyGraph extraDeps = springToDependencyGraph(spring.springDeps);
  DependencyGraph mergedGraph = spring.base.invocations + extraDeps;
  ValidationReport report = validateGraph(arch, mergedGraph);

  return formatExtractionSummary(spring.base)
    + "Spring dependencies: <size(spring.springDeps)>\n"
    + "REST clients: <size(spring.restClients)>\n"
    + "Repositories: <size(spring.repositories)>\n\n"
    + formatReport(report);
}

void printAnalysis(loc dslFile, loc projectDir, int serviceDepth) {
  println(runAnalysis(dslFile, projectDir, serviceDepth));
}

Architecture loadArchitecture(loc dslFile) =
  buildAST(parseArchitecture(readFile(dslFile)));

Architecture loadArchitectureFromString(str content) =
  buildAST(parseArchitecture(content));
