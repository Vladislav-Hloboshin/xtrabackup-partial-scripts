#! /bin/bash

BASEDIR=$(dirname $0)
SHFLAGS_LIB_PATH=$BASEDIR/lib/shflags

source $SHFLAGS_LIB_PATH
if [[ $? -ne 0 ]]; then
    echo "Unable to source shFlags library: ${SHFLAGS_LIB_PATH}"
    exit 1
fi

# FLAGS
DEFINE_string 'databases'       ''              '' 'b' 'required'
DEFINE_string 'backupdir'       ''              '' 'd' 'required'
DEFINE_string 'backupprefix'    ''              '' 'p'
DEFINE_string 'backupsuffix'    ''              '' 's'
DEFINE_string 'user'            'xtrabackup'    '' 'u'

# parse the command-line
FLAGS "$@" || exit 1
eval set -- "${FLAGS_ARGV}"

TDIR=`mktemp -d`
trap "{ cd - ; rm -rf $TDIR; exit 255; }" SIGINT

xtrabackup --backup --user="${FLAGS_user}"  --databases="$FLAGS_databases" --target-dir=$TDIR
xtrabackup --prepare --export --target-dir=$TDIR
rm -f $TDIR/ibdata1

IFS=' ' read -ra DATABASES <<< "$FLAGS_databases"
for b in "${DATABASES[@]}"; do
    mysqldump --user="${FLAGS_user}" --no-data --single-transaction --routines $b | sed '/ALTER DATABASE/d' > $TDIR/$b/ddl.sql

    cp $TDIR/xtrabackup_* $TDIR/$b

    FILE=$FLAGS_backupdir/${FLAGS_backupprefix}${b}${FLAGS_backupsuffix}.tar.gz

    rm -f $FILE
    tar -cpvzf $FILE -C $TDIR/$b .
done

rm -rf $TDIR
