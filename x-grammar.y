%locations

%{
  #include <stdio.h>
  #include <string.h>
  #include <assert.h>

  #include "x-lexer.h"
  
  #define MAX_NAME 	32
  #define MAX_COUNT 64
  #define YYDEBUG 1

  /* Это глобальные переменные */
  int flag_default = 0;
  int flag_loop = 0;
  
  int flag_struct = 0;
  int flag_enum = 0;
  int flag_union = 0;
  int flag_local_var = 0;
  
  char struct_construct[MAX_COUNT][MAX_NAME] = { 0 };
  int count_struct = 0;
  char union_construct[MAX_COUNT][MAX_NAME] = { 0 };
  int count_union = 0;
  
  char global_vars[MAX_COUNT][MAX_NAME] = { 0 };
  int count_global_vars = 0;  
  char local_vars[MAX_COUNT][MAX_NAME] = { 0 };
  int count_local_vars = 0;  

  /* Это сигнатуры необходимых bison'у функций */
  int yylex (void);
  void yyerror (char const * s);

  /* Здесь сигнатуры наших функций */
  static void printTerminal(const char * tokName);
  static void printNonTerminal(const char * tokName);
  
  void checkNewDeclaration(const char * identificator);
  void controlDeclaratedVariables(const char * identificator);
  void checkVariables(char variables[MAX_COUNT][MAX_NAME], int* count, const char * identificator);
  void free_local_vars();
  
  void newConstructionNameCheck(const char * identificator);
  void controlConstructionName(const char * identificator);
%}

%token TOK_IF TOK_ELIF TOK_ELSE TOK_FOR TOK_BREAK TOK_CONTINUE TOK_RET
%token TOK_TYPE_CHAR TOK_TYPE_FLOAT TOK_TYPE_VOID TOK_TYPE_INT TOK_TYPE_STATIC TOK_TYPE_CONST TOK_TYPE_FILE TOK_TYPE__Bool TOK_TYPE_size_t
%token TOK_CHAR TOK_INT TOK_FLOAT TOK_HEX_NUMBER
%token TOK_LOGIC TOK_COMPARE
%token TOK_SHIFT_OP TOK_BIT_OP TOK_INC_DEC TOK_PRE_ASSIGN_OP
%token TOK_EXTERN TOK_INCLUDE TOK_DEFINE TOK_STRING_DEFINE TOK_STRING TOK_STRING_INCLUDE TOK_WHILE TOK_DO
%token TOK_ENUM TOK_UNION TOK_STRUCT
%token TOK_SWITCH TOK_CASE TOK_DEFAULT
%token TOK_ERROR
%token TOK_DOT TOK_NULL TOK_SIZEOF

%union
{
 char *name;
}

%token <name> TOK_IDENT

%left TOK_PRE_ASSIGN_OP

%left TOK_BIT_OP '&'
%left TOK_LOGIC 
%left TOK_COMPARE 
%left TOK_SHIFT_OP
%left '-' '+'
%left '*' '/' '%'
%left TOK_UMIN TOK_NOT TOK_INC_DEC
%left TOK_DOT
%left '(' ')'

%start program

%%

/* Аксиома грамматики */
program:
  input { printNonTerminal("OK"); }
;

/* Здесь идут входные выражения */
input:
  func_def          					{ printNonTerminal("func_def"); }
| func_def input    					{ printNonTerminal("func_def input"); }
| global_var_decl input					{ printNonTerminal("global_var_decl input"); } 
| include	input						{ printNonTerminal("include input"); }
| define	input						{ printNonTerminal("define input"); }
| enumeration input						{ printNonTerminal("enumeration input"); }
| union input							{ printNonTerminal("union input"); }
| struct input							{ printNonTerminal("struct input"); }
| ';' input


;

/* Приколы с union */
union:
  union_tok TOK_IDENT '{' union_args '}' ';'	{  flag_union = 0; printNonTerminal("TOK_UNION TOK_IDENT '{' union_args '}' ';'"); }
;

union_tok:
  TOK_UNION			{ flag_union = 1; printNonTerminal("TOK_UNION"); }
;

union_args:
  type_token TOK_IDENT ';' union_args 									{ printNonTerminal("type_token TOK_IDENT ';' union_args"); }
| type_token TOK_IDENT arr_index_token ';' union_args					{ printNonTerminal("type_token TOK_IDENT arr_index_token ';' union_args"); }
| union_tok TOK_IDENT ident_ref_modifier TOK_IDENT ';' union_args		{ printNonTerminal("union_tok TOK_IDENT ident_ref_modifier TOK_IDENT ';' union_args"); }
| empty_rule 																{ /* Ничего не пишем */ }
; 

