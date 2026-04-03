module lang::arch::TestAST

import lang::arch::Syntax;
import lang::arch::Parser;
import lang::arch::AST;

test bool astSinglePermits() =
  buildAST(parseArchitecture("service \"Orders\" permits {\"Payments\"}"))
  == architecture([permits("Orders", ["Payments"])]);

test bool astSingleForbids() =
  buildAST(parseArchitecture("service \"Orders\" forbids {\"Analytics\"}"))
  == architecture([forbids("Orders", ["Analytics"])]);

test bool astSingleDependsOn() =
  buildAST(parseArchitecture("service \"Payments\" dependsOn {\"Database\"}"))
  == architecture([dependsOn("Payments", ["Database"])]);

test bool astMultipleTargets() =
  buildAST(parseArchitecture("service \"Orders\" permits {\"Payments\", \"Inventory\", \"Shipping\"}"))
  == architecture([permits("Orders", ["Payments", "Inventory", "Shipping"])]);

test bool astEmptyTargetSet() =
  buildAST(parseArchitecture("service \"Orders\" permits {}"))
  == architecture([permits("Orders", [])]);

test bool astMultipleDeclarations() =
  buildAST(parseArchitecture(
    "service \"Orders\" permits {\"Payments\"}
     service \"Auth\" forbids {\"Analytics\"}"
  ))
  == architecture([permits("Orders", ["Payments"]), forbids("Auth", ["Analytics"])]);

test bool astMixedRelations() =
  buildAST(parseArchitecture(
    "service \"Auth\" permits {\"Users\"}
     service \"Auth\" forbids {\"Orders\"}
     service \"Auth\" dependsOn {\"Database\"}"
  ))
  == architecture([
       permits("Auth", ["Users"]),
       forbids("Auth", ["Orders"]),
       dependsOn("Auth", ["Database"])
     ]);

test bool astEmptyArchitecture() =
  buildAST(parseArchitecture(""))
  == architecture([]);

test bool astPreservesTargetOrder() =
  buildAST(parseArchitecture("service \"X\" permits {\"C\", \"A\", \"B\"}"))
  == architecture([permits("X", ["C", "A", "B"])]);

test bool astPreservesDeclarationOrder() =
  buildAST(parseArchitecture(
    "service \"B\" permits {\"X\"}
     service \"A\" forbids {\"Y\"}
     service \"C\" dependsOn {\"Z\"}"
  ))
  == architecture([
       permits("B", ["X"]),
       forbids("A", ["Y"]),
       dependsOn("C", ["Z"])
     ]);
