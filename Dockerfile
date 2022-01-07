FROM centos:7

COPY scripts/setup-gpadmin.sh /opt

## Install GPDB dependencies
## package requirements taken from GPDB 6 RPM SPEC file:
##   https://github.com/greenplum-db/greenplum-database-release/blob/main/ci/concourse/scripts/greenplum-db-6.spec
RUN yum install -y \
        apr apr-util \
        bash \
        bzip2 \
        curl \
        iproute \
        krb5-devel \
        less \
        libcurl \
        libevent \
        libxml2 \
        libyaml \
        net-tools \
        openldap \
        openssh \
        openssh-clients \
        openssh-server \
        openssl \
        openssl-libs \
        perl \
        readline \
        rsync \
        sed \
        tar \
        which \
        zip \
        zlib

## Create gpadmin user and a few GPDB environment requirements
RUN /opt/setup-gpadmin.sh
