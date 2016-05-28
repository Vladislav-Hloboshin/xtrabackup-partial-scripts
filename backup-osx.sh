#! /bin/bash

BASEDIR=$(dirname $0)
SHFLAGS_LIB_PATH=$BASEDIR/lib/shflags

source $SHFLAGS_LIB_PATH
if [[ $? -ne 0 ]]; then
    echo "Unable to source shFlags library: ${SHFLAGS_LIB_PATH}"
    exit 1
fi

# FLAGS
DEFINE_string 'database' ''           '' 'b' 'required'
DEFINE_string 'file'     ''           '' 'f'  'required'
DEFINE_string 'user'     'xtrabackup' '' 'u'

# parse the command-line
FLAGS "$@" || exit 1
eval set -- "${FLAGS_ARGV}"

TDIR=`mktemp -d`
trap "{ cd - ; rm -rf $TDIR; exit 255; }" SIGINT

xtrabackup --defaults-file=/usr/local/mysql/my.cnf --backup --user="${FLAGS_user}"  --databases=$FLAGS_database --target-dir=$TDIR

mysqldump --user="${FLAGS_user}" --no-data --single-transaction --routines $FLAGS_database | sed '/ALTER DATABASE/d' > $TDIR/$FLAGS_database/ddl.sql

xtrabackup --prepare --export --target-dir=$TDIR

rm -f $TDIR/ibdata1

mv $TDIR/xtrabackup_* $TDIR/$FLAGS_database

rm -f $FLAGS_file
tar -cpvzf $FLAGS_file -C $TDIR/$FLAGS_database .
rm -rf $TDIR
