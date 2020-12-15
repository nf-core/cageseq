import groovy.json.JsonSlurper

class Validation {

    /*
    * Function to loop over all parameters defined in schema and check
    * whether the given paremeters adhere to the specificiations
    */
    private static void validateParameters(params, json_schema){

        def json = new File(json_schema).text
        def Map json_params = (Map) new JsonSlurper().parseText(json).get('definitions')
        def specified_param_keys = params.keySet()
        def nf_params = ['profile', 'config', 'c', 'q', 'syslog', 'v', 'dockerize']

        def expected_params = []

        // Loop over all parameters in schema and compare to given parameters
        for (group in json_params){
            for (p in group.value['properties']){
                validateParamPair(params[p.key], p)
                expected_params.push(p.key)
            }
        }

        // Check for nextflow core params and unexpected params
        for (specified_param in specified_param_keys){
            // nextflow params
            if (nf_params.contains(specified_param)){
                println("That's a nextflow param!")
            }
            // unexpected params
            if (!expected_params.contains(specified_param)){
                println("UNEXPECTED PARAM")
                println(specified_param)
            }
            
        }

    }

    /*
    * Compare a pair of params (schema, command line) and check whether 
    * they are valid
    */
     private static boolean validateParamPair(given_param, json_param){
        def param_type = json_param.value['type']
        def valid_param = false
        def required = json_param.value['required']

        // Check only if required or parameter is given
        if (required || given_param){
            def given_param_class = given_param.getClass()

                switch(given_param_class) {
                    case String:
                        valid_param = param_type == 'string'
                        break
                    case java.lang.Boolean:
                        valid_param = param_type == 'boolean'
                        break
                    case Integer:
                        valid_param = param_type == 'integer'
                        break
                    case nextflow.util.MemoryUnit:
                        valid_param = (param_type == 'string' && given_param.toString() ==~ /\d+\.?\s*[KMGT]?B?/)
                        break
                    case nextflow.util.Duration:
                        valid_param = (param_type == 'string' && given_param.toString() ==~ /\d+\.?\s*[mhd]/)
                        break
                    case java.math.BigDecimal:
                        valid_param = param_type == 'number'
                        break
                    case java.util.LinkedHashMap:
                        valid_param = param_type == 'string'
                }

            if (!valid_param){
                println("Parameter ${json_param.key} is wrong type! Expected ${param_type}, found ${given_param.getClass()}, ${given_param}")
            }

        }
        return valid_param
     }
}