/* Приколы с struct */
struct:
  struct_tok TOK_IDENT '{' struct_args '}' ';'	{ flag_struct = 0; printNonTerminal("struct_tok TOK_IDENT '{' struct_args '}' ';'"); }
;

struct_tok:
  TOK_STRUCT 		{ flag_struct = 1; printTerminal("TOK_STRUCT"); }
;

struct_args:
  type_token TOK_IDENT ';' struct_args 									{ printNonTerminal("type_token TOK_IDENT ';' struct_args"); }
| type_token TOK_IDENT arr_index_token ';' struct_args 					{ printNonTerminal("type_token arr_index_token TOK_IDENT ';' struct_args"); }
| struct_tok TOK_IDENT ident_ref_modifier TOK_IDENT ';' struct_args		{ printNonTerminal("sruct_tok TOK_IDENT ident_ref_modifier TOK_IDENT ';' struct_args"); }
| empty_rule 																{ /* Ничего не пишем */ }
; 

/* Приколы с enumeration */
enumeration:
  enum_tok TOK_IDENT '{' enum_args '}' ';' 		{ flag_enum = 0; printNonTerminal("enum_tok TOK_IDENT '{' enum_args '}' ';'"); }
;

enum_tok:
  TOK_ENUM 			{ flag_enum = 1; printTerminal("TOK_ENUM"); }
;

enum_args:
  TOK_IDENT '=' const_token enum_args 			{ checkNewDeclaration($1); printNonTerminal("TOK_IDENT '=' const_token enum_args"); }
| TOK_IDENT enum_args							{ checkNewDeclaration($1); printNonTerminal("TOK_IDENT enum_args"); }  
| ',' TOK_IDENT '=' const_token enum_args		{ checkNewDeclaration($2); printNonTerminal("',' TOK_IDENT '=' const_token enum_args"); }
| ',' TOK_IDENT enum_args						{ checkNewDeclaration($2); printNonTerminal("',' TOK_IDENT enum_args"); }
| empty_rule  										{ /* Ничего не пишем */ }
;

/* Объявление глобальных переменных */
global_var_decl:
  TOK_EXTERN decl_statement ';'   		{ printNonTerminal("TOK_EXTERN decl_statement ';'"); }
| decl_statement ';'  					{ printNonTerminal("decl_statement ';'"); }
;

/* Работа с #include */
include: 
  TOK_INCLUDE TOK_STRING_INCLUDE	{ printNonTerminal("TOK_INCLUDE TOK_STRING_INCLUDE"); }
| TOK_INCLUDE TOK_STRING			{ printNonTerminal("TOK_INCLUDE TOK_STRING"); }
;

define:
  /*TOK_DEFINE TOK_IDENT const_token	{ checkNewDeclaration($2); printNonTerminal("TOK_DEFINE IDENTIFIER const_token"); }*/
  TOK_DEFINE TOK_IDENT expr	{ checkNewDeclaration($2); printNonTerminal("TOK_DEFINE IDENTIFIER expr"); }
|  TOK_DEFINE TOK_IDENT '(' TOK_IDENT ')' expr '?' expr ':' expr	{ checkNewDeclaration($2); printNonTerminal("TOK_DEFINE IDENTIFIER expr"); }
|TOK_DEFINE TOK_IDENT 
/* Здесь описание и определение функции */
func_def:
  func_sign '{' func_body '}'   { printNonTerminal("func_sign '{' func_body '}'"); flag_local_var = 0; free_local_vars();}
| func_sign ';'                 { printNonTerminal("func_sign ';'"); flag_local_var = 0; }
| func_sign ',' func_def 
;

/* Сигнатура функции */
func_sign:
  type_token TOK_IDENT sign_arg_cons                  { flag_local_var = 1; printNonTerminal("type_token TOK_IDENT sign_arg_cons"); }

|  type_token '*' TOK_IDENT sign_arg_cons                  { flag_local_var = 1; printNonTerminal("type_token TOK_IDENT sign_arg_cons"); }
|  type_token '*' '*'  TOK_IDENT sign_arg_cons                  { flag_local_var = 1; printNonTerminal("type_token TOK_IDENT sign_arg_cons"); }
| TOK_TYPE_VOID TOK_IDENT sign_arg_cons               { flag_local_var = 1; printNonTerminal("TOK_TYPE_VOID TOK_IDENT sign_arg_cons"); }
| type_token arr_decl_token TOK_IDENT sign_arg_cons   { flag_local_var = 1; printNonTerminal("type_token arr_decl_token TOK_IDENT sign_arg_cons"); }
| TOK_IDENT sign_arg_cons
| '*'  TOK_IDENT sign_arg_cons
;

/* Список аргументов */
sign_arg_cons:
  '(' ')'               		{ printNonTerminal("'(' ')'"); }
