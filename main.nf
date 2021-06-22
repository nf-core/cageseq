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

log.info Utils.logo(workflow, params.monochrome_logs)

def json_schema = "$projectDir/nextflow_schema.json"
if (params.help) {
    def command = 'nextflow run nf-core/cageseq --input samplesheet.csv --genome GRCh38 -profile docker'
    log.info NfcoreSchema.params_help(workflow, params, json_schema, command)
    log.info Utils.dashedLine(params.monochrome_logs)
    exit 0
}


////////////////////////////////////////////////////
/* --         VALIDATE PARAMETERS              -- */
////////////////////////////////////////////////////+
def unexpectedParams = []
if (params.validate_params) {
    unexpectedParams = NfcoreSchema.validateParameters(params, json_schema, log)
}

////////////////////////////////////////////////////
/* --         PRINT PARAMETER SUMMARY          -- */
////////////////////////////////////////////////////

def summary_params = NfcoreSchema.params_summary_map(workflow, params, json_schema)
log.info NfcoreSchema.params_summary_log(workflow, params, json_schema)
log.info Utils.dashedLine(params.monochrome_logs)

////////////////////////////////////////////////////
/* --          PARAMETER CHECKS                -- */
////////////////////////////////////////////////////

// Check AWS batch settings
Checks.awsBatch(workflow, params)

// Check the hostnames against configured profiles
Checks.hostName(workflow, params, log)

/////////////////////////////
/* -- RUN MAIN WORKFLOW -- */
/////////////////////////////

workflow {
    include { CAGESEQ } from './workflows/cageseq'
    CAGESEQ ()
}

workflow.onError {
    // Print unexpected parameters
    for (p in unexpectedParams) {
        log.warn "Unexpected parameter: ${p}"
    }
}

/////////////////////////////
/* -- THE END -- */
/////////////////////////////
