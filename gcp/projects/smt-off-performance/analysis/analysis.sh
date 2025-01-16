#!/usr/bin/env bash
set -e  

EXIT_SCRIPTERROR=1

# See https://stackoverflow.com/a/246128
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

PROJECT="cbpetersen-shared"
GCS_BUCKET="cbpetersen-smtoff"

POSITIONAL_ARGS=()
TIMESTAMP=

printHelp()
{
  echo "Usage: $0 TIMESTAMP "
  echo ""
  echo "Parameters can also be set using environmental variables:"
  echo "  TIMESTAMP"
  echo ""
}

download_gcs() {
  # Download data from GCS
  gcs_bucket_uri="gs://$GCS_BUCKET/data/$TIMESTAMP"
  gcloud storage cp $gcs_bucket_uri/\*.db $SCRIPT_DIR --quiet
  gcloud storage cp $gcs_bucket_uri/\*.csv $SCRIPT_DIR --quiet

  # Fix file names for HammerDB files
  files=`find $SCRIPT_DIR -name hammer-\*.db`
  for file in $files; do
    newFile=`echo $file | sed 's/hammer-/hammer_/'`
    mv $file $newFile
  done

  # Fix file names for perfcounter files
  files=`find $SCRIPT_DIR -name perfcounter-\*.csv`
  for file in $files; do
    newFile=`echo $file | sed 's/perfcounter-/perfcounter_/'`
    mv $file $newFile
  done
}

write_hammerdb() {
  previousSkus=()

  databases=`ls -S1 $SCRIPT_DIR/*.db| tac`
  for database in $databases; do
    sku=`basename $database .db | sed 's/hammer_//'`

    fileJobs="$SCRIPT_DIR/jobs_$sku.csv"
    fileCounters="$SCRIPT_DIR/counters_$sku.csv"

    sqlite3 -header -csv $database < jobs.sql > $fileJobs
    sqlite3 -header -csv $database < counters.sql > $fileCounters

    # Workaround for missing HammerDB file cleanup
    if [ ${#previousSkus[@]} -gt 0 ]; then
      # Remove previous files content from this file
      for previousSku in "${previousSkus[@]}"; do
        fileJobsPrevious="$SCRIPT_DIR/jobs_$previousSku.csv"
        fileCountersPrevious="$SCRIPT_DIR/counters_$previousSku.csv"

        ruby -e "puts File.readlines('$fileJobs') - File.readlines('$fileJobsPrevious')" > $fileJobs.temp
        ruby -e "puts File.readlines('$fileCounters') - File.readlines('$fileCountersPrevious')" > $fileCounters.temp

        # Rename temp files
        mv $fileJobs.temp $fileJobs
        mv $fileCounters.temp $fileCounters

        # Add headers
        sed -i '1s/^/jobid,timestamp,users,nopm,tpm\n/' $fileJobs
        sed -i '1s/^/jobid,counter,timestamp\n/' $fileCounters
      done
    fi

    previousSkus+=($sku)
  done
}

add_file_meta() {
  file=$1
  sku=$2
  run=$3
  quotes=$4

  if [ "$quotes" == "" ]; then
    quotes=false
  fi

  headers=`head -n 1 $file`

  if [ "$quotes" = "true" ]; then
    headers="\"sku\",\"run\",$headers"
    sku="\"$sku\""
    run="\"$run\""
  else
    headers="sku,run,$headers"
  fi

  # Prepend SKU
  awk '{print sku","run"," $0}' sku="$sku" run=$run $file >> $file.temp

  # Write headers
  echo "$headers" > $file

  # Write contents (but skip header)
  tail -n +2 $file.temp >> $file

  # Remove temp file
  rm $file.temp
}

import_bigquery() {
  # Import files to Big Query
  files=`ls -S1 $SCRIPT_DIR/*.csv | tac`
  for file in $files; do
    base=`basename $file .csv`
    sku=`echo $base | sed 's/.*_\(.*\)/\1/'`
    table=`echo $base | sed 's/\(.*\)_.*/\1/' | sed 's/perfcounter/perfcounters/'`

    quotes=false
    if [ "$table" == "perfcounters" ]; then
      quotes=true
    fi

    add_file_meta "$file" "$sku" "$TIMESTAMP" $quotes

    # Set format to coerce "run" to string
    case $table in
      counters)
        format="sku:STRING,run:STRING,jobid:STRING,timestamp:TIMESTAMP,counter:INTEGER"
        ;;
      jobs)
        format="sku:STRING,run:STRING,jobid:STRING,timestamp:TIMESTAMP,users:INTEGER,nopm:INTEGER,tpm:INTEGER"
        ;;
      perfcounters)
        format="sku:STRING,run:STRING,users:INTEGER,timestamp:TIMESTAMP,path:STRING,value:FLOAT"
        ;;
    esac

    bq load \
      --project_id $PROJECT \
      --headless \
      --source_format=CSV \
      --field_delimiter ',' \
      --skip_leading_rows 1 \
      smtoff.$table \
      $file \
      $format
  done
}

run_bigquery() {
  bq query \
    --project_id $PROJECT \
    --use_legacy_sql=false \
    --headless < bigquery.sql 1> /dev/null
}

remove_files() {
  rm $SCRIPT_DIR/*.db
  rm $SCRIPT_DIR/*.csv
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --)
      shift;
      break
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit $EXIT_SCRIPTERROR
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

# Check if we have enough positional arguments
if [ ${#POSITIONAL_ARGS[@]} -ne 1 ]; then
  printHelp
  exit $EXIT_SCRIPTERROR
else
  TIMESTAMP="${POSITIONAL_ARGS[0]}"
fi

if [[ -z "$TIMESTAMP" ]]; then
  printHelp
  exit $EXIT_SCRIPTERROR
fi

download_gcs
write_hammerdb
import_bigquery
run_bigquery
remove_files
