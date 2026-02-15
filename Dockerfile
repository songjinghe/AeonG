FROM hououou/aeong:v1
MAINTAINER Jinghe Song <songjh@buaa.edu.cn>
ARG TZ=Asia/Shanghai

WORKDIR cd /home/AeonG
COPY . .

# Download required patches into libs
RUN mkdir -p libs && cd libs && \
    wget https://raw.githubusercontent.com/memgraph/memgraph/v2.2.0/libs/antlr4.patch && \
    wget https://raw.githubusercontent.com/memgraph/memgraph/v2.2.0/libs/librdtsc.patch

RUN source /opt/toolchain-v4/activate && bash setup.sh
# Modify setup.sh to skip applying rocksdb.patch (comment matching line)
# RUN sed -i 's/^\s*git apply ..\/rocksdb.patch/\# &/' setup.sh || true

# Apply RocksDB related small fixes described in instructions
RUN ROCKS_CMAKE="libs/rocksdb/CMakeLists.txt" && \
    if [ -f "$ROCKS_CMAKE" ]; then \
      sed -i '/-momit-leaf-frame-pointer/ a\  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-deprecated-copy -Wno-unused-but-set-variable")' $ROCKS_CMAKE; \
      sed -i 's/TARGETS ${ROCKSDB_SHARED_LIB}/TARGETS ${ROCKSDB_SHARED_LIB} OPTIONAL/' $ROCKS_CMAKE; \
    fi

# Initialize project (downloads dependencies). This may be slow.
RUN /home/AeonG/init

ENV LD_LIBRARY_PATH /home/AeonG/libs/protobuf/lib:$LD_LIBRARY_PATH
RUN git checkout -- quicklisp.lisp

# Build memgraph (server)
RUN mkdir -p build && cd build && cmake .. && make -j$(nproc) memgraph

# Build mgbench client and libs/mgconsole as per instructions
RUN mkdir -p build/tests/mgbench && cd build/tests/mgbench && make
RUN mkdir -p build/libs && cd build/libs && make

# Collect built binaries
# RUN mkdir -p /out/bin && if [ -d build/bin ]; then cp -a build/bin/* /out/bin/ || true; fi

# FROM ubuntu:22.04 AS runtime
# ARG TZ=Asia/Shanghai
# ENV TZ=${TZ}
# RUN apt-get update && apt-get install -y --no-install-recommends  && rm -rf /var/lib/apt/lists/*
# COPY --from=builder /out/bin/ /usr/local/bin/

# # If memgraph binary exists, use it as entrypoint, otherwise fall back to bash
# RUN if [ -x /usr/local/bin/memgraph ]; then ln -s /usr/local/bin/memgraph /usr/local/bin/aeong || true; fi
# ENTRYPOINT ["/usr/local/bin/memgraph"]
# FROM songjinghe/temporal-graph-dbms:aeong-2.2-e11679d
# COPY docker/aeong.docker-entrypoint.sh /home/AeonG/build/docker-entrypoint.sh

RUN mkdir -p /database

WORKDIR /home/AeonG/build
RUN chmod 755 /home/AeonG/build/docker-entrypoint.sh

ENTRYPOINT [ "/home/AeonG/build/docker-entrypoint.sh" ]
