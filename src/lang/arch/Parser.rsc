module lang::arch::Parser

import lang::arch::Syntax;
import ParseTree;

start[Architecture] parseArchitecture(str input) = parse(#start[Architecture], input);
