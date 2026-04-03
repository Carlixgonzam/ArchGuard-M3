module ArchGuard

import lang::arch::Syntax;
import lang::arch::Parser;
import lang::arch::AST;
import extract::M3Extractor;
import check::DriftValidator;
import check::Reporter;
import IO;
import Set;
import String;

str runAnalysis(loc dslFile, loc projectDir, int serviceDepth) {
  Architecture arch = loadArchitecture(dslFile);
  ExtractionResult extraction = extractArchitecture(projectDir, serviceDepth);
  ValidationReport report = validate(arch, extraction);
  return formatExtractionSummary(extraction)
    + "\n"
    + formatReport(report);
}

str runFullAnalysis(loc dslFile, loc projectDir, int serviceDepth) {
  Architecture arch = loadArchitecture(dslFile);
  ExtractionResult extraction = extractArchitecture(projectDir, serviceDepth);
  ValidationReport report = validateFull(arch, extraction);
  return formatExtractionSummary(extraction)
    + "\n"
    + formatReport(report);
}

ValidationReport analyze(loc dslFile, loc projectDir, int serviceDepth) {
  Architecture arch = loadArchitecture(dslFile);
  ExtractionResult actual = extractArchitecture(projectDir, serviceDepth);
  return validate(arch, actual);
}

ValidationReport analyzeFromString(str dslContent, loc projectDir, int serviceDepth) {
  Architecture arch = loadArchitectureFromString(dslContent);
  ExtractionResult actual = extractArchitecture(projectDir, serviceDepth);
  return validate(arch, actual);
}

ValidationReport analyzeFromModels(Architecture arch, ExtractionResult actual) =
  validate(arch, actual);

ValidationReport analyzeFullFromModels(Architecture arch, ExtractionResult actual) =
  validateFull(arch, actual);

void printAnalysis(loc dslFile, loc projectDir, int serviceDepth) {
  println(runAnalysis(dslFile, projectDir, serviceDepth));
}

Architecture loadArchitecture(loc dslFile) =
  buildAST(parseArchitecture(readFile(dslFile)));

Architecture loadArchitectureFromString(str content) =
  buildAST(parseArchitecture(content));

void exportFullReport(ValidationReport report, loc outputTex) {
  writeFile(outputTex, generateFullLatex(report));
}
