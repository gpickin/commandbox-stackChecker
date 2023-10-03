component {

    property name="environment";
    property name="stackID";
    property name="portainerUsername";
    property name="portainerPassword";
    property name="portainerURL";
    property name="composeFile";
    property name="composePath";
    property name="serviceName";
    property name="envExampleFile";
    property name="jwt" default="";

    /**
     * Verify and validate the Stack file in Portainer vs the Compose file in the repo and the env variables in the .env.example file.
     *
     * @environment Environment the build process is running, staging or production
     * @composeFile The name of the Compose/Stack file to use in the Local Environment - Defaulting to docker-compose.yml
     * @serviceName The name of the Service in the Compose/Stack file to use in the Local Environment - Defaulting to the Environment Name
     */
    function checkLocalStack( 
        environment="staging", 
        composeFile="docker-compose.yml", 
        serviceName="", 
        envExampleFile=".env.example" 
    ){
        setVariables( argumentCollection=arguments );
		var composeFile = validateDockerComposeFile();
        dotEnvCheck();
    }

    /**
     * CheckLocalSecrets function to verify the Compose file in the repo has all of the secrets setup correctly for the service, and top level in the Docker Compose file, including secrets expected by CommandBox's `<<SECRET:MY_SECRET_NAME>>` format.
     *
     * @environment Environment the build process is running, staging or production
     * @composeFile The name of the Compose/Stack file to use in the Local Environment - Defaulting to docker-compose.yml
     * @serviceName The name of the Service in the Compose/Stack file to use in the Local Environment - Defaulting to the Environment Name
     */
    function checkLocalSecrets( environment="staging", composeFile="docker-compose.yml", serviceName="" ){
        setVariables( argumentCollection=arguments );
        checkComposeSecrets();
    }

    /**
     * CheckRemoteStack function tries to verify and validate the Stack file in Portainer vs the Compose file in the repo and the env variables in the .env.example file.
     *
     * @environment Environment the build process is running, staging or production
     * @stackID The stackID for this site in Portainer for the given environment
     * @portainerUsername The username to log into Portainer with
     * @portainerPassword The password to log into Portainer with
     * @portainerURL The Portainer URL for this environment
     * @composeFile The name of the Compose/Stack file to use in the Local Environment - Defaulting to docker-compose.yml
     */
    function checkRemoteStack( environment="staging", required stackID, required portainerUsername, required portainerPassword, required portainerURL, composeFile="docker-compose.yml", serviceName="", envExampleFile=".env.example" ){
        setVariables( argumentCollection=arguments );
        getStackFileFromPortainer();
        diffFiles();
    }

    /**
     * Run the putStack function to update Stack file in Portainer with the Compose file in the repo. This auto updates the service.
     *
     * @environment Environment the build process is running, staging or production
     * @stackID The stackID for this site in Portainer for the given environment
     * @portainerUsername The username to log into Portainer with
     * @portainerPassword The password to log into Portainer with
     * @portainerURL The Portainer URL for this environment
     * @composeFile The name of the Compose/Stack file to use in the Local Environment - Defaulting to docker-compose.yml
     */
    function putStack( environment="staging", stackID, portainerUsername, portainerPassword, portainerURL, composeFile="docker-compose.yml", serviceName="" ){
        setVariables( argumentCollection=arguments );
        var composeFile = validateDockerComposeFile();
        //dotEnvCheck();
        var newStackBody = {
            "StackFileContent": composeFile,
            "Prune": false
        };
        cfhttp( method="put", url="#portainerURL#/api/stacks/#stackID#", result="result"  ){
            cfhttpparam( type="header", name="Authorization", value="Bearer #portainerLogin()#" );
            cfhttpparam( type="url", name="endpointId", value="#getStackFromPortainer().EndpointId#" );
            cfhttpparam( type="body", name="body", value="#serializeJSON( newStackBody )#" );
        }
        if( result.status_text != "OK" && result.fileContent == "Connection Failure"){
            error( "Error Communicating with Portainer Instance", result );
        } else if( result.status_text != "OK" ){    
			error( "Error updating Stack File", serializeJSON( result ) );
        } else {
            print.green( "Stack file updated - service is updating" ).line().toConsole();
        }
    }

    /**
     * Verify and validate the list of Secrets setup in Portainer vs the Compose file in the repo.
     *
     * @environment Environment the build process is running, staging or production
     * @stackID The stackID for this site in Portainer for the given environment
     * @portainerUsername The username to log into Portainer with
     * @portainerPassword The password to log into Portainer with
     * @portainerURL The Portainer URL for this environment
     * @composeFile The name of the Compose/Stack file to use in the Local Environment - Defaulting to docker-compose.yml
     */
    function checkRemoteSecrets( 
        environment="staging", 
        required stackID, 
        required portainerUsername, 
        required portainerPassword, 
        required portainerURL, 
        composeFile="docker-compose.yml", 
        serviceName="", 
        envExampleFile=".env.example" 
    ){
        setVariables( argumentCollection=arguments );
        
        var secretNames = getSecretNamesFromPortainer();
        var composeFileObject = getComposeFileObject();

        if( !structKeyExists( composeFileObject, "secrets" ) ){
            print.line().greenLine( "No Top Level Secrets in Compose File to compare" ).line().toConsole();
        } else {
            var errorCount = 0;
            for( var secret in composeFileObject.secrets ){
                if( arrayFindNoCase( secretNames, secret ) == 0 ){
                    print.magenta( "Docker Compose has a secret defined called '#secret#' that does not exist in Portainer" ).line().toConsole();
                    errorCount++;
                }
            }
            if( errorCount ){
                error( "Secrets in Compose File are not setup in Portainer" );
            } else {
                print.line().greenLine( "All Secrets in Compose File are setup in Portainer" ).line().toConsole();
            }
        }
        

    }

    /********************************************************************************************/
    /***************************    PRIVATE FUNCTIONS    ****************************************/
    /********************************************************************************************/
    
    /**
     * Gets the Secrets from Portainer as an Array of Structs
     */
    private function getSecretsFromPortainer(){
        cfhttp( url="#portainerURL#/api/endpoints/#getEndpointID()#/docker/secrets" ){
            cfhttpparam( type="header", name="Authorization", value="Bearer #portainerLogin()#" );
		}
        var secrets = deserializeJSON( cfhttp.fileContent );
        return secrets;
    }

    private function getEndpointID(){
        print.line().line( "Getting Endpoint ID" ).toConsole();
        return getStackFromPortainer().EndpointId;
    }

    /**
     * Gets an Array of Secret Names from Portainer
     */
    array private function getSecretNamesFromPortainer( verbose=false ){
        var secretNames = getSecretsFromPortainer().map( function( item ){
            return item.Spec.Name;
        });
        if( verbose ){
            print.line().greenline( "Outputting list of Secrets Available in Portainer" ).line().toConsole();
            for( var secret in secretNames ){
                print.line( secret );
            }
            print.line().toConsole();
        }
        return secretNames;
    }
    
    /**
     * Sets variables and defaults up for the Task Runner
     *
     * @environment Environment the build process is running, staging or production
     * @stackID The stackID for this site in Portainer for the given environment
     * @portainerUsername The username to log into Portainer with
     * @portainerPassword The password to log into Portainer with
     * @portainerURL The Portainer URL for this environment
     * @composeFile The name of the Compose/Stack file to use in the Local Environment - Defaulting to docker-compose.yml
     * @serviceName The name of the Service which helps find `docker-compose.yml` file by Convention as well.
     * @envExampleFile The name of the .env example file to use in the Local Environment - Defaulting `.env.example`
     */
    private function setVariables( 
        environment="staging", 
        stackID="", 
        portainerUsername="", 
        portainerPassword="", 
        portainerURL="", 
        composeFile="docker-compose.yml", 
        serviceName="", 
        envExampleFile=".env.example" ,
        composePath=""
    ){
        if( arguments.environment.len() ){
            variables.environment           = arguments.environment;
        } else {
            variables.environment           = "staging"
        }
        if( arguments.stackID.len() ){
            variables.stackID               = arguments.stackID;
        } else {
            variables.stackID           = "UNKNOWN-STACK-ID";
        }
        variables.portainerUsername     = arguments.portainerUsername;
        variables.portainerPassword     = arguments.portainerPassword;
        variables.portainerURL          = arguments.portainerURL;
        if( arguments.composeFile.len() ){
            variables.composeFile           = arguments.composeFile;
        } else {
            variables.composeFile       = "docker-compose.yml";
        }
        if( arguments.composePath.len() ){
            variables.composePath           = arguments.composePath;
        } else {
            variables.composePath       = "";
        }
        if( arguments.serviceName.len() ){
            variables.serviceName       = arguments.serviceName;
        } else {
            variables.serviceName       = arguments.environment;
        }
        if( arguments.envExampleFile.len() ){
            variables.envExampleFile       = arguments.envExampleFile;
        } else {
            variables.envExampleFile       = ".env.example";
        }
    }

    /**
     * Setup the Yaml Parser
     *
     * returns Parser from the CBYaml module
     */
    private function setupYamlParser(){
        loadModule( 'modules/cbyaml' );
        return getInstance( "parser@cbyaml" );
    }

    /**
     * Creates a .env.stack file from the environment variables in the environments docker-compose.yml.
     */
    private function createEnvStackFile(){
        var composeFileObject = getComposeFileObject();
        fileWrite( resolvePath( ".env.stackFile", getCWD() ), "" );
        if( structKeyExists( composeFileObject, "services" )
            && structKeyExists( composeFileObject.services, serviceName )
            && structKeyExists( composeFileObject.services[ serviceName ], "environment" ) 
            && arrayLen( composeFileObject.services[ serviceName ].environment ) ){
            for( var envVar in composeFileObject.services[ serviceName ].environment ){
                fileAppend( filepath=resolvePath( ".env.stackFile", getCWD() ), data=envVar& chr(13) );
            }
        } else {
            print.magenta( "No Environment Variables in Compose File to compare" ).line().toConsole();
        }
    }

    function getComposeFileObject(){
        var parser = setupYamlParser();
        if( len( variables.composePath ) && fileExists( resolvePath( variables.composePath & variables.composeFile, getCWD() ) ) ){
            var composeFile = fileRead( resolvePath( variables.composePath & variables.composeFile, getCWD() ) );
        } else {
            var composeFile = fileRead( resolvePath( "build/env/#variables.environment#/#variables.composeFile#", getCWD() ) );
        }
        return parser.deserialize( composeFile );
    }

    /**
     * Creates a .env.stack file from the environment variables in the environments docker-compose.yml.
     */
    function checkComposeSecrets(){
        var composeFileObject = getComposeFileObject();
        var errorCount = 0;
        var serviceSecrets = {};
        if( structKeyExists( composeFileObject.services[ serviceName ], "secrets" ) && arrayLen( composeFileObject.services[ serviceName ].secrets ) ){
            for( var envVar in composeFileObject.services[ serviceName ].secrets ){
                serviceSecrets[ listFirst( envVar, "=" ) ] = listDeleteAt( envVar, 1, "=" );
            }
            if( !structKeyExists( composeFileObject, "secrets" ) ){
                print.magenta( "No Top Level Secrets in Compose File to compare" ).line().toConsole();
                for( var envVar in composeFileObject.services[ serviceName ].secrets ){
                    print.magenta( "Service has defined Secret called '#envVar#' that does not exist in top level of Compose File" ).line().toConsole();
                    errorCount++;
                }
            } else {
                for( var envVar in composeFileObject.services[ serviceName ].secrets ){
                    if( !structKeyExists( composeFileObject.secrets, envVar ) ){
                        print.magenta( "Service has defined Secret called '#envVar#' that does not exist in top level of Compose File" ).line().toConsole();
                        errorCount++;
                    }
                }
            }
        } else {
            if( structKeyExists( composeFileObject, "secrets" ) ){
                print.cyan( "Compose File has Secrets, but service has no secrets to compare" ).line().toConsole();
            } else {
                print.cyan( "No Secrets in Compose File to compare" ).line().toConsole();
            } 
        }

        if( structKeyExists( composeFileObject.services[ serviceName ], "environment" ) && arrayLen( composeFileObject.services[ serviceName ].environment ) ){
            for( var envVar in composeFileObject.services[ serviceName ].environment ){
                var result = refindNoCase( "<<SECRET:(.*)>>", envVar, 1, true, "ALL" );
                if( arrayLen( result ) and result[ 1 ][ "len" ][1] > 0 ){
                    for( var needle in result ){
                        print.cyan( "#serviceName# Service uses the '#needle[ "MATCH" ][2]#' secret via CommandBox in the Env Variable: #listFirst( envVar, "=")#" ).line().toConsole();
                        if( !structKeyExists( composeFileObject, "secrets" ) || !structKeyExists( composeFileObject.secrets, needle[ "MATCH" ][2] ) ){
                            print.magenta( "Docker Compose #serviceName# Service is referencing a Secret via CommandBox called '#needle[ "MATCH" ][2]#' that is missing from the top level Secrets" ).line().toConsole();
                            errorCount++;
                        } 
                        if( !structKeyExists( serviceSecrets, needle[ "MATCH" ][2] ) ){
                            print.magenta( "Docker Compose #serviceName# Service is referencing a Secret via CommandBox called '#needle[ "MATCH" ][2]#' that is missing from the Service Level Secrets" ).line().toConsole();
                            errorCount++;
                        }
                    }
                    print.line().toConsole();
                }
            }
        }

        if( errorCount ){
            error( "Secrets in Compose File are not setup correctly" );
        }
    }

    /**
     * Diffs the stackFile from Portainer ( stored as stack.yml locally ) and the environments docker-compose.yml
     */
    private function diffFiles(){
        
        print.line( "Diffing Files" ).toConsole();
        if( len( variables.composePath ) && fileExists( resolvePath( variables.composePath & variables.composeFile, getCWD() ) ) ){
            var composePath = resolvePath( variables.composePath & variables.composeFile, getCWD() );
        } else {
            var composePath = resolvePath( "build/env/#variables.environment#/#variables.composeFile#", getCWD() );
        }

        command( "!diff" )
            .params(
                "-c",
                resolvePath( "stack.yml", getCWD() ),
                composePath
            )
            .run();
        print.green( "Diff Successful" ).toConsole();
    }

    /**
     * Performs a dotEnv check of the .env.stackFile against the .env.example file. It performs a forward and reverse check.
     */
    private function dotEnvCheck( envExampleFile=variables.envExampleFile ){
        print.line().line().bold( "Running DotEnv Check" ).line().toConsole();
        createEnvStackFile();
        
        print.line( "Checking all #arguments.envExampleFile# variables exist in the local Compose file #variables.composeFile#" ).toConsole();
        command( "dotenv check" )
            .params(
                "envFileName" = ".env.stackFile",
                "envExampleFileName" = arguments.envExampleFile
            )
            .run();
            
        print.line( "Checking all local #variables.composeFile# env variables exist in the .env.example file" ).toConsole();
        command( "dotenv check" )
            .params(
                "envFileName" = ".env.stackFile",
                "envExampleFileName" = arguments.envExampleFile,
                "reverse" = true
            )
            .run();
    }

    /**
     * Determines if the environments docker-compose.yml file is syntactically valid yml file.
     *
     * @returns The string of the contents of the docker-compose.yml file
     */
    private function validateDockerComposeFile(){
        print.line().line( "Checking for valid Yaml File" ).toConsole();
        var composeFileObject = getComposeFileObject();
        print.green( "Docker Compose is a valid Yaml File" ).line().toConsole();
        return composeFile;
    }

    /**
     * Determines if the portainer stack file is syntactically valid yml file.
     *
     * @returns The string of the contents of the docker-compose.yml file
     */
    private function validateStackFile(){
        print.line().line( "Checking for valid Yaml File" ).toConsole();
        var parser = setupYamlParser();
        var composeFile = fileRead( resolvePath( "stack.yml", getCWD() ) );
        var composeFileObject = parser.deserialize( composeFile );
        print.green( "Stack file is a valid Yaml File" ).line().toConsole();
        return composeFile;
    }

    /**
     * Gets the Stack File from Portainer for comparison and stores it in the stack.yml locally
     */
    private function getStackFileFromPortainer(){
        print.line().bold( "Reading Stack File from Portainer" ).line().toConsole();

        var result = "";
        cfhttp( url="#portainerURL#/api/stacks/#stackID#/file" ){
            cfhttpparam( type="header", name="Authorization", value="Bearer #portainerLogin()#" );
		}
        print.line( "Outputting Stack File Debug Code" );
        print.line( serializeJSON( cfhttp ) ).toConsole();
        var stackFile = replaceNoCase( deserializeJSON( cfhttp.fileContent ).StackFileContent, "\n", chr(13), "all" );
        stackFile = replaceNoCase( stackFile, '\"', '"', "all" );
        fileWrite( resolvePath( "stack.yml", getCWD() ), stackFile );
        print.line( "Stack.yml file created" ).toConsole();
        validateStackFile();
        return stackFile;
    }

    /**
     * Gets the stack details object from Portainer and returns the struct
     */
    private function getStackFromPortainer(){
        var result = "";
        print.line().line( "Getting stack Details from Portainer" ).toConsole();
        cfhttp( url="#portainerURL#/api/stacks/#stackID#", result="result" ){
            cfhttpparam( type="header", name="Authorization", value="Bearer #portainerLogin()#" );
        }
        return deserializeJSON( result.fileContent );
    }

    /**
     * Generates the creds object needed to login to Portainer
     */
    private function portainerLoginCreds(){
        return {
            "username": variables.portainerUsername,
            "password": variables.portainerPassword
        }
    }

    /**
     * Logs into Portainer and returns the jwt
     */
    private function portainerLogin(){
        if( variables.jwt.len() ){
            return variables.jwt;    
        }
        print.line().line( "Authenticating with Portainer" ).toConsole();
        var result = "";
        cfhttp( method="post", url="#portainerURL#/api/auth", result="result" ){
            cfhttpparam( type="body", name="body", value="#serializeJSON( portainerLoginCreds() )#" );
        };
        if( result.status_text != "OK" && result.fileContent == "Connection Failure"){
            error( "Error Communicating with Portainer Instance", serializeJSON( result ) );
        } else if( result.status_text != "OK" ){    
			error( "Error Logging into Portainer", serializeJSON( result ) );
        } else {
            var resultObject = deserializeJSON( result.fileContent );
            if( structKeyExists( resultObject, "jwt" ) ){
                variables.jwt = resultObject.jwt;
                return resultObject.jwt;
            } else {
                print.line( "JWT not returned" ).toConsole();
                // print.line( portainerLoginCreds() );
                print.line( result ).toConsole();
            }
        }
    }
}