| '(' sign_arg_list ')' 		{ printNonTerminal("'(' sign_arg_list ')'"); }
;

/* Непосредственно перечисление аргументов */
sign_arg_list:
  type_token TOK_IDENT                               					{ flag_local_var = 1; checkNewDeclaration($2);  printNonTerminal("type_token TOK_IDENT"); }
  
| TOK_TYPE_CONST type_token TOK_IDENT                               	{ flag_local_var = 1; checkNewDeclaration($3);  printNonTerminal("type_token TOK_IDENT"); }

|  TOK_TYPE_CONST TOK_TYPE_VOID TOK_IDENT                               	{ flag_local_var = 1; checkNewDeclaration($3);  printNonTerminal("type_token TOK_IDENT"); }

|  TOK_TYPE_CONST TOK_TYPE_VOID '*' TOK_IDENT                               	{ flag_local_var = 1; checkNewDeclaration($4);  printNonTerminal("type_token TOK_IDENT"); }

| TOK_TYPE_VOID

| type_token arr_decl_token TOK_IDENT                     				{ flag_local_var = 1; checkNewDeclaration($3);  printNonTerminal("type_token arr_decl_token TOK_IDENT"); }

| type_token TOK_IDENT ',' sign_arg_list             					{ flag_local_var = 1; checkNewDeclaration($2);  printNonTerminal("type_token TOK_IDENT ',' sign_arg_list"); }

| TOK_TYPE_CONST type_token TOK_IDENT ',' sign_arg_list             	{ flag_local_var = 1; checkNewDeclaration($3);  printNonTerminal("type_token TOK_IDENT ',' sign_arg_list"); }

| TOK_TYPE_CONST TOK_TYPE_VOID TOK_IDENT ',' sign_arg_list             { flag_local_var = 1; checkNewDeclaration($3);  printNonTerminal("type_token TOK_IDENT ',' sign_arg_list"); }

| TOK_TYPE_CONST TOK_TYPE_VOID '*' TOK_IDENT ',' sign_arg_list             { flag_local_var = 1; checkNewDeclaration($4);  printNonTerminal("type_token TOK_IDENT ',' sign_arg_list"); }

| type_token arr_decl_token TOK_IDENT ',' sign_arg_list   	{ flag_local_var = 1; checkNewDeclaration($3);  printNonTerminal("type_token arr_decl_token TOK_IDENT ',' sign_arg_list"); }
| type_token TOK_IDENT  arr_decl_token
| type_token TOK_IDENT  arr_decl_token ',' sign_arg_list 
| type_token
| type_token  ',' sign_arg_list

;

/* Здесь у нас тело функции */
func_body:
  func_body statement   { printNonTerminal("func_body statement"); }
| empty_rule                { /* Ничего не пишем */ }
;

/* Разбираем выражения, допустимые в теле функции */
statement:
  single_statement ';'  { printNonTerminal("single_statement ';'"); }
| if_statement          { printNonTerminal("if_statement"); }
| for_statement         { printNonTerminal("for_statement"); }
| while_statement		{ printNonTerminal("while_statement"); }
| do_while_statement 	{ printNonTerminal("do_while_statement"); }
| switch_case			{ printNonTerminal("switch_case"); }
;

/* Конструкция switch case */
switch_case:
  switch_token '(' expr ')' '{' switch_body '}' 	{ flag_loop = 0; flag_default = 0; printNonTerminal("switch_token '(' expr ')' '{' switch_body '}'"); }
;

switch_token:
  TOK_SWITCH 		{ flag_loop = 1; printTerminal("TOK_SWITCH"); }
;

switch_body:
  TOK_CASE const_token ':' case_body switch_body	{ printNonTerminal("TOK_CASE const_token ':' case_body switch_body"); }
| TOK_DEFAULT ':' case_body	switch_body				{ if (flag_default) printNonTerminal("default label is duplicated"); flag_default = 1; printNonTerminal("TOK_DEFAULT ':' case_body switch_body"); }  
| empty_rule   											{ /* Ничего не пишем */ }
;

case_body:
  statement  case_body		{ printNonTerminal("statement  case_body"); }
| empty_rule           		{ /* Ничего не пишем */ }
;

/* Выражаение, заканчивающееся на ; */
single_statement:
  decl_statement    			{ printNonTerminal("decl_statement"); }
| call_expr         			{ printNonTerminal("call_expr"); }
| assign_expr       			{ printNonTerminal("assign_expr"); }
| return_expr       			{ printNonTerminal("return_expr"); }
| TOK_BREAK         			{ if (!flag_loop) printTerminal("break is not in loop"); printTerminal("TOK_BREAK"); }
| TOK_CONTINUE      			{ printTerminal("TOK_CONTINUE"); }
| expr TOK_INC_DEC				{ printNonTerminal("expr TOK_INC_DEC"); }
| TOK_INC_DEC expr				{ printNonTerminal("TOK_INC_DEC expr"); }
;

