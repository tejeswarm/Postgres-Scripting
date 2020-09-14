#!/bin/sh +x

if [ $# -ne 1 ]
then
	echo "Please pass version"
	exit
fi

VERSION=$1
PGINSTALL="/home/temuppar/work/pg/install.$VERSION"
export PATH="$PGINSTALL/bin:$PATH"
export PGPASSWORD=`cat /home/temuppar/work/pg/pwd`
export STANDBY1=geo1
export PGARCHIVE="/tmp/install"

primenv()
{
  export PGDATA=/home/temuppar/work/data_prim
  export PGPORT=5555
  export CONF="$PGDATA/postgresql.conf"
}

secenv()
{
  export PGDATA=/home/temuppar/work/data_sec
  export PGPORT=7777
  export CONF="$PGDATA/postgresql.conf"
}

start()
{
  if [ $1 -eq 1 ]
  then
    primenv
  else
    secenv
  fi

  echo "Starting @..... $PGPORT"
  pg_ctl start -l $PGDATA/logfile -D$PGDATA
}

stop()
{
  if [ $1 -eq 1 ]
  then
    primenv
  else
    secenv
  fi

  echo "Stpping @..... $PGPORT"
  pg_ctl stop -D$PGDATA -m smart
}

restart()
{
  if [ $1 -eq 1 ]
  then
    primenv
  else
    secenv
  fi

  echo "Starting @..... $PGPORT"
  pg_ctl restart -l $PGDATA/logfile -D$PGDATA
}

enableHA()
{
  if [ $1 -eq 1 ]
  then
  	# Configs
	echo "synchronous_commit = remote_write" > $CONF
  	echo "wal_level  = replica" >> $CONF
	echo "archive_command = 'test ! -f $PGARCHIVE/%f && cp %p $PGARCHIVE/%f'" >> $CONF
	#Ensure quorom
	echo "synchronous_standby_names  = 'ANY 1 ($STANDBY1, foo)'" >> $CONF
	echo "azure.enforce_ha_quorom  = true" >> $CONF
	echo "azure.bogus  = false" >> $CONF
	echo "azure.extensions  = 'azure, pglogical'" >> $CONF
	echo "shared_preload_libraries = 'azure,pglogical'" >> $CONF
  else
  	# Configs
	echo "primary_conninfo = 'application_name=$STANDBY1 host=localhost port=5555 user=sa password=sa'" > $CONF
	echo "restore_command = 'cp $PGARCHIVE/%f %p'" >> $CONF
	echo "hot_standby = on" >> $CONF
	echo "application_name = $STANDBY1" >> $CONF
	echo "shared_preload_libraries = azure" >> $CONF
	touch $PGDATA/standby.signal
  fi
}

BuildPrimary()
{
  primenv
  stop 1
  rm -rf $PGDATA
  rm -rf $PGARCHIVE/*

  initdb -A password --pwfile="/home/temuppar/work/pg/pwd"  -U sa -D$PGDATA --noclean
  start 1
  createdb -Usa orcadb -w

  enableHA 1
  restart 1
}

BuildSecondary()
{
  secenv
  stop 2
  rm -rf $PGDATA
  primenv

  pg_basebackup -Usa -D/home/temuppar/work/data_sec 

  secenv
  enableHA 2
  start 2
  #restart 2
}

echo "Enter Choice 1) BuildPrimary 2) BuildSecondary 3) StartPrim 4) StopPrim"
echo "             5) StartSec 6) StopSec"
read opt
case $opt in
        1) BuildPrimary $1;
                ;;
        2) BuildSecondary $1;
                ;;
        3) start 1;
                ;;
        4) stop 1;
                ;;
        5) start 2;
                ;;
        6) stop 2;
                ;;
esac
