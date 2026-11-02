//
// Sample-name rules shared by the sample sheet (--input), the FASTQ folder
// (--infolder) and the CAGEr sample list (--cager_sample_file): a sample name
// must not contain spaces or hyphens and must not start with a digit, because
// the names end up as file names, column names and R identifiers downstream.
// Names that break the rules are amended automatically (never rejected):
//   spaces  -> underscores
//   hyphens -> underscores
//   leading digit -> 'Sample' is put in front (23_KO -> Sample23_KO)
// and one warning per amended name tells the user what was changed.
//

// Returns [amended_name, list_of_changes_applied] (changes is empty when the name was fine).
def fixSampleName(String name) {
    def fixed = name.trim()
    def changes = []
    if (fixed =~ /\s/) {
        fixed = fixed.replaceAll(/\s+/, '_')
        changes << "spaces were replaced with underscores"
    }
    if (fixed.contains('-')) {
        fixed = fixed.replaceAll('-', '_')
        changes << "hyphens were replaced with underscores"
    }
    if (fixed ==~ /^[0-9].*/) {
        fixed = "Sample" + fixed
        changes << "'Sample' was added at the beginning because the name started with a digit"
    }
    return [fixed, changes]
}

// Amend a list of user-provided names, warning once per amended name.
// Returns a map original_name -> amended_name (identity for valid names).
def amendSampleNames(List names, String source) {
    def mapping = [:]
    names.findAll { n -> n != null }.unique().each { String n ->
        def (fixed, changes) = fixSampleName(n)
        if (changes) {
            log.warn "Sample name '${n}' in the ${source} was automatically changed to '${fixed}': " +
                "${changes.join('; ')}. Sample names must not contain spaces or hyphens and must not start with a digit."
        }
        mapping[n] = fixed
    }
    return mapping
}
