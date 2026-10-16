//
// Modifying sample sheet for relative inputs for processing
//

process RELATIVISATION {
    label 'process_medium'
    stageInMode 'copy'

    input:
    path sample_file

    output:
    path "sample_list_relativepath.csv"

    script:
    """
    make_paths_relative.py -f "${sample_file}"
    """
}
