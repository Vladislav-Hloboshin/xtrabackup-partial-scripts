# source shflags
. ../src/shflags

# define a 'name' command-line string flag
DEFINE_string 'databases'			''					'' 'd'	'required'
DEFINE_string 'backup-directory'	''					'' 'bd'	'required'
DEFINE_string 'ibbackup'			'xtrabackup_55'		'' 'i'
DEFINE_string 'defaults-file'		'/etc/mysql/my.cnf' '' 'df'

# parse the command-line
FLAGS "$@" || exit 1
eval set -- "${FLAGS_ARGV}"


innobackupex --ibbackup=${FLAGS_ibbackup} --databases="${FLAGS_databases}" --defaults-file=${FLAGS_defaults_file} ${FLAGS_backup_directory} --no-timestamp

cd ${FLAGS_backup_directory}
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

innobackupex --apply-log --export ${FLAGS_backup_directory}