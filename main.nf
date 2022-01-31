#!/usr/bin/env nextflow
/*
========================================================================================
    nf-core/cageseq
========================================================================================
    Github : https://github.com/nf-core/cageseq
    Website: https://nf-co.re/cageseq
    Slack  : https://nfcore.slack.com/channels/cageseq
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    GENOME PARAMETER VALUES
========================================================================================
*/

params.fasta = WorkflowMain.getGenomeAttribute(params, 'fasta')
params.gtf   = WorkflowMain.getGenomeAttribute(params, 'gtf')

/*
========================================================================================
    VALIDATE & PRINT PARAMETER SUMMARY
========================================================================================
*/

WorkflowMain.initialise(workflow, params, log)

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { CAGESEQ } from './workflows/cageseq'

//
// WORKFLOW: Run main nf-core/cageseq analysis pipeline
//
workflow NFCORE_CAGESEQ {
    CAGESEQ ()
}

/*
========================================================================================
    RUN ALL WORKFLOWS
========================================================================================
*/

//
// WORKFLOW: Execute a single named workflow for the pipeline
// See: https://github.com/nf-core/rnaseq/issues/619
//
workflow {
    NFCORE_CAGESEQ ()
}

/*
========================================================================================
    THE END
========================================================================================
*/