/* Здесь у нас объявление переменных */
decl_statement:
  type_token TOK_IDENT decl_list                          						{ checkNewDeclaration($2); printNonTerminal("type_token TOK_IDENT decl_list"); }
  
| type_token TOK_IDENT arr_index_token decl_list          						{ checkNewDeclaration($2); printNonTerminal("type_token arr_index_token TOK_IDENT decl_list"); }
| type_token TOK_IDENT '=' expr decl_list                 						{ checkNewDeclaration($2); printNonTerminal("type_token TOK_IDENT '=' expr decl_list"); }
|TOK_IDENT

| type_token TOK_IDENT arr_decl_token '=' expr decl_list  						{ checkNewDeclaration($2); printNonTerminal("type_token arr_decl_token TOK_IDENT '=' expr decl_list"); }

| type_token TOK_IDENT '=' '{' struct_list_init '}' decl_list					{ checkNewDeclaration($2); printNonTerminal("type_token TOK_IDENT '=' '{' struct_list_init '}' decl_list"); } 
| type_token TOK_IDENT arr_index_token '=' '{' struct_list_init '}' decl_list	{ checkNewDeclaration($2); printNonTerminal("type_token TOK_IDENT arr_index_token '=' '{' struct_list_init '}' decl_list"); } 

| struct_tok TOK_IDENT ident_ref_modifier TOK_IDENT decl_list				  					{ checkNewDeclaration($4); printNonTerminal("struct_tok TOK_IDENT TOK_IDENT decl_list"); flag_struct = 0; }
| struct_tok TOK_IDENT ident_ref_modifier TOK_IDENT '=' '{' struct_list_init '}' decl_list		{ checkNewDeclaration($4); printNonTerminal("struct_tok TOK_IDENT TOK_IDENT '=' '{' struct_list_init '}' decl_list"); flag_struct = 0; }
| struct_tok TOK_IDENT ident_ref_modifier TOK_IDENT '=' expr decl_list							{ checkNewDeclaration($4); printNonTerminal("struct_tok TOK_IDENT TOK_IDENT '=' expr decl_list"); flag_struct = 0; }

| union_tok TOK_IDENT ident_ref_modifier TOK_IDENT decl_list									{ checkNewDeclaration($4); printNonTerminal("union_tok TOK_IDENT TOK_IDENT decl_list"); flag_union = 0; }
| union_tok TOK_IDENT ident_ref_modifier TOK_IDENT '=' '{' const_token '}' decl_list			{ checkNewDeclaration($4); printNonTerminal("union_tok TOK_IDENT TOK_IDENT '=' '{' const_token '}' decl_list"); flag_union = 0; }
| union_tok TOK_IDENT ident_ref_modifier TOK_IDENT '=' expr decl_list							{ checkNewDeclaration($4); printNonTerminal("union_tok TOK_IDENT TOK_IDENT '=' expr decl_list"); flag_union = 0; }
;

/* Список объявления переменных через запятую */
decl_list:
  ',' TOK_IDENT decl_list 						{ checkNewDeclaration($2); printNonTerminal("',' TOK_IDENT decl_list");}
|  ',' '*' TOK_IDENT  decl_list 						{ checkNewDeclaration($3); printNonTerminal("',' TOK_IDENT decl_list");}
|  ',' '*' '*' TOK_IDENT  decl_list 						{ checkNewDeclaration($4); printNonTerminal("',' TOK_IDENT decl_list");}
|   ',' '*' '*' '*' TOK_IDENT  decl_list 						{ checkNewDeclaration($5); printNonTerminal("',' TOK_IDENT decl_list");}
| ',' TOK_IDENT '=' expr decl_list 							{ checkNewDeclaration($2); printNonTerminal("',' TOK_IDENT '=' expr decl_list"); }
| ',' '*' TOK_IDENT '=' expr decl_list 							{ checkNewDeclaration($3); printNonTerminal("',' TOK_IDENT '=' expr decl_list"); }
| ',' '*' '*' TOK_IDENT '=' expr decl_list 							{ checkNewDeclaration($4); printNonTerminal("',' TOK_IDENT '=' expr decl_list"); }
| ',' TOK_IDENT '=' '{' struct_list_init '}' decl_list		{ checkNewDeclaration($2); printNonTerminal("',' TOK_IDENT '=' '{' struct_list_init '}' decl_list"); }
| ',' '*' TOK_IDENT '=' '{' struct_list_init '}' decl_list		{ checkNewDeclaration($3); printNonTerminal("',' TOK_IDENT '=' '{' struct_list_init '}' decl_list"); }
|  ',' TOK_IDENT arr_index_token decl_list
| ',' TOK_IDENT arr_index_token '=' '{' struct_list_init '}' decl_list
| TOK_IDENT arr_index_token '=' expr decl_list 
| empty_rule													{ /* Ничего не пишем */ }
;

