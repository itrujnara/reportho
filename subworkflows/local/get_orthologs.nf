include { IDENTIFY_SEQ_ONLINE          } from "../../modules/local/identify_seq_online"
include { WRITE_SEQINFO                } from "../../modules/local/write_seqinfo"

include { FETCH_OMA_GROUP_ONLINE       } from "../../modules/local/fetch_oma_group_online"
include { FETCH_PANTHER_GROUP_ONLINE   } from "../../modules/local/fetch_panther_group_online"
include { FETCH_INSPECTOR_GROUP_ONLINE } from "../../modules/local/fetch_inspector_group_online"

include { FETCH_OMA_GROUP_LOCAL        } from "../../modules/local/fetch_oma_group_local"
include { FETCH_PANTHER_GROUP_LOCAL    } from "../../modules/local/fetch_panther_group_local"
include { FETCH_EGGNOG_GROUP_LOCAL     } from "../../modules/local/fetch_eggnog_group_local"

include { CSVTK_JOIN as MERGE_CSV      } from "../../modules/nf-core/csvtk/join/main"

workflow GET_ORTHOLOGS {
    take:
    ch_samplesheet_query
    ch_samplesheet_fasta
    ch_oma_groups
    ch_oma_uniprot
    ch_oma_ensembl
    ch_oma_refseq
    ch_panther
    ch_eggnog
    ch_eggnog_idmap

    main:
    ch_versions     = Channel.empty()
    ch_orthogroups  = Channel.empty()

    ch_samplesheet_fasta.map {
        if (params.offline_run) {
            error "Tried to use FASTA input in an offline run. Aborting pipeline for user safety."
        }
        return it
    }.set { ch_samplesheet_fasta }

    // Preprocessing - find the ID and taxid of the query sequences

    ch_samplesheet_fasta
        .map { it -> [it[0], file(it[1])] }
        .set { ch_fasta }

    IDENTIFY_SEQ_ONLINE (
        ch_fasta
    )

    ch_versions = ch_versions.mix(IDENTIFY_SEQ_ONLINE.out.versions)

    WRITE_SEQINFO (
        ch_samplesheet_query,
        params.offline_run
    )

    ch_query = IDENTIFY_SEQ_ONLINE.out.seqinfo.mix(WRITE_SEQINFO.out.seqinfo)
    ch_versions = ch_versions.mix(WRITE_SEQINFO.out.versions)

    // Ortholog fetching

    // OMA

    if (params.use_all || !params.skip_oma) {
        if (params.local_databases) {
            FETCH_OMA_GROUP_LOCAL (
                ch_query,
                ch_oma_groups,
                ch_oma_uniprot,
                ch_oma_ensembl,
                ch_oma_refseq
            )

            ch_orthogroups
                .mix(FETCH_OMA_GROUP_LOCAL.out.oma_group)
                .set { ch_orthogroups }

            ch_versions = ch_versions.mix(FETCH_OMA_GROUP_LOCAL.out.versions)
        }
        else {
            FETCH_OMA_GROUP_ONLINE (
                ch_query
            )

            ch_orthogroups
                .mix(FETCH_OMA_GROUP_ONLINE.out.oma_group)
                .set { ch_orthogroups }

            ch_versions = ch_versions.mix(FETCH_OMA_GROUP_ONLINE.out.versions)
        }
    }

    // PANTHER

    if (params.use_all || !params.skip_panther) {
        if (params.local_databases) {
            FETCH_PANTHER_GROUP_LOCAL (
                ch_query,
                ch_panther
            )

            ch_orthogroups
                .mix(FETCH_PANTHER_GROUP_LOCAL.out.panther_group)
                .set { ch_orthogroups }

            ch_versions = ch_versions.mix(FETCH_PANTHER_GROUP_LOCAL.out.versions)
        } else {
            FETCH_PANTHER_GROUP_ONLINE (
                ch_query
            )

            ch_orthogroups
                .mix(FETCH_PANTHER_GROUP_ONLINE.out.panther_group)
                .set { ch_orthogroups }

            ch_versions = ch_versions.mix(FETCH_PANTHER_GROUP_ONLINE.out.versions)
        }
    }

    // OrthoInspector

    if ((params.use_all || !params.skip_orthoinspector) && !params.local_databases) {
        FETCH_INSPECTOR_GROUP_ONLINE (
            ch_query,
            params.orthoinspector_version
        )

        ch_orthogroups
            .mix(FETCH_INSPECTOR_GROUP_ONLINE.out.inspector_group)
            .set { ch_orthogroups }

        ch_versions = ch_versions.mix(FETCH_INSPECTOR_GROUP_ONLINE.out.versions)
    }

    // EggNOG

    if (params.use_all || (!params.skip_eggnog && params.local_databases)) {
        FETCH_EGGNOG_GROUP_LOCAL (
            ch_query,
            ch_eggnog,
            ch_eggnog_idmap,
            ch_oma_ensembl,
            ch_oma_refseq,
            params.offline_run
        )

        ch_orthogroups
            .mix(FETCH_EGGNOG_GROUP_LOCAL.out.eggnog_group)
            .set { ch_orthogroups }

        ch_versions = ch_versions.mix(FETCH_EGGNOG_GROUP_LOCAL.out.versions)
    }

    // Result merging

    MERGE_CSV (
        ch_orthogroups.groupTuple()
    )

    ch_versions = ch_versions.mix(MERGE_CSV.out.versions)

    ch_versions
        .collectFile(name: "get_orthologs_versions.yml", sort: true, newLine: true)
        .set { ch_merged_versions }

    emit:
    seqinfo     = ch_query
    id          = ch_query.map { it[1] }
    taxid       = ch_query.map { it[2] }
    exact       = ch_query.map { it[3] }
    orthogroups = ch_orthogroups
    orthologs   = MERGE_CSV.out.csv     
    versions    = ch_merged_versions
}
