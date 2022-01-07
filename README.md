
# Table of Contents

1.  [Copy files to GCP compute instance](#org2ebe8a8)
2.  [Log into GCP compute instance](#orge6a25b8)
3.  [Dowload rpms](#org007031c)
    1.  [Download OSS CentOS/RHEL 7 Greenplum 6 release from GitHub](#orgeae8fb6)
    2.  [Download CentOS/RHEL 7 Greenplum 6 release from Tanzu Network](#orgffe3712)
4.  [Update docker host with sysctl settings](#org71ef7c4)
5.  [Install Docker](#org33b882c)
    1.  [Add user to docker group (needed to use docker CLI without sudo)](#org1504a55)
6.  [Create docker image](#org0f66eca)
7.  [Run gpdb container passing in GPDB kernel.sem required values](#org8cf0b02)
8.  [Container operations](#orgbaff40b)
9.  [Simple GPDB config checks](#org740c013)
10. [Create test databases, tables and data](#orgc80b7d0)
11. [Delete GPDB cluster](#orgd4d8a1c)
12. [Misc docker commands](#orgc67a574)


<a id="org2ebe8a8"></a>

# Copy files to GCP compute instance

    gcloud beta compute scp --project "$(gcloud config get-value project)" --recurse . dockergpdbenv:~/gp-docker


<a id="orge6a25b8"></a>

# Log into GCP compute instance

    gcloud beta compute ssh --project "$(gcloud config get-value project)" --zone "us-west1-a" dockergpdbenv
    cat /etc/redhat-release


<a id="org007031c"></a>

# Dowload rpms


<a id="orgeae8fb6"></a>

## Download OSS CentOS/RHEL 7 Greenplum 6 release from GitHub

    mkdir -p $HOME/gp-docker/rpms
    curl -L https://github.com/greenplum-db/gpdb/releases/download/6.19.0/open-source-greenplum-db-6.19.0-rhel7-x86_64.rpm -o $HOME/gp-docker/rpms/open-source-greenplum-db-6.19.0-rhel7-x86_64.rpm


<a id="orgffe3712"></a>

## Download CentOS/RHEL 7 Greenplum 6 release from Tanzu Network

Alternartively retrieve GPDB from Tanzu Network


<a id="org71ef7c4"></a>

# Update docker host with sysctl settings

    sudo cp gp-docker/configs/99-gpdb-sysctl.conf /etc/sysctl.d
    sudo sysctl -p /etc/sysctl.d/99-gpdb-sysctl.conf


<a id="org33b882c"></a>

# Install Docker

    sudo yum install -q -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -q -y docker-ce docker-ce-cli containerd.io
    
    sudo systemctl start docker
    sudo systemctl status docker
    
    sudo docker version
    sudo docker images
    sudo docker ps -a


<a id="org1504a55"></a>

## Add user to docker group (needed to use docker CLI without sudo)

    groups
    sudo usermod -aG docker eespino
    newgrp docker
    groups


<a id="org0f66eca"></a>

# Create docker image

    cd $HOME/gp-docker
    docker build --tag gpdbenv .
    
    docker images


<a id="org8cf0b02"></a>

# Run gpdb container passing in GPDB kernel.sem required values

    docker run --sysctl kernel.sem="500 1024000 200 4096" \
               --hostname mdw \
               --interactive \
               --tty \
               --volume $HOME/gp-docker:/tmp/gp-docker gpdbenv bash


<a id="orgbaff40b"></a>

# Container operations

    # Install Greenplum
    yum install -y /tmp/gp-docker/rpms/open-source-greenplum-db-6.19.0-rhel7-x86_64.rpm
    # or
    yum install -y /tmp/gp-docker/rpms/greenplum-db-6.19.0-rhel7-x86_64.rpm
    
    # Prep for running GPDB
    chown -R gpadmin:gpadmin /usr/local/greenplum-db*
    
    # Start ssh daemon
    /usr/sbin/sshd
    
    # Become gpadmin
    su - gpadmin
    
    # Initialize ssh known_hosts file
    ssh -o StrictHostKeyChecking=no $(hostname) date
    
    # Init GDPB cluster
    source /usr/local/greenplum-db/greenplum_path.sh
    
    postgres --gp-version
    postgres --version
    
    cp /tmp/gp-docker/configs/gpinitsystem.conf /tmp/gp-docker/configs/gpinitsystem-addons.conf /tmp/gp-docker/configs/hostfile .
    gpinitsystem -a -c gpinitsystem.conf -p gpinitsystem-addons.conf -h hostfile


<a id="org740c013"></a>

# Simple GPDB config checks

    psql -P pager=off -c 'select version()'
    psql -P pager=off -c '\l'
    psql -P pager=off -c 'select * from gp_segment_configuration'


<a id="orgc80b7d0"></a>

# Create test databases, tables and data

    psql -P pager=off -c 'DROP DATABASE IF EXISTS db1'
    psql -P pager=off -c 'DROP DATABASE IF EXISTS db2'
    psql -P pager=off -c 'CREATE DATABASE db1'
    psql -P pager=off -c 'CREATE DATABASE db2'
    
    psql -P pager=off -d db1 -c 'CREATE TABLE table1         (a int)'
    psql -P pager=off -d db1 -c 'CREATE TABLE table1_ao      (a int) WITH (appendonly=true) DISTRIBUTED BY (a)'
    psql -P pager=off -d db2 -c 'CREATE TABLE table1_aoco    (a int) WITH (appendonly=true, orientation=column) DISTRIBUTED BY (a)'
    psql -P pager=off -d db2 -c 'CREATE TABLE table1_ao_zlib (a int) WITH (appendonly=true, compresstype=zlib, compresslevel=5)'
    
    psql -P pager=off -d db1 -c 'INSERT INTO table1         SELECT generate_series(1,1000000)'
    psql -P pager=off -d db1 -c 'INSERT INTO table1_ao      SELECT generate_series(1,1000000)'
    psql -P pager=off -d db2 -c 'INSERT INTO table1_aoco    SELECT generate_series(1,1000000)'
    psql -P pager=off -d db2 -c 'INSERT INTO table1_ao_zlib SELECT generate_series(1,1000000)'
    
    psql -P pager=off -d db1 -c 'SELECT count(*) from table1'
    psql -P pager=off -d db1 -c 'SELECT count(*) from table1_ao'
    psql -P pager=off -d db2 -c 'SELECT count(*) from table1_aoco'
    psql -P pager=off -d db2 -c 'SELECT count(*) from table1_ao_zlib'
    
    psql -P pager=off -d db1 -c 'SELECT gp_segment_id, count(*) from public.table1 GROUP BY gp_segment_id order by 2'
    psql -P pager=off -d db1 -c 'SELECT gp_segment_id, count(*) from public.table1_ao GROUP BY gp_segment_id order by 2'
    psql -P pager=off -d db2 -c 'SELECT gp_segment_id, count(*) from public.table1_aoco GROUP BY gp_segment_id order by 2'
    psql -P pager=off -d db2 -c 'SELECT gp_segment_id, count(*) from public.table1_ao_zlib GROUP BY gp_segment_id order by 2'


<a id="orgd4d8a1c"></a>

# Delete GPDB cluster

    export MASTER_DATA_DIRECTORY=/data0/master/gpseg-1
    gpdeletesystem
    rm -rf $HOME/gpAdminLogs


<a id="orgc67a574"></a>

# Misc docker commands

    docker images
    
    docker ps -a -f status=created
    docker rm -v $(docker ps -q -a -f status=created)
    
    docker ps -a -f status=exited
    docker rm -v $(docker ps -q -a -f status=exited)
    
    docker images -q --filter "dangling=true"
    docker rmi $(docker images -q --filter "dangling=true")
    
    docker ps -a
    docker rm $(docker ps -a -q)
    
    docker images
    docker rmi $(docker images -q)

