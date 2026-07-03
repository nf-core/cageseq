//
// Modifying sample sheet for relative inputs for processing
//

process RELATIVISATION {
    label 'process_medium'
    stageInMode 'copy'

    input:
    path sample_file

    output:
    path "cager_sample_list.csv"

    """
    make_paths_relative.py -f "${sample_file}"
    mv sample_list_relativepath.csv cager_sample_list.csv
    """
}
