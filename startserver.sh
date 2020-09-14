#!/bin/sh

VERSION=$1
export PATH=$PATH:PGINSTALL.11

start()
{
}

stop()
{
}

BuildPrimary()
{
  initdb -A password --pwfile="/home/temuppar/work/pg/pwd"  -U sa -D$PGDATA --noclean
}

BuildSecondary()
{
}

echo "Enter Choice 1) BuildPrimary 2)BuildSecondary 3)Start 5)Stop"
