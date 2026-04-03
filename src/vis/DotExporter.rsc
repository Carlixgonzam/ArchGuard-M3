module vis::DotExporter

import check::DriftValidator;
import extract::M3Extractor;
import Relation;
import Set;
import List;
import String;
import IO;

str generateDot(ValidationReport report) {
  set[str] services = collectServices(report);
  str nodes = intercalate("\n", [dotNode(s) | s <- sort(toList(services))]);
  str edges = intercalate("\n", dotViolationEdges(report));
  return "digraph ArchGuard {\n"
    + "  rankdir=LR;\n"
    + "  node [shape=ellipse, style=filled, fillcolor=lightblue, fontname=Helvetica];\n"
    + "  edge [fontname=Helvetica, fontsize=10];\n\n"
    + nodes + "\n\n"
    + edges + "\n\n"
    + dotLegend()
    + "}\n";
}

str generateDot(ValidationReport report, DependencyGraph actual) {
  set[str] services = {toLowerCase(s) | s <- collectServices(report)} + carrier(actual);
  set[tuple[str,str]] bad = violationPairs(report);
  set[tuple[str,str]] missing = missingPairs(report);

  str nodes = intercalate("\n", [dotNode(s) | s <- sort(toList(services))]);

  list[str] edgeLines = [];
  for (<str s, str t> <- actual) {
    if (<s, t> in bad)
      edgeLines += ["  \"<s>\" -\> \"<t>\" [color=red, penwidth=2.0, label=\"violation\"];"];
    else
      edgeLines += ["  \"<s>\" -\> \"<t>\" [color=green, penwidth=2.0, label=\"permitted\"];"];
  }
  for (<str s, str t> <- missing) {
    str sn = toLowerCase(s);
    str tn = toLowerCase(t);
    edgeLines += ["  \"<sn>\" -\> \"<tn>\" [color=grey, style=dashed, label=\"missing\"];"];
  }

  return "digraph ArchGuard {\n"
    + "  rankdir=LR;\n"
    + "  node [shape=ellipse, style=filled, fillcolor=lightblue, fontname=Helvetica];\n"
    + "  edge [fontname=Helvetica, fontsize=10];\n\n"
    + nodes + "\n\n"
    + intercalate("\n", edgeLines) + "\n\n"
    + dotLegend()
    + "}\n";
}

void exportDot(ValidationReport report, loc output) {
  writeFile(output, generateDot(report));
}

void exportDot(ValidationReport report, DependencyGraph actual, loc output) {
  writeFile(output, generateDot(report, actual));
}

str dotNode(str name) =
  "  \"<name>\" [label=\"<name>\"];";

str dotViolationEdge(forbiddenDependency(str s, str t)) =
  "  \"<s>\" -\> \"<t>\" [color=red, penwidth=2.5, label=\"forbidden\"];";

str dotViolationEdge(unpermittedDependency(str s, str t)) =
  "  \"<s>\" -\> \"<t>\" [color=red, penwidth=2.0, style=bold, label=\"unpermitted\"];";

str dotViolationEdge(missingDependency(str s, str t)) =
  "  \"<s>\" -\> \"<t>\" [color=grey, style=dashed, label=\"missing\"];";

str dotViolationEdge(circularDependency(list[str] _)) = "";

set[str] violationNodes(forbiddenDependency(str s, str t)) = {s, t};
set[str] violationNodes(unpermittedDependency(str s, str t)) = {s, t};
set[str] violationNodes(missingDependency(str s, str t)) = {s, t};
set[str] violationNodes(circularDependency(list[str] c)) = toSet(c);

set[str] collectServices(ValidationReport report) {
  set[str] result = {};
  for (<Violation v, _> <- report.findings)
    result += violationNodes(v);
  return result;
}

set[tuple[str,str]] violationPairs(ValidationReport report) =
  {<toLowerCase(s), toLowerCase(t)> | <forbiddenDependency(str s, str t), _> <- report.findings} +
  {<toLowerCase(s), toLowerCase(t)> | <unpermittedDependency(str s, str t), _> <- report.findings};

set[tuple[str,str]] missingPairs(ValidationReport report) =
  {<s, t> | <missingDependency(str s, str t), _> <- report.findings};

list[str] dotViolationEdges(ValidationReport report) {
  list[str] edges = [];
  for (<Violation v, _> <- report.findings) {
    str e = dotViolationEdge(v);
    if (e != "") edges += [e];
  }
  return edges;
}

str dotLegend() =
  "  subgraph cluster_legend {\n"
  + "    label=\"Legend\";\n"
  + "    style=dashed;\n"
  + "    fontname=Helvetica;\n"
  + "    leg_g [label=\"Permitted\", shape=box, fillcolor=green, style=filled];\n"
  + "    leg_r [label=\"Forbidden/Unpermitted\", shape=box, fillcolor=red, style=filled, fontcolor=white];\n"
  + "    leg_d [label=\"Missing (dependsOn)\", shape=box, fillcolor=grey, style=\"filled,dashed\"];\n"
  + "  }\n";
