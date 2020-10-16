#!/bin/bash

export PGPASSWORD=Yukon900

load ()
{
table=alpha$1
psql -q -h 24x7-prod-app.postgres.database.azure.com -U cloudsa   -d contapp <<EOF
drop table if exists $table;
create table $table(c varchar, i int);
insert into $table select 'test', generate_series(1, 100000, 1);
select count(*) from $table;
update $table set i = i + 1;
delete from $table;
EOF
}

threads=5

x=1
while [ $x -le 1 ]
do

psql -h 24x7-prod-app.postgres.database.azure.com -U cloudsa   -d contapp <<EOF
SELECT pg_size_pretty( pg_database_size('contapp') );
EOF

	for i in {1..5}
	do
		echo start load on thread:$i
		load $i &
	done

echo "Waiting for load to finish"
wait

psql -h 24x7-prod-app.postgres.database.azure.com -U cloudsa   -d contapp <<EOF
SELECT pg_size_pretty( pg_database_size('contapp') );
EOF
sleep 5
echo start the next Job

done
