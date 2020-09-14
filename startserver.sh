#!/bin/sh

VERSION=$1
export PATH=$PATH:PGINSTALL.$VERSION

primenv()
{
  export PGDATA=/home/temuppar/work/data_prim
  export PGPORT=5555
}

secenv()
{
  export PGDATA=/home/temuppar/work/data_sec
  export PGPORT=7777
}

start()
{
  pg_ctl start -D$PGDATA
}

stop()
{
  pg_ctl stop -D$PGDATA -msmart
}

BuildPrimary()
{
  primenv
  initdb -A password --pwfile="/home/temuppar/work/pg/pwd"  -U sa -D$PGDATA --noclean
}

BuildSecondary()
{
}

echo "Enter Choice 1) BuildPrimary 2)BuildSecondary 3)Start 5)Stop"
