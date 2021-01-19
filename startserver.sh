#!/bin/bash +x

if [ $# -ne 1 ]
then
	echo "Please pass rel version"
	exit
fi

export PATH="/home/temuppar/work/pg/install.$1/bin:$PATH"
export VERSION=$1

setprim()
{
       export PGDATA="/home/temuppar/work/pg/data_prim"
       export PGPORT=5555
}

setsec()
{
       export PGDATA="/home/temuppar/work/pg/data_sec"
       export PGPORT=7777
}
setsec2()
{
       export PGDATA="/home/temuppar/work/pg/data_sec2"
       export PGPORT=8888
}


whichser()
{
        echo "Enter choice 1)Primary 2)Secondary-1 3)Secondary-2"
        read opt
        case $opt in
                1) setprim;
                ;;
                2) setsec;
                ;;
                3) setsec2;
                ;;
        esac
}

buildset() {
        setprim;
        echo "Building server1: $1"
        stopserver 0;
        rm -rf $PGDATA
        initdb -A password --pwfile="/home/temuppar/work/pg/pwd"  -U sa -D$PGDATA --noclean
	echo "wal_level = logical" >> $PGDATA/postgresql.conf
        startserver 0;
        createdb -Usa orcadb
        setsec;
        echo "Building server2: $1"
        stopserver 0;
        rm -rf $PGDATA
        initdb -A password --pwfile="/home/temuppar/work/pg/pwd"  -U sa -D$PGDATA --noclean
	echo "wal_level = logical" >> $PGDATA/postgresql.conf
        startserver 0;
        createdb -Usa orcadb
	psql -Usa --port=5555 orcadb << EOF
	CREATE TABLE sync_set_t (id int primary key, c varchar);
	CREATE PUBLICATION expose_s1 FOR TABLE sync_set_t;
	\c 'port=7777 dbname=orcadb user=sa';
	CREATE TABLE sync_set_t (id int primary key, c varchar);
	CREATE PUBLICATION expose_s2 FOR TABLE sync_set_t;
	\c 'port=5555 dbname=orcadb user=sa';
	CREATE SUBSCRIPTION receive_s2 CONNECTION 'port=7777 dbname=orcadb user=sa' PUBLICATION expose_s2;
	\c 'port=7777 dbname=orcadb user=sa';
	CREATE SUBSCRIPTION receive_s1 CONNECTION 'port=5555 dbname=orcadb user=sa' PUBLICATION expose_s1;
EOF
}

buildprimary() {
        setprim;
        echo "Building primary server: $1"
        stopserver 0;
        rm -rf $PGDATA
        initdb -A password --pwfile="/home/temuppar/work/pg/pwd"  -U sa -D$PGDATA --noclean
	#echo "synchronous_standby_names = 'ANY 1 (pg_receivewal, standby1)' ">> $PGDATA/postgresql.conf
	echo "wal_level = logical" >> $PGDATA/postgresql.conf >> $PGDATA/postgresql.conf
	echo "archive_mode    = on" >> $PGDATA/postgresql.conf >> $PGDATA/postgresql.conf
	echo "hot_standby    = on" >> $PGDATA/postgresql.conf >> $PGDATA/postgresql.conf
	echo "archive_command = 'cp %p /tmp/pubs_archive/%f'" >> $PGDATA/postgresql.conf
	echo "shared_preload_libraries = 'azure, pg_stat_statements'" >> $PGDATA/postgresql.conf
	echo "azure.extensions = 'pg_stat_statements'"  >> $PGDATA/postgresql.conf
	echo "azure.custom_path = '/tmp'"  >> $PGDATA/postgresql.conf
        startserver 0;
        createdb -Usa orcadb
	setup_master;
}

buildsec() {
        echo "Building standby server: $1"
        setsec;
        rm -rf $PGDATA
	setprim;
	echo "Taking base backup"
	pg_basebackup -U sa -p 5555 -D /home/temuppar/work/pg/data_sec -Fp -Xs -P -R
        #stopserver 0;
        #initdb -A password -U sa --pwfile="/home/temuppar/work/pg/pwd" -D$PGDATA
        setsec;
	echo "hot_standby = on" >> $PGDATA/postgresql.conf
	echo "shared_preload_libraries = 'azure'" >> $PGDATA/postgresql.conf
	#echo "restore_command = 'cp /tmp/walsvc_archive/%f "%p"'"  >> $PGDATA/postgresql.conf
	echo "#Stream from WAL service at port:7777" >> $PGDATA/postgresql.conf
	
	if [ $VERSION -eq "11" ]
	then
		echo "restore_command = 'cp /tmp/pubs_archive/%f "%p"'"  >> $PGDATA/recovery.conf
		#echo "primary_conninfo = 'host=localhost user=replication password=password port=5555 sslmode=disable sslcompression=0 target_session_attrs=any application_name=standby1'" >> $PGDATA/recovery.conf
	else
		echo "primary_conninfo = 'host=localhost user=replication password=password port=5555 sslmode=disable sslcompression=0 gssencmode=disable target_session_attrs=any application_name=standby1'" >> $PGDATA/postgresql.auto.conf
		echo "restore_command = 'cp /tmp/pubs_archive/%f "%p"'"  >> $PGDATA/postgresql.conf
		echo "primary_conninfo = 'host=localhost user=replication password=password port=5555 sslmode=disable sslcompression=0 gssencmode=disable target_session_attrs=any application_name=standby1'" >> $PGDATA/postgresql.conf
	fi
	#echo "primary_slot_name = '1standby'">> $PGDATA/postgresql.conf
	touch $PGDATA/standby.signal
        startserver 0;
        #createdb -Usa orcadb
}

