PRIV_DIR = $(MIX_APP_PATH)/priv
NIF_SO = $(PRIV_DIR)/exrdkafka_nif.so
DEPS_DIR = $(CURDIR)/_build/deps

CFLAGS = -fPIC -I$(ERTS_INCLUDE_DIR) -I$(ERL_INTERFACE_INCLUDE_DIR)
CXXFLAGS = -fPIC -I$(ERTS_INCLUDE_DIR) -I$(ERL_INTERFACE_INCLUDE_DIR)
LDFLAGS = -L$(ERL_INTERFACE_LIB_DIR) -shared -lei

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    OPENSSL_DIR = $(shell brew --prefix openssl)
    LZ4_DIR = $(shell brew --prefix lz4)
    ZSTD_DIR = $(shell brew --prefix zstd)
    CURL_DIR = $(shell brew --prefix curl)
    CXXFLAGS += -I$(OPENSSL_DIR)/include -I$(LZ4_DIR)/include -I$(ZSTD_DIR)/include -I$(CURL_DIR)/include
    LDFLAGS += -L$(OPENSSL_DIR)/lib -L$(LZ4_DIR)/lib -L$(ZSTD_DIR)/lib -L$(CURL_DIR)/lib
endif

CXXFLAGS += -std=c++11 -O3 -Wall -Wextra -Wno-missing-field-initializers \
            -DNDEBUG \
            -I$(DEPS_DIR)/librdkafka/src \
            -I$(DEPS_DIR)

LDFLAGS += -L$(DEPS_DIR)/librdkafka/src \
           -lrdkafka \
           -lsasl2 \
           -lz \
           -lssl \
           -lcrypto \
           -lstdc++ \
           -llz4 \
           -lzstd \
           -lcurl

SOURCES = $(wildcard c_src/*.cpp)
OBJECTS = $(SOURCES:.cpp=.o)

.PHONY: all clean deps

all: deps $(NIF_SO)

deps:
	@echo "Building dependencies..."
	@./build_deps.sh

$(NIF_SO): $(OBJECTS)
	@mkdir -p $(PRIV_DIR)
	$(CXX) $(OBJECTS) $(LDFLAGS) -o $@

%.o: %.cpp
	$(CXX) -c $(CXXFLAGS) $< -o $@

clean:
	@rm -rf $(PRIV_DIR) $(OBJECTS)
	@rm -rf $(DEPS_DIR)
