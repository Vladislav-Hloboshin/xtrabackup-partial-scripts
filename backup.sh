SHFLAGS_LIB_PATH=./lib/shflags

source ${SHFLAGS_LIB_PATH}
if [[ $? -ne 0 ]]; then
    echo "Unable to source shFlags library: ${SHFLAGS_LIB_PATH}"
fi

# FLAGS
DEFINE_string 'databases'	''			''	'db'	'required'
DEFINE_string 'file'		''			''	'f'	'required'
DEFINE_string 'user'            'xtrabackup'            ''      'u'

# parse the command-line
FLAGS "$@" || exit 1
eval set -- "${FLAGS_ARGV}"

TDIR=`mktemp -d`
trap "{ cd - ; rm -rf $TDIR; exit 255; }" SIGINT

xtrabackup --backup --user="${FLAGS_user}"  --databases="${FLAGS_databases}" --target-dir=${TDIR}

cd $TDIR
for DATABASE in *; do
  if [ ! -d "$DATABASE" ]; then
    continue
  fi

  DATABASE_DECODED="$(
    echo "$DATABASE" |
    perl -ne 's/@([0-9a-f]{4})/chr(hex "0x${1}")/ge; print;'
  )"

  mysqldump --no-data --single-transaction --routines "$DATABASE_DECODED" >"$DATABASE.ddl.sql"
done
cd -

xtrabackup --prepare --export --target-dir=$TDIR

rm -f ${FLAGS_file}
tar -cpvzf ${FLAGS_file} -C $TDIR .
rm -rf $TDIR
