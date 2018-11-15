#!/bin/bash

RETRY=true
JOB_NUM=$CIRCLE_PREVIOUS_BUILD_NUM

while [[ $(echo $RETRY) == true ]]
do
  if [[ $(curl https://circleci.com/api/v1.1/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$JOB_NUM | grep '"retry_of" : null') ]]; then
  	RETRY=false
  else
  	echo "$JOB_NUM was a retry of a previous job"
    JOB_NUM=$(( $JOB_NUM - 1 ))
  fi
done

LAST_PUSHED_COMMIT=$(curl https://circleci.com/api/v1.1/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$JOB_NUM | grep '"commit" : ' | sed -E 's/"commit" ://' | sed -E 's/[[:punct:]]//g')

echo "last pushed commit hash is:" $LAST_PUSHED_COMMIT
echo "this job's commit hash is:" $CIRCLE_SHA1
echo "recreated CIRCLE_COMPARE_URL: https://github.com/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/compare/${LAST_PUSHED_COMMIT:0:12}...${CIRCLE_SHA1:0:12}"