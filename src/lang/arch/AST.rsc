module lang::arch::AST

import lang::arch::Syntax;
import ParseTree;

data Architecture = architecture(list[ServiceDecl] decls);

data ServiceDecl
  = permits(str name, list[str] targets)
  | forbids(str name, list[str] targets)
  | dependsOn(str name, list[str] targets)
  ;

Architecture buildAST(start[Architecture] pt) = buildAST(pt.top);

Architecture buildAST((Architecture)`<ServiceDecl* ds>`) =
  architecture([buildDecl(d) | d <- ds]);

ServiceDecl buildDecl((ServiceDecl)`service <StringLit n> permits <StringSet s>`) =
  permits(unquote("<n>"), extractTargets(s));

ServiceDecl buildDecl((ServiceDecl)`service <StringLit n> forbids <StringSet s>`) =
  forbids(unquote("<n>"), extractTargets(s));

ServiceDecl buildDecl((ServiceDecl)`service <StringLit n> dependsOn <StringSet s>`) =
  dependsOn(unquote("<n>"), extractTargets(s));

list[str] extractTargets((StringSet)`{<{StringLit ","}* es>}`) =
  [unquote("<e>") | e <- es];

str unquote(str s) = s[1..-1];
