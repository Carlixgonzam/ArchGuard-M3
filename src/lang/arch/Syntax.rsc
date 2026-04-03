module lang::arch::Syntax

layout Layout = [\t\n\r\ ]* !>> [\t\n\r\ ];

lexical StringLit = "\"" ![\"]*  "\"";

start syntax Architecture = architecture: ServiceDecl* decls;

syntax ServiceDecl
  = permits:   "service" StringLit name "permits"   StringSet targets
  | forbids:   "service" StringLit name "forbids"   StringSet targets
  | dependsOn: "service" StringLit name "dependsOn" StringSet targets
  ;

syntax StringSet = stringSet: "{" {StringLit ","}* elements "}";
