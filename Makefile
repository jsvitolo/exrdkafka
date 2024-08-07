PUS := $(shell getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu)
BASEDIR := $(shell pwd)
MIX_APP_PATH ?= $(BASEDIR)/_build/dev/lib/exrdkafka
PRIV_DIR := $(MIX_APP_PATH)/priv
NIF_SO := $(PRIV_DIR)/exrdkafka_nif.so
C_SRC_DIR := $(BASEDIR)/c_src
C_SRC_NIF := $(C_SRC_DIR)/exrdkafka_nif.so
C_SRC_ENV ?= $(C_SRC_DIR)/env.mk

.PHONY: all get_deps compile_nif clean_nif generate_env copy_nif

all: compile_nif copy_nif

get_deps:
	@./build_deps.sh

compile_nif: get_deps generate_env
	@mkdir -p $(PRIV_DIR)
	@$(MAKE) -C $(C_SRC_DIR) -j $(CPUS)

copy_nif: compile_nif
	@mkdir -p $(PRIV_DIR)
	@cp $(C_SRC_NIF) $(NIF_SO)
	@echo "NIF copied to $(NIF_SO)"

clean_nif:
	@$(MAKE) -C $(C_SRC_DIR) clean
	@rm -f $(NIF_SO)
	@echo "Cleaned NIF files"

generate_env:
	@erl -noshell -s init stop -eval " \
		file:write_file(\"$(C_SRC_ENV)\", \
		io_lib:format( \
			\"ERTS_INCLUDE_DIR ?= ~s/erts-~s/include/~n\" \
			\"ERL_INTERFACE_INCLUDE_DIR ?= ~s~n\" \
			\"ERL_INTERFACE_LIB_DIR ?= ~s~n\", \
			[code:root_dir(), erlang:system_info(version), \
			code:lib_dir(erl_interface, include), \
			code:lib_dir(erl_interface, lib)])), \
		halt()."

-include $(C_SRC_ENV)

cpplint:
	cpplint --counting=detailed \
	        --filter=-legal/copyright,-build/include_subdir,-build/include_order,-whitespace/blank_line,-whitespace/braces,-whitespace/indent,-whitespace/parens,-whitespace/newline \
            --linelength=300 \
			--exclude=c_src/*.o --exclude=c_src/*.mk  \
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
