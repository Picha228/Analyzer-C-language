SRC_DIR  = src
GEN_DIR  = gen
CC       = gcc
LEX      = flex
BISON    = bison
OBJS     = main

BIN_DIR  = bin
BIN_NAME = compiler
OBJ_DIR  = obj
CFLAGS   = -Wall -Werror -std=c18
LDFLAGS  =

# Устанавливаем опции для release
all : BIN_DIR  := $(BIN_DIR)/release
all : OBJ_DIR  := $(OBJ_DIR)/release
# Запускаем
all : build

# Устанавливаем опции для debug
debug : BIN_DIR  := $(BIN_DIR)/debug
debug : BIN_NAME = compiler_debug
debug : OBJ_DIR  := $(OBJ_DIR)/debug
debug : CFLAGS += -g -fsanitize=address
debug : LDFLAGS += -g -fsanitize=address
# Запускаем
debug : build

# Создаём каталоги для временных файлов
mk_dir:
	mkdir -p $(BIN_DIR) $(OBJ_DIR)

# Здесь создаются объектные файлы
$(OBJS) :
	$(CC) $(CFLAGS) $(SRC_DIR)/$@.c -I$(GEN_DIR) -c -o $(OBJ_DIR)/$@.o

# Запуск сборки всех исходников
build :  mk_dir x-grammar.o x-lexer.o $(OBJS)
	$(CC) $(LDFLAGS) $(OBJ_DIR)/*.o -o $(BIN_DIR)/$(BIN_NAME)

x-grammar.c: x-lexer.c
	mkdir -p $(GEN_DIR)
	$(BISON) -d $(SRC_DIR)/x-grammar.y --defines=$(GEN_DIR)/x-grammar.h -o $(GEN_DIR)/x-grammar.c

x-grammar.o: x-grammar.c
	$(CC) $(CFLAGS) $(GEN_DIR)/x-grammar.c -I$(GEN_DIR) -o $(OBJ_DIR)/x-grammar.o -c

x-lexer.c:
	mkdir -p $(GEN_DIR)
	$(LEX) --header-file=$(GEN_DIR)/x-lexer.h -o $(GEN_DIR)/x-lexer.c $(SRC_DIR)/x-lexer.l

x-lexer.o: x-lexer.c
	$(CC) $(CFLAGS) $(GEN_DIR)/x-lexer.c -I$(GEN_DIR) -o $(OBJ_DIR)/x-lexer.o -c -std=gnu18
