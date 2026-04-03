module lang::arch::TestParser

import lang::arch::Syntax;
import lang::arch::Parser;
import ParseTree;

test bool validSinglePermits() {
  parseArchitecture("service \"Orders\" permits {\"Payments\"}");
  return true;
}

test bool validSingleForbids() {
  parseArchitecture("service \"Orders\" forbids {\"Analytics\"}");
  return true;
}

test bool validSingleDependsOn() {
  parseArchitecture("service \"Payments\" dependsOn {\"Database\"}");
  return true;
}

test bool validMultipleTargets() {
  parseArchitecture("service \"Orders\" permits {\"Payments\", \"Inventory\", \"Shipping\"}");
  return true;
}

test bool validEmptyTargetSet() {
  parseArchitecture("service \"Orders\" permits {}");
  return true;
}

test bool validMultipleDeclarations() {
  parseArchitecture(
    "service \"Orders\" permits {\"Payments\", \"Inventory\"}
     service \"Orders\" forbids {\"Analytics\"}
     service \"Payments\" dependsOn {\"Database\", \"Cache\"}"
  );
  return true;
}

test bool validMixedRelations() {
  parseArchitecture(
    "service \"Auth\" permits {\"Users\"}
     service \"Auth\" forbids {\"Orders\"}
     service \"Auth\" dependsOn {\"Database\"}"
  );
  return true;
}

test bool validEmptyArchitecture() {
  parseArchitecture("");
  return true;
}

test bool invalidMissingServiceKeyword() {
  try {
    parseArchitecture("\"Orders\" permits {\"Payments\"}");
    return false;
  } catch ParseError(_): return true;
}

test bool invalidUnknownRelation() {
  try {
    parseArchitecture("service \"Orders\" requires {\"Payments\"}");
    return false;
  } catch ParseError(_): return true;
}

test bool invalidMissingBraces() {
  try {
    parseArchitecture("service \"Orders\" permits \"Payments\"");
    return false;
  } catch ParseError(_): return true;
}

test bool invalidUnquotedServiceName() {
  try {
    parseArchitecture("service Orders permits {\"Payments\"}");
    return false;
  } catch ParseError(_): return true;
}

test bool invalidIncompleteDeclaration() {
  try {
    parseArchitecture("service \"Orders\"");
    return false;
  } catch ParseError(_): return true;
}

test bool invalidMissingClosingBrace() {
  try {
    parseArchitecture("service \"Orders\" permits {\"Payments\"");
    return false;
  } catch ParseError(_): return true;
}
