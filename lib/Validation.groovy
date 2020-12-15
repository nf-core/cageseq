import groovy.json.JsonSlurper
import groovy.util.logging.Log

class Validation {

    /*
    * Function to loop over all parameters defined in schema and check
    * whether the given paremeters adhere to the specificiations
    */
    private static void validateParameters(params, json_schema, log, workflow){

        def json = new File(json_schema).text
        def Map json_params = (Map) new JsonSlurper().parseText(json).get('definitions')
        def specified_param_keys = params.keySet()
        def nf_params = ['profile', 'config', 'c', 'C', 'syslog', 'd', 'dockerize', 
                        'bg', 'h', 'log', 'quiet', 'q', 'v', 'version']
        def valid_params = []
        def expected_params = []

        // Loop over all parameters in schema and compare to given parameters
        for (group in json_params){
            for (p in group.value['properties']){
                valid_params.push(validateParamPair(params[p.key], p, log))
                expected_params.push(p.key)
            }
        }

        // Check for nextflow core params and unexpected params
        for (specified_param in specified_param_keys){
            // nextflow params
            if (nf_params.contains(specified_param)){
                log.error "ERROR: That's a nextflow param!"
            }
            // unexpected params
            if (!expected_params.contains(specified_param)){
                log.warn "Unexpected parameter specified: ${specified_param}"               
            }
            
        }

    }

    /*
    * Compare a pair of params (schema, command line) and check whether 
    * they are valid
    */
     private static boolean validateParamPair(given_param, json_param, log){
        def param_type = json_param.value['type']
        def valid_param = false
        def required = json_param.value['required']
        def param_enum = json_param.value['enum']
        // Get the expected class
        def schema_param_class = determineDefaultClass(json_param)

        
        // Check only if required or parameter is given
        if (required || given_param){
            def given_param_class = given_param.getClass()

                switch(param_type) {
                    case 'string':
                        // memory
                        if (schema_param_class == nextflow.util.MemoryUnit || given_param_class == nextflow.util.MemoryUnit){
                            valid_param = given_param.toString() ==~ /\d+\.?\s*[KMGT]?B?/
                        }
                         // duration
                        else if (schema_param_class == nextflow.util.Duration || given_param_class == nextflow.util.Duration){
                            valid_param = given_param.toString() ==~ /\d+\.?\s*[mhd]/
                        }
                         // hashmap
                        else if (schema_param_class == LinkedHashMap || given_param_class == LinkedHashMap){
                            valid_param = true // TODO change this later too
                        }
                         // enum
                        else if (param_enum){
                            valid_param = param_enum.contains(given_param)
                        }
                        // normal string
                        else {
                            valid_param = given_param_class == String
                        }  
                        break
                    case 'boolean':
                        if (given_param_class == Boolean){
                            valid_param = true
                        }
                        else if (given_param){
                            valid_param = true
                        }
                        break
                    case 'integer':
                        valid_param = given_param_class == Integer
                        break
                    case 'number':
                        valid_param = given_param_class == BigDecimal
                        break
                }

            if (!valid_param){
                log.error "ERROR: Parameter ${json_param.key} is wrong type! Expected ${schema_param_class}, found ${param_type}, ${given_param}"
                if (param_enum){
                    log.error "Must be one of: ${param_enum}"
                }
            }

        }
        return valid_param
     }

    private static Class determineDefaultClass(json_param){
        def default_value = json_param.value['default']
        def schema_param_class = default_value.getClass()

        // If value is not null, try to cast to other objects
        if (default_value){
            // try memory object
            try {
                default_value as nextflow.util.MemoryUnit
                schema_param_class = nextflow.util.MemoryUnit
            }catch (Exception) {}

            // try duration object
            try {
                default_value as nextflow.util.Duration
                schema_param_class = nextflow.util.Duration
            } catch (Exception) {}
        }


        return schema_param_class
    }
}