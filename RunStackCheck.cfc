component {

    property name="environment";
    property name="stackID";
    property name="portainerUsername";
    property name="portainerPassword";
    property name="portainerURL";
    property name="composeFile";
    property name="serviceName";

    /**
     * Run the CheckStack function to verify and validate the Stack file in Portainer vs the Compose file in the repo and the env variables in the .env.example file.
     *
     * @environment Environment the build process is running, staging or production
     * @stackID The stackID for this site in Portainer for the given environment
     * @portainerUsername The username to log into Portainer with
     * @portainerPassword The password to log into Portainer with
     * @portainerURL The Portainer URL for this environment
     * @composeFile The name of the Compose/Stack file to use in the Local Environment - Defaulting to docker-compose.yml
     * @serviceName The name of the Service in the Compose/Stack file to use in the Local Environment - Defaulting to the Environment Name
     */
    function checkLocalStack( environment="staging", required stackID, required portainerUsername, required portainerPassword, required portainerURL, composeFile="docker-compose.yml", serviceName="" ){
        setVariables( argumentCollection=arguments );
		var composeFile = validateDockerComposeFile();
        dotEnvCheck();
    }

    /**
     * Run the CheckStack function to verify and validate the Stack file in Portainer vs the Compose file in the repo and the env variables in the .env.example file.
     *
     * @environment Environment the build process is running, staging or production
     * @stackID The stackID for this site in Portainer for the given environment
     * @portainerUsername The username to log into Portainer with
     * @portainerPassword The password to log into Portainer with
     * @portainerURL The Portainer URL for this environment
     * @composeFile The name of the Compose/Stack file to use in the Local Environment - Defaulting to docker-compose.yml
     */
    function checkRemoteStack( environment="staging", required stackID, required portainerUsername, required portainerPassword, required portainerURL, composeFile="docker-compose.yml", serviceName="" ){
        setVariables( argumentCollection=arguments );
        diffFiles();
        validateStackFile();
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
    function putStack( environment="staging", required stackID, required portainerUsername, required portainerPassword, required portainerURL, composeFile="docker-compose.yml", serviceName="" ){
        setVariables( argumentCollection=arguments );
        var composeFile = validateDockerComposeFile();
        dotEnvCheck();
        var newStackBody = {
            "StackFileContent": composeFile,
            "Prune": false
        };
        cfhttp( method="put", url="#portainerURL#/api/stacks/#stackID#", result="result"  ){
            cfhttpparam( type="header", name="Authorization", value="Bearer #portainerLogin()#" );
            cfhttpparam( type="url", name="endpointId", value="#getStackFromPortainer().EndpointId#" );
            cfhttpparam( type="body", name="body", value="#serializeJSON( newStackBody )#" );
        }
        if( result.status_text != "OK" ){
            print.red( "Error updating Stack File" ).line().toConsole();
            print.line( result );
        } else {
            print.green( "Stack file updated - service is udpating" ).line().toConsole();
        }
    }

    /********************************************************************************************/
    /***************************    PRIVATE FUNCTIONS    ****************************************/
    /********************************************************************************************/
    private function setVariables( environment="staging", required stackID, required portainerUsername, required portainerPassword, required portainerURL, composeFile="docker-compose.yml", serviceName="" ){
        variables.environment           = arguments.environment;
        variables.stackID               = arguments.stackID;
        variables.portainerUsername     = arguments.portainerUsername;
        variables.portainerPassword     = arguments.portainerPassword;
        variables.portainerURL          = arguments.portainerURL;
        variables.composeFile           = arguments.composeFile;
        if( arguments.serviceName.len() ){
            variables.serviceName       = arguments.serviceName;
        } else {
            variables.serviceName       = arguments.environment;
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
        var parser = setupYamlParser();
        var composeFile = fileRead( expandPath( "build/env/#environment#/#variables.composeFile#" ) );
        var composeFileObject = parser.deserialize( composeFile );
        fileWrite( expandPath( ".env.stackFile" ), "" );
        if( structKeyExists( composeFileObject.services[ environment ], "environment" ) && arrayLen( composeFileObject.services[ environment ].environment ) ){
            for( var envVar in composeFileObject.services[ environment ].environment ){
                fileAppend( filepath=expandPath( ".env.stackFile" ), data=envVar& chr(13) );
            }
        } else {
            print.magenta( "No Environment Variables in Compose File to compare" ).line().toConsole();
        }
    }

    /**
     * Diffs the stackFile from Portainer ( stored as stack.yml locally ) and the environments docker-compose.yml
     */
    private function diffFiles(){
        getStackFileFromPortainer();
        print.line( "Diffing Files" ).toConsole();
        command( "!diff" )
            .params(
                "-c",
                expandPath( "stack.yml" ),
                expandPath( "build/env/#environment#/#variables.composeFile#" )
            )
            .run();
        print.green( "Diff Successful" ).toConsole();
    }

    /**
     * Performs a dotEnv check of the .env.stackFaile against the .env.example file. It performs a forward and reverse check.
     */
    private function dotEnvCheck(){
        print.line().line().bold( "Running DotEnv Check" ).line().toConsole();
        createEnvStackFile();
        print.line( "Checking all .env.example variables exist in the local #variables.composeFile# file" ).toConsole();
        command( "dotenv check" )
            .params(
                "envFileName" = ".env.stackFile"
            )
            .run();
        print.line( "Checking all local #variables.composeFile# env variables exist in the .env.example file" ).toConsole();
        command( "dotenv check" )
            .params(
                "envFileName" = ".env.stackFile",
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
        var parser = setupYamlParser();
        var composeFile = fileRead( expandPath( "build/env/#environment#/#variables.composeFile#" ) );
        var composeFileObject = parser.deserialize( composeFile );
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
        var composeFile = fileRead( expandPath( "stack.yml" ) );
        var composeFileObject = parser.deserialize( composeFile );
        print.green( "Stakc file is a valid Yaml File" ).line().toConsole();
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
        fileWrite( expandPath( "stack.yml" ), stackFile );
        print.line( "Stack.yml file created" ).toConsole();
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
        print.line().line( "Authenticating with Portainer" ).toConsole();
        var result = "";
        cfhttp( method="post", url="#portainerURL#/api/auth", result="result" ){
            cfhttpparam( type="body", name="body", value="#serializeJSON( portainerLoginCreds() )#" );
        };
        var resultObject = deserializeJSON( result.fileContent );
        if( structKeyExists( resultObject, "jwt" ) ){
            return resultObject.jwt;
        } else {
            print.line( "JWT not returned" ).toConsole();
            print.line( portainerLoginCreds() );
            print.line( result ).toConsole();
        }
    }
}