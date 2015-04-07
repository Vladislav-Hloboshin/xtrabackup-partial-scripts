BASEDIR=$(dirname $0)
SHFLAGS_LIB_PATH=$BASEDIR/lib/shflags

source ${SHFLAGS_LIB_PATH}
if [[ $? -ne 0 ]]; then
    echo "Unable to source shFlags library: ${SHFLAGS_LIB_PATH}"
    exit 1
fi

# FLAGS
DEFINE_string 'file'		''			''	'f'	'required'
DEFINE_string 'database'	''			''	'db'	'required'
DEFINE_string 'datadir'		'/var/lib/mysql'	''	'dd'
DEFINE_string 'user'		'xtrabackup'		''	'u'

# parse the command-line
FLAGS "$@" || exit 1
eval set -- "${FLAGS_ARGV}"

mysql -u"${FLAGS_user}" --execute "drop database if exists ${FLAGS_database};" 2> /dev/null
mysql -u"${FLAGS_user}" --execute "drop database if exists ${FLAGS_database}; create database ${FLAGS_database};" || exit 1

TDIR=`mktemp -d`
trap "{ cd - ; rm -rf $TDIR; exit 255; }" SIGINT

cd $TDIR
tar -xvzpf ${FLAGS_file}

mysql -u"${FLAGS_user}" ${FLAGS_database} < ddl.sql
for FILE in *.cfg; do
  TABLE="$(basename "${FILE}" .cfg)"

  # Reset ownership and permissions on our
  # backup files to be what MySQL expects.
  chmod --reference="${FLAGS_datadir}/${FLAGS_database}/$TABLE.ibd" "$TABLE.cfg" "$TABLE.ibd"
  chown --reference="${FLAGS_datadir}/${FLAGS_database}/$TABLE.ibd" "$TABLE.cfg" "$TABLE.ibd"

  # Instruct MySQL to discard the target tablespace.
  echo "discard tablespace for $TABLE"
  mysql -u"${FLAGS_user}" --database=$FLAGS_database --execute "set FOREIGN_KEY_CHECKS=0; alter table $TABLE discard tablespace;"

  # Overwrite the target tablespace with our backup.
  mv -f "$TABLE.cfg" "${FLAGS_datadir}/${FLAGS_database}/$TABLE.cfg"
  mv -f "$TABLE.ibd" "${FLAGS_datadir}/${FLAGS_database}/$TABLE.ibd"

  # Instruct MySQL to import the target tablespace.
  echo "import tablespace for $TABLE"
  mysql -u"${FLAGS_user}" --database=$FLAGS_database --execute "alter table $TABLE import tablespace;"

  # Instruct MySQL to analyze the resulting table and update
  # its table statistics.
  echo "analyze table $TABLE"
  mysql -u"${FLAGS_user}" --database=$FLAGS_database --execute "analyze table $TABLE;"
done

rm -rf $TDIR
