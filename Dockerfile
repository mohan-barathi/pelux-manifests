FROM ubuntu:16.04

LABEL description="PELUX Yocto build environment"

# Enables us to overwrite the user and group ID for the yoctouser. See below
ARG userid=1000
ARG groupid=1000
ARG proxy=http://10.0.2.2:3128

USER root

# Using Cntlm proxy
# Change the IP according to your Cntlm setup
ENV http_proxy ${proxy} 
ENV https_proxy ${proxy} 

# Install dependencies in one command to avoid potential use of previous cache
# like explained here: https://stackoverflow.com/a/37727984
RUN apt-get update && \
    apt-get upgrade && \
    apt-get install -y \
        bc \
        build-essential \
        chrpath \
        coreutils \
        cpio \
        curl \
        cvs \
        debianutils \
        diffstat \
        g++-multilib \
        gawk \
        gcc-multilib \
        git-core \
        graphviz \
        help2man \
        iptables \
        iputils-ping \
        libegl1-mesa \
        libfdt1 \
        libsdl1.2-dev \
        libxml2-utils \
        locales \
        m4 \
        openssh-server \
        python \
        python-pysqlite2 \
        python3 \
        python3-git \
        python3-jinja2 \
        python3-pexpect \
        python3-pip \
        qemu-user \
        repo \
        rsync \
        screen \
        socat \
        subversion \
        sudo \
        sysstat \
        texinfo \
        tmux \
        unzip \
        vim \
        wget \
        xz-utils \
        libncurses5-dev \
        libncursesw5-dev 

RUN apt-get clean

# Install Bosch certificates
ADD Bosch-CA-DE.crt /usr/local/share/ca-certificates/Bosch-CA-DE.crt
ADD Bosch-CA1-DE.crt /usr/local/share/ca-certificates/Bosch-CA1-DE.crt
ADD Bosch-CA2-DE.crt /usr/local/share/ca-certificates/Bosch-CA2-DE.crt
RUN chmod 644 /usr/local/share/ca-certificates/*.crt && update-ca-certificates


# For Yocto bitbake -c testimage XML reporting
RUN pip3 install unittest-xml-reporting

# For git-lfs
# The downloaded script is needed since git-lfs is not available per default for Ubuntu 16.04
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo -E bash && sudo -E apt-get update && sudo -E apt-get install -y git-lfs

# Remove all apt lists to avoid build caching
RUN rm -rf /var/lib/apt/lists/*

# en_US.utf8 is required by Yocto sanity check
RUN /usr/sbin/locale-gen en_US.UTF-8
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
RUN echo 'export LC_ALL="en_US.UTF-8"' >> /etc/profile
ENV LANG en_US.utf8

RUN useradd -U -m yoctouser

# Make sure the user/groupID matches the UID/GID given to Docker. This is so that mounted
# dirs will get the correct permissions
RUN usermod --uid $userid yoctouser
RUN groupmod --gid $groupid yoctouser
RUN echo 'yoctouser:yoctouser' | chpasswd
RUN echo 'yoctouser ALL=(ALL) NOPASSWD:SETENV: ALL' > /etc/sudoers.d/yoctouser

# Copy cookbook
ADD --chown=yoctouser:yoctouser cookbook /tmp/cookbook/

USER yoctouser
WORKDIR /home/yoctouser

# Script which allows to pass containers CMD as an argument to timeout command
# in case we need redefine entrypoint '--entrypoint' key can be used durring container start
RUN echo "#!/usr/bin/env bash" >> /home/yoctouser/docker-ep.sh && \
    echo 'exec  timeout --signal=SIGKILL 21600 "$@"' >> /home/yoctouser/docker-ep.sh && \
    chmod +x /home/yoctouser/docker-ep.sh
ENTRYPOINT ["/home/yoctouser/docker-ep.sh"]

