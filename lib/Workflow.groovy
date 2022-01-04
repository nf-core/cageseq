class Workflow {

    // Function that parses and returns the alignment rate from the STAR log output
    static ArrayList getStarPercentMapped(workflow, params, log, align_log) {
        def percent_aligned = 0
        def pattern = /Uniquely mapped reads %\s*\|\s*([\d\.]+)%/
        align_log.eachLine { line ->
            def matcher = line =~ pattern
            if (matcher) {
                percent_aligned = matcher[0][1].toFloat()
            }
        }

        def pass = false
        def logname = align_log.getBaseName() - '.Log.final'
        Map colors = Utils.logColours(params.monochrome_logs)
        if (percent_aligned <= params.min_mapped_reads.toFloat()) {
            log.info "-${colors.purple}[$workflow.manifest.name]${colors.red} [FAIL] STAR ${params.min_mapped_reads}% mapped threshold. IGNORING FOR FURTHER DOWNSTREAM ANALYSIS: ${percent_aligned}% - $logname${colors.reset}."
        } else {
            pass = true
            log.info "-${colors.purple}[$workflow.manifest.name]${colors.green} [PASS] STAR ${params.min_mapped_reads}% mapped threshold: ${percent_aligned}% - $logname${colors.reset}."
        }
        return [ percent_aligned, pass ]
    }

    //    Function that parses and returns the alignment rate from the bowtie log output
    static ArrayList getBowtiePercentMapped(workflow, params, log, align_log) {
        def percent_aligned = 0
        def pattern = /# reads with at least one alignment:\s*\d*\s*\((\d*\.\d*)%\)/
        align_log.eachLine { line ->
            def matcher = line =~ pattern
            if (matcher) {
                percent_aligned = matcher[0][1].toFloat()
            }
        }
        def pass = false
        def logname = align_log.getBaseName()
        Map colors = Utils.logColours(params.monochrome_logs)
        if (percent_aligned <= params.min_mapped_reads.toFloat()) {
            log.info "-${colors.purple}[$workflow.manifest.name]${colors.red} [FAIL] BOWTIE ${params.min_mapped_reads}% mapped threshold. IGNORING FOR FURTHER DOWNSTREAM ANALYSIS: ${percent_aligned}% - $logname${colors.reset}."
        } else {
            pass = true
            log.info "-${colors.purple}[$workflow.manifest.name]${colors.green} [PASS] BOWTIE ${params.min_mapped_reads}% mapped threshold: ${percent_aligned}% - $logname${colors.reset}."
        }
        return [ percent_aligned, pass ]
    }

}