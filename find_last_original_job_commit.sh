#!/bin/bash

RETRY=true
JOB_NUM=$CIRCLE_PREVIOUS_BUILD_NUM

while [ echo $RETRY ]
do
  JOB_OUTPUT=$(curl https://circleci.com/api/v1.1/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_JOB/$JOB_NUM)

  if [[ echo $JOB_OUTPUT | grep '"retry_of" : null' ]]; then
  	RETRY=false
  else
    JOB_NUM=$(( $JOB_NUM - 1 ))
  fi
done

LAST_PUSHED_COMMIT=$(curl https://circleci.com/api/v1.1/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_JOB/$JOB_NUM | grep '"commit" : ' | sed -E 's/"commit" ://' | sed -E 's/[[:punct:]]//g')