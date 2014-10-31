# source shflags
. ./lib/shflags

# FLAGS
DEFINE_string 'databases'		''			'' 'd'	'required'
DEFINE_string 'file'			''			'' 'f'	'required'

# parse the command-line
FLAGS "$@" || exit 1
eval set -- "${FLAGS_ARGV}"

TDIR=`mktemp -d`
trap "{ cd - ; rm -rf $TDIR; exit 255; }" SIGINT

xtrabackup --backup  --databases="${FLAGS_databases}" --target-dir=${TDIR}

cd $TDIR
for DATABASE in *; do
  if [ ! -d "$DATABASE" ]; then
    continue
  fi

  DATABASE_DECODED="$(
    echo "$DATABASE" |
    perl -ne 's/@([0-9a-f]{4})/chr(hex "0x${1}")/ge; print;'
  )"

  mysqldump --no-data --single-transaction \
    "$DATABASE_DECODED" >"$DATABASE.ddl.sql"
done
cd -

xtrabackup --prepare --export --target-dir=$TDIR

rm -f ${FLAGS_file}
tar -cpvzf ${FLAGS_file} -C $TDIR .
rm -rf $TDIR
