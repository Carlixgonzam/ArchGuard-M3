module extract::SpringBootAnalyzer

import extract::M3Extractor;
import analysis::m3::Core;
import lang::java::m3::Core;
import Set;
import String;
import List;
import Relation;

data SpringDependency
  = restCall(str source, str target, str method)
  | feignBinding(str source, str clientInterface)
  | dbCrossAccess(str service, str entity, str ownerService)
  ;

data SpringAnalysis = springAnalysis(
  ExtractionResult base,
  set[SpringDependency] springDeps,
  rel[str service, str client] restClients,
  rel[str service, str repository] repositories
);

SpringAnalysis analyzeSpringBoot(M3 model, int depth) {
  ExtractionResult base = extractFromModel(model, depth);
  return springAnalysis(
    base,
    detectSpringDependencies(model, depth, base),
    detectRestClients(model, depth),
    detectRepositories(model, depth)
  );
}

SpringAnalysis analyzeSpringBoot(loc projectDir, int depth) =
  analyzeSpringBoot(buildModel(projectDir), depth);

set[SpringDependency] detectSpringDependencies(M3 model, int depth, ExtractionResult base) =
  detectFeignClients(model, depth)
  + detectRestTemplateCalls(model, depth)
  + detectCrossDbAccess(model, depth, base);

set[SpringDependency] detectFeignClients(M3 model, int depth) =
  {feignBinding(segmentAt(decl.path, depth), decl.path) |
    <decl, ann> <- model.annotations,
    /FeignClient/ := ann.path,
    segmentAt(decl.path, depth) != ""};

set[SpringDependency] detectRestTemplateCalls(M3 model, int depth) =
  {restCall(segmentAt(caller.path, depth), callee.path, "HTTP") |
    <caller, callee> <- model.methodInvocation,
    /RestTemplate|WebClient|HttpClient/ := callee.path,
    segmentAt(caller.path, depth) != ""};

set[SpringDependency] detectCrossDbAccess(M3 model, int depth, ExtractionResult base) {
  rel[str, str] repoOwners = {<segmentAt(decl.path, depth), decl.path> |
    <decl, ann> <- model.annotations,
    /Repository/ := ann.path,
    segmentAt(decl.path, depth) != ""};

  set[SpringDependency] violations = {};
  for (<caller, callee> <- model.methodInvocation) {
    str callerSvc = segmentAt(caller.path, depth);
    str calleePath = callee.path;
    for (<str repoOwner, str repoPath> <- repoOwners,
         contains(calleePath, repoPath),
         callerSvc != "" && repoOwner != "" && callerSvc != repoOwner) {
      violations += {dbCrossAccess(callerSvc, repoPath, repoOwner)};
    }
  }
  return violations;
}

rel[str, str] detectRestClients(M3 model, int depth) =
  {<segmentAt(decl.path, depth), decl.path> |
    <decl, ann> <- model.annotations,
    /FeignClient|RestController|Controller/ := ann.path,
    segmentAt(decl.path, depth) != ""};

rel[str, str] detectRepositories(M3 model, int depth) =
  {<segmentAt(decl.path, depth), decl.path> |
    <decl, ann> <- model.annotations,
    /Repository|JpaRepository|CrudRepository/ := ann.path,
    segmentAt(decl.path, depth) != ""};

DependencyGraph springToDependencyGraph(set[SpringDependency] deps) {
  DependencyGraph graph = {};
  for (restCall(str src, str tgt, _) <- deps) graph += {<src, tgt>};
  for (dbCrossAccess(str svc, _, str owner) <- deps) graph += {<svc, owner>};
  return graph;
}
