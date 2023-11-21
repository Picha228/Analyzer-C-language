%option nounput
%option noinput
%option noyywrap

%{

#include <stdio.h>
#include <stdbool.h>
#include <assert.h>

#include "x-grammar.h"

typedef struct
{
    int line;   /* Строка */
    int colomn; /* Столбец */
} Position_t;

/* Переменная, в которой храним текущую позицию */
static Position_t Position = {1, 1};

/* Количество строк, на которое сдвигаемся */
static void incrLine(int num) {Position.line += num;}

/* Текущая строка в читаемом файле */
static int line(void) {return Position.line;}

/* Количество столбцов, на которое сдвигаемся */
static void incrColomn(int num) {Position.colomn += num;}

/* Текущий столбец в читаемом файле */
static int colomn(void) {return Position.colomn;}

/* Сбрасываем текущий столбец в читаемом файле в начало строки */
static void dropColomn(void) {Position.colomn = 1;}

/* Автоматическое действие при чтении лексемы */
#define YY_USER_ACTION { \
    yylloc.first_line   = line(); \
    yylloc.last_line    = line(); \
    yylloc.first_column = colomn(); \
    yylloc.last_column  = colomn() + yyleng - 1; \
    incrColomn(yyleng); }

%}

/* Здесь описываем состояния, в которые попадает лексический анализатор */

/* Состояние многострочного коментария */
%x COMMENT

INTEGER 		[0-9]+
FLOAT			([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][0-9]+)?
SPACE 			[ \t]*
IDENTIFIER 		[a-zA-Z_][a-zA-Z_0-9]*
CHAR 			 \'[^\']*\'
STRING 			\"(\\.|[^\"])*\"
STRING_INCLUDE 	        [<][a-zA-Z_.0-9+\*/><!;,(){}\[\]' \\]*[>]
NOT_AVIABLE 		[^a-zA-Z_0-9+\-*/><!;:,=(){}\[\]&|'" \n\t]

%%

 /* Обработка комментариев */
"/*"                    { /* Включаем состояние анализа комментариев */ BEGIN(COMMENT); }
<COMMENT>.              { /* Внутри комментария ничего не делаем */ }
<COMMENT>"*/"           { /* Возвращаемся в начальное состояние */ BEGIN(INITIAL); }

"//"(.*) 				{ /* Внутри комментария ничего не делаем */ }

 /* Ключевые слова */
if                      { return TOK_IF; }
"else if"               { return TOK_ELIF; }
else                    { return TOK_ELSE; }
for                     { return TOK_FOR; }
do						{ return TOK_DO; }
while					{ return TOK_WHILE; }
break                   { return TOK_BREAK; }
continue                { return TOK_CONTINUE; }
return                  { return TOK_RET; }
extern					{ return TOK_EXTERN; }
#include				{ return TOK_INCLUDE; }
#define					{ return TOK_DEFINE; }
enum					{ return TOK_ENUM; }
union					{ return TOK_UNION; }
struct					{ return TOK_STRUCT; }
switch					{ return TOK_SWITCH; }
case					{ return TOK_CASE; }
default					{ return TOK_DEFAULT; }
NULL					{ return TOK_NULL; }
sizeof					{ return TOK_SIZEOF; }

"int"|"unsigned int"|"long"|"unsigned long"|"long long"|"unsigned long long"|"short"|"unsigned short" { yylval.name = strdup(yytext);  return TOK_TYPE_INT; }
"char"|"unsigned char" 				{ return TOK_TYPE_CHAR; }
"float"|"double"|"long double"		{ return TOK_TYPE_FLOAT; }
"void"                   			{ return TOK_TYPE_VOID; }
"static"				{ return TOK_TYPE_STATIC; }
"const"				{ return TOK_TYPE_CONST; }
"FILE"				{ return TOK_TYPE_FILE; }
"_Bool"				{ return TOK_TYPE__Bool; }
"size_t"			{ return TOK_TYPE_size_t; }

 /* Операции */
"<<"|">>" 												{ return TOK_SHIFT_OP; }
"^"|"|"													{ return TOK_BIT_OP; }
"&&"|"||"   											{ return TOK_LOGIC; }
"=="      { return TOK_COMPARE; }
"!="      { return TOK_COMPARE; }
"<"       { return TOK_COMPARE; }
">"       { return TOK_COMPARE; }
">="      { return TOK_COMPARE; }
"<="      { return TOK_COMPARE; }



"++"|"--"												{ return TOK_INC_DEC; }
"+="|"-="|"*="|"/="|"%="|">>="|"<<="|"&="|"^="|"|=" 	{ return TOK_PRE_ASSIGN_OP; }
"."|"->"												{ return TOK_DOT; }

 /* Обработка единичных символов */
[+\-*/><!;?:,=(){}\[\]#%&"]   { return yytext[0]; }

 /* Обработка нормального хода программы */

{INTEGER}               { return TOK_INT; }
0x[0-9a-fA-F]+ { return TOK_HEX_NUMBER; }
{FLOAT}					{ return TOK_FLOAT; }
{IDENTIFIER}            { yylval.name = strdup(yytext); return TOK_IDENT; }
{SPACE}                 { /* Пробелы игнорируем*/ }
{CHAR}               { return TOK_CHAR; }
{STRING}				{ return TOK_STRING; }
{STRING_INCLUDE}		{ return TOK_STRING_INCLUDE; }


 /* В любом состоянии лексического анализатора учитываем переход на новую строку */
<*>\n                   { dropColomn(); incrLine(1);yylloc.first_line++;}

 /* Все недопустимые символы являются ошибкой */
{NOT_AVIABLE}+          { return TOK_ERROR; }

 /* Здесь ловим то что не удалось поймать предыдущими правилами */
.                       { assert(!"Сюда не попадаем!"); return TOK_ERROR; }

%%
