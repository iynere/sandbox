#!/bin/bash

RETRY=true
JOB_NUM=$(( $CIRCLE_BUILD_NUM - 1 ))

if [[ $(echo $CIRCLE_REPOSITORY_URL | grep github.com:$CIRCLE_PROJECT_USERNAME) ]]; then
  VCS=github
fi

if [[ $(echo $CIRCLE_REPOSITORY_URL | grep bitbucket.org:$CIRCLE_PROJECT_USERNAME) ]]; then
  VCS=bitbucket
fi

while [[ $(echo $RETRY) == true ]]
do
  curl --user <<parameters.circle-token>>: \
    https://circleci.com/api/v1.1/project/$VCS/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$JOB_NUM \
    > JOB_OUTPUT

  if [[ $(grep '"retry_of" : null' JOB_OUTPUT) && \
    # ignore jobs that were SSH reruns of previous jobs
    ! $(grep "\"workflow_id\" : \"$CIRCLE_WORKFLOW_ID\"" JOB_OUTPUT) && \
    # ignore jobs that are part of the same workflow
    ! $(grep "\"commit\" : \"$CIRCLE_SHA1\"" JOB_OUTPUT) && \
    # ignore jobs that share the same commit
    $(grep "\"branch\" : \"$CIRCLE_BRANCH\"" JOB_OUTPUT) ]]; then
    # make sure we filter out results from other branches

    RETRY=false
  else
    echo "$JOB_NUM was a retry of a previous job, part of a rerun workflow, or else part of the current workflow"
    # deincrement job num by 1 & try again
    JOB_NUM=$(( $JOB_NUM - 1 ))
  fi
done

rm -f JOB_OUTPUT

LAST_PUSHED_COMMIT=$(curl --user <<parameters.circle-token>>: \
  https://circleci.com/api/v1.1/project/$VCS/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$JOB_NUM | \
  grep '"commit" : ' | sed -E 's/"commit" ://' | sed -E 's/[[:punct:]]//g' | sed -E 's/ //g')

if [[ $(echo $VCS | grep github) ]]; then
  CIRCLE_COMPARE_URL="https://github.com/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/compare/${LAST_PUSHED_COMMIT:0:12}...${CIRCLE_SHA1:0:12}"
fi

if [[ $(echo $VCS | grep bitbucket) ]]; then
  CIRCLE_COMPARE_URL="https://bitbucket.org/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/branches/compare/${LAST_PUSHED_COMMIT:0:12}...${CIRCLE_SHA1:0:12}"
fi

echo "last pushed commit hash is:" $LAST_PUSHED_COMMIT

echo "- - - - - - - - - - - - - - - - - - - - - - - -"

echo "this job's commit hash is:" $CIRCLE_SHA1

echo "- - - - - - - - - - - - - - - - - - - - - - - -"

echo "recreated CIRCLE_COMPARE_URL:" $CIRCLE_COMPARE_URL

echo "- - - - - - - - - - - - - - - - - - - - - - - -"

echo "outputting CIRCLE_COMPARE_URL to a file in your working directory, called CIRCLE_COMPARE_URL.txt"

echo $CIRCLE_COMPARE_URL > CIRCLE_COMPARE_URL.txt