/* Список инициализации */
struct_list_init:
  const_token ',' struct_list_init							{ printNonTerminal("const_token ',' struct_list_init"); }
| const_token  struct_list_init								{ printNonTerminal("const_token  struct_list_init"); }
| empty_rule													{ /* Ничего не пишем */ }
;

/* Различные условные конструкции */
if_statement:
  if_statement_head                             { printNonTerminal("if_statement_head"); }
| if_statement_head TOK_ELSE '{' func_body '}'  { printNonTerminal("if_statement_head TOK_ELSE '{' func_body '}'"); }
| if_statement_head TOK_ELSE func_body  { printNonTerminal("if_statement_head TOK_ELSE func_body "); }
;

/* Общая голова для любой условной конструкции */
if_statement_head:
  TOK_IF '(' expr ')' '{' func_body '}' elif_statement { printNonTerminal("TOK_IF '(' expr ')' '{' func_body '}' elif_statement"); }
| 
 TOK_IF '(' expr ')'  func_body elif_statement  	{ printNonTerminal("TOK_IF '(' expr ')' func_body elif_statement"); }
 |TOK_IF '(' expr ')' ';'
;

/* Последовательность конструкций elif */
elif_statement:
  TOK_ELIF '(' expr ')' '{' func_body '}' elif_statement    { printNonTerminal("TOK_ELIF '(' expr ')' '{' func_body '}' elif_statement"); }
|  TOK_ELIF '(' expr ')' func_body elif_statement    { printNonTerminal("TOK_ELIF '(' expr ')' func_body  elif_statement"); }
| empty_rule                                                   { /* Ничего не пишем */ }
;

/* Цикловая конструкция do..while */
do_while_statement:
  do_token '{' func_body '}' while_token '(' loop_expr_2 ')' ';' { flag_loop = 0; printNonTerminal("do_token '{' func_body '}' while_token '(' loop_expr_2 ')' ';' "); }
;

do_token:
  TOK_DO 		{ flag_loop = 1; printTerminal("TOK_DO"); }
;

/* Цикловая конструкция while */
while_statement:
  while_token '(' loop_expr_2 ')' '{' func_body '}' { flag_loop = 0; printNonTerminal("TOK_WHILE '(' loop_expr_2 ')' '{' func_body '}'"); }
  |
   while_token '(' loop_expr_2 ')' '{' func_body '}' ';' { flag_loop = 0; printNonTerminal("TOK_WHILE '(' loop_expr_2 ')' '{' func_body '}'"); }
  |
  while_token '(' loop_expr_2 ')'  func_body  { flag_loop = 0; printNonTerminal("TOK_WHILE '(' loop_expr_2 ')'  func_body "); }
  |while_token '(' loop_expr_2 ')' ';'{ flag_loop = 0; printNonTerminal("TOK_WHILE '(' loop_expr_2 ')'  func_body "); }
  /*|
  while_token '(' loop_expr_2 ')' { flag_loop = 0; printNonTerminal("TOK_WHILE '(' loop_expr_2 ')' "); }*/
;

while_token:
  TOK_WHILE 		{ flag_loop = 1; printTerminal("TOK_WHILE"); }
;

/* Цикловая конструкция for */
for_statement:
  for_token '(' loop_expr_1 ';' loop_expr_2 ';' loop_expr_3 ')' '{' func_body '}' { flag_loop = 0; printNonTerminal("for_token '(' loop_expr_1 ';' loop_expr_2 ';' loop_expr_3 ')' '{' func_body '}'"); }
  |
  for_token '(' loop_expr_1 ';' loop_expr_2 ';' loop_expr_3 ')'  func_body  { flag_loop = 0; printNonTerminal("for_token '(' loop_expr_1 ';' loop_expr_2 ';' loop_expr_3 ')'  func_body "); }
;

for_token:
  TOK_FOR 		{ flag_loop = 1; printTerminal("TOK_FOR"); }
;

/* Опционально заводим переменную в первой секции цикла */
loop_expr_1:
  decl_statement            { printNonTerminal("decl_statement"); }
  | assign_expr   { printNonTerminal("assign_expr"); }
| empty_rule                 { /* Ничего не пишем */ }
;

/* Опциональное выражение во второй секции цикла (подразумевает проверку) */
loop_expr_2:
  expr      	{ printNonTerminal("expr"); }
