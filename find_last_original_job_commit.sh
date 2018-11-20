# <<parameters.circle-token>> => $CIRCLE_TOKEN

#!/bin/bash

# this starts as false, set to true to exit `until` loop
FOUND_BASE_COMPARE_COMMIT=false

# start iteration from the job before $CIRCLE_BUILD_NUM
JOB_NUM=$(( $CIRCLE_BUILD_NUM - 1 ))

# abstract this logic out, it gets reused a few times
extract_commit_from_job () {
  # takes $1 (VCS_TYPE) & $2 (a job number)

  curl --user $CIRCLE_TOKEN: \
  https://circleci.com/api/v1.1/project/$1/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$2 | \
  grep '"vcs_revision" : ' | sed -E 's/"vcs_revision" ://' | sed -E 's/[[:punct:]]//g' | sed -E 's/ //g'
}


check_if_branch_is_new () {
  # takes a single argument for VCS_TYPE

  # functionally, this means: same commit for all jobs on the branch

  # assume this is true, set to false if proven otherwise
  local BRANCH_IS_NEW=true

  # grab URL endpoints for jobs on this branch
  # transform them into single-job API endpoints
  # output them to a file for subsequent iteration
  curl --user $CIRCLE_TOKEN: https://circleci.com/api/v1.1/project/$1/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/tree/$CIRCLE_BRANCH | grep "build_url" | sed -E 's/"build_url" : //' | sed -E 's|/bb/|/api/v1.1/project/bitbucket/|' | sed -E 's|/gh/|/api/v1.1/project/github/|' | sed -E 's/"|,//g' | sed -E 's/ //g' > API_ENDPOINTS_FOR_JOBS_ON_BRANCH

  # loop through each job to compare commit hashes
  while read line
  do
    if [[ $(curl --user $CIRCLE_TOKEN: $line | grep "\"vcs_revision\" : \"$CIRCLE_SHA1\"") ]]; then
      continue
    else
      BRANCH_IS_NEW=false
      break
    fi
  done < API_ENDPOINTS_FOR_JOBS_ON_BRANCH

  rm -f API_ENDPOINTS_FOR_JOBS_ON_BRANCH

  echo $BRANCH_IS_NEW
}

# figure this out up top, so we don't worry about it later
if [[ $(echo $CIRCLE_REPOSITORY_URL | grep github.com:$CIRCLE_PROJECT_USERNAME) ]]; then
  VCS_TYPE=github
else
  VCS_TYPE=bitbucket
fi

# manually iterate downard through previous jobs
until [[ $(echo $FOUND_BASE_COMPARE_COMMIT) == true ]]
do

  # save circle api output to a temp file for reuse
  curl --user $CIRCLE_TOKEN: \
    https://circleci.com/api/v1.1/project/$VCS_TYPE/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$JOB_NUM \
    > JOB_OUTPUT

  # general approach:
  # there's a couple of skip conditions to observe here—
  # roughly in order of precedence:

  # 1. is JOB_NUM part of the current workflow?
  # 2. is JOB_NUM a retry of a job from the same commit?
    # 2.5 or part of a rerun workflow from the same commit?
  # 3. is JOB_NUM from a different branch?
    # 3.5 unless this is a new branch—see below

  # edge cases:
  # 1. if $CIRCLE_SHA1 is the first commit on a new branch
    # then we need the most recent ancestor, branch-agnostic

  # skip conditions 1 & 2/2.5:
  if [[ $(grep "\"workflow_id\" : \"$CIRCLE_WORKFLOW_ID\"" JOB_OUTPUT) || \
    ! $(grep '"retry_of" : null' JOB_OUTPUT) || \
    $(grep "\"vcs_revision\" : \"$CIRCLE_SHA1\"" JOB_OUTPUT) ]]; then
    echo "$JOB_NUM was a retry of a previous job, part of a rerun workflow, or else part of the current workflow"
    JOB_NUM=$(( $JOB_NUM - 1 ))
    continue
  fi

  # handling condition 3 & edge case 1:
  # check if this is a brand-new branch
  if [[ $(check_if_branch_is_new $VCS_TYPE) == true ]]; then
    echo "$CIRCLE_SHA1 is the first commit on branch $CIRCLE_BRANCH"

    COMMIT_FROM_JOB_NUM=$(extract_commit_from_job $VCS_TYPE $JOB_NUM)

    cd ~/project # <<parameters.project-path>>

    # check if commit from JOB_NUM is an ancestor of $CIRCLE_SHA1
    git merge-base --is-ancestor $COMMIT_FROM_JOB_NUM $CIRCLE_SHA1; RETURN_CODE=$?

    if [[ $RETURN_CODE == 1 ]]; then
      echo "commit $COMMIT_FROM_JOB_NUM from $JOB_NUM is not an ancestor of the current commit"
      JOB_NUM=$(( $JOB_NUM - 1 ))
      continue
    elif [[ $RETURN_CODE == 0 ]]; then
      FOUND_BASE_COMPARE_COMMIT=true
    else
      echo "unknown return code $RETURN_CODE from git merge-base with base commit $COMMIT_FROM_JOB_NUM, from job $JOB_NUM"
    fi
  else
    # if not a new branch, find its most recent previous commit
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

BASE_COMPARE_COMMIT=$(extract_commit_from_job $VCS_TYPE $JOB_NUM)

# construct our compare URL, based on VCS type
if [[ $(echo $VCS_TYPE | grep github) ]]; then
  CIRCLE_COMPARE_URL="https://github.com/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/compare/${BASE_COMPARE_COMMIT:0:12}...${CIRCLE_SHA1:0:12}"
else
  CIRCLE_COMPARE_URL="https://bitbucket.org/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/branches/compare/${BASE_COMPARE_COMMIT:0:12}...${CIRCLE_SHA1:0:12}"
fi

echo "base compare commit hash is:" $BASE_COMPARE_COMMIT

echo "- - - - - - - - - - - - - - - - - - - - - - - -"

echo "this job's commit hash is:" $CIRCLE_SHA1

echo "- - - - - - - - - - - - - - - - - - - - - - - -"

echo "recreated CIRCLE_COMPARE_URL:" $CIRCLE_COMPARE_URL

echo "- - - - - - - - - - - - - - - - - - - - - - - -"

echo "outputting CIRCLE_COMPARE_URL to a file in your working directory, called CIRCLE_COMPARE_URL.txt"

echo $CIRCLE_COMPARE_URL > CIRCLE_COMPARE_URL.txt
