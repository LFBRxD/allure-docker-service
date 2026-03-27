#!/bin/bash

EXEC_STORE_RESULTS_PROCESS=$1
PROJECT_ID=$2

# USED FROM API
ORIGIN=$3
EXECUTION_NAME=$4
EXECUTION_FROM=$5
EXECUTION_TYPE=$6

PROJECT_REPORTS=$STATIC_CONTENT_PROJECTS/$PROJECT_ID/reports
if [ "$(ls $PROJECT_REPORTS | wc -l)" != "0" ]; then
    if [ -e "$PROJECT_REPORTS/latest" ]; then
        LAST_REPORT_PATH_DIRECTORY=$(ls -td $PROJECT_REPORTS/* | grep -wv $PROJECT_REPORTS/latest | grep -v $EMAILABLE_REPORT_FILE_NAME | head -1)
    else
        LAST_REPORT_PATH_DIRECTORY=$(ls -td $PROJECT_REPORTS/* | grep -v $EMAILABLE_REPORT_FILE_NAME | head -1)
    fi
fi

LAST_REPORT_DIRECTORY=$(basename -- "$LAST_REPORT_PATH_DIRECTORY")
#echo "LAST REPORT DIRECTORY >> $LAST_REPORT_DIRECTORY"

RESULTS_DIRECTORY=$STATIC_CONTENT_PROJECTS/$PROJECT_ID/results
PROJECT_ROOT=$STATIC_CONTENT_PROJECTS/$PROJECT_ID
ALLURE_CONFIG_FILE=$PROJECT_ROOT/allurerc.json
ALLURE3_HISTORY_FILE=$PROJECT_ROOT/history.jsonl
if [ ! -d "$RESULTS_DIRECTORY" ]; then
    echo "Creating results directory for PROJECT_ID: $PROJECT_ID"
    mkdir -p $RESULTS_DIRECTORY
fi

EXECUTOR_PATH=$RESULTS_DIRECTORY/$EXECUTOR_FILENAME

echo "Creating $EXECUTOR_FILENAME for PROJECT_ID: $PROJECT_ID"
if [[ "$LAST_REPORT_DIRECTORY" != "latest" ]]; then
    BUILD_ORDER=$(($LAST_REPORT_DIRECTORY + 1))

    if [ -z "$EXECUTION_NAME" ]; then
        EXECUTION_NAME='Automatic Execution'
    fi

    if [ -z "$EXECUTION_TYPE" ]; then
        EXECUTION_TYPE='another'
    fi

EXECUTOR_JSON=$(cat <<EOF
{
    "reportName": "$PROJECT_ID",
    "buildName": "$PROJECT_ID #$BUILD_ORDER",
    "buildOrder": "$BUILD_ORDER",
    "name": "$EXECUTION_NAME",
    "reportUrl": "../$BUILD_ORDER/index.html",
    "buildUrl": "$EXECUTION_FROM",
    "type": "$EXECUTION_TYPE"
}
EOF
)
    if [[ "$EXEC_STORE_RESULTS_PROCESS" == "1" ]]; then
        echo $EXECUTOR_JSON > $EXECUTOR_PATH
    else
        # Allure 3 parses every *.json under results; an empty file breaks generate.
        rm -f "$EXECUTOR_PATH"
    fi
else
    rm -f "$EXECUTOR_PATH"
fi

echo "Generating report for PROJECT_ID: $PROJECT_ID"
REPORT_OUTPUT=$STATIC_CONTENT_PROJECTS/$PROJECT_ID/reports/latest
rm -rf "$REPORT_OUTPUT"
mkdir -p "$REPORT_OUTPUT"
# Allure 3: results path must be the real directory (symlink .../results -> /app/allure-results).
RESULTS_REAL=$(cd "$RESULTS_DIRECTORY" && pwd -P)
# Allure Report 3: persist trends in a JSONL per project.
cat > "$ALLURE_CONFIG_FILE" <<EOF
{
  "historyPath": "$ALLURE3_HISTORY_FILE"
}
EOF
# Default: Allure Awesome single HTML (Allure Report 3). Set ALLURE_REPORT_ENGINE=generate for classic multi-file tree.
ALLURE_REPORT_ENGINE="${ALLURE_REPORT_ENGINE:-awesome}"
if [ "$ALLURE_REPORT_ENGINE" = "generate" ]; then
    (
      cd "$PROJECT_ROOT" || exit 1
      allure generate "$RESULTS_REAL" --output "$REPORT_OUTPUT"
    )
else
    (
      cd "$PROJECT_ROOT" || exit 1
      allure awesome "$RESULTS_REAL" --output "$REPORT_OUTPUT" --single-file
    )
fi
if [ "$OPTIMIZE_STORAGE" == "1" ] ; then
    if [ -f "$ALLURE_RESOURCES/app.js" ]; then
        ln -sf "$ALLURE_RESOURCES/app.js" "$REPORT_OUTPUT/app.js"
    fi
    if [ -f "$ALLURE_RESOURCES/styles.css" ]; then
        ln -sf "$ALLURE_RESOURCES/styles.css" "$REPORT_OUTPUT/styles.css"
    fi
fi

if [ "$KEEP_HISTORY" == "TRUE" ] || [ "$KEEP_HISTORY" == "true" ] || [ "$KEEP_HISTORY" == "1" ] ; then
    if [[ "$EXEC_STORE_RESULTS_PROCESS" == "1" ]]; then
        $ROOT/storeAllureReport.sh $PROJECT_ID $BUILD_ORDER
    fi
fi

$ROOT/keepAllureLatestHistory.sh $PROJECT_ID
