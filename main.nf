#!/usr/bin/env nextflow
/*
========================================================================================
                                    nf-core/cageseq
========================================================================================
nf-core/cageseq Analysis Pipeline.
#### Homepage / Documentation
https://github.com/nf-core/cageseq
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

////////////////////////////////////////////////////
/* --               PRINT HELP                 -- */
////////////////////////////////////////////////////

def json_schema = "$baseDir/nextflow_schema.json"
if (params.help) {
    def command = "nextflow run nf-core/cageseq --input samplesheet.csv --genome GRCh38 -profile docker"
    log.info Schema.params_help(workflow, params, json_schema, command)
    exit 0
}

////////////////////////////////////////////////////
/* --         VALIDATE PARAMETERS              -- */
////////////////////////////////////////////////////
Validation.validateParameters(params, json_schema)
////////////////////////////////////////////////////
/* --         PRINT PARAMETER SUMMARY          -- */
////////////////////////////////////////////////////

def summary_params = Schema.params_summary_map(workflow, params, json_schema)
log.info Schema.params_summary_log(workflow, params, json_schema)

////////////////////////////////////////////////////
/* --          PARAMETER CHECKS                -- */
////////////////////////////////////////////////////

// Check AWS batch settings
Checks.aws_batch(workflow, params)

// Check the hostnames against configured profiles
Checks.hostname(workflow, params, log)


/////////////////////////////
/* -- RUN MAIN WORKFLOW -- */
/////////////////////////////

workflow {
    include { CAGESEQ } from './cageseq'
    CAGESEQ ()
}

/////////////////////////////
/* -- THE END -- */
/////////////////////////////