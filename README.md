# CommandBox StackChecker

CommandBox Task Runner that allows you to check your local docker compose against your portainer stack file and your .env.example, including publishing your Docker Compose to your Stack

Recently added: the ability to validate secrets required with CommandBox's `<<SECRET:MY_SECRET_VAR>>` format, and ensure the exist for the Service, and in the top level of the Docker Compose, and those secrets are setup in Portainer.

## Assumptions

We assume your local build process follows Ortus conventions with a build folder, and an env folder with a folder named after your environments.

Your docker compose file will be in the following folder:

`build/env/#environment#/docker-compose.yml`

## Overrides

You can now pass in overrides for

- `envExampleFile` - defaults to `.env.example` - you can also pass in a path, which will resolve based on the CWD when running the command.
- `composeFile` - defaults to `docker-compose.yml` - you can also pass in a path, which will resolve based on the CWD when running the command.

## How to call this Task Runner

Run the taskFile from the root of your project, using named params, you can define the location of the task runner, and the target is the function you would like to run.

There are several params needed, depending on the function you are calling.

Calling the checkLocalStack does not require any variables, if you follow conventions and are checking staging. You can pass in environment, or override defaults for `composeFile` and or `envExampleFile`

```
box task run taskfile=build/modules/commandbox-stackChecker/RunStackCheck target=checkLocalStack :environment=staging
```

or to test production's compose file

```
box task run taskfile=build/modules/commandbox-stackChecker/RunStackCheck target=checkLocalStack :environment=production
```

or using customized overrides like

```
box task run taskfile=build/modules/commandbox-stackChecker/RunStackCheck target=checkLocalStack :environment=production :composeFile=build/docker/production/stack.yml
```

Calling remoteStackCheck reaches out to Portainer and requires more variables to authenticate and communicate with Portainer.

```
box task run taskfile=build/modules/commandbox-stackChecker/RunStackCheck target=checkRemoteStack
    :environment=staging
    :stackID=$STG_STACKID
    :portainerUsername=$PORTAINER_USERNAME
    :portainerPassword=$PORTAINER_PASSWORD
    :portainerURL=$STG_PORTAINER_URL
```

### Environment

The environment / tier you're deploying/checking

This defaults to staging. This is used for looking up conventions for where your `docker-compose.yml` file will be located (unless you override that location with a full path). This also is used as the default service name in your `docker-compose.yml` file.

### stackID

This is the portainer assigned id for the stack on the server you're deploying this tier to. We recommend using variables for multiple deployment tiers.

### Portainer Username

The username to connect to portainer with

### Portainer Password

This password to connect to portainer with

### Portainer URL

This is the url for the portainer you are deploying to. For multiple portainer tiers. We recommend using variables for multiple deployment tiers.

## Methods to call

There are 5 methods to call, checkLocalStack, checkLocalSecrets, checkRemoteStack, putStack, and checkRemoteSecrets

We recommend calling them at different phases of your build process for efficiency.

stages:

- tests
- localStackCheck - Run checkLocalStack and checkLocalSecrets
- imageBuild
- remoteStackCheck - Run the checkRemoteStack and checkRemoteSecrets ( and if you need to update the service then run the putStack function but only if checkRemoteSecrets passes first )
- imageDeploy
- imageTest
- artifacts

### checkLocalStack

Run the CheckStack function to verify and validate the Stack file in Portainer vs the Compose file in the repo and the env variables in the .env.example file.

Example of a failed Check

```
Checking for valid Yaml File

Checking Secrets in Compose File are setup in Portainer

Docker Compose is a valid Yaml File


Running DotEnv Check

Checking Secrets in Compose File are setup in Portainer

Checking all ./test1/.env.example variables exist in the local Compose file ./test1/docker-compose.yml
Missing keys detected from .env.stackFile
LDAP_PASSWORD
LDAP_USERNAME
```

### checkLocalSecrets

CheckLocalSecrets function to verify the Compose file in the repo has all of the secrets setup correctly for the service, and top level in the Docker Compose file, including secrets expected by CommandBox's `<<SECRET:MY_SECRET_NAME>>` format.

Example of failed check

```
Checking Secrets in Compose File are setup in Portainer

Service has defined Secret called 'AWS_SECRET_KEY' that does not exist in top level of Compose File
staging Service uses the 'DB_DEVELOPMENT_USER' secret via CommandBox in the Env Variable: DB_USER

staging Service uses the 'DB_DEVELOPMENT_PASSWORD' secret via CommandBox in the Env Variable: DB_PASSWORD

staging Service uses the 'S3_ACCESS_KEY' secret via CommandBox in the Env Variable: S3_ACCESS_KEY

staging Service uses the 'S3_SECRET_KEY' secret via CommandBox in the Env Variable: S3_SECRET_KEY

staging Service uses the 'JWT_SECRET' secret via CommandBox in the Env Variable: JWT_SECRET

staging Service uses the 'SENDGRID_API_KEY' secret via CommandBox in the Env Variable: SENDGRID_API_KEY

staging Service uses the 'API_CLIENT_TOKEN' secret via CommandBox in the Env Variable: CLIENT_TOKEN

staging Service uses the 'AWS_KEY' secret via CommandBox in the Env Variable: AWS_KEY
Docker Compose staging Service is referencing a Secret via CommandBox called 'AWS_KEY' that is missing from the Service Level Secrets

staging Service uses the 'AWS_SECRET_KEY' secret via CommandBox in the Env Variable: AWS_SECRET_KEY
Docker Compose staging Service is referencing a Secret via CommandBox called 'AWS_SECRET_KEY' that is missing from the top level Secrets
```

### checkRemoteStack

CheckRemoteStack function tries to verify and validate the Stack file in Portainer vs the Compose file in the repo and the env variables in the .env.example file.

### putStack

Run the putStack function to update Stack file in Portainer with the Compose file in the repo. This auto updates the service.

### checkRemoteSecrets

Verify and validate the list of Secrets setup in Portainer vs the Compose file in the repo.

Example output of a failing check

```
Getting Endpoint ID

Getting stack Details from Portainer

Authenticating with Portainer

Checking Secrets in Compose File are setup in Portainer

Docker Compose has a secret defined called 'JWT_SECRET' that does not exist in Portainer
Docker Compose has a secret defined called 'S3_ACCESS_KEY' that does not exist in Portainer
Docker Compose has a secret defined called 'API_CLIENT_TOKEN' that does not exist in Portainer
Docker Compose has a secret defined called 'S3_SECRET_KEY' that does not exist in Portainer
Docker Compose has a secret defined called 'AWS_KEY' that does not exist in Portainer
```

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
    - cd build && box install commandbox-stackChecker@2
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
