# vim:ft=dockerfile

# Base image
FROM ubuntu:22.04 AS base

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        cmake libgmp-dev libmpfr-dev libmpc-dev \
        libboost-all-dev bison texinfo bzip2 \
        ruby flex curl g++ git macutils unzip

# Add toolchain to default PATH
ENV PATH=/Retro68-build/toolchain/bin:$PATH
WORKDIR /root

# Build image
FROM base AS build

ADD . /Retro68

RUN mkdir /Retro68-build && \
    mkdir /Retro68-build/bin && \
    bash -c "cd /Retro68-build && bash /Retro68/build-toolchain.bash"

# Install MPW Interfaces (provides MacTCP.h, OpenTransport.h, etc.)
RUN mkdir -p /tmp/InterfacesAndLibraries && \
    unzip -o /Retro68/resources/MPW_Interfaces.zip -d /tmp/InterfacesAndLibraries/ && \
    bash /Retro68/interfaces-and-libraries.sh /Retro68-build/toolchain \
        "/tmp/InterfacesAndLibraries/MPW_Interfaces/Interfaces&Libraries" && \
    rm -rf /tmp/InterfacesAndLibraries

# Release image
FROM base AS release

# MPW Interfaces are pre-installed (universal), no runtime setup needed
ENV INTERFACES=universal

COPY --from=build \
    /Retro68/interfaces-and-libraries.sh \
    /Retro68/prepare-headers.sh \
    /Retro68/prepare-rincludes.sh \
    /Retro68/install-universal-interfaces.sh \
    /Retro68/docker-entrypoint.sh \
    /Retro68-build/bin/

COPY --from=build /Retro68-build/toolchain /Retro68-build/toolchain

LABEL org.opencontainers.image.source https://github.com/matthewdeaves/Retro68

CMD [ "/bin/bash" ]
ENTRYPOINT [ "/Retro68-build/bin/docker-entrypoint.sh" ]