| empty_rule    	{ /* Ничего не пишем */ }
;

/* Опциональное выражение в третьей секции цикла (работа с индукцией) */
loop_expr_3:
  expr   		{ printNonTerminal("expr"); }
| empty_rule        { /* Ничего не пишем */ }
;

/* Здесь обрабатывается вызов функции */
call_expr:
  TOK_IDENT '(' arg_cons ')'  	{ printNonTerminal("TOK_IDENT '(' arg_cons ')'"); }
;

/* Выражение завершения процедуры */
return_expr:
  TOK_RET return_expr_tail 		{ printNonTerminal("TOK_RET return_expr_tail"); }
;

/* Завершение процедуры может быть либо по значению, либо пустое */
return_expr_tail:
  expr      		{ printNonTerminal("expr"); }
| empty_rule    		{ /* Ничего не пишем */ }
;

/* Выражение с присваиванием (и операциями +=, -=, *= и т.д.) */
assign_expr:

  expr '=' expr	  			{printNonTerminal("expr '=' expr");}
 | expr '=' expr '?' expr ':' expr
 | expr TOK_COMPARE expr '?' expr ':' expr

| TOK_IDENT arr_index_token '=' expr  				{ controlDeclaratedVariables($1); printNonTerminal("TOK_IDENT arr_index_token '=' expr"); }
| expr TOK_DOT expr  					                { printNonTerminal("expr TOK_DOT expr "); }
| TOK_IDENT TOK_PRE_ASSIGN_OP expr  		{ controlDeclaratedVariables($1); printNonTerminal("TOK_IDENT TOK_PRE_ASSIGN_OP expr"); }

| TOK_IDENT arr_index_token TOK_PRE_ASSIGN_OP expr  	{ controlDeclaratedVariables($1); printNonTerminal("TOK_IDENT arr_index_token TOK_PRE_ASSIGN_OP expr"); }


| TOK_IDENT TOK_DOT TOK_IDENT '=' expr									{ controlDeclaratedVariables($1); printNonTerminal("TOK_IDENT TOK_DOT TOK_IDENT '=' expr"); } 

| TOK_IDENT TOK_DOT TOK_IDENT arr_index_token '=' expr		{ controlDeclaratedVariables($1); printNonTerminal("TOK_IDENT TOK_DOT TOK_IDENT arr_index_token '=' expr"); }

| TOK_IDENT TOK_DOT TOK_IDENT TOK_PRE_ASSIGN_OP expr	{ controlDeclaratedVariables($1); printNonTerminal("TOK_IDENT TOK_DOT TOK_IDENT arr_index_token TOK_PRE_ASSIGN_OP expr"); }

| TOK_IDENT TOK_DOT TOK_IDENT arr_index_token TOK_PRE_ASSIGN_OP expr	{ controlDeclaratedVariables($1); printNonTerminal("TOK_IDENT TOK_DOT TOK_IDENT arr_index_token TOK_PRE_ASSIGN_OP expr"); }


;

/* Обрабатываем последовательность аргументов */
arg_cons:
  expr                      { printNonTerminal("expr"); }
| expr ',' arg_cons         { printNonTerminal("expr ',' arg_cons"); }
| empty_rule                   { /* Ничего не пишем */ }
;

/* Допустимые выражения. Здесь допускается только rvalue (т.е. непосредственно вычисления) */
expr:
  const_token                   					{ printNonTerminal("const_token"); }
  
| '*' TOK_IDENT  		{ printNonTerminal(" '*' TOK_IDENT   "); }


| assign_expr					{ printNonTerminal("assign_expr"); }

| '{' array_list '}'

| TOK_HEX_NUMBER

| TOK_SIZEOF '(' expr ')'							{ printNonTerminal("TOK_SIZEOF '(' expr ')'"); }

|'*' '(' expr ')' 						{ printNonTerminal("'*' '(' expr ')'"); }

| TOK_SIZEOF '(' type_token ')'						{ printNonTerminal("TOK_SIZEOF '(' type_token ')'"); }

| '(' type_token ')' expr 							{ printNonTerminal("'(' type_token ')' expr"); }  

| call_expr                     					{ printNonTerminal("call_expr"); }

| TOK_NULL											{ printTerminal("TOK_NULL"); }

| TOK_IDENT                     					{ controlDeclaratedVariables($1); printNonTerminal("TOK_IDENT_expr"); }

| '&' TOK_IDENT                     				{ controlDeclaratedVariables($2); printNonTerminal("'&' TOK_IDENT"); }
//| '(' '*' TOK_IDENT ')' arr_index_token			{ printNonTerminal("'(' '*' TOK_IDENT ')' arr_index_token"); }
| expr arr_index_token	

