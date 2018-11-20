#!/bin/bash

FOUND_BASE_COMPARE_COMMIT=false
JOB_NUM=$(( $CIRCLE_BUILD_NUM - 1 ))

# <<parameters.circle-token>> => $CIRCLE_TOKEN

extract_commit_from_job () {
  curl --user $CIRCLE_TOKEN: \
  https://circleci.com/api/v1.1/project/$1/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$2 | \
  grep '"vcs_revision" : ' | sed -E 's/"vcs_revision" ://' | sed -E 's/[[:punct:]]//g' | sed -E 's/ //g'
}

if [[ $(echo $CIRCLE_REPOSITORY_URL | grep github.com:$CIRCLE_PROJECT_USERNAME) ]]; then
  VCS_TYPE=github
else
  VCS_TYPE=bitbucket
fi

until [[ $(echo $FOUND_BASE_COMPARE_COMMIT) == true ]]
do

  # save circle api output to a temp file
  # avoids additional api calls

  curl --user $CIRCLE_TOKEN: \
    https://circleci.com/api/v1.1/project/$VCS_TYPE/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$JOB_NUM \
    > JOB_OUTPUT

  # there's a couple of skip conditions to observe here—
  # roughly in order of precedence:

  # 1. is JOB_NUM part of the current workflow?
  # 2. is JOB_NUM a retry of a job from the same commit?
    # 2.5 or part of a rerun workflow from the same commit?
  # 3. is JOB_NUM from a different branch?

  # edge cases:
  # 1. $CIRCLE_SHA1 is the first commit on a new branch
    # then, we need the nearest ancestor, branch-agnostic

  # skip conditions 1 & 2:
  if [[ $(grep "\"workflow_id\" : \"$CIRCLE_WORKFLOW_ID\"" JOB_OUTPUT) || \
    ! $(grep '"retry_of" : null' JOB_OUTPUT) || \
    $(grep "\"vcs_revision\" : \"$CIRCLE_SHA1\"" JOB_OUTPUT) ]]; then
    echo "$JOB_NUM was a retry of a previous job, part of a rerun workflow, or else part of the current workflow"
    JOB_NUM=$(( $JOB_NUM - 1 ))
    continue
  fi

  # handling condition 3 & edge case 1:
  # if it's the first commit on its branch
  if [[ $(curl --user $CIRCLE_TOKEN: \
    https://circleci.com/api/v1.1/project/$VCS_TYPE/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$CIRCLE_BUILD_NUM | grep '"previous" : null') ]]; then
    echo "$CIRCLE_SHA1 is the first commit on branch $CIRCLE_BRANCH"

    COMMIT_FROM_JOB_NUM=$(extract_commit_from_job $VCS_TYPE $JOB_NUM)

    cd ~/project

    git merge-base --is-ancestor $COMMIT_FROM_JOB_NUM $CIRCLE_SHA1; RETURN_CODE=$?

    if [[ RETURN_CODE == 1 ]]; then
      echo "commit $COMMIT_FROM_JOB_NUM from $JOB_NUM is not an ancestor of the current commit"
      JOB_NUM=$(( $JOB_NUM - 1 ))
      continue
    elif [[ RETURN_CODE == 0 ]]; then
      FOUND_BASE_COMPARE_COMMIT=true
    else
      echo "unknown return code $RETURN_CODE from git merge-base with base commit $COMMIT_FROM_JOB_NUM, from job $JOB_NUM"
    fi
  else
    # find previous commit from this branch
    if [[ $(grep "\"branch\" : \"$CIRCLE_BRANCH\"" JOB_OUTPUT) ]]; then
      FOUND_BASE_COMPARE_COMMIT=true
    else
      echo "$JOB_NUM was not on branch $CIRCLE_BRANCH"
      JOB_NUM=$(( $JOB_NUM - 1 ))
      continue
    fi
  fi
done

rm -f JOB_OUTPUT

LAST_PUSHED_COMMIT=$(extract_commit_from_job $VCS_TYPE $JOB_NUM)

if [[ $(echo $VCS_TYPE | grep github) ]]; then
  CIRCLE_COMPARE_URL="https://github.com/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/compare/${LAST_PUSHED_COMMIT:0:12}...${CIRCLE_SHA1:0:12}"
else
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
