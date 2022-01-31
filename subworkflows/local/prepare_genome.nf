//
// Uncompress and prepare reference genome files
//

include { GUNZIP as GUNZIP_FASTA      } from '../../modules/nf-core/modules/gunzip/main'
include { GUNZIP as GUNZIP_GTF        } from '../../modules/nf-core/modules/gunzip/main'
include { GUNZIP as GUNZIP_GFF        } from '../../modules/nf-core/modules/gunzip/main'

include { UNTAR as UNTAR_STAR_INDEX   } from '../../modules/nf-core/modules/untar/main'
include { UNTAR as UNTAR_BOWTIE_INDEX } from '../../modules/nf-core/modules/untar/main'

include { GFFREAD                     } from '../../modules/nf-core/modules/gffread/main'
include { CUSTOM_GETCHROMSIZES        } from '../../modules/nf-core/modules/custom/getchromsizes/main'

include { STAR_GENOMEGENERATE         } from '../../modules/nf-core/modules/star/genomegenerate/main'
include { BOWTIE_BUILD                } from '../../modules/nf-core/modules/bowtie/build/main'

include { GTF2BED                     } from '../../modules/local/gtf2bed'

workflow PREPARE_GENOME {

    main:

    ch_versions = Channel.empty()

    //
    // Uncompress genome fasta file if required
    //
    if (params.fasta.endsWith('.gz')) {
        ch_fasta    = GUNZIP_FASTA ( [ [:], params.fasta ] ).gunzip.map { it[1] }
        ch_versions = ch_versions.mix(GUNZIP_FASTA.out.versions)
    } else {
        ch_fasta = file(params.fasta)
    }

    //
    // Uncompress GTF annotation file or create from GFF3 if required
    //
    if (params.gtf) {
        if (params.gtf.endsWith('.gz')) {
            ch_gtf      = GUNZIP_GTF ( [ [:], params.gtf ] ).gunzip.map { it[1] }
            ch_versions = ch_versions.mix(GUNZIP_GTF.out.versions)
        } else {
            ch_gtf = file(params.gtf)
        }
    } else if (params.gff) {
        if (params.gff.endsWith('.gz')) {
            ch_gff      = GUNZIP_GFF ( [ [:], params.gff ] ).gunzip.map { it[1] }
            ch_versions = ch_versions.mix(GUNZIP_GFF.out.versions)
        } else {
            ch_gff = file(params.gff)
        }
        ch_gtf      = GFFREAD ( ch_gff ).gtf
        ch_versions = ch_versions.mix(GFFREAD.out.versions)
    }

    //
    // create bed file from gtf, for re
    //
    ch_gene_bed = Channel.empty()
    if (!params.skip_qc || !params.skip_tag_cluster_qc || !params.skip_ctss_clustering) {
        ch_gene_bed = GTF2BED ( ch_gtf ).bed
        ch_versions = ch_versions.mix(GTF2BED.out.versions)
    }

    //
    // Create chromosome sizes file
    //
    ch_chrom_sizes = CUSTOM_GETCHROMSIZES ( ch_fasta ).sizes
    ch_versions    = ch_versions.mix(CUSTOM_GETCHROMSIZES.out.versions)

    //
    // Uncompress STAR index or generate from scratch if required
    //
    ch_star_index = Channel.empty()
    ch_bowtie_index = Channel.empty()
    if (params.aligner == 'star') {
        if (params.star_index) {
            if (params.star_index.endsWith('.tar.gz')) {
                ch_star_index = UNTAR_STAR_INDEX ( params.star_index ).untar
                ch_versions   = ch_versions.mix(UNTAR_STAR_INDEX.out.versions)
            } else {
                ch_star_index = file(params.star_index)
            }
        } else {
            ch_star_index = STAR_GENOMEGENERATE ( ch_fasta, ch_gtf ).index
            ch_versions   = ch_versions.mix(STAR_GENOMEGENERATE.out.versions)
        }
    }
    if (params.aligner == 'bowtie') {
        if (params.bowtie_index) {
            if (params.bowtie_index.endsWith('.tar.gz')) {
                ch_bowtie_index = UNTAR_BOWTIE_INDEX ( params.bowtie_index ).untar
                ch_versions   = ch_versions.mix(UNTAR_BOWTIE_INDEX.out.versions)
            } else {
                ch_bowtie_index = file(params.bowtie_index)
            }
        } else {
            ch_bowtie_index = BOWTIE_BUILD ( ch_fasta ).index
            ch_versions   = ch_versions.mix(BOWTIE_BUILD.out.versions)
        }
    }


    emit:
    fasta            = ch_fasta            //    path: genome.fasta
    gtf              = ch_gtf              //    path: genome.gtf
    gene_bed         = ch_gene_bed         //    path: gene.bed
    chrom_sizes      = ch_chrom_sizes      //    path: genome.sizes
    star_index       = ch_star_index       //    path: star/index/
    bowtie_index     = ch_bowtie_index     //    path: bowtie/index/

    versions         = ch_versions.ifEmpty(null) // channel: [ versions.yml ]
}