| TOK_IDENT arr_index_token     					{ controlDeclaratedVariables($1); printNonTerminal("TOK_IDENT arr_index_token"); }

| '&' '(' '*' TOK_IDENT ')' arr_index_token   			

| '&' TOK_IDENT arr_index_token     				{ controlDeclaratedVariables($2); printNonTerminal("'&' TOK_IDENT arr_index_token"); }

| TOK_IDENT TOK_DOT TOK_IDENT  						{ controlDeclaratedVariables($1); printNonTerminal("TOK_IDENT TOK_DOT TOK_IDENT"); }

| '&' TOK_IDENT TOK_DOT TOK_IDENT  					{ controlDeclaratedVariables($2); printNonTerminal("'&' TOK_IDENT TOK_DOT TOK_IDENT"); }

| TOK_IDENT TOK_DOT TOK_IDENT arr_index_token   	{ controlDeclaratedVariables($1); printNonTerminal("TOK_IDENT TOK_DOT TOK_IDENT arr_index_token"); }

| '&' TOK_IDENT TOK_DOT TOK_IDENT arr_index_token   { controlDeclaratedVariables($2); printNonTerminal("'&' TOK_IDENT TOK_DOT TOK_IDENT arr_index_token"); }


| '(' expr ')'                  					{ printNonTerminal("'(' expr ')'"); }

| expr TOK_SHIFT_OP expr							{ printNonTerminal("expr TOK_SHIFT_OP expr"); }

| expr TOK_BIT_OP expr								{ printNonTerminal("expr TOK_BIT_OP expr"); }

| expr '&' expr										{ printNonTerminal("expr '&' expr"); }

| expr TOK_INC_DEC									{ printNonTerminal("expr TOK_INC_DEC"); }

| TOK_INC_DEC expr									{ printNonTerminal("TOK_INC_DEC expr"); }

| expr '+' expr                 					{ printNonTerminal("expr '+' expr"); }

| expr '-' expr                 					{ printNonTerminal("expr '-' expr"); }

| expr '*' expr                 					{ printNonTerminal("expr '*' expr"); }

| expr '/' expr                 					{ printNonTerminal("expr '/' expr"); }

| expr '%' expr                 					{ printNonTerminal("expr ' ' expr"); }

| expr TOK_LOGIC expr       						{ printNonTerminal("expr TOK_LOGIC expr"); }



| expr TOK_COMPARE expr         					{ printNonTerminal("expr TOK_COMPARE expr"); }

| '-' expr  %prec TOK_UMIN      					{ printNonTerminal("'-' expr  prec TOK_UMIN"); }

| '!' expr  %prec TOK_NOT       					{ printNonTerminal("'!' expr  prec TOK_NOT"); }

;
array_list:
  const_token
| const_token',' array_list             		

;

/* Здесь обрабатываем лексему типа */
type_token:
  TOK_TYPE_INT  ident_ref_modifier	{ printNonTerminal("TOK_TYPE_INT  ident_ref_modifier"); }
| TOK_TYPE_CONST TOK_TYPE_INT  ident_ref_modifier	{ printNonTerminal("TOK_TYPE_INT  ident_ref_modifier"); }
| TOK_TYPE_CHAR ident_ref_modifier	{ printNonTerminal("TOK_TYPE_CHAR  ident_ref_modifier"); }
| TOK_TYPE_CONST TOK_TYPE_CHAR ident_ref_modifier	{ printNonTerminal("TOK_TYPE_CHAR  ident_ref_modifier"); }
| TOK_TYPE_FLOAT ident_ref_modifier	{ printNonTerminal("TOK_TYPE_FLOAT  ident_ref_modifier"); }
| TOK_TYPE_CONST TOK_TYPE_FLOAT ident_ref_modifier	{ printNonTerminal("TOK_TYPE_FLOAT  ident_ref_modifier"); }
| TOK_TYPE_VOID ident_ref_modifier	{ printNonTerminal("TOK_TYPE_FLOAT  ident_ref_modifier"); }
| TOK_TYPE_CONST TOK_TYPE_VOID ident_ref_modifier	{ printNonTerminal("TOK_TYPE_FLOAT  ident_ref_modifier"); }
| TOK_TYPE_STATIC  TOK_TYPE_INT  ident_ref_modifier	{ printNonTerminal("TOK_TYPE_INT  ident_ref_modifier"); }
| TOK_TYPE_STATIC TOK_TYPE_CHAR ident_ref_modifier	{ printNonTerminal("TOK_TYPE_CHAR  ident_ref_modifier"); }
| TOK_TYPE_STATIC TOK_TYPE_FLOAT ident_ref_modifier	{ printNonTerminal("TOK_TYPE_FLOAT  ident_ref_modifier"); }
| TOK_TYPE_FILE ident_ref_modifier { printNonTerminal("TOK_TYPE_FILE  ident_ref_modifier"); }
| TOK_TYPE__Bool ident_ref_modifier { printNonTerminal("TOK_TYPE__Bool  ident_ref_modifier"); }
| TOK_TYPE_size_t ident_ref_modifier { printNonTerminal("TOK_TYPE__Bool  ident_ref_modifier"); }
;