buildsec2() {
        echo "Building standby server: $1"
        setsec2;
        rm -rf $PGDATA
	#setprim;
	echo "Copying base backup"
	cp -r /home/temuppar/work/pg/data_sec /home/temuppar/work/pg/data_sec2
        if [ -f "$PGDATA/postmaster.pid" ]
	then
		rm $PGDATA/postmaster.pid
	fi
	#pg_basebackup -U sa -p 5555 -D /home/temuppar/work/pg/data_sec2 -Fp -Xs -P -R
        setsec2;
	echo "hot_standby = on" >> $PGDATA/postgresql.conf
	echo "restore_command = 'cp /tmp/walsvc_archive/%f "%p"'"  >> $PGDATA/postgresql.conf
	echo "#Stream from WAL service at port:7777" >> $PGDATA/postgresql.conf
	echo "primary_conninfo = 'host=localhost user=replication password=password port=5555 sslmode=disable sslcompression=0 gssencmode=disable target_session_attrs=any'" >> $PGDATA/postgresql.auto.conf
	echo "primary_conninfo = 'host=localhost user=replication password=password port=5555 sslmode=disable sslcompression=0 gssencmode=disable target_session_attrs=any'" >> $PGDATA/postgresql.conf
	touch $PGDATA/standby.signal
        startserver 0;
}

startserver() {

        if [ -z "$1" ]
        then
                whichser;
        fi

        if [ -f "$PGDATA/log" ]
	then
		rm $PGDATA/log
	fi
        pg_ctl -D$PGDATA -l $PGDATA/log -w start
}

restartserver() {
        echo "Restarting server"
        if [ -z "$1" ]
        then
                whichser;
        fi
	rm $PGDATA/log
        pg_ctl -D$PGDATA -l $PGDATA/log restart -m smart >&/tmp/log
}

stopserver() {
        echo "Stopping server"
        if [ -z "$1" ]
        then
                whichser;
        fi
        pg_ctl -D$PGDATA stop -m fast
}

ping() {
        whichser;
        pg_ctl -D$PGDATA status
	sudo netstat -plunt |egrep "postgres|walsvc"
}

setup_master() {
psql -Usa --port=5555 orcadb << EOF
CREATE USER replication WITH REPLICATION password 'password' LOGIN;
EOF
}

setup_standby() {
pg_basebackup -h localhost -U sa -p 5555 -D /home/temuppar/work/pg/data_sec -Fp -Xs -P -R
}

loaddata() {
psql -Usa --port=5555 orcadb << EOF
drop table bloat00;
create table bloat00 (pk int primary key, c char(3333));
alter table bloat00 alter column c set storage plain;
insert into bloat00 select generate_series(1, 2624), 'X';
EOF

}

verifydata() {
        if [ -z "$1" ]
        then
                whichser;
        fi
	psql -Usa --port=$PGPORT orcadb << EOF
	select version();
	select count(*) as "Total:" from bloat00;
	select sum(pk) from bloat00;
EOF
}

upgdata() {
#Shutdown old server
stopserver;
#Shutdown new server
stopserver;
#pg_upgrade will connect to the old and new servers several times, so you might want to set authentication to peer in pg_hba.conf or use a ~/.pgpass file (see Section 32.15)
export PGPASSFILE=/home/temuppar/work/pg/pwd
pg_upgrade -Usa --verbose --old-datadir "/home/temuppar/work/pg/data_prim" --new-datadir "/home/temuppar/work/pg/data_sec" --old-bindir "/home/temuppar/work/pg/install.10/bin" --new-bindir "/home/temuppar/work/pg/install.11/bin" --link
#Optimizer statistics are not transferred by pg_upgrade so, once you start the new server, consider running:
#    ./analyze_new_cluster.sh
#Running this script will delete the old cluster's data files:
#    ./delete_old_cluster.sh
}

echo "Enter choice 1)Start 2)Stop 3)Restart 4)Build Primary 5) Build Secondary 6)Build Secondary-2 7)ping 8)load 9)upgrade 10)verifydata 11) buildset;"
read opt
case $opt in

        1) startserver;
                ;;
        2) stopserver;
                ;;
        3) restartserver;
                ;;
        4) buildprimary;
                ;;
        5) buildsec;
                ;;
        6) buildsec2;
                ;;
        7) ping;
                ;;
        8) loaddata;
                ;;
	9) upgdata;
		;;
	10) verifydata;
		;;
	11) buildset;
		;;
	esac
