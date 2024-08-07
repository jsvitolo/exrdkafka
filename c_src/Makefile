PROJECT_NIF_NAME := exrdkafka_nif
CURDIR := $(shell pwd)
BASEDIR := $(abspath $(CURDIR)/..)

PRIV_DIR = $(MIX_APP_PATH)/priv
C_SRC_DIR = $(CURDIR)
C_SRC_ENV ?= $(C_SRC_DIR)/env.mk
C_SRC_OUTPUT ?= $(PRIV_DIR)/$(PROJECT_NIF_NAME).so

include $(C_SRC_ENV)

# System type and C compiler/flags.
UNAME_SYS := $(shell uname -s)
UNAME_SYS_LOWCASE := $(shell echo $(UNAME_SYS) | tr A-Z a-z)

CC ?= gcc
CXX ?= g++
CFLAGS ?= -O3 -std=c99 -finline-functions -Wall
CXXFLAGS ?= -O3 -finline-functions -Wall

ifeq ($(UNAME_SYS_LOWCASE), darwin)
    OPENSSL_ROOT := $(shell brew --prefix openssl@1.1)
    LZ4_ROOT := $(shell brew --prefix lz4)
    ZSTD_ROOT := $(shell brew --prefix zstd)
    CXXFLAGS += -I$(OPENSSL_ROOT)/include
    LDFLAGS += -L$(OPENSSL_ROOT)/lib \
               -L$(LZ4_ROOT)/lib \
               -L$(ZSTD_ROOT)/lib \
               -L/usr/local/lib
    LDFLAGS += -Wl,-U,_enif_alloc \
               -Wl,-U,_enif_free \
               -Wl,-U,_enif_alloc_resource \
               -Wl,-U,_enif_open_resource_type \
               -Wl,-U,_enif_release_resource \
               -Wl,-U,_enif_keep_resource \
               -Wl,-U,_enif_alloc_env \
               -Wl,-U,_enif_free_env \
               -Wl,-U,_enif_get_local_pid \
               -Wl,-U,_enif_send \
               -Wl,-U,_enif_thread_create \
               -Wl,-U,_enif_thread_join \
               -Wl,-U,_enif_thread_opts_create \
               -Wl,-U,_enif_thread_opts_destroy \
               -Wl,-U,_enif_mutex_create \
               -Wl,-U,_enif_mutex_destroy \
               -Wl,-U,_enif_mutex_lock \
               -Wl,-U,_enif_mutex_unlock \
               -Wl,-U,_enif_priv_data \
               -Wl,-U,_enif_self \
               -Wl,-U,_enif_consume_timeslice \
               -Wl,-U,_enif_inspect_binary \
               -Wl,-U,_enif_inspect_iolist_as_binary \
               -Wl,-U,_enif_is_binary \
               -Wl,-U,_enif_is_identical \
               -Wl,-U,_enif_is_list \
               -Wl,-U,_enif_get_int \
               -Wl,-U,_enif_get_long \
               -Wl,-U,_enif_get_list_cell \
               -Wl,-U,_enif_get_list_length \
               -Wl,-U,_enif_get_resource \
               -Wl,-U,_enif_get_tuple \
               -Wl,-U,_enif_make_copy \
               -Wl,-U,_enif_make_int \
               -Wl,-U,_enif_make_long \
               -Wl,-U,_enif_make_ref \
               -Wl,-U,_enif_make_atom \
               -Wl,-U,_enif_make_badarg \
               -Wl,-U,_enif_make_existing_atom \
               -Wl,-U,_enif_make_double \
               -Wl,-U,_enif_make_new_binary \
               -Wl,-U,_enif_make_resource \
               -Wl,-U,_enif_make_string_len \
               -Wl,-U,_enif_make_tuple \
               -Wl,-U,_enif_make_new_map \
               -Wl,-U,_enif_make_map_put \
               -Wl,-U,_enif_make_list \
               -Wl,-U,_enif_make_list_from_array \
               -Wl,-U,_enif_make_ulong \
               -Wl,-U,_enif_get_ulong \
               -Wl,-U,_enif_get_uint \
               -Wl,-U,_enif_make_list_cell \
               -Wl,-U,_enif_make_reverse_list
    LDFLAGS += -flat_namespace -undefined suppress
else ifeq ($(UNAME_SYS_LOWCASE), linux)
    LDFLAGS += -Wl,--exclude-libs=ALL
endif

CFLAGS += -fPIC -I$(ERTS_INCLUDE_DIR) -I$(ERL_INTERFACE_INCLUDE_DIR)
CXXFLAGS += -fPIC -I$(ERTS_INCLUDE_DIR) -I$(ERL_INTERFACE_INCLUDE_DIR)
LDFLAGS += -L$(ERL_INTERFACE_LIB_DIR) -shared -lei

CXXFLAGS += -DNDEBUG \
            -I$(BASEDIR)/_build/deps/librdkafka/src \
            -I$(BASEDIR)/_build/deps \
            -g -Wextra -Werror -Wno-missing-field-initializers -fno-exceptions -fno-rtti -std=c++11

LDFLAGS += -L$(BASEDIR)/_build/deps/librdkafka/src \
           -lrdkafka \
           -lsasl2 \
           -lz \
           -lssl \
           -lcrypto \
           -lstdc++ \
           -llz4 \
           -lzstd \
           -lcurl

# Verbosity.
V ?= 0

c_verbose_0 = @echo " C     " $(?F);
c_verbose = $(c_verbose_$(V))

cpp_verbose_0 = @echo " CPP   " $(?F);
cpp_verbose = $(cpp_verbose_$(V))

link_verbose_0 = @echo " LD    " $(@F);
link_verbose = $(link_verbose_$(V))

SOURCES := $(shell find $(C_SRC_DIR) -type f \( -name "*.c" -o -name "*.C" -o -name "*.cc" -o -name "*.cpp" \))
OBJECTS = $(addsuffix .o, $(basename $(SOURCES)))

COMPILE_C = $(c_verbose) $(CC) $(CFLAGS) $(CPPFLAGS) -c
COMPILE_CPP = $(cpp_verbose) $(CXX) $(CXXFLAGS) $(CPPFLAGS) -c

$(C_SRC_OUTPUT): $(OBJECTS)
	@mkdir -p $(PRIV_DIR)
	$(link_verbose) $(CXX) $(OBJECTS) $(LDFLAGS) -o $(C_SRC_OUTPUT)

%.o: %.c
	$(COMPILE_C) $(OUTPUT_OPTION) $<

%.o: %.cc
	$(COMPILE_CPP) $(OUTPUT_OPTION) $<

%.o: %.C
	$(COMPILE_CPP) $(OUTPUT_OPTION) $<

%.o: %.cpp
	$(COMPILE_CPP) $(OUTPUT_OPTION) $<

clean:
	@rm -f $(C_SRC_OUTPUT) $(OBJECTS)
	@rm -f $(C_SRC_ENV)