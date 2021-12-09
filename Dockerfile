FROM alpine:3.14 AS build

RUN apk update && \
    apk add --no-cache build-base autoconf libtool zlib-dev ldc dub && \
    mkdir /zextractor

WORKDIR /zextractor
COPY source/ ./source/
COPY configgenerator/ ./configgenerator/
COPY dub.json ./dub.json
RUN dub clean && dub build --build=release --config=docker --force


FROM alpine:3.14

RUN apk update && \
    apk add --no-cache zlib llvm-libunwind

WORKDIR /zext
COPY --from=build /zextractor/bin/zextractor .

ENTRYPOINT ["./zextractor"]
