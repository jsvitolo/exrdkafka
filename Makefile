# Variables
CPUS := $(shell getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu)
PREFIX = $(MIX_COMPILE_PATH)/../priv
BUILD  = $(MIX_COMPILE_PATH)/../obj

# Erlang-specific settings
ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR)

LDFLAGS += -shared
CFLAGS += -fPIC
CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter -std=c99

ifeq ($(CROSSCOMPILE),)
    ifeq ($(shell uname),Darwin)
        LDFLAGS += -undefined dynamic_lookup
    endif
endif

NIF = $(PREFIX)/exrdkafka_nif.so

# C source settings
C_SRC_DIR = $(shell pwd)/c_src
C_SRC_ENV ?= $(C_SRC_DIR)/env.mk

# Targets
.PHONY: all get_deps compile_nif clean_nif cpplint cppcheck

all: compile_nif

get_deps:
	@./build_deps.sh

compile_nif: get_deps
	@make V=0 -C c_src -j $(CPUS)

$(BUILD)/%.o: c_src/%.c
	@echo " CC $(notdir $@)"
	$(CC) -c $(ERL_CFLAGS) $(CFLAGS) -o $@ $<

$(NIF): $(BUILD)/exrdkafka_nif.o
	@echo " LD $(notdir $@)"
	$(CC) $< $(ERL_LDFLAGS) $(LDFLAGS) -o $@

$(PREFIX) $(BUILD):
	mkdir -p $@

clean_nif:
	@make -C c_src clean
	$(RM) $(NIF)
	$(RM) $(BUILD)/*.o

cpplint:
	cpplint --counting=detailed \
	        --filter=-legal/copyright,-build/include_subdir,-build/include_order,-whitespace/blank_line,-whitespace/braces,-whitespace/indent,-whitespace/parens,-whitespace/newline \
            --linelength=300 \
			--exclude=c_src/*.o --exclude=c_src/*.mk \
			c_src/*.*

cppcheck:
	cppcheck -j $(CPUS) \
             -I /usr/local/opt/openssl/include \
             -I deps/librdkafka/src \
             -I $(ERTS_INCLUDE_DIR) \
             -I $(ERL_INTERFACE_INCLUDE_DIR) \
             --force \
             --enable=all \
	 		 --xml-version=2 \
	 		 --output-file=cppcheck_results.xml \
	 		 c_src/

# Generate env.mk
ifneq ($(wildcard $(C_SRC_DIR)),)
    GEN_ENV ?= $(shell erl -noshell -s init stop -eval "file:write_file(\"$(C_SRC_ENV)\", \
		io_lib:format( \
			\"ERTS_INCLUDE_DIR ?= ~s/erts-~s/include/~n\" \
			\"ERL_INTERFACE_INCLUDE_DIR ?= ~s~n\" \
			\"ERL_INTERFACE_LIB_DIR ?= ~s~n\", \
			[code:root_dir(), erlang:system_info(version), \
			code:lib_dir(erl_interface, include), \
			code:lib_dir(erl_interface, lib)])), \
		halt().")
    $(GEN_ENV)
endif

include $(C_SRC_ENV)

# Don't echo commands unless the caller exports "V=1"
${V}.SILENT: