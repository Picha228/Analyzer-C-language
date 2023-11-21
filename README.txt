If the file is correct from the point of view of the C programming language, then the analyzer outputs ok. But if there are any errors, the program points to the line and position where it was found.
Parser (x-grammar.y) and lexer(x-lexer.l).You can use makefile to compile analyzer.
kurs.zip contains all necessary files.
running tests:
cd bin/release
./compiler ../../tests/1.1.c
