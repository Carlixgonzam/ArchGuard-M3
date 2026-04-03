module extract::M3Extractor

import lang::java::m3::Core;
import analysis::m3::Core;
import IO;
import Set;
import String;
import List;
import Relation;

alias ServiceName = str;
alias DependencyGraph = rel[ServiceName source, ServiceName target];

data ExtractionResult = extractionResult(
  set[ServiceName] services,
  DependencyGraph invocations,
  DependencyGraph typeDependencies,
  rel[ServiceName, str] endpoints,
  rel[ServiceName, str] dbEntities,
  rel[ServiceName, str] feignClients = {},
  rel[ServiceName, str] restClients = {},
  rel[ServiceName, str] repositories = {}
);

M3 buildModel(loc projectDir) = createM3FromDirectory(projectDir);

ExtractionResult extractArchitecture(loc projectDir, int serviceDepth) =
  extractFromModel(buildModel(projectDir), serviceDepth);

ExtractionResult extractFromModel(M3 model, int depth) =
  extractionResult(
    discoverServices(model, depth),
    extractInvocations(model, depth),
    extractTypeDependencies(model, depth),
    extractEndpoints(model, depth),
    extractDbEntities(model, depth),
    feignClients = extractFeignClients(model, depth),
    restClients = extractRestClients(model, depth),
    repositories = extractRepositories(model, depth)
  );

set[ServiceName] discoverServices(M3 model, int depth) =
  {s | <pkg, _> <- model.containment,
       pkg.scheme == "java+package",
       str s := segmentAt(pkg.path, depth),
       s != ""};

DependencyGraph extractInvocations(M3 model, int depth) {
  DependencyGraph result = {};
  for (<caller, callee> <- model.methodInvocation) {
    str s = segmentAt(caller.path, depth);
    str t = segmentAt(callee.path, depth);
    if (s != "" && t != "" && s != t)
      result += {<s, t>};
  }
  return result;
}

DependencyGraph extractTypeDependencies(M3 model, int depth) {
  DependencyGraph result = {};
  for (<src, dep> <- model.typeDependency) {
    str s = segmentAt(src.path, depth);
    str t = segmentAt(dep.path, depth);
    if (s != "" && t != "" && s != t)
      result += {<s, t>};
  }
  return result;
}

rel[ServiceName, str] extractEndpoints(M3 model, int depth) =
  {<segmentAt(decl.path, depth), decl.path> |
    <decl, ann> <- model.annotations,
    /RequestMapping|GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping/ := ann.path};

rel[ServiceName, str] extractDbEntities(M3 model, int depth) =
  {<segmentAt(decl.path, depth), decl.path> |
    <decl, ann> <- model.annotations,
    /Entity|Repository|Table/ := ann.path};

rel[ServiceName, str] extractFeignClients(M3 model, int depth) =
  {<segmentAt(decl.path, depth), decl.path> |
    <decl, ann> <- model.annotations,
    /FeignClient/ := ann.path,
    segmentAt(decl.path, depth) != ""};

rel[ServiceName, str] extractRestClients(M3 model, int depth) =
  {<segmentAt(caller.path, depth), callee.path> |
    <caller, callee> <- model.methodInvocation,
    /RestTemplate|WebClient|HttpClient/ := callee.path,
    segmentAt(caller.path, depth) != ""};

rel[ServiceName, str] extractRepositories(M3 model, int depth) =
  {<segmentAt(decl.path, depth), decl.path> |
    <decl, ann> <- model.annotations,
    /Repository|JpaRepository|CrudRepository/ := ann.path,
    segmentAt(decl.path, depth) != ""};

DependencyGraph mergeAllDependencies(ExtractionResult result) =
  result.invocations +
  {<s, t> | <s, t> <- result.typeDependencies,
            s in result.services, t in result.services};

str segmentAt(str path, int index) {
  list[str] parts = [p | p <- split("/", path), p != ""];
  if (index < size(parts)) return parts[index];
  return "";
}
