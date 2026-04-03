module vis::DriftVisualizer

import vis::Figure;
import vis::Render;
import check::DriftValidator;
import extract::M3Extractor;
import Relation;
import Set;
import List;
import String;

void renderDriftGraph(ValidationReport report) {
  set[str] services = collectServices(report);
  list[Figure] nodes = [makeNode(s) | s <- sort(toList(services))];
  list[Figure] edges = makeViolationEdges(report);
  render(vcat([
    text("ArchGuard-M3 Drift Visualization", fontSize(18)),
    graph(nodes, edges, hint("layered"), gap(40)),
    makeLegend()
  ], gap(15)));
}

void renderDriftGraph(ValidationReport report, DependencyGraph actual) {
  set[str] services = {toLowerCase(s) | s <- collectServices(report)} + carrier(actual);
  set[tuple[str,str]] bad = violationPairs(report);
  set[tuple[str,str]] missing = missingPairs(report);

  list[Figure] nodes = [makeNode(s) | s <- sort(toList(services))];

  list[Figure] edges = [];
  for (<str s, str t> <- actual) {
    if (<s, t> in bad)
      edges += [edge(s, t, lineColor("red"), lineWidth(3))];
    else
      edges += [edge(s, t, lineColor("green"), lineWidth(2))];
  }
  for (<str s, str t> <- missing) {
    str sn = toLowerCase(s);
    str tn = toLowerCase(t);
    if (sn in services)
      edges += [edge(sn, tn, lineColor("grey"), lineWidth(1), lineStyle([8, 4]))];
  }

  render(vcat([
    text("ArchGuard-M3 Drift Visualization", fontSize(18)),
    graph(nodes, edges, hint("layered"), gap(40)),
    makeLegend()
  ], gap(15)));
}

Figure makeNode(str name) =
  ellipse(text(name, fontSize(12)), id(name), size(120, 50), fillColor("lightblue"), lineWidth(2));

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

list[Figure] makeViolationEdges(ValidationReport report) {
  list[Figure] edges = [];
  for (<Violation v, _> <- report.findings)
    edges += violationToEdge(v);
  return edges;
}

list[Figure] violationToEdge(forbiddenDependency(str s, str t)) =
  [edge(s, t, lineColor("red"), lineWidth(3))];

list[Figure] violationToEdge(unpermittedDependency(str s, str t)) =
  [edge(s, t, lineColor("red"), lineWidth(2))];

list[Figure] violationToEdge(missingDependency(str s, str t)) =
  [edge(s, t, lineColor("grey"), lineWidth(1), lineStyle([8, 4]))];

list[Figure] violationToEdge(circularDependency(list[str] _)) = [];

Figure makeLegend() = hcat([
  hcat([box(fillColor("green"), size(15, 15)), text(" Permitted")]),
  hcat([box(fillColor("red"), size(15, 15)), text(" Forbidden/Unpermitted")]),
  hcat([box(fillColor("grey"), size(15, 15)), text(" Missing (dependsOn)")])
], gap(20));
