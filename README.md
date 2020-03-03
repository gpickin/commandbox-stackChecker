# CommandBox StackChecker

CommandBox Task Runner that allows you to check your local docker compose against your portainer stack file and your .env.example, including publishing your Docker Compose to your Stack

## Assumptions

We assume your local build process follows Ortus conventions with a build folder, and an env folder with a folder named after your environments. 

Your docker compose file will be in the following folder: 

`build/env/#environment#/docker-compose.yml`

## How to call this Task Runner

Run the taskFile from the root of your project, using named params, you can define the location of the task runner, and the target is the function you would like to run. 

There are several params needed. 

```
box task run taskfile=build/modules/commandbox-stackChecker/RunStackCheck target=checkLocalStack 
    :environment=staging 
    :stackID=$STG_STACKID 
    :portainerUsername=$PORTAINER_USERNAME 
    :portainerPassword=$PORTAINER_PASSWORD 
    :portainerURL=$STG_PORTAINER_URL
```


### Environment

The environment / tier you're deploying/checking

### stackID 

This is the portainer assigned id for the stack on the server you're deploying this tier to. We recommend using variables for multiple deployment tiers.

### Portainer Username

The username to connect to portainer with

### Portainer Password

This password to connect to portainer with

### Portainer URL

This is the url for the portainer you are deploying to. For multiple tiers. We recommend using variables for multiple deployment tiers. 

## Methods to call

There are 3 methods to call, RunLocalCheck, checkRemoteStack and putStack.
We recommend calling them at different phases of your build process for efficiency.

stages:
  - tests
  - localStackCheck - Run the RunLocalCheck
  - imageBuild
  - remoteStackCheck - Run the checkRemoteStack ( and if you need to update the service then run the putStack function)
  - imageDeploy
  - imageTest
  - artifacts

### RunLocalCheck

Run the CheckStack function to verify and validate the Stack file in Portainer vs the Compose file in the repo and the env variables in the .env.example file.

### checkRemoteStack

Run the CheckStack function to verify and validate the Stack file in Portainer vs the Compose file in the repo and the env variables in the .env.example file.

### putStack

Run the putStack function to update Stack file in Portainer with the Compose file in the repo. This auto updates the service.

## Example Yml

Here is an example of usage within a gitlab-ci.yml build process

```
####### CHECK STAGING STACK FILE #########
checkLocalStackFile_stg:
  image: ortussolutions/commandbox
  stage: localStackCheck
  only:
    - development
  script:
    - cd build && box install commandbox-stackChecker
    - cd ../
    - box task run taskfile=build/modules/commandbox-stackChecker/RunStackCheck target=checkLocalStack :environment=staging :stackID=$STG_STACKID :portainerUsername=$PORTAINER_USERNAME :portainerPassword=$PORTAINER_PASSWORD :portainerURL=$STG_PORTAINER_URL

####### CHECK STAGING STACK FILE #########
checkRemoteStackFile_stg:
  image: hac-registry.revagency.net/hq/andale:commandbox
  stage: remoteStackCheck
  only:
    - development
  script:
    - cd build && box install commandbox-stackChecker
    - cd ../
    - box task run taskfile=build/modules/commandbox-stackChecker/RunStackCheck target=checkRemoteStack :environment=staging :stackID=$STG_STACKID :portainerUsername=$PORTAINER_USERNAME :portainerPassword=$PORTAINER_PASSWORD :portainerURL=$STG_PORTAINER_URL

####### DEPLOY STACK FILE TO STG #########
deployStackFile_stg:
  image: hac-registry.revagency.net/hq/andale:commandbox
  stage: remoteStackCheck
  only:
    - development
  when: manual
  script:
    - cd build && box install commandbox-stackChecker
    - cd ../
    - box task run taskfile=build/modules/commandbox-stackChecker/RunStackCheck target=putStack :environment=staging :stackID=$STG_STACKID :portainerUsername=$PORTAINER_USERNAME :portainerPassword=$PORTAINER_PASSWORD :portainerURL=$STG_PORTAINER_URL
```