/* Это опциональные модификаторы типа */
ident_ref_modifier:
  '*'   ident_ref_modifier    	{  printNonTerminal(" '*'   ident_ref_modifier"); }
| empty_rule   					{ /* Ничего не пишем */ }
;

/* Обращение к массиву по индексу либо выражение с указанием количества элементов */
arr_index_token:
  '[' expr ']'  arr_index_token 		{ printNonTerminal("'[' expr ']'  arr_index_token"); }
| '[' expr ']'                  		{ printNonTerminal("'[' expr ']'"); }
;

/* Объявление массива для случаев когда размер заранее неизвестен */
arr_decl_token:
  '[' ']' arr_decl_token 			{ printNonTerminal("'[' ']' arr_decl_token"); }
| '[' ']' 							{ printNonTerminal("'[' ']'"); }
;

/* Здесь обрабатываем константные значения */
const_token:
  TOK_INT       { printTerminal("TOK_INT"); }
| TOK_CHAR      { printTerminal("TOK_CHAR"); }
| TOK_FLOAT  	{ printTerminal("TOK_FLOAT"); }
| TOK_STRING	{ printTerminal("TOK_STRING"); }
;
empty_rule: /* пустое правило */

    ;
%%

/**
 * Данная функция автоматически вызывается bison'ом если на вход поступает
 * токен, не удовлетворяющий ни одному правилу
 */
void yyerror(char const * msg)
{
    fprintf (stderr,
             "Ошибка: %d:%d: %s\n",
             yylloc.first_line,
             yylloc.first_column,
             msg);
    exit(1);
}

static void printTerminal(const char * tokName)
{
    printf("<%s, \"%s\", %d:%d, %d:%d>\n",
           tokName,
           yytext,
           yylloc.first_line,
           yylloc.first_column,
           yylloc.last_line,
           yylloc.last_column);
}

static void printNonTerminal(const char * tokName)
{
    printf("<%s>\n", tokName);
}

void checkNewDeclaration(const char * identificator)
{
	checkVariables(local_vars, &count_local_vars, identificator); /* Заносим переменную локально (если мы сейчас не в функции, то ниже обнулится */
	
	if (!flag_local_var) /* Т.е. это не в локальной функции - будет глобальная видимость переменных */
	{
		checkVariables(global_vars, &count_global_vars, identificator);
		free_local_vars();
	}
}

void checkVariables(char variables[MAX_COUNT][MAX_NAME], int* count, const char * identificator)
{
	for (int i = 0; i < *count; ++i)
	{
		if (!strcmp(variables[i], identificator))
		{
			printNonTerminal("Duplication of variable");
		}
	}

	strcpy(variables[*count], identificator);
	++(*count);
}

void free_local_vars()
{
	memset(local_vars, 0, sizeof(local_vars));
	count_local_vars = 0;
}
 
void controlDeclaratedVariables(const char * identificator)
{
	for (int i = 0; i < count_local_vars; ++i)
	{
		if (!strcmp(local_vars[i], identificator)) /* Если такая переменная уже была объявлена локально, то все окей */
		{
			return;
		}
	}	
	for (int i = 0; i < count_global_vars; ++i)
	{
		if (!strcmp(global_vars[i], identificator)) /* Если такая переменная уже была объявлена глобально, то все окей */
		{
			return;
		}
	}
	printNonTerminal("Undeclared variable");
	//yyerror("Undeclared variable");
}

void newConstructionNameCheck(const char * identificator)
{
	if (flag_struct) {
		checkVariables(struct_construct, &count_struct, identificator);	/* Смотрим на то, является ли это структурой */
	}		
	else if (flag_union) {
		checkVariables(union_construct, &count_union, identificator);	/* Смотрим на то, является ли это объединением */
	}			
}

void controlConstructionName(const char * identificator)
{
	for (int i = 0; i < count_struct; ++i)
	{
		if (!strcmp(struct_construct[i], identificator)) /* Если такая структура уже объявлена, то все окей */
		{
			return;
		}
	}	
	for (int i = 0; i < count_union; ++i)
	{
		if (!strcmp(union_construct[i], identificator)) /* Если такое объединение уже объявлено, то все окей */
		{
			return;
		}
	}	
	yyerror("Undeclared construction name");
}
